const std = @import("std");

/// Console output backend that writes to standard logging
pub const Console = struct {
    const Self = @This();
    
    /// Write a log message to console via std.log
    pub fn write(_: Self, level: std.log.Level, message: []const u8) void {
        switch (level) {
            .debug => std.log.debug("{s}", .{message}),
            .info => std.log.info("{s}", .{message}),
            .warn => std.log.warn("{s}", .{message}),
            .err => std.log.err("{s}", .{message}),
        }
    }
};