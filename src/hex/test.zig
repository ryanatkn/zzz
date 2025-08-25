// Hex Game Test Barrel File
//
// This file re-exports all tests from hex game modules for clean integration
// with the main test suite.

const std = @import("std");

// Import all module tests that don't require SDL
test {
    // Core game logic modules (no SDL dependency)
    _ = @import("factions.zig");
    _ = @import("constants.zig");
    _ = @import("disposition.zig");
    _ = @import("coordinate_validation.zig");

    // New module structure - import mod.zig files for non-SDL modules
    _ = @import("entities/mod.zig");
    _ = @import("systems/mod.zig"); // May have tests but systems likely use SDL
    _ = @import("world/mod.zig"); // Zone/world logic shouldn't need SDL
    _ = @import("abilities/mod.zig"); // Ability type definitions and helpers
    _ = @import("combat/mod.zig"); // Combat system module

    // Skip modules that definitely use SDL:
    // - controllers/mod.zig (uses input system)
    // - ui/mod.zig (uses rendering)
    // - rendering/mod.zig (all rendering modules use SDL GPU)
    // - game_loop.zig, game_renderer.zig, world_state.zig (use SDL directly)
    //
    // Note: Old files game.zig and hex_game.zig were removed after Phase 1 refactoring
}
