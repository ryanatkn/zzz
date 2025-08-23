const std = @import("std");
const c = @import("sdl.zig");
const loggers = @import("../debug/loggers.zig");

/// Window creation and management utilities
/// This is platform-level functionality that doesn't depend on rendering
/// Common error types for window operations
pub const WindowError = error{
    WindowCreationFailed,
    OutOfMemory,
};

/// Window configuration structure
pub const WindowConfig = struct {
    title: [*:0]const u8,
    width: i32,
    height: i32,
    flags: u32 = c.sdl.SDL_WINDOW_VULKAN,
};

/// Create a window with the specified configuration
pub fn createWindow(config: WindowConfig) WindowError!*c.sdl.SDL_Window {
    return c.sdl.SDL_CreateWindow(config.title, config.width, config.height, config.flags) orelse {
        const game_log = loggers.getGameLog();
        game_log.err("window", "Failed to create window: {s} {}x{}", .{ config.title, config.width, config.height });
        return WindowError.WindowCreationFailed;
    };
}
