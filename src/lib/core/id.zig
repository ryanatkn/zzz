const std = @import("std");

/// Generic ID type for type-safe entity/resource identification
pub fn ID(comptime T: type) type {
    return enum(u64) {
        const Self = @This();
        
        invalid = 0,
        _,

        /// Create an ID from a raw value
        pub fn from(value: u64) Self {
            return @enumFromInt(value);
        }

        /// Get the raw value of the ID
        pub fn raw(self: Self) u64 {
            return @intFromEnum(self);
        }

        /// Check if the ID is valid (not zero)
        pub fn isValid(self: Self) bool {
            return self != .invalid;
        }

        /// Create an invalid ID
        pub fn invalid() Self {
            return .invalid;
        }
    };
}

/// Thread-safe ID generator for creating unique IDs
pub fn IDGenerator(comptime T: type) type {
    return struct {
        const Self = @This();
        const IDType = ID(T);

        counter: std.atomic.Atomic(u64),

        pub fn init() Self {
            return .{
                .counter = std.atomic.Atomic(u64).init(1), // Start at 1 to avoid invalid ID
            };
        }

        /// Generate a new unique ID
        pub fn next(self: *Self) IDType {
            const id_value = self.counter.fetchAdd(1, .Monotonic);
            return IDType.from(id_value);
        }

        /// Reset the generator (mainly for testing)
        pub fn reset(self: *Self) void {
            self.counter.store(1, .Monotonic);
        }

        /// Get the current counter value (for debugging/stats)
        pub fn getCurrentCount(self: *const Self) u64 {
            return self.counter.load(.Monotonic);
        }
    };
}

/// Handle-based resource management system
/// Combines ID generation with a sparse array for fast lookups
pub fn HandleSystem(comptime T: type, comptime max_items: u32) type {
    return struct {
        const Self = @This();
        const HandleID = ID(T);
        const Generator = IDGenerator(T);

        // Sparse array storage
        items: [max_items]?T,
        generations: [max_items]u32, // Track generations to detect stale handles
        free_indices: [max_items]u32,
        free_count: u32,
        generator: Generator,

        pub fn init() Self {
            var self = Self{
                .items = [_]?T{null} ** max_items,
                .generations = [_]u32{0} ** max_items,
                .free_indices = undefined,
                .free_count = max_items,
                .generator = Generator.init(),
            };

            // Initialize free list
            for (0..max_items) |i| {
                self.free_indices[i] = @intCast(max_items - 1 - i);
            }

            return self;
        }

        /// Create a new handle and store the item
        pub fn create(self: *Self, item: T) ?HandleID {
            if (self.free_count == 0) return null;

            self.free_count -= 1;
            const index = self.free_indices[self.free_count];
            
            self.items[index] = item;
            self.generations[index] += 1;
            
            // Encode index and generation into the handle
            const handle_value = (@as(u64, index) << 32) | @as(u64, self.generations[index]);
            return HandleID.from(handle_value);
        }

        /// Get an item by handle
        pub fn get(self: *const Self, handle: HandleID) ?*const T {
            if (!handle.isValid()) return null;
            
            const handle_value = handle.raw();
            const index = @intCast(u32, (handle_value >> 32) & 0xFFFFFFFF);
            const generation = @intCast(u32, handle_value & 0xFFFFFFFF);
            
            if (index >= max_items) return null;
            if (self.generations[index] != generation) return null;
            
            return if (self.items[index]) |*item| item else null;
        }

        /// Get a mutable item by handle
        pub fn getMut(self: *Self, handle: HandleID) ?*T {
            if (!handle.isValid()) return null;
            
            const handle_value = handle.raw();
            const index = @intCast(u32, (handle_value >> 32) & 0xFFFFFFFF);
            const generation = @intCast(u32, handle_value & 0xFFFFFFFF);
            
            if (index >= max_items) return null;
            if (self.generations[index] != generation) return null;
            
            return if (self.items[index]) |*item| item else null;
        }

        /// Remove an item by handle
        pub fn remove(self: *Self, handle: HandleID) ?T {
            if (!handle.isValid()) return null;
            
            const handle_value = handle.raw();
            const index = @intCast(u32, (handle_value >> 32) & 0xFFFFFFFF);
            const generation = @intCast(u32, handle_value & 0xFFFFFFFF);
            
            if (index >= max_items) return null;
            if (self.generations[index] != generation) return null;
            
            if (self.items[index]) |item| {
                self.items[index] = null;
                self.free_indices[self.free_count] = index;
                self.free_count += 1;
                return item;
            }
            
            return null;
        }

        /// Check if a handle is valid and points to an existing item
        pub fn isValid(self: *const Self, handle: HandleID) bool {
            return self.get(handle) != null;
        }

        /// Get current item count
        pub fn getCount(self: *const Self) u32 {
            return max_items - self.free_count;
        }

        /// Get maximum capacity
        pub fn getCapacity(self: *const Self) u32 {
            return max_items;
        }

        /// Check if system is full
        pub fn isFull(self: *const Self) bool {
            return self.free_count == 0;
        }

        /// Check if system is empty
        pub fn isEmpty(self: *const Self) bool {
            return self.free_count == max_items;
        }

        /// Clear all items (invalidates all handles)
        pub fn clear(self: *Self) void {
            self.items = [_]?T{null} ** max_items;
            // Increment all generations to invalidate existing handles
            for (&self.generations) |*gen| {
                gen.* += 1;
            }
            // Rebuild free list
            for (0..max_items) |i| {
                self.free_indices[i] = @intCast(max_items - 1 - i);
            }
            self.free_count = max_items;
        }
    };
}

/// Simple UUID-like ID generator for when you need globally unique IDs
pub const UUID = struct {
    bytes: [16]u8,

    pub fn generate() UUID {
        var bytes: [16]u8 = undefined;
        std.crypto.random.bytes(&bytes);
        
        // Set version (4) and variant bits according to RFC 4122
        bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
        bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 1
        
        return UUID{ .bytes = bytes };
    }

    pub fn toString(self: UUID, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "{:02x}{:02x}{:02x}{:02x}-{:02x}{:02x}-{:02x}{:02x}-{:02x}{:02x}-{:02x}{:02x}{:02x}{:02x}{:02x}{:02x}", .{
            self.bytes[0], self.bytes[1], self.bytes[2], self.bytes[3],
            self.bytes[4], self.bytes[5],
            self.bytes[6], self.bytes[7],
            self.bytes[8], self.bytes[9],
            self.bytes[10], self.bytes[11], self.bytes[12], self.bytes[13], self.bytes[14], self.bytes[15],
        });
    }

    pub fn fromString(str: []const u8) !UUID {
        if (str.len != 36) return error.InvalidUUIDFormat;
        
        var bytes: [16]u8 = undefined;
        var byte_idx: usize = 0;
        var str_idx: usize = 0;
        
        while (str_idx < str.len and byte_idx < 16) {
            if (str[str_idx] == '-') {
                str_idx += 1;
                continue;
            }
            
            if (str_idx + 1 >= str.len) return error.InvalidUUIDFormat;
            
            bytes[byte_idx] = try std.fmt.parseInt(u8, str[str_idx..str_idx + 2], 16);
            byte_idx += 1;
            str_idx += 2;
        }
        
        return UUID{ .bytes = bytes };
    }

    pub fn eql(self: UUID, other: UUID) bool {
        return std.mem.eql(u8, &self.bytes, &other.bytes);
    }
};

// Common entity ID types
pub const EntityID = ID(opaque {});
pub const ComponentID = ID(opaque {});
pub const ResourceID = ID(opaque {});
pub const SystemID = ID(opaque {});

// Global ID generators (these would typically be singletons)
pub var entity_id_generator = IDGenerator(opaque {}).init();
pub var component_id_generator = IDGenerator(opaque {}).init();
pub var resource_id_generator = IDGenerator(opaque {}).init();

// Tests
const testing = std.testing;

test "ID basic functionality" {
    const TestID = ID(opaque {});
    
    const id1 = TestID.from(42);
    const id2 = TestID.from(0);
    const invalid = TestID.invalid();
    
    try testing.expectEqual(@as(u64, 42), id1.raw());
    try testing.expect(id1.isValid());
    try testing.expect(!id2.isValid());
    try testing.expect(!invalid.isValid());
}

test "IDGenerator functionality" {
    const TestGenerator = IDGenerator(opaque {});
    var gen = TestGenerator.init();
    
    const id1 = gen.next();
    const id2 = gen.next();
    
    try testing.expect(id1.isValid());
    try testing.expect(id2.isValid());
    try testing.expect(id1.raw() != id2.raw());
}

test "HandleSystem basic operations" {
    const TestItem = struct { value: i32 };
    const TestSystem = HandleSystem(TestItem, 10);
    
    var system = TestSystem.init();
    
    // Create an item
    const handle = system.create(TestItem{ .value = 42 });
    try testing.expect(handle != null);
    
    // Retrieve the item
    const item = system.get(handle.?);
    try testing.expect(item != null);
    try testing.expectEqual(@as(i32, 42), item.?.value);
    
    // Remove the item
    const removed = system.remove(handle.?);
    try testing.expect(removed != null);
    try testing.expectEqual(@as(i32, 42), removed.?.value);
    
    // Should no longer be accessible
    try testing.expect(system.get(handle.?) == null);
}

test "UUID generation and parsing" {
    const uuid1 = UUID.generate();
    const uuid2 = UUID.generate();
    
    // UUIDs should be different
    try testing.expect(!uuid1.eql(uuid2));
    
    // Test string conversion
    var allocator = testing.allocator;
    const uuid_str = try uuid1.toString(allocator);
    defer allocator.free(uuid_str);
    
    const parsed_uuid = try UUID.fromString(uuid_str);
    try testing.expect(uuid1.eql(parsed_uuid));
}