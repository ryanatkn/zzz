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
            .fleeing => 100,        // Highest priority - survival
            .chasing => 80,         // High priority - engagement
            .guarding => 60,        // Medium-high priority - area control
            .patrolling => 40,      // Medium priority - routine activity
            .returning_home => 20,  // Low priority - maintenance
            .idle => 0,            // Lowest priority - default state
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

/// Profile-specific behavior preferences
pub const BehaviorProfile = enum {
    aggressive,
    defensive, 
    wandering,
    patrolling,
    guardian,
    
    /// Get ranges for different behaviors based on profile
    pub fn getRanges(self: BehaviorProfile, base_detection: f32) BehaviorRanges {
        return switch (self) {
            .aggressive => .{
                .flee_range = base_detection * 0.3,  // Flee very close
                .chase_range = base_detection * 1.5, // Chase far
                .guard_range = base_detection * 0.8,
                .home_tolerance = 15.0,
            },
            .defensive => .{
                .flee_range = base_detection * 1.2,  // Flee early
                .chase_range = base_detection * 0.6, // Chase reluctantly
                .guard_range = base_detection * 1.0,
                .home_tolerance = 20.0,
            },
            .wandering => .{
                .flee_range = base_detection * 1.0,  // Standard flee range
                .chase_range = base_detection * 0.4, // Very reluctant to chase
                .guard_range = base_detection * 0.6,
                .home_tolerance = 25.0,
            },
            .patrolling => .{
                .flee_range = base_detection * 0.8,
                .chase_range = base_detection * 1.0,
                .guard_range = base_detection * 0.9,
                .home_tolerance = 10.0,  // Stay close to patrol route
            },
            .guardian => .{
                .flee_range = base_detection * 0.4,  // Brave guardians
                .chase_range = base_detection * 1.3, // Aggressive pursuit
                .guard_range = base_detection * 1.5, // Large guard area
                .home_tolerance = 30.0,  // Can roam large area
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
    
    // Determine what state we should be in
    const desired_state = evaluateDesiredState(context, profile, ranges);
    
    // Handle state transitions
    if (desired_state != current_state) {
        // Check if we can transition to the desired state
        if (canTransitionToState(current_state, desired_state, context, ranges)) {
            const priority = getBehaviorPriority(desired_state);
            
            // Use interrupt system for high-priority state changes
            if (priority.higherThan(state_machine_ref.getCurrentPriority())) {
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
    }
    
    // Calculate velocity based on current state
    const final_state = state_machine_ref.getCurrentState();
    result.active_behavior = final_state;
    result.velocity = calculateVelocityForState(final_state, context, profile);
    
    return result;
}

/// Evaluate what state the unit should be in given the context
fn evaluateDesiredState(context: BehaviorContext, profile: BehaviorProfile, ranges: BehaviorRanges) BehaviorState {
    // Priority order: fleeing > chasing > guarding > patrolling > returning_home > idle
    
    // Check for fleeing conditions
    if (context.player_alive and context.distance_to_player < ranges.flee_range * context.aggro_multiplier) {
        return .fleeing;
    }
    
    // Check for chasing conditions (only if not fleeing)
    if (context.player_alive and context.distance_to_player < ranges.chase_range * context.aggro_multiplier) {
        // Profile-specific chase willingness
        return switch (profile) {
            .aggressive, .guardian => .chasing,
            .defensive => if (context.distance_from_home < ranges.guard_range) .guarding else .fleeing,
            .wandering => if (context.distance_to_player < ranges.chase_range * 0.5) .chasing else .idle,
            .patrolling => .chasing,
        };
    }
    
    // Check for guarding conditions  
    if (context.distance_from_home < ranges.guard_range) {
        return switch (profile) {
            .guardian, .defensive => .guarding,
            else => .idle,
        };
    }
    
    // Check for patrolling conditions
    if (profile == .patrolling and context.distance_from_home < ranges.home_tolerance) {
        return .patrolling;
    }
    
    // Check if we need to return home
    if (context.distance_from_home > ranges.home_tolerance) {
        return .returning_home;
    }
    
    // Default to idle
    return .idle;
}

/// Check if transition from current state to target state is allowed
fn canTransitionToState(current: BehaviorState, target: BehaviorState, context: BehaviorContext, ranges: BehaviorRanges) bool {
    if (current == target) return false; // No transition needed
    
    return switch (current) {
        .idle => true, // Idle can transition to anything
        
        
        .chasing => switch (target) {
            .fleeing => true, // CRITICAL: Chase can be interrupted by flee (fixes bug)
            .idle, .returning_home => true, // Can lose target
            .guarding => context.distance_from_home < ranges.guard_range,
            else => false,
        },
        
        .fleeing => switch (target) {
            .idle => true, // Can reach safety
            .returning_home => true, // Can start going home
            // CRITICAL: Fleeing CANNOT transition to chasing (prevents aggro bug)
            else => false,
        },
        
        .patrolling => switch (target) {
            .fleeing, .chasing, .guarding => true, // Can be interrupted
            .idle, .returning_home => true,
            else => false,
        },
        
        .guarding => switch (target) {
            .fleeing, .chasing => true, // Can be interrupted by threats
            .patrolling, .idle => true,
            .returning_home => context.distance_from_home > ranges.home_tolerance,
            else => false,
        },
        
        .returning_home => switch (target) {
            .fleeing, .chasing => true, // Can be interrupted by immediate threats
            .idle => context.distance_from_home <= ranges.home_tolerance,
            .patrolling, .guarding => context.distance_from_home <= ranges.home_tolerance,
            else => false,
        },
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
) Vec2 {
    return switch (state) {
        .idle => Vec2.ZERO,
        
        
        .chasing => {
            // Inlined chase behavior for performance
            if (context.player_pos) |player_pos| {
                if (!context.player_alive) return Vec2.ZERO;
                
                const to_target = player_pos.sub(context.unit_pos);
                const dist_sq = to_target.lengthSquared();
                const detection_range = 200.0;
                const min_distance = 10.0;
                
                const effective_range_sq = (detection_range * context.aggro_multiplier) * (detection_range * context.aggro_multiplier);
                const min_dist_sq = min_distance * min_distance;
                
                if (dist_sq <= effective_range_sq and dist_sq > min_dist_sq) {
                    const direction = to_target.normalize();
                    return direction.scale(getChaseSpeed(profile));
                }
            }
            return Vec2.ZERO;
        },
        
        .fleeing => {
            // Inlined flee behavior for performance
            if (context.player_pos) |player_pos| {
                if (!context.player_alive) return Vec2.ZERO;
                
                const to_threat = player_pos.sub(context.unit_pos);
                const dist_sq = to_threat.lengthSquared();
                const danger_range = 150.0;
                const danger_sq = (danger_range * context.aggro_multiplier) * (danger_range * context.aggro_multiplier);
                
                if (dist_sq <= danger_sq) {
                    const direction = to_threat.normalize().scale(-1.0); // Away from threat
                    return direction.scale(getFleeSpeed(profile));
                }
            }
            return Vec2.ZERO;
        },
        
        .patrolling => {
            // Use simple back-and-forth patrol for now
            // TODO: Implement with actual waypoints when needed
            return patrol_behavior.simplePatrol(
                context.unit_pos,
                context.home_pos,
                Vec2{.x = context.home_pos.x + 100.0, .y = context.home_pos.y}, // Simple waypoint
                getWalkSpeed(profile),
                context.aggro_multiplier, // speed_multiplier
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

// Speed helper functions
fn getChaseSpeed(profile: BehaviorProfile) f32 {
    return switch (profile) {
        .aggressive => 100.0,
        .guardian => 95.0,
        .patrolling => 85.0,
        .defensive => 70.0,
        .wandering => 60.0,
    };
}

fn getFleeSpeed(profile: BehaviorProfile) f32 {
    return switch (profile) {
        .wandering => 120.0,  // Fast fleeing
        .defensive => 110.0,
        .patrolling => 100.0,
        .aggressive => 80.0,  // Reluctant to flee
        .guardian => 70.0,    // Very reluctant to flee
    };
}

fn getWalkSpeed(profile: BehaviorProfile) f32 {
    return switch (profile) {
        .aggressive => 65.0,
        .guardian => 60.0,
        .patrolling => 55.0,
        .defensive => 50.0,
        .wandering => 45.0,
    };
}

test "behavior state machine basic transitions" {
    var behavior_sm = BehaviorStateMachine.init(.idle);
    const ranges = BehaviorProfile.wandering.getRanges(100.0);
    
    // Test context with nearby player (should trigger fleeing for wandering profile)
    const context = BehaviorContext.init(
        Vec2{ .x = 0, .y = 0 },    // unit_pos
        Vec2{ .x = 0, .y = 0 },    // home_pos  
        Vec2{ .x = 50, .y = 0 },   // player_pos (within flee range)
        true,                       // player_alive
        1.0,                       // aggro_multiplier
        0.1                        // dt
    );
    
    const result = updateBehaviorStateMachine(&behavior_sm, context, .wandering, ranges);
    
    // Should transition to fleeing
    try std.testing.expect(result.active_behavior == .fleeing);
    try std.testing.expect(result.behavior_changed);
    try std.testing.expect(result.started_fleeing);
}

test "fleeing cannot transition to chasing" {
    _ = BehaviorStateMachine.init(.fleeing);
    const ranges = BehaviorProfile.aggressive.getRanges(100.0);
    
    // Even with aggressive profile, fleeing state should not transition to chasing
    const context = BehaviorContext.init(
        Vec2{ .x = 0, .y = 0 },
        Vec2{ .x = 0, .y = 0 },
        Vec2{ .x = 80, .y = 0 },   // Player at chase range
        true,
        1.0,
        0.1
    );
    
    // Fleeing should stay fleeing, not transition to chasing
    try std.testing.expect(!canTransitionToState(.fleeing, .chasing, context, ranges));
}