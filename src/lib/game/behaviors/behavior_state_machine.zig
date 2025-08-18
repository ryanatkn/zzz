const std = @import("std");
const Vec2 = @import("../../math/mod.zig").Vec2;
const state_machine = @import("../../core/state_machine.zig");

// Import only complex behavior modules that need delegation
const patrol_behavior = @import("patrol_behavior.zig");

/// Specific behavior states for unit AI
pub const BehaviorState = enum {
    idle,
    chasing,
    fleeing,
    patrolling,
    guarding,
    returning_home,

    /// Get the priority of this state (higher = more important)
    pub fn getPriority(self: BehaviorState) u8 {
        return switch (self) {
            .fleeing => 100, // Highest priority - survival
            .chasing => 80, // High priority - engagement
            .guarding => 60, // Medium-high priority - area control
            .patrolling => 40, // Medium priority - routine activity
            .returning_home => 20, // Low priority - maintenance
            .idle => 0, // Lowest priority - default state
        };
    }
};

/// Behavior state machine using the generic infrastructure
pub const BehaviorStateMachine = state_machine.InterruptibleStateMachine(BehaviorState, 16);

/// Context for behavior decision making
pub const BehaviorContext = struct {
    unit_pos: Vec2,
    home_pos: Vec2,
    player_pos: ?Vec2,
    player_alive: bool,
    aggro_multiplier: f32,
    dt: f32,

    // Computed fields for convenience
    distance_from_home: f32,
    distance_to_player: f32,

    pub fn init(unit_pos: Vec2, home_pos: Vec2, player_pos: ?Vec2, player_alive: bool, aggro_multiplier: f32, dt: f32) BehaviorContext {
        const distance_to_player = if (player_pos) |pp| unit_pos.sub(pp).length() else std.math.inf(f32);

        return .{
            .unit_pos = unit_pos,
            .home_pos = home_pos,
            .player_pos = player_pos,
            .player_alive = player_alive,
            .aggro_multiplier = aggro_multiplier,
            .dt = dt,
            .distance_from_home = unit_pos.sub(home_pos).length(),
            .distance_to_player = distance_to_player,
        };
    }
};

/// Profile-specific behavior preferences - simplified taxonomy
pub const BehaviorProfile = enum {
    hostile, // Always aggressive, never flees (red), damages player on collision
    fearful, // Always flees from player (orange/yellow), damages player on collision
    neutral, // Ignores player, returns home when far (gray), damages player on collision
    friendly, // Never attacks, may follow player (green), no collision damage

    /// Get ranges for different behaviors based on profile
    pub fn getRanges(self: BehaviorProfile, base_detection: f32) BehaviorRanges {
        return switch (self) {
            .hostile => .{
                .flee_range = 0.0, // Never flee
                .chase_range = base_detection * 1.5, // Chase far and aggressively
                .guard_range = base_detection * 0.8, // Not used for hostile
                .home_tolerance = 20.0, // Return home when far
            },
            .fearful => .{
                .flee_range = base_detection * 1.5, // Flee early and far
                .chase_range = 0.0, // Never chase
                .guard_range = 0.0, // Not used for fearful
                .home_tolerance = 15.0, // Return home quickly
            },
            .neutral => .{
                .flee_range = 0.0, // Ignore player
                .chase_range = 0.0, // Ignore player
                .guard_range = 0.0, // Not used for neutral
                .home_tolerance = 25.0, // Return home when moderately far
            },
            .friendly => .{
                .flee_range = 0.0, // Never flee
                .chase_range = base_detection * 0.8, // May follow player (not chase)
                .guard_range = 0.0, // Not used for friendly
                .home_tolerance = 30.0, // Can wander far
            },
        };
    }
};

pub const BehaviorRanges = struct {
    flee_range: f32,
    chase_range: f32,
    guard_range: f32,
    home_tolerance: f32,
};

/// Result of behavior state machine update
pub const BehaviorResult = struct {
    velocity: Vec2,
    active_behavior: BehaviorState,
    behavior_changed: bool,

    // Events
    detected_target: bool = false,
    lost_target: bool = false,
    started_fleeing: bool = false,
    stopped_fleeing: bool = false,
    state_changed: bool = false,
};

/// Update behavior state machine and return result
pub fn updateBehaviorStateMachine(
    state_machine_ref: *BehaviorStateMachine,
    context: BehaviorContext,
    profile: BehaviorProfile,
    ranges: BehaviorRanges,
) BehaviorResult {
    const current_state = state_machine_ref.getCurrentState();
    var result = BehaviorResult{
        .velocity = Vec2.ZERO,
        .active_behavior = current_state,
        .behavior_changed = false,
    };

    // Update state machine timer
    state_machine_ref.update(context.dt);

    // Throttled logging for test unit - every second using static counter
    const log = @import("../../debug/loggers.zig");
    const is_test_unit = (context.home_pos.x == 850.0 and context.home_pos.y == 150.0 and profile == .hostile);
    if (is_test_unit) {
        const DebugState = struct {
            var frame_counter: u32 = 0;
        };
        
        DebugState.frame_counter += 1;
        // Log every 60 frames (approximately 1 second at 60fps)
        if (DebugState.frame_counter % 60 == 0) {
            const distance_from_home = context.unit_pos.sub(context.home_pos).length();
            log.getGameLog().info("unit_status", "HOSTILE TEST UNIT: pos=({d:.1},{d:.1}), home=({d:.1},{d:.1}), distance={d:.1}, state={}", .{ 
                context.unit_pos.x, context.unit_pos.y, 
                context.home_pos.x, context.home_pos.y, 
                distance_from_home, 
                state_machine_ref.getCurrentState() 
            });
        }
    }

    // Determine what state we should be in
    const desired_state = evaluateDesiredState(context, profile, ranges);

    // Handle state transitions
    if (desired_state != current_state) {
        // Debug state transitions for test unit
        if (is_test_unit) {
            log.getGameLog().info("state_transition", "HOSTILE TEST UNIT - State transition: {} -> {}", .{ current_state, desired_state });
        }

        // Check if we can transition to the desired state
        if (canTransitionToState(current_state, desired_state, context, ranges)) {
            const priority = getBehaviorPriority(desired_state);

            // Always allow valid transitions - the state evaluation logic already determines what's appropriate
            _ = state_machine_ref.interrupt(desired_state, priority, true);
            result.behavior_changed = true;
            result.state_changed = true;

            // Track specific events
            if (desired_state == .fleeing and current_state != .fleeing) {
                result.started_fleeing = true;
            } else if (current_state == .fleeing and desired_state != .fleeing) {
                result.stopped_fleeing = true;
            }

            if (desired_state == .chasing and current_state != .chasing) {
                result.detected_target = true;
            } else if (current_state == .chasing and desired_state != .chasing) {
                result.lost_target = true;
            }
        }
    }

    // Calculate velocity based on current state
    const final_state = state_machine_ref.getCurrentState();
    result.active_behavior = final_state;
    result.velocity = calculateVelocityForState(final_state, context, profile, ranges);

    return result;
}

/// Evaluate what state the unit should be in given the context - simplified logic
fn evaluateDesiredState(context: BehaviorContext, profile: BehaviorProfile, ranges: BehaviorRanges) BehaviorState {
    // Simplified behavior logic based on profile type
    return switch (profile) {
        .hostile => {
            // Hostile: chase player if in range, otherwise idle (idle will handle homing)
            if (context.player_alive and context.distance_to_player < ranges.chase_range * context.aggro_multiplier) {
                return .chasing;
            }
            return .idle;
        },

        .fearful => {
            // Fearful: flee from player if close, otherwise idle (idle will handle homing)
            if (context.player_alive and context.distance_to_player < ranges.flee_range * context.aggro_multiplier) {
                return .fleeing;
            }
            return .idle;
        },

        .neutral => {
            // Neutral: ignore player completely, always idle (idle will handle homing)
            return .idle;
        },

        .friendly => {
            // Friendly: may follow player (using chase range), otherwise idle (idle will handle homing)
            if (context.player_alive and context.distance_to_player < ranges.chase_range * context.aggro_multiplier) {
                return .chasing; // Using chase state for following behavior
            }
            return .idle;
        },
    };
}

/// Check if transition from current state to target state is allowed - simplified logic
fn canTransitionToState(current: BehaviorState, target: BehaviorState, context: BehaviorContext, ranges: BehaviorRanges) bool {
    if (current == target) return false; // No transition needed

    // Simplified transition rules - most transitions are allowed for the simplified behavior system
    return switch (current) {
        .idle => true, // Idle can transition to anything

        .chasing => switch (target) {
            .idle, .returning_home, .fleeing => true, // Can lose target or be interrupted
            else => false,
        },

        .fleeing => switch (target) {
            .idle, .returning_home => true, // Can reach safety or start going home
            else => false, // Fleeing units don't chase
        },

        .returning_home => switch (target) {
            .chasing, .fleeing => true, // Can be interrupted by player interaction
            .idle => context.distance_from_home <= ranges.home_tolerance, // Reached home
            else => false,
        },

        // Unused states in simplified system
        .patrolling, .guarding => true, // Allow transitions for backward compatibility
    };
}

/// Get behavior priority for state machine interrupt system
fn getBehaviorPriority(state: BehaviorState) state_machine.BehaviorPriority {
    return switch (state) {
        .fleeing => .critical,
        .chasing => .high,
        .guarding => .normal,
        .patrolling => .normal,
        .returning_home => .low,
        .idle => .lowest,
    };
}

/// Calculate velocity vector for a given behavior state
fn calculateVelocityForState(
    state: BehaviorState,
    context: BehaviorContext,
    profile: BehaviorProfile,
    ranges: BehaviorRanges,
) Vec2 {
    return switch (state) {
        .idle => {
            // Idle units always move toward their home position
            const to_home = context.home_pos.sub(context.unit_pos);
            const dist_sq = to_home.lengthSquared();
            const tolerance = 2.0; // Very close tolerance - stop when within 2 units of home
            const tolerance_sq = tolerance * tolerance;

            if (dist_sq > tolerance_sq) {
                const direction = to_home.normalize();
                const velocity = direction.scale(getWalkSpeed(profile));
                return velocity;
            }
            return Vec2.ZERO;
        },

        .chasing => {
            // Chase behavior with range validation - should only move if we're in valid chase range
            if (context.player_pos) |player_pos| {
                if (!context.player_alive) return Vec2.ZERO;

                const to_target = player_pos.sub(context.unit_pos);
                const distance = to_target.length();

                // Only move if we're actually in chase range and not too close
                if (distance <= ranges.chase_range * context.aggro_multiplier and distance > 5.0) {
                    const direction = to_target.normalize();
                    const velocity = direction.scale(getChaseSpeed(profile));
                    return velocity;
                }
            }
            return Vec2.ZERO;
        },

        .fleeing => {
            // Flee behavior with range validation - should only move if we're in valid flee range
            if (context.player_pos) |player_pos| {
                if (!context.player_alive) return Vec2.ZERO;

                const distance = context.distance_to_player;

                // Only flee if we're actually in flee range
                if (distance <= ranges.flee_range * context.aggro_multiplier) {
                    const to_threat = player_pos.sub(context.unit_pos);
                    const direction = to_threat.normalize().scale(-1.0); // Away from threat
                    return direction.scale(getFleeSpeed(profile));
                }
            }
            return Vec2.ZERO;
        },

        .patrolling => {
            // Use simple back-and-forth patrol for now
            // TODO: Implement with actual waypoints when needed
            return patrol_behavior.simplePatrol(context.unit_pos, context.home_pos, Vec2{ .x = context.home_pos.x + 100.0, .y = context.home_pos.y }, // Simple waypoint
                getWalkSpeed(profile), context.aggro_multiplier, // speed_multiplier
                10.0 // tolerance
            );
        },

        .guarding => {
            // Inlined guard behavior - stay close to home position
            const to_home = context.home_pos.sub(context.unit_pos);
            const dist_sq = to_home.lengthSquared();
            const tolerance = 5.0; // Small tolerance - stay very close
            const tolerance_sq = tolerance * tolerance;

            if (dist_sq > tolerance_sq) {
                const direction = to_home.normalize();
                return direction.scale(getWalkSpeed(profile) * 0.3); // Very slow movement
            }
            return Vec2.ZERO;
        },

        .returning_home => {
            // Inlined return home behavior for performance
            const to_home = context.home_pos.sub(context.unit_pos);
            const dist_sq = to_home.lengthSquared();
            const tolerance = 10.0;
            const tolerance_sq = tolerance * tolerance;

            if (dist_sq > tolerance_sq) {
                const direction = to_home.normalize();
                return direction.scale(getWalkSpeed(profile));
            }
            return Vec2.ZERO;
        },
    };
}

// Speed helper functions - simplified for new profiles
fn getChaseSpeed(profile: BehaviorProfile) f32 {
    return switch (profile) {
        .hostile => 100.0, // Fast aggressive chase
        .fearful => 0.0, // Fearful units never chase
        .neutral => 0.0, // Neutral units never chase
        .friendly => 80.0, // Moderate following speed
    };
}

fn getFleeSpeed(profile: BehaviorProfile) f32 {
    return switch (profile) {
        .hostile => 0.0, // Hostile units never flee
        .fearful => 120.0, // Fast panicked fleeing
        .neutral => 0.0, // Neutral units never flee
        .friendly => 0.0, // Friendly units never flee
    };
}

fn getWalkSpeed(profile: BehaviorProfile) f32 {
    return switch (profile) {
        .hostile => 65.0, // Steady patrol speed
        .fearful => 55.0, // Cautious movement
        .neutral => 50.0, // Casual walking pace
        .friendly => 60.0, // Gentle following pace
    };
}

test "behavior state machine basic transitions" {
    var behavior_sm = BehaviorStateMachine.init(.idle);
    const ranges = BehaviorProfile.fearful.getRanges(100.0);

    // Test context with nearby player (should trigger fleeing for fearful profile)
    const context = BehaviorContext.init(Vec2{ .x = 0, .y = 0 }, // unit_pos
        Vec2{ .x = 0, .y = 0 }, // home_pos
        Vec2{ .x = 50, .y = 0 }, // player_pos (within flee range)
        true, // player_alive
        1.0, // aggro_multiplier
        0.1 // dt
    );

    const result = updateBehaviorStateMachine(&behavior_sm, context, .fearful, ranges);

    // Should transition to fleeing
    try std.testing.expect(result.active_behavior == .fleeing);
    try std.testing.expect(result.behavior_changed);
    try std.testing.expect(result.started_fleeing);
}

test "hostile units never flee" {
    var behavior_sm = BehaviorStateMachine.init(.idle);
    const ranges = BehaviorProfile.hostile.getRanges(100.0);

    // Even with player very close, hostile profile should chase, not flee
    const context = BehaviorContext.init(Vec2{ .x = 0, .y = 0 }, Vec2{ .x = 0, .y = 0 }, Vec2{ .x = 5, .y = 0 }, // Player very close
        true, 1.0, 0.1);

    const result = updateBehaviorStateMachine(&behavior_sm, context, .hostile, ranges);

    // Should transition to chasing, not fleeing
    try std.testing.expect(result.active_behavior == .chasing);
    try std.testing.expect(result.behavior_changed);
    try std.testing.expect(result.detected_target);
}
