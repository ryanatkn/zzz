const std = @import("std");

/// Cached computation storage to avoid recalculating expensive values
pub const Cache = struct {
    allocator: std.mem.Allocator,
    values: std.StringHashMap(CachedValue),
    
    const Self = @This();
    
    const CachedValue = union(enum) {
        bool: bool,
        int: i64,
        float: f64,
        string: []u8,
    };
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .values = std.StringHashMap(CachedValue).init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        var iter = self.values.iterator();
        while (iter.next()) |entry| {
            switch (entry.value_ptr.*) {
                .string => |s| self.allocator.free(s),
                else => {},
            }
        }
        self.values.deinit();
    }
    
    /// Store a boolean value
    pub fn setBool(self: *Self, key: []const u8, value: bool) !void {
        try self.values.put(key, .{ .bool = value });
    }
    
    /// Store an integer value
    pub fn setInt(self: *Self, key: []const u8, value: i64) !void {
        try self.values.put(key, .{ .int = value });
    }
    
    /// Store a float value
    pub fn setFloat(self: *Self, key: []const u8, value: f64) !void {
        try self.values.put(key, .{ .float = value });
    }
    
    /// Store a string value (copies the string)
    pub fn setString(self: *Self, key: []const u8, value: []const u8) !void {
        const copy = try self.allocator.dupe(u8, value);
        
        // Free old string if it exists
        if (self.values.get(key)) |old| {
            switch (old) {
                .string => |s| self.allocator.free(s),
                else => {},
            }
        }
        
        try self.values.put(key, .{ .string = copy });
    }
    
    /// Get a boolean value
    pub fn getBool(self: *const Self, key: []const u8) ?bool {
        if (self.values.get(key)) |value| {
            switch (value) {
                .bool => |b| return b,
                else => return null,
            }
        }
        return null;
    }
    
    /// Get an integer value
    pub fn getInt(self: *const Self, key: []const u8) ?i64 {
        if (self.values.get(key)) |value| {
            switch (value) {
                .int => |i| return i,
                else => return null,
            }
        }
        return null;
    }
    
    /// Get a float value
    pub fn getFloat(self: *const Self, key: []const u8) ?f64 {
        if (self.values.get(key)) |value| {
            switch (value) {
                .float => |f| return f,
                else => return null,
            }
        }
        return null;
    }
    
    /// Get a string value
    pub fn getString(self: *const Self, key: []const u8) ?[]const u8 {
        if (self.values.get(key)) |value| {
            switch (value) {
                .string => |s| return s,
                else => return null,
            }
        }
        return null;
    }
    
    /// Check if a key exists
    pub fn has(self: *const Self, key: []const u8) bool {
        return self.values.contains(key);
    }
    
    /// Remove a cached value
    pub fn invalidate(self: *Self, key: []const u8) void {
        if (self.values.fetchRemove(key)) |entry| {
            switch (entry.value) {
                .string => |s| self.allocator.free(s),
                else => {},
            }
        }
    }
    
    /// Clear all cached values
    pub fn clear(self: *Self) void {
        var iter = self.values.iterator();
        while (iter.next()) |entry| {
            switch (entry.value_ptr.*) {
                .string => |s| self.allocator.free(s),
                else => {},
            }
        }
        self.values.clearRetainingCapacity();
    }
    
    /// Get the number of cached values
    pub fn count(self: *const Self) usize {
        return self.values.count();
    }
};