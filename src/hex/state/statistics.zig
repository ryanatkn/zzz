// Game Statistics Management - Phase 4 extraction from game_loop.zig
// Handles game statistics tracking using generic StatisticsInterface from lib/game

const std = @import("std");

// Hex game modules
const world = @import("../world/mod.zig");
const systems = @import("../systems/mod.zig");

/// Game statistics management - extracted from game_loop.zig
pub const StatisticsManager = struct {
    /// Check if all lifestones are attuned (achievement tracking)
    pub fn hasAttunedAllLifestones(game_state: anytype) bool {
        return systems.LifestoneSystem.hasAttunedAllLifestones(game_state);
    }

    /// Compute if all lifestones are attuned across the entire world
    pub fn computeAllLifestonesAttunedForWorld(game_state: anytype) bool {
        return systems.LifestoneSystem.hasAttunedAllLifestones(game_state);
    }

    /// Get total number of lifestones in the world
    pub fn computeTotalLifestonesForWorld(game_state: anytype) usize {
        return systems.LifestoneSystem.getTotalLifestones(game_state);
    }

    /// Get number of attuned lifestones in the world
    pub fn computeTotalAttunedLifestonesForWorld(game_state: anytype) usize {
        return systems.LifestoneSystem.getAttunedLifestones(game_state);
    }
};
