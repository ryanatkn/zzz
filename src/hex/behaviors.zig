const std = @import("std");
const math = @import("../lib/math/mod.zig");
const constants = @import("constants.zig");
const hex_game_mod = @import("hex_game.zig");
const frame = @import("../lib/core/frame.zig");
const behaviors_mod = @import("../lib/game/behaviors/mod.zig");

// No additional imports needed - using behavior_state_machine directly

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


/// Optimized hex-specific unit update using persistent state machine
pub fn updateUnitWithAggroMod(
    unit_comp: *Unit,
    transform: *Transform,
    visual: *Visual,
    player_pos: Vec2,
    player_alive: bool,
    aggro_multiplier: f32,
    frame_ctx: FrameContext,
) void {
    const dt = frame_ctx.effectiveDelta();
    const profile = unit_comp.behavior_profile; // Direct profile access - no wrapper!
    
    // Create context for state machine
    const behavior_context = behaviors_mod.behavior_state_machine.BehaviorContext.init(
        transform.pos,         // unit_pos
        unit_comp.home_pos,    // home_pos - direct access!
        if (player_alive) player_pos else null, // player_pos
        player_alive,         // player_alive
        aggro_multiplier,     // aggro_multiplier
        dt                    // dt
    );
    
    const ranges = profile.getRanges(getDetectionRange(profile));
    
    // Use persistent state machine - major performance improvement!
    const result = behaviors_mod.behavior_state_machine.updateBehaviorStateMachine(
        &unit_comp.behavior_state_machine, // Direct access - no wrapper!
        behavior_context,
        profile,
        ranges
    );
    
    // State is now managed entirely by the persistent state machine - no duplication needed!
    
    // Apply hex-specific colors
    visual.color = constants.getBehaviorColor(result.active_behavior, profile);
    
    // Apply movement
    transform.vel = result.velocity;
    transform.pos = transform.pos.add(result.velocity.scale(dt));
}


// No initialization/cleanup needed - persistent state machines manage themselves
