const std = @import("std");
const c = @import("../../lib/platform/sdl.zig");
const math = @import("../../lib/math/mod.zig");
const core_colors = @import("../../lib/core/colors.zig");
const hex_colors = @import("../colors.zig");
const constants = @import("../constants.zig");
const loggers = @import("../../lib/debug/loggers.zig");
const world_state_mod = @import("../world_state.zig");

const Vec2 = math.Vec2;
const HexGame = world_state_mod.HexGame;

/// UI overlay rendering system for debug displays
/// Handles FPS counter, debug info, and AI mode indicator with optimized text rendering
pub const UIOverlayRenderer = struct {
    /// Prepare FPS text texture BEFORE render pass (avoids copy pass conflicts)
    pub fn prepareFPS(gpu_renderer: anytype, fps: u32, font_mgr: anytype) void {
        // Format FPS text
        var fps_buffer: [32]u8 = undefined;
        const fps_text = std.fmt.bufPrint(&fps_buffer, "FPS: {}", .{fps}) catch "FPS: ERR";
        const position = Vec2{ .x = 10.0, .y = 10.0 };

        // Queue FPS text for buffer-based rendering
        gpu_renderer.text_integration.queuePersistentText(fps_text, position, font_mgr, .sans, 14.0, core_colors.WHITE) catch |err| {
            const fps_error_log = loggers.getRenderLog();
            fps_error_log.err("fps_display", "Failed to queue FPS text: {}", .{err});
            return;
        };

        // DEBUG: Add test text with visible characters to verify vertex rendering
        const test_position = Vec2{ .x = 10.0, .y = 35.0 };
        gpu_renderer.text_integration.queuePersistentText("ABC", test_position, font_mgr, .sans, 24.0, hex_colors.RED_BRIGHT) catch |err| {
            const test_log = loggers.getRenderLog();
            test_log.err("test_text", "Failed to queue test ABC text: {}", .{err});
            return;
        };
    }

    /// Draw FPS text (assumes texture was already created in prepareFPS)
    pub fn drawFPS(gpu_renderer: anytype, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass) void {
        _ = gpu_renderer; // Textures already prepared
        _ = cmd_buffer;
        _ = render_pass;
        // Text textures were already created and queued in prepareFPS
        // They will be drawn in the main text rendering pass
    }

    /// Prepare debug info text texture BEFORE render pass
    pub fn prepareDebugInfo(gpu_renderer: anytype, game: *const HexGame, font_mgr: anytype) void {
        // Get controlled entity position for debugging
        const controlled_pos = if (game.getControlledEntity()) |controlled_entity| blk: {
            const zone = game.getCurrentZoneConst();
            if (zone.units.getComponent(controlled_entity, .transform)) |transform| {
                break :blk transform.pos;
            }
            break :blk Vec2.ZERO;
        } else Vec2.ZERO;

        // Format coordinate text
        var coord_buffer: [64]u8 = undefined;
        const coord_text = std.fmt.bufPrint(&coord_buffer, "Pos: ({d:.1}, {d:.1})", .{ controlled_pos.x, controlled_pos.y }) catch "Pos: ERR";

        // Position below FPS display
        const position = Vec2{ .x = 10.0, .y = 35.0 };

        // TEMPORARY: Disable text rendering due to SDL3 device->debug_mode crash
        _ = gpu_renderer;
        _ = font_mgr;
        _ = coord_text;
        _ = position;

        // TODO: Re-enable once SDL3 issue is resolved
        // gpu_renderer.text_integration.queuePersistentText(coord_text, position, font_mgr, .sans, 12.0, hex_colors.YELLOW_BRIGHT) catch |err| {
        //     const render_log = loggers.getRenderLog();
        //     render_log.err("debug_info", "Failed to queue debug info: {}", .{err});
        //     return;
        // };
    }

    /// Draw debug info (assumes texture was already created in prepareDebugInfo)
    pub fn drawDebugInfo(gpu_renderer: anytype, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass) void {
        _ = gpu_renderer; // Textures already prepared
        _ = cmd_buffer; // Not used in current implementation
        _ = render_pass; // Not used in current implementation
        // Text textures were already created and queued in prepareDebugInfo
    }

    /// Prepare AI mode text texture BEFORE render pass
    pub fn prepareAIMode(gpu_renderer: anytype, ai_enabled: bool, font_mgr: anytype) void {
        // Only show indicator when AI is enabled
        if (ai_enabled) {
            const ai_text = "AI CONTROL";

            // Use hex game constants for screen width
            const screen_width = constants.SCREEN_WIDTH;

            // Position in top-right corner for visibility
            const position = Vec2{ .x = screen_width - 120.0, .y = 10.0 };

            // TEMPORARY: Disable text rendering due to SDL3 device->debug_mode crash
            _ = gpu_renderer;
            _ = font_mgr;
            _ = ai_text;
            _ = position;

            // TODO: Re-enable once SDL3 issue is resolved
            // gpu_renderer.text_integration.queuePersistentText(ai_text, position, font_mgr, .sans, 14.0, hex_colors.RED_BRIGHT) catch |err| {
            //     const render_log = loggers.getRenderLog();
            //     render_log.err("ai_indicator", "Failed to queue AI mode text: {}", .{err});
            //     return;
            // };
        }
    }

    /// Draw AI mode indicator (assumes texture was already created in prepareAIMode)
    pub fn drawAIMode(gpu_renderer: anytype, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass) void {
        _ = gpu_renderer; // Textures already prepared
        _ = cmd_buffer;
        _ = render_pass;
        // Text textures were already created and queued in prepareAIMode
    }
};
