/// Memory management utilities and semantic helpers
/// Consolidates common allocation patterns into reusable helpers
const std = @import("std");

/// Allocator helper utilities for common patterns
/// Eliminates duplicate `std.ArrayList(T).init(allocator)` constructions
pub const AllocatorHelpers = struct {
    /// Create a list with semantic naming for clarity
    pub fn createList(comptime T: type, allocator: std.mem.Allocator) std.ArrayList(T) {
        return std.ArrayList(T).init(allocator);
    }

    /// Create a string hash map with semantic naming for clarity
    pub fn createStringMap(comptime V: type, allocator: std.mem.Allocator) std.StringHashMap(V) {
        return std.StringHashMap(V).init(allocator);
    }

    /// Create an array list with initial capacity
    pub fn createListWithCapacity(comptime T: type, allocator: std.mem.Allocator, capacity: usize) !std.ArrayList(T) {
        var list = std.ArrayList(T).init(allocator);
        try list.ensureTotalCapacity(capacity);
        return list;
    }

    /// Create a string hash map with initial capacity
    pub fn createStringMapWithCapacity(comptime V: type, allocator: std.mem.Allocator, capacity: u32) !std.StringHashMap(V) {
        var map = std.StringHashMap(V).init(allocator);
        try map.ensureTotalCapacity(capacity);
        return map;
    }

    /// Create a bounded array (fixed-size stack array)
    pub fn createBoundedArray(comptime T: type, comptime capacity: usize) std.BoundedArray(T, capacity) {
        return std.BoundedArray(T, capacity){};
    }

    /// Create an arena allocator
    pub fn createArena(backing_allocator: std.mem.Allocator) std.heap.ArenaAllocator {
        return std.heap.ArenaAllocator.init(backing_allocator);
    }
};

/// Resource management patterns for automatic cleanup
pub const ResourceManager = struct {
    /// RAII-style wrapper for ArrayList with automatic cleanup
    pub fn ManagedList(comptime T: type) type {
        return struct {
            list: std.ArrayList(T),
            allocator: std.mem.Allocator,

            const Self = @This();

            pub fn init(allocator: std.mem.Allocator) Self {
                return Self{
                    .list = AllocatorHelpers.createList(T, allocator),
                    .allocator = allocator,
                };
            }

            pub fn deinit(self: *Self) void {
                self.list.deinit();
            }

            /// Append item to the list
            pub fn append(self: *Self, item: T) !void {
                try self.list.append(item);
            }

            /// Get items slice
            pub fn items(self: *const Self) []const T {
                return self.list.items;
            }

            /// Get mutable items slice
            pub fn itemsMut(self: *Self) []T {
                return self.list.items;
            }

            /// Clear the list but retain capacity
            pub fn clearRetainingCapacity(self: *Self) void {
                self.list.clearRetainingCapacity();
            }

            /// Get list length
            pub fn len(self: *const Self) usize {
                return self.list.items.len;
            }
        };
    }

    /// RAII-style wrapper for StringHashMap with automatic cleanup
    pub fn ManagedStringMap(comptime V: type) type {
        return struct {
            map: std.StringHashMap(V),
            allocator: std.mem.Allocator,

            const Self = @This();

            pub fn init(allocator: std.mem.Allocator) Self {
                return Self{
                    .map = AllocatorHelpers.createStringMap(V, allocator),
                    .allocator = allocator,
                };
            }

            pub fn deinit(self: *Self) void {
                self.map.deinit();
            }

            /// Put key-value pair
            pub fn put(self: *Self, key: []const u8, value: V) !void {
                try self.map.put(key, value);
            }

            /// Get value by key
            pub fn get(self: *const Self, key: []const u8) ?V {
                return self.map.get(key);
            }

            /// Remove entry by key
            pub fn remove(self: *Self, key: []const u8) bool {
                return self.map.remove(key);
            }

            /// Get map count
            pub fn count(self: *const Self) u32 {
                return self.map.count();
            }
        };
    }

    /// RAII-style wrapper for ArenaAllocator with automatic cleanup
    pub const ManagedArena = struct {
        arena: std.heap.ArenaAllocator,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(backing_allocator: std.mem.Allocator) Self {
            return Self{
                .arena = AllocatorHelpers.createArena(backing_allocator),
                .allocator = undefined, // Will be set below
            };
        }

        pub fn initComplete(self: *Self) void {
            self.allocator = self.arena.allocator();
        }

        pub fn deinit(self: *Self) void {
            self.arena.deinit();
        }

        /// Reset arena but retain capacity
        pub fn reset(self: *Self, mode: std.heap.ArenaAllocator.ResetMode) std.mem.Allocator {
            _ = self.arena.reset(mode);
            return self.arena.allocator();
        }
    };
};

test "allocator helpers" {
    const gpa = std.testing.allocator;

    // Test list creation
    var list = AllocatorHelpers.createList(i32, gpa);
    defer list.deinit();
    try list.append(42);
    try std.testing.expect(list.items.len == 1);
    try std.testing.expect(list.items[0] == 42);

    // Test string map creation
    var map = AllocatorHelpers.createStringMap(i32, gpa);
    defer map.deinit();
    try map.put("test", 100);
    try std.testing.expect(map.get("test").? == 100);

    // Test bounded array
    var bounded = AllocatorHelpers.createBoundedArray(i32, 10);
    try bounded.append(1);
    try bounded.append(2);
    try std.testing.expect(bounded.len == 2);
    try std.testing.expect(bounded.get(0) == 1);
}

test "managed resources" {
    const gpa = std.testing.allocator;

    // Test managed list
    var managed_list = ResourceManager.ManagedList(i32).init(gpa);
    defer managed_list.deinit();
    try managed_list.append(10);
    try managed_list.append(20);
    try std.testing.expect(managed_list.len() == 2);
    try std.testing.expect(managed_list.items()[0] == 10);

    // Test managed string map
    var managed_map = ResourceManager.ManagedStringMap([]const u8).init(gpa);
    defer managed_map.deinit();
    try managed_map.put("key1", "hello");
    try managed_map.put("key2", "world");
    try std.testing.expect(managed_map.count() == 2);
    try std.testing.expect(std.mem.eql(u8, managed_map.get("key1").?, "hello"));

    // Test managed arena
    var managed_arena = ResourceManager.ManagedArena.init(gpa);
    defer managed_arena.deinit();
    managed_arena.initComplete();

    const allocated = try managed_arena.allocator.alloc(u8, 100);
    try std.testing.expect(allocated.len == 100);

    // Reset arena
    _ = managed_arena.reset(.retain_capacity);
}
