const std = @import("std");
const c = @import("../lib/platform/sdl.zig");

const colors = @import("../lib/core/colors.zig");

const Color = colors.Color;

// HUD system now uses GPU-based rendering through the renderer
// Old bitmap digit constants removed - see renderer.zig for current implementation

pub const Hud = struct {
    // HUD visibility toggle (FPS tracking now handled by reactive Time module)
    visible: bool,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .visible = true, // Start visible
        };
    }

    pub fn toggle(self: *Self) void {
        self.visible = !self.visible;
    }

    // Note: FPS tracking is now handled by the reactive Time module
    // The updateFPS() method has been removed in favor of reactive computation
    // Rendering is handled directly by the renderer.drawFPS() method using reactive_time.getFPS()
};
