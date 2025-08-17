const std = @import("std");

/// Passthrough formatter that doesn't modify messages
pub const Passthrough = struct {
    const Self = @This();

    pub fn init(_: std.mem.Allocator) Self {
        return Self{};
    }

    pub fn deinit(_: *Self) void {}

    /// Pass through message without modification
    pub fn format(_: Self, _: []u8, _: std.log.Level, message: []const u8) ![]const u8 {
        return message;
    }
};
