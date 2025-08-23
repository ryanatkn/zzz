// Input Processing - Phase 4 extraction from game_loop.zig
// Handles input processing and command mapping

const std = @import("std");

// Platform capabilities
const input = @import("../../lib/platform/input.zig");

// Game system capabilities
const controllers = @import("../controllers/mod.zig");
const ai_control = @import("../../lib/game/control/mod.zig");

// Debug capabilities
const Logger = @import("../../lib/debug/logger.zig").Logger;
const outputs = @import("../../lib/debug/outputs.zig");
const filters = @import("../../lib/debug/filters.zig");

const InputState = input.InputState;

const ModuleLogger = Logger(.{
    .output = outputs.Console,
    .filter = filters.Throttle,
});

/// Input processing and command mapping - extracted from game_loop.zig
pub const InputHandler = struct {
    /// Initialize AI control system
    pub fn initAIControl(ai_input: *?*ai_control.MappedInput, ai_enabled: *bool, allocator: std.mem.Allocator, logger: *ModuleLogger) !void {
        if (ai_input.* == null) {
            ai_input.* = try controllers.AIController.initAIControl(allocator, logger);
            ai_enabled.* = true;
        }
    }

    /// Cleanup AI control system
    pub fn deinitAIControl(ai_input: *?*ai_control.MappedInput, ai_enabled: *bool, allocator: std.mem.Allocator, logger: *ModuleLogger) void {
        if (ai_input.*) |ai| {
            controllers.AIController.deinitAIControl(ai, allocator, logger);
            ai_input.* = null;
            ai_enabled.* = false;
        }
    }

    /// Toggle AI control on/off
    pub fn toggleAIControl(ai_enabled: *bool, ai_input: ?*ai_control.MappedInput, logger: *ModuleLogger) void {
        controllers.AIController.toggleAIControl(ai_enabled, ai_input, logger);
    }
};
