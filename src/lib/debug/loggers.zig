const std = @import("std");
const Logger = @import("logger.zig").Logger;
const outputs = @import("outputs.zig");
const filters = @import("filters.zig");
const formatters = @import("formatters.zig");

// Pre-configured logger types for different use cases

/// Full logging for game-critical modules (game state, combat, etc.)
/// Logs to both console and file with throttling
pub const GameLogger = Logger(.{
    .output = outputs.Multi(.{ 
        outputs.Console, 
        outputs.File(.{ .path = "game.log" })
    }),
    .filter = filters.Throttle,
    .formatter = formatters.Timestamped,
});

/// Console-only logger for UI components (less file spam)
/// Still throttled to prevent console flooding
pub const UILogger = Logger(.{
    .output = outputs.Console,
    .filter = filters.Throttle,
    .formatter = formatters.Passthrough,
});

/// Performance-focused logger for rendering systems
/// Only logs warnings and errors to avoid frame drops
pub const RenderLogger = Logger(.{
    .output = outputs.Console,
    .filter = filters.Level(.{ .min_level = .warn }),
    .formatter = formatters.Passthrough,
});

/// Debug logger for development - verbose output
/// Logs everything without throttling (use sparingly)
pub const DebugLogger = Logger(.{
    .output = outputs.Multi(.{
        outputs.Console,
        outputs.File(.{ .path = "debug.log" })
    }),
    .filter = filters.Passthrough,
    .formatter = formatters.Timestamped,
});

/// Font/text system logger - console only with moderate throttling
pub const FontLogger = Logger(.{
    .output = outputs.Console,
    .filter = filters.Throttle,
    .formatter = formatters.Passthrough,
});

// Global logger instances for modules without allocator access
// Must be initialized by calling initGlobalLoggers()
pub var game_log: ?GameLogger = null;
pub var ui_log: ?UILogger = null;
pub var render_log: ?RenderLogger = null;
pub var font_log: ?FontLogger = null;

/// Initialize global logger instances
/// Call this once at program startup with a persistent allocator
pub fn initGlobalLoggers(allocator: std.mem.Allocator) !void {
    // Clean up any existing loggers first
    deinitGlobalLoggers();
    
    // Initialize new logger instances
    game_log = GameLogger.init(allocator);
    ui_log = UILogger.init(allocator);
    render_log = RenderLogger.init(allocator);
    font_log = FontLogger.init(allocator);
}

/// Clean up global logger instances
/// Call this at program shutdown
pub fn deinitGlobalLoggers() void {
    if (game_log) |*log| {
        log.deinit();
        game_log = null;
    }
    if (ui_log) |*log| {
        log.deinit();
        ui_log = null;
    }
    if (render_log) |*log| {
        log.deinit();
        render_log = null;
    }
    if (font_log) |*log| {
        log.deinit();
        font_log = null;
    }
}

/// Helper to get game logger or panic if not initialized
pub fn getGameLog() *GameLogger {
    return &(game_log orelse @panic("Global game logger not initialized. Call initGlobalLoggers() first."));
}

/// Helper to get UI logger or panic if not initialized
pub fn getUILog() *UILogger {
    return &(ui_log orelse @panic("Global UI logger not initialized. Call initGlobalLoggers() first."));
}

/// Helper to get render logger or panic if not initialized
pub fn getRenderLog() *RenderLogger {
    return &(render_log orelse @panic("Global render logger not initialized. Call initGlobalLoggers() first."));
}

/// Helper to get font logger or panic if not initialized
pub fn getFontLog() *FontLogger {
    return &(font_log orelse @panic("Global font logger not initialized. Call initGlobalLoggers() first."));
}