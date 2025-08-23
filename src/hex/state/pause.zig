// Pause State Management - Phase 4 extraction from game_loop.zig
// Handles pause/resume functionality and quit requests

const std = @import("std");

// Debug capabilities
const Logger = @import("../../lib/debug/logger.zig").Logger;
const outputs = @import("../../lib/debug/outputs.zig");
const filters = @import("../../lib/debug/filters.zig");

const ModuleLogger = Logger(.{
    .output = outputs.Console,
    .filter = filters.Throttle,
});

/// Pause state management - extracted from game_loop.zig
pub const PauseManager = struct {
    /// Toggle game pause state
    pub fn togglePause(game_paused: *bool, logger: *ModuleLogger) void {
        game_paused.* = !game_paused.*;
        if (game_paused.*) {
            logger.info("game_paused", "Game paused", .{});
        } else {
            logger.info("game_resumed", "Game resumed", .{});
        }
    }

    /// Request game quit
    pub fn requestQuit(quit_requested: *bool) void {
        quit_requested.* = true;
    }

    /// Check if quit was requested
    pub fn shouldQuit(quit_requested: bool) bool {
        return quit_requested;
    }

    /// Check if game is paused
    pub fn isPaused(game_paused: bool) bool {
        return game_paused;
    }
};
