const std = @import("std");

// Game system capabilities
const ai_control = @import("../../lib/game/control/mod.zig");

// Platform capabilities
const input = @import("../../lib/platform/input.zig");

// Debug capabilities
const Logger = @import("../../lib/debug/logger.zig").Logger;
const outputs = @import("../../lib/debug/outputs.zig");
const filters = @import("../../lib/debug/filters.zig");

const InputState = input.InputState;

const ModuleLogger = Logger(.{
    .output = outputs.Console,
    .filter = filters.Throttle,
});

/// AI controller functionality extracted from game.zig
pub const AIController = struct {
    /// Initialize AI control system
    pub fn initAIControl(allocator: std.mem.Allocator, logger: *ModuleLogger) !*ai_control.MappedInput {
        // Log the memory layout that Zig expects
        ai_control.DirectInputBuffer.InputCommand.debugLayout();

        const ai = try allocator.create(ai_control.MappedInput);
        ai.* = try ai_control.MappedInput.init(".ai_commands");
        logger.info("ai_init", "AI control system initialized", .{});
        return ai;
    }

    /// Deinitialize AI control system
    pub fn deinitAIControl(ai_input: *ai_control.MappedInput, allocator: std.mem.Allocator, logger: *ModuleLogger) void {
        ai_input.deinit();
        allocator.destroy(ai_input);
        logger.info("ai_deinit", "AI control system deinitialized", .{});
    }

    /// Process AI commands
    pub fn processAICommands(ai_input: *ai_control.MappedInput, input_state: *InputState, frame_counter: u32, logger: *ModuleLogger) void {
        const pending = ai_input.buffer.pending();
        if (pending > 0) {
            logger.info("ai_process", "Processing {} AI commands at frame {}", .{ pending, frame_counter });
        }
        ai_control.processCommands(ai_input.buffer, input_state, frame_counter);
    }

    /// Toggle AI control mode
    pub fn toggleAIControl(ai_enabled: *bool, ai_input: ?*ai_control.MappedInput, logger: *ModuleLogger) void {
        ai_enabled.* = !ai_enabled.*;
        if (ai_input) |mapped| {
            const pending = mapped.buffer.pending();
            logger.info("ai_toggle", "AI control: {} (ai_input exists, {} commands pending)", .{ ai_enabled.*, pending });
        } else {
            logger.info("ai_toggle", "AI control: {} (ai_input is null)", .{ai_enabled.*});
        }
    }
};
