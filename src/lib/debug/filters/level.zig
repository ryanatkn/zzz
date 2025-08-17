const std = @import("std");

/// Level filter that only allows log messages at or above a minimum level
pub fn Level(comptime config: LevelConfig) type {
    return struct {
        const Self = @This();

        /// Check if a log message should be allowed based on its level
        pub fn shouldLog(_: Self, level: std.log.Level, _: []const u8, _: []const u8) bool {
            return @intFromEnum(level) <= @intFromEnum(config.min_level);
        }
    };
}

/// Configuration for level filter
pub const LevelConfig = struct {
    min_level: std.log.Level,
};
