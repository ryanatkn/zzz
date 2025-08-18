const std = @import("std");
const Vec2 = @import("../../math/mod.zig").Vec2;
const chase_behavior = @import("chase_behavior.zig");
const flee_behavior = @import("flee_behavior.zig");
const patrol_behavior = @import("patrol_behavior.zig");
const guard_behavior = @import("guard_behavior.zig");
const wander_behavior = @import("wander_behavior.zig");
const return_home_behavior = @import("return_home_behavior.zig");
const behavior_state_machine = @import("behavior_state_machine.zig");

/// Behavior type enumeration (kept for compatibility)
pub const BehaviorType = enum {
    chase,
    flee,
    patrol,
    guard,
    wander,
    return_home,
    idle,
    
    /// Convert from new BehaviorState to old BehaviorType for compatibility
    pub fn fromBehaviorState(state: behavior_state_machine.BehaviorState) BehaviorType {
        return switch (state) {
            .chasing => .chase,
            .fleeing => .flee,
            .patrolling => .patrol,
            .guarding => .guard,
            .investigating => .wander, // Map investigating to wander for compatibility
            .returning_home => .return_home,
            .idle => .idle,
        };
    }
};

/// Behavior priority levels (higher number = higher priority)
pub const BehaviorPriority = enum(u8) {
    lowest = 0,
    low = 1,
    normal = 2,
    high = 3,
    critical = 4,
};

/// Behavior priority configuration
pub const BehaviorPriorities = struct {
    chase: BehaviorPriority = .normal,
    flee: BehaviorPriority = .high,
    patrol: BehaviorPriority = .low,
    guard: BehaviorPriority = .normal,
    wander: BehaviorPriority = .lowest,
    return_home: BehaviorPriority = .low,

    pub fn default() BehaviorPriorities {
        return .{};
    }

    pub fn getPriority(self: *const BehaviorPriorities, behavior_type: BehaviorType) BehaviorPriority {
        return switch (behavior_type) {
            .chase => self.chase,
            .flee => self.flee,
            .patrol => self.patrol,
            .guard => self.guard,
            .wander => self.wander,
            .return_home => self.return_home,
            .idle => .lowest,
        };
    }
};

/// Generic unit behavior configuration
pub const UnitBehaviorConfig = struct {
    /// Chase behavior configuration
    chase: chase_behavior.ChaseConfig,
    /// Flee behavior configuration
    flee: flee_behavior.FleeConfig,
    /// Patrol behavior configuration (optional waypoints set in state)
    patrol: patrol_behavior.PatrolConfig,
    /// Guard behavior configuration
    guard: guard_behavior.GuardConfig,
    /// Wander behavior configuration
    wander: wander_behavior.WanderConfig,
    /// Return home behavior configuration
    return_home: return_home_behavior.ReturnHomeConfig,
    /// Speed multiplier when walking vs running
    walk_speed_multiplier: f32 = 0.5,
    /// Behavior priorities (can be customized per unit)
    behavior_priorities: BehaviorPriorities = BehaviorPriorities.default(),

    pub fn init(
        home_pos: Vec2,
        detection_range: f32,
        min_distance: f32,
        chase_speed: f32,
        walk_speed: f32,
        chase_duration: f32,
        home_tolerance: f32,
        lose_tolerance: f32,
    ) UnitBehaviorConfig {
        return .{
            .chase = chase_behavior.ChaseConfig.init(
                detection_range,
                min_distance,
                chase_speed,
                chase_duration,
                lose_tolerance,
            ),
            .flee = flee_behavior.FleeConfig.init(
                detection_range * 0.8, // Flee range slightly smaller than chase
                detection_range * 1.2, // Safe distance larger than detection
                chase_speed * 1.2, // Flee faster than chase
                2.0, // Flee for 2 seconds after escaping danger
            ),
            .patrol = patrol_behavior.PatrolConfig.init(walk_speed, home_tolerance, true),
            .guard = guard_behavior.GuardConfig.init(
                home_pos,
                detection_range * 1.5, // Guard area larger than detection
                detection_range,
                walk_speed,
                chase_speed,
                5.0, // Pursue for 5 seconds
            ),
            .wander = wander_behavior.WanderConfig.init(
                walk_speed * 0.7, // Wander slower than walk
                detection_range * 0.8, // Wander within smaller area
                4.0, // Change direction every 4 seconds
            ),
            .return_home = return_home_behavior.ReturnHomeConfig.init(
                home_tolerance,
                walk_speed,
            ),
            .walk_speed_multiplier = walk_speed / chase_speed,
        };
    }

    /// Create a simple aggressive config (chase + return home only)
    pub fn aggressive(home_pos: Vec2, detection_range: f32, chase_speed: f32) UnitBehaviorConfig {
        var config = UnitBehaviorConfig.init(home_pos, detection_range, 20.0, chase_speed, chase_speed * 0.6, 3.0, 15.0, 1.15);
        config.behavior_priorities.chase = .critical;
        config.behavior_priorities.flee = .lowest;
        return config;
    }

    /// Create a defensive config (flee + guard prioritized)
    pub fn defensive(home_pos: Vec2, detection_range: f32, flee_speed: f32) UnitBehaviorConfig {
        var config = UnitBehaviorConfig.init(home_pos, detection_range, 30.0, flee_speed * 0.8, flee_speed * 0.5, 2.0, 15.0, 1.0);
        config.behavior_priorities.flee = .critical;
        config.behavior_priorities.guard = .high;
        config.behavior_priorities.chase = .low;
        return config;
    }

    /// Create a patrol config (patrol + guard prioritized)
    pub fn patrolling(home_pos: Vec2, detection_range: f32, patrol_speed: f32) UnitBehaviorConfig {
        var config = UnitBehaviorConfig.init(home_pos, detection_range, 25.0, patrol_speed, patrol_speed * 0.8, 2.0, 10.0, 1.1);
        config.behavior_priorities.patrol = .high;
        config.behavior_priorities.guard = .normal;
        config.behavior_priorities.wander = .lowest;
        return config;
    }
};

/// Generic unit state for behavior management (now using state machine)
pub const UnitBehaviorState = struct {
    /// State machine for behavior transitions
    state_machine: behavior_state_machine.BehaviorStateMachine,
    /// Individual behavior states (kept for compatibility with existing behaviors)
    chase: chase_behavior.ChaseState,
    flee: flee_behavior.FleeState,
    patrol: patrol_behavior.PatrolState,
    guard: guard_behavior.GuardState,
    wander: wander_behavior.WanderState,
    return_home: return_home_behavior.PatrolState,

    pub fn init(home_pos: Vec2, patrol_waypoints: []const Vec2, random_seed: u64) UnitBehaviorState {
        return .{
            .state_machine = behavior_state_machine.BehaviorStateMachine.init(.idle),
            .chase = chase_behavior.ChaseState.init(),
            .flee = flee_behavior.FleeState.init(),
            .patrol = patrol_behavior.PatrolState.init(patrol_waypoints),
            .guard = guard_behavior.GuardState.init(),
            .wander = wander_behavior.WanderState.init(home_pos, random_seed),
            .return_home = return_home_behavior.PatrolState.init(&[_]Vec2{}),
        };
    }

    pub fn reset(self: *UnitBehaviorState, home_pos: Vec2) void {
        self.state_machine = behavior_state_machine.BehaviorStateMachine.init(.idle);
        self.chase.reset();
        self.flee.reset();
        self.patrol.reset();
        self.guard.reset();
        self.wander.reset(home_pos);
        self.return_home = return_home_behavior.PatrolState.init(&[_]Vec2{});
    }

    /// Get current behavior type for compatibility
    pub fn getActiveBehavior(self: *const UnitBehaviorState) BehaviorType {
        return BehaviorType.fromBehaviorState(self.state_machine.getCurrentState());
    }
    
    /// Get previous behavior type for compatibility  
    pub fn getPreviousBehavior(self: *const UnitBehaviorState) BehaviorType {
        return BehaviorType.fromBehaviorState(self.state_machine.state_machine.getPreviousState());
    }
};

/// Result of unit behavior evaluation
pub const UnitBehaviorResult = struct {
    /// Velocity to apply to the unit
    velocity: Vec2,
    /// Current active behavior
    active_behavior: BehaviorType,
    /// Previous behavior (if changed this frame)
    previous_behavior: ?BehaviorType,
    /// Whether behavior changed this frame
    behavior_changed: bool,
    /// Whether any behavior state changed internally
    state_changed: bool,
    /// Behavior-specific events
    detected_target: bool = false,
    lost_target: bool = false,
    reached_waypoint: bool = false,
    returned_to_post: bool = false,
    started_fleeing: bool = false,
    stopped_fleeing: bool = false,
};

/// Behavior evaluation context
pub const BehaviorContext = struct {
    unit_pos: Vec2,
    target_pos: ?Vec2,
    target_alive: bool,
    threat_pos: ?Vec2,
    threat_active: bool,
    home_pos: Vec2,
    aggro_multiplier: f32 = 1.0,
    speed_multiplier: f32 = 1.0,
    dt: f32,
};

/// Update unit behavior with state machine-based behavior switching
pub fn updateUnitBehavior(
    context: BehaviorContext,
    state: *UnitBehaviorState,
    config: UnitBehaviorConfig,
) UnitBehaviorResult {
    const old_behavior = state.getActiveBehavior();
    
    // Create behavior context for state machine
    const behavior_context = behavior_state_machine.BehaviorContext.init(
        context.unit_pos,
        context.home_pos,
        context.target_pos,
        context.target_alive,
        context.aggro_multiplier,
        context.dt
    );
    
    // Determine profile based on config priorities (simplified mapping)
    const profile = determineProfileFromConfig(config);
    const ranges = profile.getRanges(config.chase.detection_range);
    
    // Update state machine
    const state_machine_result = behavior_state_machine.updateBehaviorStateMachine(
        &state.state_machine,
        behavior_context,
        profile,
        ranges
    );
    
    const result = UnitBehaviorResult{
        .velocity = state_machine_result.velocity,
        .active_behavior = BehaviorType.fromBehaviorState(state_machine_result.active_behavior),
        .previous_behavior = if (state_machine_result.behavior_changed) old_behavior else null,
        .behavior_changed = state_machine_result.behavior_changed,
        .state_changed = state_machine_result.state_changed,
        .detected_target = state_machine_result.detected_target,
        .lost_target = state_machine_result.lost_target,
        .started_fleeing = state_machine_result.started_fleeing,
        .stopped_fleeing = state_machine_result.stopped_fleeing,
    };
    
    return result;
}

/// Determine behavior profile from config priorities (compatibility layer)
fn determineProfileFromConfig(config: UnitBehaviorConfig) behavior_state_machine.BehaviorProfile {
    // Analyze priority configuration to guess the intended profile
    const chase_priority = @intFromEnum(config.behavior_priorities.chase);
    const flee_priority = @intFromEnum(config.behavior_priorities.flee);
    const guard_priority = @intFromEnum(config.behavior_priorities.guard);
    const patrol_priority = @intFromEnum(config.behavior_priorities.patrol);
    
    // Aggressive: high chase, low flee
    if (chase_priority >= 3 and flee_priority <= 1) return .aggressive;
    
    // Defensive: high flee, high guard
    if (flee_priority >= 3 and guard_priority >= 2) return .defensive;
    
    // Patrolling: high patrol
    if (patrol_priority >= 3) return .patrolling;
    
    // Guardian: high guard, high chase
    if (guard_priority >= 3 and chase_priority >= 2) return .guardian;
    
    // Default to wandering (balanced behavior)
    return .wandering;
}

// Deprecated: Use updateUnitBehavior() directly with FrameContext.effectiveDelta()
// This function existed for the old complex context system

/// Apply unit behavior result to transform and visual components
/// This is a generic helper that games can customize
pub fn applyBehaviorResult(
    transform: anytype, // Should have pos, vel fields
    visual: anytype, // Should have color field
    result: UnitBehaviorResult,
    colors: BehaviorColors,
    dt: f32,
) void {
    // Apply velocity
    transform.vel = result.velocity;
    transform.pos = transform.pos.add(result.velocity.scale(dt));

    // Apply visual feedback based on active behavior
    visual.color = switch (result.active_behavior) {
        .chase => colors.chasing,
        .flee => colors.fleeing,
        .patrol => colors.patrolling,
        .guard => colors.guarding,
        .wander => colors.wandering,
        .return_home => colors.returning_home,
        .idle => colors.idle,
    };
}

/// Color configuration for different behavior states
pub const BehaviorColors = struct {
    chasing: @TypeOf(@field(@import("../../core/colors.zig").Color, "RED")),
    fleeing: @TypeOf(@field(@import("../../core/colors.zig").Color, "ORANGE")),
    patrolling: @TypeOf(@field(@import("../../core/colors.zig").Color, "BLUE")),
    guarding: @TypeOf(@field(@import("../../core/colors.zig").Color, "PURPLE")),
    wandering: @TypeOf(@field(@import("../../core/colors.zig").Color, "CYAN")),
    returning_home: @TypeOf(@field(@import("../../core/colors.zig").Color, "YELLOW")),
    idle: @TypeOf(@field(@import("../../core/colors.zig").Color, "GRAY")),

    pub fn init() BehaviorColors {
        const Color = @import("../../core/colors.zig").Color;
        return .{
            .chasing = Color.RED,
            .fleeing = Color.ORANGE,
            .patrolling = Color.BLUE,
            .guarding = Color.PURPLE,
            .wandering = Color.GREEN_BRIGHT,
            .returning_home = Color.YELLOW,
            .idle = Color.GRAY,
        };
    }
};

test "unit behavior basic functionality" {
    const home_pos = Vec2{ .x = 0, .y = 0 };
    var state = UnitBehaviorState.init(home_pos, &[_]Vec2{}, 12345);
    const config = UnitBehaviorConfig.init(home_pos, 100.0, 20.0, 150.0, 75.0, 3.0, 10.0, 1.15);

    const unit_pos = Vec2{ .x = 0, .y = 0 };
    const target_pos = Vec2{ .x = 50, .y = 0 }; // Within detection range

    const context = BehaviorContext{
        .unit_pos = unit_pos,
        .target_pos = target_pos,
        .target_alive = true,
        .threat_pos = null,
        .threat_active = false,
        .home_pos = home_pos,
        .dt = 0.1,
    };

    // Test initial detection
    const result = updateUnitBehavior(context, &state, config);
    try std.testing.expect(result.detected_target);
    try std.testing.expect(result.active_behavior == .chase);
    try std.testing.expect(result.velocity.x > 0); // Should move toward target
}

test "unit behavior priority system" {
    const home_pos = Vec2{ .x = 0, .y = 0 };
    var state = UnitBehaviorState.init(home_pos, &[_]Vec2{}, 54321);

    // Create aggressive config (chase priority = critical)
    const config = UnitBehaviorConfig.aggressive(home_pos, 100.0, 150.0);

    const unit_pos = Vec2{ .x = 50, .y = 0 };
    const target_pos = Vec2{ .x = 80, .y = 0 };
    const threat_pos = Vec2{ .x = 30, .y = 0 }; // Closer threat

    // With both threat and target, should prioritize chase (critical) over flee (lowest)
    const context = BehaviorContext{
        .unit_pos = unit_pos,
        .target_pos = target_pos,
        .target_alive = true,
        .threat_pos = threat_pos,
        .threat_active = true,
        .home_pos = home_pos,
        .dt = 0.1,
    };

    const result = updateUnitBehavior(context, &state, config);
    try std.testing.expect(result.active_behavior == .chase); // Should chase despite threat
}

test "behavior switching" {
    const home_pos = Vec2{ .x = 0, .y = 0 };
    var state = UnitBehaviorState.init(home_pos, &[_]Vec2{}, 98765);

    // Create defensive config (flee priority = critical)
    const config = UnitBehaviorConfig.defensive(home_pos, 100.0, 120.0);

    const unit_pos = Vec2{ .x = 50, .y = 0 };
    const threat_pos = Vec2{ .x = 60, .y = 0 }; // Close threat

    var context = BehaviorContext{
        .unit_pos = unit_pos,
        .target_pos = null,
        .target_alive = false,
        .threat_pos = threat_pos,
        .threat_active = true,
        .home_pos = home_pos,
        .dt = 0.1,
    };

    // Should start fleeing
    var result = updateUnitBehavior(context, &state, config);
    try std.testing.expect(result.active_behavior == .flee);
    try std.testing.expect(result.behavior_changed);

    // Remove threat, should switch to different behavior
    context.threat_active = false;
    context.threat_pos = null;
    result = updateUnitBehavior(context, &state, config);
    try std.testing.expect(result.active_behavior != .flee);
    try std.testing.expect(result.behavior_changed);
}
