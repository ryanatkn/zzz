const std = @import("std");

pub const History = struct {
    stack: std.ArrayList([]const u8),
    current_index: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !History {
        var stack = std.ArrayList([]const u8).init(allocator);
        try stack.append(try allocator.dupe(u8, "/"));
        
        return .{
            .stack = stack,
            .current_index = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *History) void {
        for (self.stack.items) |path| {
            self.allocator.free(path);
        }
        self.stack.deinit();
    }

    pub fn navigate(self: *History, path: []const u8) !void {
        // Remove any forward history
        while (self.stack.items.len > self.current_index + 1) {
            const removed = self.stack.pop();
            self.allocator.free(removed);
        }

        // Add new path
        try self.stack.append(try self.allocator.dupe(u8, path));
        self.current_index = self.stack.items.len - 1;
    }

    pub fn back(self: *History) bool {
        if (self.current_index > 0) {
            self.current_index -= 1;
            return true;
        }
        return false;
    }

    pub fn forward(self: *History) bool {
        if (self.current_index < self.stack.items.len - 1) {
            self.current_index += 1;
            return true;
        }
        return false;
    }

    pub fn getCurrentPath(self: *const History) []const u8 {
        return self.stack.items[self.current_index];
    }
};