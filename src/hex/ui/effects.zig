const std = @import("std");

// Core capabilities
const time_utils = @import("../../lib/core/time.zig");

// Game system capabilities
const GameParticleSystem = @import("../../lib/particles/game_particles.zig").GameParticleSystem;

// Hex game modules
const constants = @import("../constants.zig");

/// Visual effects coordination extracted from game.zig
pub const EffectsSystem = struct {
    /// Handle respawn iris wipe effect
    pub fn handleRespawn(game_state: anytype) void {
        // Start iris wipe effect
        game_state.iris_wipe_active = true;
        game_state.iris_wipe_start_time = time_utils.Time.now();

        const combat = @import("../combat/mod.zig");
        combat.death.respawnPlayer(game_state);
    }

    /// Update iris wipe effect
    pub fn updateIrisWipe(game_state: anytype) void {
        if (game_state.iris_wipe_active) {
            const elapsed_sec = game_state.iris_wipe_start_time.getElapsedSec();
            if (elapsed_sec >= constants.IRIS_WIPE_DURATION) {
                game_state.iris_wipe_active = false;
            }
        }
    }

    /// Clear all effects for zone transitions
    pub fn clearAllEffects(particle_system: *GameParticleSystem) void {
        particle_system.clear();
    }

    /// Add lifestone attunement effect
    pub fn addLifestoneEffect(particle_system: *GameParticleSystem, pos: @import("../../lib/math/mod.zig").Vec2, radius: f32) void {
        particle_system.addLifestoneInnerParticleOnly(pos, radius);
    }

    /// Add portal travel effect
    pub fn addPortalTravelEffect(particle_system: *GameParticleSystem, pos: @import("../../lib/math/mod.zig").Vec2, radius: f32) void {
        particle_system.addPortalTravelParticle(pos, radius);
    }
};
