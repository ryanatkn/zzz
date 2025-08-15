const std = @import("std");
const ArrayList = std.ArrayList;

/// Entity identifier with generation for safe recycling
pub const EntityId = packed struct {
    index: u24, // Index into dense arrays (16M entities)
    generation: u8, // Version counter (256 generations)

    pub const INVALID = EntityId{ .index = 0xFFFFFF, .generation = 0 };

    pub fn isValid(self: EntityId) bool {
        return self.index != 0xFFFFFF;
    }

    pub fn eql(self: EntityId, other: EntityId) bool {
        return self.index == other.index and self.generation == other.generation;
    }
};

/// Manages entity allocation with generation tracking for safe ID recycling
pub const EntityAllocator = struct {
    generations: []u8, // Generation per slot
    free_list: ArrayList(u24), // Available indices
    next_index: u24, // Next unused index
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, initial_capacity: usize) !EntityAllocator {
        const generations = try allocator.alloc(u8, initial_capacity);
        @memset(generations, 0);

        return .{
            .generations = generations,
            .free_list = ArrayList(u24).init(allocator),
            .next_index = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *EntityAllocator) void {
        self.allocator.free(self.generations);
        self.free_list.deinit();
    }

    pub fn create(self: *EntityAllocator) !EntityId {
        // Try to reuse a freed index first
        if (self.free_list.items.len > 0) {
            const index = self.free_list.items[self.free_list.items.len - 1];
            _ = self.free_list.pop();
            return .{
                .index = index,
                .generation = self.generations[index],
            };
        }

        // Allocate new index
        if (self.next_index >= self.generations.len) {
            // TODO: Implement capacity growth
            return error.OutOfEntitySlots;
        }

        const index: u24 = @intCast(self.next_index);
        self.next_index += 1;
        return .{
            .index = index,
            .generation = self.generations[index],
        };
    }

    pub fn destroy(self: *EntityAllocator, id: EntityId) !void {
        if (id.index >= self.generations.len) return error.InvalidEntity;
        if (self.generations[id.index] != id.generation) return error.StaleEntity;

        // Increment generation (with wrapping)
        self.generations[id.index] +%= 1;
        try self.free_list.append(id.index);
    }

    pub fn isAlive(self: *EntityAllocator, id: EntityId) bool {
        if (id.index >= self.generations.len) return false;
        return self.generations[id.index] == id.generation;
    }
};

test "EntityId basic operations" {
    const id1 = EntityId{ .index = 42, .generation = 1 };
    const id2 = EntityId{ .index = 42, .generation = 2 };
    const invalid = EntityId.INVALID;

    try std.testing.expect(id1.isValid());
    try std.testing.expect(!invalid.isValid());
    try std.testing.expect(!id1.eql(id2));
}

test "EntityAllocator lifecycle" {
    var allocator = try EntityAllocator.init(std.testing.allocator, 100);
    defer allocator.deinit();

    // Create entities
    const e1 = try allocator.create();
    const e2 = try allocator.create();
    try std.testing.expect(allocator.isAlive(e1));
    try std.testing.expect(allocator.isAlive(e2));

    // Destroy and recreate
    try allocator.destroy(e1);
    try std.testing.expect(!allocator.isAlive(e1));

    const e3 = try allocator.create();
    try std.testing.expect(e3.index == e1.index);
    try std.testing.expect(e3.generation == e1.generation + 1);
}