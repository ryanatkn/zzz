const std = @import("std");

/// Passthrough filter that allows all log messages (identity filter)
pub const Passthrough = struct {
    const Self = @This();
    
    /// Always returns true - no filtering
    pub fn shouldLog(_: Self, _: std.log.Level, _: []const u8, _: []const u8) bool {
        return true;
    }
};