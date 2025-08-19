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
    new_state: BehaviorState, // The state that should be transitioned to (may equal active_behavior)
    behavior_changed: bool,

    // Events
    detected_target: bool = false,
    lost_target: bool = false,
    started_fleeing: bool = false,
    stopped_fleeing: bool = false,
    state_changed: bool = false,
};

/// Pure function to evaluate behavior state and calculate results (no side effects)
///
/// This function determines the desired behavior state based on current context
/// and calculates the appropriate velocity and events. It has no side effects
/// and is easily testable. Use this for testing or when you need to evaluate
/// behavior without applying state changes.
///
/// Example:
/// ```zig
/// const result = evaluateBehavior(.idle, context, .hostile, ranges);
/// if (result.state_changed) {
///     // Apply the transition manually
///     state_machine.transitionTo(result.new_state);
/// }
/// ```
pub fn evaluateBehavior(
    current_state: BehaviorState,
    context: BehaviorContext,
    profile: BehaviorProfile,
    ranges: BehaviorRanges,
) BehaviorResult {
    var result = BehaviorResult{
        .velocity = Vec2.ZERO,
        .active_behavior = current_state,
        .new_state = current_state,
        .behavior_changed = false,
    };

    // Determine what state we should be in
    const desired_state = evaluateDesiredState(context, profile, ranges);

    // Check if we need to transition
    if (desired_state != current_state) {
        // Check if we can transition to the desired state
        if (canTransitionToState(current_state, desired_state, context, ranges)) {
            result.new_state = desired_state;
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

    // Calculate velocity based on final state (use new_state for velocity calculation)
    result.active_behavior = result.new_state;
    result.velocity = calculateVelocityForState(result.new_state, context, profile, ranges);

    return result;
}

/// Update behavior state machine and return result (applies state changes)
///
/// This is the main interface for updating unit behavior. It uses the pure
/// evaluateBehavior() function internally and applies any state transitions
/// to the provided state machine.
///
/// Use this function for normal gameplay where you want state changes applied.
/// Use evaluateBehavior() directly for testing or custom state management.
pub fn updateBehaviorStateMachine(
    state_machine_ref: *BehaviorStateMachine,
    context: BehaviorContext,
    profile: BehaviorProfile,
    ranges: BehaviorRanges,
) BehaviorResult {
    const current_state = state_machine_ref.getCurrentState();

    // Update state machine timer (side effect)
    state_machine_ref.update(context.dt);

    // Use pure evaluation function
    const result = evaluateBehavior(current_state, context, profile, ranges);

    // Handle state transitions (side effects)
    if (result.state_changed) {
        // Apply the transition
        state_machine_ref.transitionTo(result.new_state, .condition_met, 0.0);
    }

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

/// Explicit state transition validation with clear, documented rules
///
/// This function defines the complete transition matrix for the behavior system.
/// Each transition is explicitly allowed or denied with a documented reason.
///
/// This replaced the previous priority-based system that could create conflicts.
/// Now transitions are deterministic and easily debuggable.
pub fn isValidTransition(from_state: BehaviorState, to_state: BehaviorState) bool {
    // Same state = no transition needed
    if (from_state == to_state) return false;

    // Simplified explicit rules matching original performance while being more readable
    return switch (from_state) {
        .idle => true, // Idle can transition to anything (most common case - optimize for this)

        .chasing => switch (to_state) {
            .idle, .fleeing => true, // Can lose target or be interrupted
            else => false,
        },

        .fleeing => switch (to_state) {
            .idle => true, // Can reach safety
            else => false, // Fleeing units don't do anything else
        },

        // These states are not used in the simplified system but kept for compatibility
        .returning_home => switch (to_state) {
            .chasing, .fleeing, .idle => true,
            else => false,
        },
        .patrolling, .guarding => true, // Allow transitions for backward compatibility
    };
}

/// Legacy function for backward compatibility - delegates to explicit rule-based validation
fn canTransitionToState(current: BehaviorState, target: BehaviorState, context: BehaviorContext, ranges: BehaviorRanges) bool {
    _ = context; // Context no longer needed after priority system removal
    _ = ranges; // Ranges no longer needed after priority system removal
    return isValidTransition(current, target);
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
            // Simple back-and-forth patrol implementation
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

test "explicit state transition rules" {
    // Test all valid transitions using the pure isValidTransition function

    // Idle can transition to main behavioral states
    try std.testing.expect(isValidTransition(.idle, .chasing));
    try std.testing.expect(isValidTransition(.idle, .fleeing));
    try std.testing.expect(!isValidTransition(.idle, .idle)); // Same state not allowed

    // Chasing can lose target or be interrupted
    try std.testing.expect(isValidTransition(.chasing, .idle));
    try std.testing.expect(isValidTransition(.chasing, .fleeing));
    try std.testing.expect(!isValidTransition(.chasing, .patrolling)); // Not allowed
    try std.testing.expect(!isValidTransition(.chasing, .guarding)); // Not allowed

    // Fleeing can only return to idle (safety)
    try std.testing.expect(isValidTransition(.fleeing, .idle));
    try std.testing.expect(!isValidTransition(.fleeing, .chasing)); // Fleeing units don't chase
    try std.testing.expect(!isValidTransition(.fleeing, .patrolling)); // Fleeing units don't patrol
}

test "pure behavior evaluation function" {
    const ranges = BehaviorProfile.hostile.getRanges(100.0);

    // Test that pure function produces same results as stateful version
    const context = BehaviorContext.init(Vec2{ .x = 0, .y = 0 }, // unit_pos
        Vec2{ .x = 0, .y = 0 }, // home_pos
        Vec2{ .x = 50, .y = 0 }, // player_pos (within detection range)
        true, // player_alive
        1.0, // aggro_multiplier
        0.1 // dt
    );

    // Test pure function
    const pure_result = evaluateBehavior(.idle, context, .hostile, ranges);

    // Should want to transition to chasing
    try std.testing.expect(pure_result.new_state == .chasing);
    try std.testing.expect(pure_result.state_changed == true);
    try std.testing.expect(pure_result.detected_target == true);
    try std.testing.expect(pure_result.velocity.lengthSquared() > 0); // Should have movement

    // Test that it correctly identifies no change when appropriate
    const no_change_result = evaluateBehavior(.chasing, context, .hostile, ranges);
    try std.testing.expect(no_change_result.new_state == .chasing); // Stay in chasing
    try std.testing.expect(no_change_result.state_changed == false); // No change
}

test "state transition comprehensive matrix" {
    const all_states = [_]BehaviorState{ .idle, .chasing, .fleeing, .returning_home, .patrolling, .guarding };

    // Test every possible state transition
    for (all_states) |from_state| {
        for (all_states) |to_state| {
            const can_transition = isValidTransition(from_state, to_state);

            // Verify specific rules
            if (from_state == to_state) {
                // Same state should never be allowed
                try std.testing.expect(!can_transition);
            } else if (from_state == .idle) {
                // Idle can transition to main behavioral states
                const expected = (to_state == .chasing or to_state == .fleeing or
                    to_state == .patrolling or to_state == .guarding or
                    to_state == .returning_home);
                try std.testing.expectEqual(expected, can_transition);
            } else if (from_state == .fleeing and to_state != .idle) {
                // Fleeing units can only go to idle (safety)
                try std.testing.expect(!can_transition);
            }
        }
    }
}
