const std = @import("std");
const math = @import("../lib/math/mod.zig");
const constants = @import("constants.zig");
const hex_game_mod = @import("hex_game.zig");
const frame = @import("../lib/core/frame.zig");
const colors = @import("../lib/core/colors.zig");
const behaviors_mod = @import("../lib/game/behaviors/mod.zig");

// Import behavior types from the library  
const unit_behavior = behaviors_mod.unit_behavior;

const Vec2 = math.Vec2;
const Unit = hex_game_mod.Unit;
const Transform = hex_game_mod.Transform;
const Visual = hex_game_mod.Visual;
const FrameContext = frame.FrameContext;

// Import BehaviorProfile from hex_game.zig to avoid circular dependency
const BehaviorProfile = hex_game_mod.BehaviorProfile;

// Simplified behavior system - no HashMap storage needed
// State is stored directly in the unit component
// Configuration is profile-based, not per-entity

// Profile-based configuration - no per-entity storage needed
fn getDetectionRange(profile: BehaviorProfile) f32 {
    const base_detection = constants.UNIT_DETECTION_RADIUS;
    return switch (profile) {
        .wandering => base_detection * constants.BEHAVIOR_WANDERING_DETECTION_MULT,
        .guardian => base_detection * constants.BEHAVIOR_GUARDIAN_DETECTION_MULT,
        else => base_detection,
    };
}

// No per-entity state storage needed - state is in unit component
// No per-entity config storage needed - use profile-based configuration

// Patrol waypoints can be generated on-demand if needed
// For now, simple patrol uses simplePatrol function

/// Get behavior profile from unit component
fn getBehaviorProfile(unit_comp: *const Unit) BehaviorProfile {
    return unit_comp.behavior_profile;
}

/// Simplified hex-specific unit update using state machine directly
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
    _ = entity_id; // Not needed anymore
    const dt = frame_ctx.effectiveDelta();
    const profile = getBehaviorProfile(unit_comp);
    
    // Create context for state machine
    const behavior_context = behaviors_mod.behavior_state_machine.BehaviorContext.init(
        transform.pos,         // unit_pos
        unit_comp.base.home_pos, // home_pos
        if (player_alive) player_pos else null, // player_pos
        player_alive,         // player_alive
        aggro_multiplier,     // aggro_multiplier
        dt                    // dt
    );
    
    const ranges = profile.getRanges(getDetectionRange(profile));
    
    // Create a temporary state machine based on current state
    var state_machine = behaviors_mod.behavior_state_machine.BehaviorStateMachine.init(unit_comp.base.behavior_state);
    
    // Update state machine
    const result = behaviors_mod.behavior_state_machine.updateBehaviorStateMachine(
        &state_machine,
        behavior_context,
        profile,
        ranges
    );
    
    // Update unit behavior state to match state machine result
    unit_comp.base.behavior_state = result.active_behavior;
    
    // Apply hex-specific colors
    visual.color = getBehaviorColor(result.active_behavior, profile);
    
    // Apply movement
    transform.vel = result.velocity;
    transform.pos = transform.pos.add(result.velocity.scale(dt));
}

/// Get color for behavior and profile combination
fn getBehaviorColor(behavior: behaviors_mod.behavior_state_machine.BehaviorState, profile: BehaviorProfile) @TypeOf(constants.COLOR_UNIT_AGGRESSIVE) {
    return switch (behavior) {
        .chasing => switch (profile) {
            .aggressive => constants.COLOR_UNIT_AGGRESSIVE,
            .guardian => colors.PORTAL, // Purple
            else => constants.COLOR_UNIT_AGGRESSIVE,
        },
        .fleeing => switch (profile) {
            .defensive => colors.OBSTACLE_DEADLY, // Orange
            .wandering => colors.BULLET, // Yellow
            else => colors.OBSTACLE_DEADLY,
        },
        .patrolling => colors.PLAYER_ALIVE, // Blue
        .guarding => colors.PORTAL, // Purple
        .returning_home => constants.COLOR_UNIT_RETURNING,
        .idle => constants.COLOR_UNIT_NON_AGGRO,
    };
}

// Simplified initialization/cleanup functions
pub fn initBehaviors(allocator: std.mem.Allocator) void {
    _ = allocator; // No storage needed anymore
}

pub fn deinitBehaviors() void {
    // No cleanup needed
}
