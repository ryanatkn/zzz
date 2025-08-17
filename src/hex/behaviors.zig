const std = @import("std");
const math = @import("../lib/math/mod.zig");
const constants = @import("constants.zig");
const hex_game_mod = @import("hex_game.zig");
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

// Import BehaviorProfile from hex_game.zig to avoid circular dependency
const BehaviorProfile = hex_game_mod.BehaviorProfile;

/// Unit behavior state storage (games need to manage this)
var unit_behavior_states = std.AutoHashMap(u32, unit_behavior.UnitBehaviorState).init(std.heap.page_allocator);
var unit_behavior_configs = std.AutoHashMap(u32, unit_behavior.UnitBehaviorConfig).init(std.heap.page_allocator);

/// Initialize behavior system
pub fn initBehaviors() void {
    // Clear any existing state
    deinitBehaviors();
    unit_behavior_states = std.AutoHashMap(u32, unit_behavior.UnitBehaviorState).init(std.heap.page_allocator);
    unit_behavior_configs = std.AutoHashMap(u32, unit_behavior.UnitBehaviorConfig).init(std.heap.page_allocator);
}

/// Cleanup behavior system
pub fn deinitBehaviors() void {
    unit_behavior_states.deinit();
    unit_behavior_configs.deinit();
}

/// Create idle behavior config (basic aggro, returns home)
pub fn idle(home_pos: Vec2, detection_range: f32, chase_speed: f32) unit_behavior.UnitBehaviorConfig {
    var config = unit_behavior.UnitBehaviorConfig.init(
        home_pos, 
        detection_range, 
        20.0, // min_distance
        chase_speed, 
        chase_speed * 0.5, // walk_speed
        1.5, // chase_duration (short)
        15.0, // home_tolerance
        1.05 // lose_tolerance (tight)
    );
    config.behavior_priorities.chase = .low;         // Will chase but not aggressively
    config.behavior_priorities.return_home = .normal; // Returns home when player leaves
    config.behavior_priorities.wander = .lowest;     // Minimal wandering
    return config;
}

/// Create behavior config based on profile
pub fn createBehaviorConfig(profile: BehaviorProfile, home_pos: Vec2) unit_behavior.UnitBehaviorConfig {
    return switch (profile) {
        .idle => idle(home_pos, constants.UNIT_DETECTION_RADIUS, constants.UNIT_CHASE_SPEED),
        .aggressive => unit_behavior.UnitBehaviorConfig.aggressive(
            home_pos,
            constants.UNIT_DETECTION_RADIUS,
            constants.UNIT_CHASE_SPEED,
        ),
        .defensive => unit_behavior.UnitBehaviorConfig.defensive(
            home_pos,
            constants.UNIT_DETECTION_RADIUS,
            constants.UNIT_CHASE_SPEED * 1.2, // Flee faster
        ),
        .patrolling => unit_behavior.UnitBehaviorConfig.patrolling(
            home_pos,
            constants.UNIT_DETECTION_RADIUS,
            constants.UNIT_WALK_SPEED,
        ),
        .wandering => blk: {
            var config = unit_behavior.UnitBehaviorConfig.init(
                home_pos,
                constants.UNIT_DETECTION_RADIUS * 0.8, // Smaller detection
                constants.PLAYER_RADIUS + 10.0,
                constants.UNIT_WALK_SPEED,
                constants.UNIT_WALK_SPEED * 0.7, // Walk slower
                2.0, // Short chase duration
                constants.UNIT_HOME_TOLERANCE,
                1.0, // No lose tolerance
            );
            config.behavior_priorities.wander = .high;
            config.behavior_priorities.flee = .critical;
            config.behavior_priorities.chase = .low;
            break :blk config;
        },
        .guardian => blk: {
            var config = unit_behavior.UnitBehaviorConfig.init(
                home_pos,
                constants.UNIT_DETECTION_RADIUS * 1.2, // Larger detection
                constants.PLAYER_RADIUS + 15.0,
                constants.UNIT_CHASE_SPEED,
                constants.UNIT_WALK_SPEED,
                5.0, // Long chase duration
                constants.UNIT_HOME_TOLERANCE * 0.5, // Stay closer to home
                1.25, // Larger lose tolerance
            );
            config.behavior_priorities.guard = .critical;
            config.behavior_priorities.chase = .high;
            config.behavior_priorities.flee = .lowest;
            break :blk config;
        },
    };
}

/// Get or create behavior state for a unit entity
fn getOrCreateBehaviorState(entity_id: u32, unit_comp: *const Unit, profile: BehaviorProfile) *unit_behavior.UnitBehaviorState {
    const state_result = unit_behavior_states.getOrPut(entity_id) catch {
        std.log.err("Failed to get or create behavior state for entity {}", .{entity_id});
        // Return a default state as fallback
        const default_state = unit_behavior.UnitBehaviorState.init(unit_comp.home_pos, &[_]Vec2{}, entity_id);
        return @constCast(&default_state);
    };
    
    if (!state_result.found_existing) {
        // Create new state with appropriate waypoints based on profile
        const waypoints = switch (profile) {
            .patrolling => &[_]Vec2{
                unit_comp.home_pos,
                Vec2{ .x = unit_comp.home_pos.x + 100, .y = unit_comp.home_pos.y },
                Vec2{ .x = unit_comp.home_pos.x + 100, .y = unit_comp.home_pos.y + 100 },
                Vec2{ .x = unit_comp.home_pos.x, .y = unit_comp.home_pos.y + 100 },
            },
            else => &[_]Vec2{}, // No waypoints for other profiles
        };
        
        state_result.value_ptr.* = unit_behavior.UnitBehaviorState.init(
            unit_comp.home_pos,
            waypoints,
            entity_id, // Use entity ID as random seed
        );
    }
    
    return state_result.value_ptr;
}

/// Get or create behavior config for a unit entity
fn getOrCreateBehaviorConfig(entity_id: u32, unit_comp: *const Unit, profile: BehaviorProfile) *unit_behavior.UnitBehaviorConfig {
    const config_result = unit_behavior_configs.getOrPut(entity_id) catch {
        std.log.err("Failed to get or create behavior config for entity {}", .{entity_id});
        // Return a default config as fallback
        const default_config = createBehaviorConfig(.aggressive, unit_comp.home_pos);
        return @constCast(&default_config);
    };
    
    if (!config_result.found_existing) {
        config_result.value_ptr.* = createBehaviorConfig(profile, unit_comp.home_pos);
    }
    
    return config_result.value_ptr;
}

/// Determine behavior profile from stored unit data (not entity ID)
fn determineBehaviorProfile(entity_id: u32, unit_comp: *const Unit) BehaviorProfile {
    _ = entity_id; // No longer needed - use stored behavior
    return unit_comp.behavior_profile; // Use stored value from ZON
}

/// Main hex-specific unit update function using library behaviors
pub fn updateUnitWithAggroMod(
    entity_id: u32,
    unit_comp: *Unit,
    transform: *Transform,
    visual: *Visual,
    player_pos: Vec2,
    player_alive: bool,
    dt: f32,
    aggro_multiplier: f32,
) void {
    // Determine behavior profile for this unit
    const profile = determineBehaviorProfile(entity_id, unit_comp);
    
    // Get or create behavior state and config
    const state = getOrCreateBehaviorState(entity_id, unit_comp, profile);
    const config = getOrCreateBehaviorConfig(entity_id, unit_comp, profile);
    
    // Create behavior context
    const context = unit_behavior.BehaviorContext{
        .unit_pos = transform.pos,
        .target_pos = if (player_alive) player_pos else null,
        .target_alive = player_alive,
        .threat_pos = if (player_alive and profile == .defensive) player_pos else null,
        .threat_active = player_alive and profile == .defensive,
        .home_pos = unit_comp.home_pos,
        .aggro_multiplier = aggro_multiplier,
        .speed_multiplier = 1.0,
        .dt = dt,
    };
    
    // Evaluate behavior
    const result = unit_behavior.updateUnitBehavior(context, state, config.*);
    
    // Update hex-specific unit state based on behavior result
    unit_comp.state = switch (result.active_behavior) {
        .chase => .chasing,
        .flee, .return_home => .returning_home,
        .patrol, .guard, .wander, .idle => .returning_home, // Hex game doesn't distinguish these
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
    const colors = @import("../lib/core/colors.zig");
    
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
        .wander => colors.LIFESTONE_ATTUNED, // Cyan
        .return_home => constants.COLOR_UNIT_RETURNING,
        .idle => constants.COLOR_UNIT_NON_AGGRO,
    };
}

/// Simple unit update using basic chase behavior (for compatibility)
pub fn updateUnitWithAggroMod_Simple(
    unit_comp: *Unit,
    transform: *Transform,
    visual: *Visual,
    player_pos: Vec2,
    player_alive: bool,
    dt: f32,
    aggro_multiplier: f32,
) void {
    var velocity = Vec2.ZERO;

    if (player_alive) {
        // Use simple chase behavior from lib
        const min_distance = transform.radius + constants.PLAYER_RADIUS;
        const chase_velocity = chase_behavior.simpleChase(
            transform.pos,
            player_pos,
            player_alive,
            constants.UNIT_DETECTION_RADIUS,
            min_distance,
            constants.UNIT_CHASE_SPEED,
            aggro_multiplier,
        );

        if (chase_velocity.x != 0.0 or chase_velocity.y != 0.0) {
            // Chasing player
            velocity = chase_velocity;
            visual.color = constants.COLOR_UNIT_AGGRESSIVE;
        } else {
            // Return home (non-aggro state)
            velocity = calculateReturnHomeVelocity(unit_comp, transform);
            visual.color = constants.COLOR_UNIT_NON_AGGRO;
        }
    } else {
        // Player dead - return home (non-aggro state)
        velocity = calculateReturnHomeVelocity(unit_comp, transform);
        visual.color = constants.COLOR_UNIT_NON_AGGRO;
    }

    // Apply velocity
    transform.vel = velocity;
    transform.pos = transform.pos.add(velocity.scale(dt));
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

/// Backwards compatibility wrapper for HexGame units
pub fn updateUnitWithAggroMod_HexGame(
    entity_id: u32,
    unit_comp: *hex_game_mod.Unit,
    transform: *hex_game_mod.Transform,
    visual: *hex_game_mod.Visual,
    player_pos: Vec2,
    player_alive: bool,
    dt: f32,
    aggro_multiplier: f32,
) void {
    updateUnitWithAggroMod(entity_id, unit_comp, transform, visual, player_pos, player_alive, dt, aggro_multiplier);
}