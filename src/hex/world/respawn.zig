// Respawn Mechanics - Phase 3 extraction from world_state.zig
// Handles lifestone and respawn functionality, delegating to existing systems

const std = @import("std");

// Core capabilities
const math = @import("../../lib/math/mod.zig");

// Hex game modules
const world_state_mod = @import("../world_state.zig");
const lifestone_mod = @import("../systems/lifestone.zig");

const Vec2 = math.Vec2;
const HexGame = world_state_mod.HexGame;

/// Respawn management - extracted from world_state.zig
/// This module provides a clean interface for respawn mechanics while
/// delegating to the existing LifestoneSystem to avoid duplication
pub const Respawn = struct {
    /// Check lifestone collisions for player respawn/attunement
    /// Delegates to the existing LifestoneSystem implementation
    pub fn checkLifestoneCollisions(game_state: anytype, player_pos: Vec2, player_radius: f32) void {
        lifestone_mod.LifestoneSystem.checkLifestoneCollisions(game_state, player_pos, player_radius);
    }

    /// Check if all lifestones across all zones are attuned
    /// Delegates to the existing LifestoneSystem implementation
    pub fn hasAttunedAllLifestones(game_state: anytype) bool {
        return lifestone_mod.LifestoneSystem.hasAttunedAllLifestones(game_state);
    }

    /// Get total number of lifestones in the world
    /// Delegates to the existing LifestoneSystem implementation
    pub fn getTotalLifestones(game_state: anytype) usize {
        return lifestone_mod.LifestoneSystem.getTotalLifestones(game_state);
    }

    /// Get number of attuned lifestones in the world
    /// Delegates to the existing LifestoneSystem implementation
    pub fn getAttunedLifestones(game_state: anytype) usize {
        return lifestone_mod.LifestoneSystem.getAttunedLifestones(game_state);
    }

    /// Respawn player at nearest attuned lifestone
    /// TODO: Implement respawn logic using lifestone positions
    pub fn respawnPlayer(game: *HexGame, force_spawn_pos: ?Vec2) !void {
        // Simple respawn implementation - move to spawn position
        const spawn_pos = force_spawn_pos orelse blk: {
            const zone = game.getCurrentZone();
            break :blk zone.spawn_pos;
        };

        game.setPlayerPos(spawn_pos);
        game.setPlayerAlive(true);

        game.logger.info("player_respawn", "Player respawned at {any}", .{spawn_pos});
    }
};
