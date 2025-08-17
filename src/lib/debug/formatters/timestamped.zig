const std = @import("std");

/// Timestamped formatter that adds timestamps to log messages
pub const Timestamped = struct {
    const Self = @This();

    /// Format a log message with timestamp prefix
    pub fn format(_: Self, buffer: []u8, level: std.log.Level, message: []const u8) ![]const u8 {
        const timestamp = std.time.timestamp();
        const level_str = switch (level) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
        };

        return std.fmt.bufPrint(buffer, "[{}] {s}: {s}", .{ timestamp, level_str, message });
    }
};
