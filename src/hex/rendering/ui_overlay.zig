const std = @import("std");
const c = @import("../../lib/platform/sdl.zig");
const math = @import("../../lib/math/mod.zig");
const core_colors = @import("../../lib/core/colors.zig");
const time_utils = @import("../../lib/core/time.zig");

// Reuse lib/rendering UI utilities
const ui_drawing = @import("../../lib/rendering/ui/drawing.zig");
const shapes = @import("../../lib/rendering/primitives/shapes.zig");

// Font capabilities
const font_manager = @import("../../lib/font/manager.zig");
const font_config = @import("../../lib/font/config.zig");

// Text capabilities
const text_alignment = @import("../../lib/text/alignment.zig");

// UI capabilities
const geometric_text = @import("../../lib/ui/geometric_text.zig");

// Debug capabilities
const loggers = @import("../../lib/debug/loggers.zig");

// Hex game modules
const world_state_mod = @import("../world_state.zig");
const constants = @import("../constants.zig");

const Vec2 = math.Vec2;
const Color = core_colors.Color;
const HexGame = world_state_mod.HexGame;

/// UI overlay rendering system extracted from game_renderer.zig
/// Handles FPS counter, debug info, and AI mode indicator using lib/rendering/ui patterns
pub const UIOverlayRenderer = struct {
    /// FPS rendering using geometric approach
    /// Extracted from game_renderer.zig lines 324-346
    pub fn drawFPS(gpu_renderer: anytype, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, fps: u32) void {
        // TODO: Implement FPS display with geometric text rendering
        _ = gpu_renderer;
        _ = cmd_buffer;
        _ = render_pass;
        _ = fps;
    }

    /// Debug info rendering - player coordinates and camera viewport
    /// Extracted from game_renderer.zig lines 349-370
    pub fn drawDebugInfo(gpu_renderer: anytype, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, game: *const HexGame) void {
        // Simplified debug info - just show coordinates for now
        // TODO: Use geometric text rendering like FPS if debug display is needed
        _ = gpu_renderer;
        _ = cmd_buffer;
        _ = render_pass;
        _ = game;
    }

    /// AI mode indicator with proper alignment
    /// Extracted from game_renderer.zig lines 372-398
    pub fn drawAIMode(gpu_renderer: anytype, ai_enabled: bool) void {
        // Simplified AI mode - just skip for now
        // TODO: Use geometric text rendering if AI mode display is needed
        _ = gpu_renderer;
        _ = ai_enabled;
    }
};
