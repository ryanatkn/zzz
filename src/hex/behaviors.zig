const std = @import("std");
const math = @import("../lib/math/mod.zig");
const constants = @import("constants.zig");
const hex_game_mod = @import("hex_game.zig");
const frame = @import("../lib/core/frame.zig");
const colors = @import("../lib/core/colors.zig");
const behaviors_mod = @import("../lib/game/behaviors/mod.zig");

// Import all behavior types from the library
const chase_behavior = behaviors_mod.chase_behavior;
const flee_behavior = behaviors_mod.flee_behavior;
const patrol_behavior = behaviors_mod.patrol_behavior;
const guard_behavior = behaviors_mod.guard_behavior;
const wander_behavior = behaviors_mod.wander_behavior;
const unit_behavior = behaviors_mod.unit_behavior;

const Vec2 = math.Vec2;
const Unit = hex_game_mod.Unit;
const Transform = hex_game_mod.Transform;
const Visual = hex_game_mod.Visual;
const FrameContext = frame.FrameContext;

// Import BehaviorProfile from hex_game.zig to avoid circular dependency
const BehaviorProfile = hex_game_mod.BehaviorProfile;

/// Unit behavior state storage with proper allocator management
var unit_behavior_states: ?std.AutoHashMap(u32, unit_behavior.UnitBehaviorState) = null;
var unit_behavior_configs: ?std.AutoHashMap(u32, unit_behavior.UnitBehaviorConfig) = null;
var behaviors_allocator: ?std.mem.Allocator = null;

/// Static fallback state for error recovery (memory-safe alternative to @constCast)
var fallback_state = unit_behavior.UnitBehaviorState.init(Vec2.ZERO, &[_]Vec2{}, 0);
var fallback_config = unit_behavior.UnitBehaviorConfig.aggressive(Vec2.ZERO, 100.0, 50.0);

/// Initialize behavior system with proper allocator
pub fn initBehaviors(allocator: std.mem.Allocator) void {
    // Clear any existing state
    deinitBehaviors();

    behaviors_allocator = allocator;
    unit_behavior_states = std.AutoHashMap(u32, unit_behavior.UnitBehaviorState).init(allocator);
    unit_behavior_configs = std.AutoHashMap(u32, unit_behavior.UnitBehaviorConfig).init(allocator);
}

/// Cleanup behavior system
pub fn deinitBehaviors() void {
    if (unit_behavior_states) |*states| {
        states.deinit();
    }
    if (unit_behavior_configs) |*configs| {
        configs.deinit();
    }
    unit_behavior_states = null;
    unit_behavior_configs = null;
    behaviors_allocator = null;
}

/// Create behavior configuration for specific profile with consistent parameters
fn createConfigForProfile(profile: BehaviorProfile, home_pos: Vec2) unit_behavior.UnitBehaviorConfig {
    const base_detection = constants.UNIT_DETECTION_RADIUS;
    const base_chase_speed = constants.UNIT_CHASE_SPEED;
    const base_walk_speed = constants.UNIT_WALK_SPEED;

    return switch (profile) {
        .idle => blk: {
            var config = unit_behavior.UnitBehaviorConfig.init(home_pos, base_detection, constants.BEHAVIOR_IDLE_MIN_DISTANCE, base_chase_speed, base_chase_speed * constants.BEHAVIOR_IDLE_WALK_SPEED_MULT, constants.BEHAVIOR_IDLE_CHASE_DURATION, constants.BEHAVIOR_IDLE_HOME_TOLERANCE, constants.BEHAVIOR_IDLE_LOSE_TOLERANCE);
            config.behavior_priorities.chase = .low;
            config.behavior_priorities.return_home = .normal;
            config.behavior_priorities.wander = .lowest;
            break :blk config;
        },
        .aggressive => unit_behavior.UnitBehaviorConfig.aggressive(home_pos, base_detection, base_chase_speed),
        .defensive => unit_behavior.UnitBehaviorConfig.defensive(home_pos, base_detection, base_chase_speed * constants.BEHAVIOR_DEFENSIVE_SPEED_MULT),
        .patrolling => unit_behavior.UnitBehaviorConfig.patrolling(home_pos, base_detection, base_walk_speed),
        .wandering => blk: {
            var config = unit_behavior.UnitBehaviorConfig.init(
                home_pos,
                base_detection * constants.BEHAVIOR_WANDERING_DETECTION_MULT,
                constants.PLAYER_RADIUS + 10.0,
                base_walk_speed,
                base_walk_speed * constants.BEHAVIOR_WANDERING_WALK_SPEED_MULT,
                constants.BEHAVIOR_WANDERING_CHASE_DURATION,
                constants.UNIT_HOME_TOLERANCE,
                constants.BEHAVIOR_WANDERING_LOSE_TOLERANCE,
            );
            config.behavior_priorities.wander = .high;
            config.behavior_priorities.flee = .critical;
            config.behavior_priorities.chase = .low;
            break :blk config;
        },
        .guardian => blk: {
            var config = unit_behavior.UnitBehaviorConfig.init(
                home_pos,
                base_detection * constants.BEHAVIOR_GUARDIAN_DETECTION_MULT,
                constants.PLAYER_RADIUS + constants.BEHAVIOR_GUARDIAN_MIN_DISTANCE_OFFSET,
                base_chase_speed,
                base_walk_speed,
                constants.BEHAVIOR_GUARDIAN_CHASE_DURATION,
                constants.UNIT_HOME_TOLERANCE * constants.BEHAVIOR_GUARDIAN_HOME_TOLERANCE_MULT,
                constants.BEHAVIOR_GUARDIAN_LOSE_TOLERANCE,
            );
            config.behavior_priorities.guard = .critical;
            config.behavior_priorities.chase = .high;
            config.behavior_priorities.flee = .lowest;
            break :blk config;
        },
    };
}

/// Create behavior config based on profile (public API)
pub fn createBehaviorConfig(profile: BehaviorProfile, home_pos: Vec2) unit_behavior.UnitBehaviorConfig {
    return createConfigForProfile(profile, home_pos);
}

/// Get or create behavior state for a unit entity
fn getOrCreateBehaviorState(entity_id: u32, unit_comp: *const Unit, profile: BehaviorProfile) *unit_behavior.UnitBehaviorState {
    if (unit_behavior_states == null) {
        std.log.err("Behavior system not initialized, using fallback for entity {}", .{entity_id});
        fallback_state = unit_behavior.UnitBehaviorState.init(unit_comp.base.home_pos, &[_]Vec2{}, entity_id);
        return &fallback_state;
    }

    const state_result = unit_behavior_states.?.getOrPut(entity_id) catch {
        std.log.err("Failed to get or create behavior state for entity {}, using fallback", .{entity_id});
        // Update fallback state and return reference to it (memory-safe)
        fallback_state = unit_behavior.UnitBehaviorState.init(unit_comp.base.home_pos, &[_]Vec2{}, entity_id);
        return &fallback_state;
    };

    if (!state_result.found_existing) {
        // Create new state with appropriate waypoints based on profile
        const waypoints = switch (profile) {
            .patrolling => generatePatrolWaypoints(unit_comp.base.home_pos, .square), // Default to square pattern
            else => &[_]Vec2{}, // No waypoints for other profiles
        };

        state_result.value_ptr.* = unit_behavior.UnitBehaviorState.init(
            unit_comp.base.home_pos,
            waypoints,
            entity_id, // Use entity ID as random seed
        );
    }

    return state_result.value_ptr;
}

/// Get or create behavior config for a unit entity
fn getOrCreateBehaviorConfig(entity_id: u32, unit_comp: *const Unit, profile: BehaviorProfile) *unit_behavior.UnitBehaviorConfig {
    if (unit_behavior_configs == null) {
        std.log.err("Behavior system not initialized, using fallback for entity {}", .{entity_id});
        fallback_config = createConfigForProfile(profile, unit_comp.base.home_pos);
        return &fallback_config;
    }

    const config_result = unit_behavior_configs.?.getOrPut(entity_id) catch {
        std.log.err("Failed to get or create behavior config for entity {}, using fallback", .{entity_id});
        // Update fallback config and return reference to it (memory-safe)
        fallback_config = createConfigForProfile(profile, unit_comp.base.home_pos);
        return &fallback_config;
    };

    if (!config_result.found_existing) {
        config_result.value_ptr.* = createConfigForProfile(profile, unit_comp.base.home_pos);
    }

    return config_result.value_ptr;
}

/// Generate patrol waypoints based on pattern and home position
fn generatePatrolWaypoints(home_pos: Vec2, pattern: constants.PatrolPattern) []const Vec2 {
    const offset_x = constants.PATROL_WAYPOINT_OFFSET_X;
    const offset_y = constants.PATROL_WAYPOINT_OFFSET_Y;

    return switch (pattern) {
        .square => &[_]Vec2{
            home_pos,
            Vec2{ .x = home_pos.x + offset_x, .y = home_pos.y },
            Vec2{ .x = home_pos.x + offset_x, .y = home_pos.y + offset_y },
            Vec2{ .x = home_pos.x, .y = home_pos.y + offset_y },
        },
        .line => &[_]Vec2{
            home_pos,
            Vec2{ .x = home_pos.x + offset_x, .y = home_pos.y },
        },
        .triangle => &[_]Vec2{
            home_pos,
            Vec2{ .x = home_pos.x + offset_x, .y = home_pos.y },
            Vec2{ .x = home_pos.x + offset_x * 0.5, .y = home_pos.y + offset_y },
        },
        .circle => &[_]Vec2{
            home_pos,
            Vec2{ .x = home_pos.x + offset_x, .y = home_pos.y },
            Vec2{ .x = home_pos.x, .y = home_pos.y + offset_y },
            Vec2{ .x = home_pos.x - offset_x, .y = home_pos.y },
        },
    };
}

/// Determine behavior profile from stored unit data (not entity ID)
fn determineBehaviorProfile(unit_comp: *const Unit) BehaviorProfile {
    return unit_comp.behavior_profile; // Use stored value from ZON
}

/// Context-aware hex-specific unit update function using library behaviors
pub fn updateUnitWithAggroMod(
    entity_id: u32,
    unit_comp: *Unit,
    transform: *Transform,
    visual: *Visual,
    player_pos: Vec2,
    player_alive: bool,
    aggro_multiplier: f32,
    frame_ctx: FrameContext,
) void {
    const dt = frame_ctx.effectiveDelta();

    // Determine behavior profile for this unit
    const profile = determineBehaviorProfile(unit_comp);

    // Get or create behavior state and config
    const state = getOrCreateBehaviorState(entity_id, unit_comp, profile);
    const config = getOrCreateBehaviorConfig(entity_id, unit_comp, profile);

    // Create behavior context
    const behavior_context = unit_behavior.BehaviorContext{
        .unit_pos = transform.pos,
        .target_pos = if (player_alive) player_pos else null,
        .target_alive = player_alive,
        .threat_pos = if (player_alive) player_pos else null,
        .threat_active = player_alive,
        .home_pos = unit_comp.base.home_pos,
        .aggro_multiplier = aggro_multiplier,
        .speed_multiplier = 1.0,
        .dt = dt,
    };

    // Evaluate behavior
    const result = unit_behavior.updateUnitBehavior(behavior_context, state, config.*);

    // Update hex-specific unit state based on behavior result
    unit_comp.base.behavior_state = switch (result.active_behavior) {
        .chase => .chasing,
        .flee => .fleeing,
        .return_home => .idle, // Returning home is considered idle state
        .patrol => .patrolling,
        .guard, .wander, .idle => .idle, // Default to idle for these behaviors
    };

    // Update chase timer and target from library state
    unit_comp.chase_timer = state.chase.chase_timer;
    unit_comp.target_pos = state.chase.target_pos;

    // Apply hex-specific colors based on behavior and profile
    visual.color = getBehaviorColor(result.active_behavior, profile);

    // Apply velocity and position
    transform.vel = result.velocity;
    transform.pos = transform.pos.add(result.velocity.scale(dt));
}

/// Get color for behavior and profile combination
fn getBehaviorColor(behavior: unit_behavior.BehaviorType, profile: BehaviorProfile) @TypeOf(constants.COLOR_UNIT_AGGRESSIVE) {
    return switch (behavior) {
        .chase => switch (profile) {
            .aggressive => constants.COLOR_UNIT_AGGRESSIVE,
            .guardian => colors.PORTAL, // Purple
            else => constants.COLOR_UNIT_AGGRESSIVE,
        },
        .flee => switch (profile) {
            .defensive => colors.OBSTACLE_DEADLY, // Orange
            .wandering => colors.BULLET, // Yellow
            else => colors.OBSTACLE_DEADLY,
        },
        .patrol => colors.PLAYER_ALIVE, // Blue
        .guard => colors.PORTAL, // Purple
        .wander => colors.GREEN_BRIGHT, // Green
        .return_home => constants.COLOR_UNIT_RETURNING,
        .idle => constants.COLOR_UNIT_NON_AGGRO,
    };
}

/// Calculate velocity for unit returning home (using lib utility)
fn calculateReturnHomeVelocity(unit_comp: *const Unit, transform: *const Transform) Vec2 {
    return behaviors_mod.return_home_behavior.simpleReturnHome(
        transform.pos,
        unit_comp.home_pos,
        constants.UNIT_HOME_TOLERANCE,
        constants.UNIT_WALK_SPEED,
    );
}
