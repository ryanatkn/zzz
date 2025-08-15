const std = @import("std");

// Centralized logging configuration
// These values are used at compile-time to configure logger instances
// Change these values and recompile to adjust logging behavior

// Game logger configuration (file + console)
pub const game_log = .{
    .file_path = "game.log",
    .throttle_interval_ms = 30000, // Summary every 30 seconds
    .first_time_delay_ms = 1000,   // Allow first occurrences for 1 second
    .min_level = .info,
};

// UI logger configuration (console only)
pub const ui_log = .{
    .throttle_interval_ms = 1000,  // More aggressive throttling for UI
    .first_time_delay_ms = 500,    // Shorter startup window
    .min_level = .debug,
};

// Render logger configuration (performance critical)
pub const render_log = .{
    .min_level = .warn,  // Only warnings and errors
};

// Font/text logger configuration (console only)
pub const font_log = .{
    .throttle_interval_ms = 5000,  // Moderate throttling
    .first_time_delay_ms = 1000,
    .min_level = .info,
};

// Debug logger configuration (verbose, unthrottled)
pub const debug_log = .{
    .file_path = "debug.log",
    .min_level = .debug,
};

// Optional: Load runtime overrides from ZON file
// This is primarily for development/debugging
pub fn loadOverrides(allocator: std.mem.Allocator) !OverrideConfig {
    const zon_path = ".zz/log-config.zon";
    
    const zon_file = std.fs.cwd().readFileAlloc(allocator, zon_path, 8192) catch |err| {
        // No config file = use defaults
        if (err == error.FileNotFound) {
            return OverrideConfig{};
        }
        return err;
    };
    defer allocator.free(zon_file);
    
    // Null-terminate for ZON parser
    const zon_data = try allocator.dupeZ(u8, zon_file);
    defer allocator.free(zon_data);
    
    // Parse ZON configuration
    const parsed = std.zon.parse.fromSlice(OverrideConfig, allocator, zon_data, null, .{}) catch |err| {
        std.log.warn("Failed to parse log config: {}", .{err});
        return OverrideConfig{};
    };
    
    return parsed;
}

// Runtime override configuration structure
pub const OverrideConfig = struct {
    game_throttle_ms: ?i64 = null,
    ui_throttle_ms: ?i64 = null,
    font_throttle_ms: ?i64 = null,
    
    // Apply overrides to mutable logger settings
    pub fn apply(self: OverrideConfig) void {
        // This will be called after loggers are initialized
        // to update their mutable settings
        const loggers = @import("loggers.zig");
        
        if (self.game_throttle_ms) |ms| {
            if (loggers.game_log) |*log| {
                if (@hasField(@TypeOf(log.filter), "summary_interval_ms")) {
                    log.filter.summary_interval_ms = ms;
                }
            }
        }
        
        if (self.ui_throttle_ms) |ms| {
            if (loggers.ui_log) |*log| {
                if (@hasField(@TypeOf(log.filter), "summary_interval_ms")) {
                    log.filter.summary_interval_ms = ms;
                }
            }
        }
        
        if (self.font_throttle_ms) |ms| {
            if (loggers.font_log) |*log| {
                if (@hasField(@TypeOf(log.filter), "summary_interval_ms")) {
                    log.filter.summary_interval_ms = ms;
                }
            }
        }
    }
};