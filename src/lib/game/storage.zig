const std = @import("std");
const entity = @import("entity.zig");
const EntityId = entity.EntityId;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;

/// Dense storage for components that most entities have
/// Uses SOA (Structure of Arrays) for cache efficiency
pub fn DenseStorage(comptime T: type) type {
    return struct {
        const Self = @This();

        data: []T, // Component data
        entity_to_dense: []?u32, // EntityId.index -> dense array index
        dense_to_entity: []EntityId, // dense array index -> EntityId
        count: u32,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, max_entities: usize) !Self {
            const data = try allocator.alloc(T, max_entities);
            const entity_to_dense = try allocator.alloc(?u32, max_entities);
            const dense_to_entity = try allocator.alloc(EntityId, max_entities);

            @memset(entity_to_dense, null);

            return .{
                .data = data,
                .entity_to_dense = entity_to_dense,
                .dense_to_entity = dense_to_entity,
                .count = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.data);
            self.allocator.free(self.entity_to_dense);
            self.allocator.free(self.dense_to_entity);
        }

        pub fn add(self: *Self, id: EntityId, component: T) !void {
            if (id.index >= self.entity_to_dense.len) return error.InvalidEntity;
            if (self.entity_to_dense[id.index] != null) return error.ComponentExists;
            if (self.count >= self.data.len) return error.StorageFull;

            const dense_idx = self.count;
            self.data[dense_idx] = component;
            self.entity_to_dense[id.index] = dense_idx;
            self.dense_to_entity[dense_idx] = id;
            self.count += 1;
        }

        pub fn remove(self: *Self, id: EntityId) bool {
            if (id.index >= self.entity_to_dense.len) return false;
            const dense_idx = self.entity_to_dense[id.index] orelse return false;

            // Validate generation
            if (!self.dense_to_entity[dense_idx].eql(id)) return false;

            // Swap with last element
            const last_idx = self.count - 1;
            if (dense_idx != last_idx) {
                self.data[dense_idx] = self.data[last_idx];
                const moved_entity = self.dense_to_entity[last_idx];
                self.dense_to_entity[dense_idx] = moved_entity;
                self.entity_to_dense[moved_entity.index] = dense_idx;
            }

            self.entity_to_dense[id.index] = null;
            self.count -= 1;
            return true;
        }

        pub fn get(self: *Self, id: EntityId) ?*T {
            if (id.index >= self.entity_to_dense.len) return null;
            const dense_idx = self.entity_to_dense[id.index] orelse return null;

            // Validate generation
            if (!self.dense_to_entity[dense_idx].eql(id)) return null;

            return &self.data[dense_idx];
        }

        pub fn getConst(self: *const Self, id: EntityId) ?*const T {
            if (id.index >= self.entity_to_dense.len) return null;
            const dense_idx = self.entity_to_dense[id.index] orelse return null;

            // Validate generation
            if (!self.dense_to_entity[dense_idx].eql(id)) return null;

            return &self.data[dense_idx];
        }

        pub fn has(self: *const Self, id: EntityId) bool {
            if (id.index >= self.entity_to_dense.len) return false;
            const dense_idx = self.entity_to_dense[id.index] orelse return false;
            return self.dense_to_entity[dense_idx].eql(id);
        }

        /// Iterator for efficient component processing
        pub fn iterator(self: *Self) Iterator {
            return .{ .storage = self, .index = 0 };
        }

        pub const Iterator = struct {
            storage: *Self,
            index: u32,

            pub fn next(it: *Iterator) ?struct { entity: EntityId, component: *T } {
                if (it.index >= it.storage.count) return null;
                const idx = it.index;
                it.index += 1;
                return .{
                    .entity = it.storage.dense_to_entity[idx],
                    .component = &it.storage.data[idx],
                };
            }
        };
    };
}

/// Sparse storage for components that few entities have
/// Uses hash map for memory efficiency
pub fn SparseStorage(comptime T: type) type {
    return struct {
        const Self = @This();

        data: AutoHashMap(EntityId, T),

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .data = AutoHashMap(EntityId, T).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit();
        }

        pub fn add(self: *Self, id: EntityId, component: T) !void {
            try self.data.put(id, component);
        }

        pub fn remove(self: *Self, id: EntityId) bool {
            return self.data.remove(id);
        }

        pub fn get(self: *Self, id: EntityId) ?*T {
            return self.data.getPtr(id);
        }

        pub fn getConst(self: *const Self, id: EntityId) ?*const T {
            return self.data.getPtr(id);
        }

        pub fn has(self: *const Self, id: EntityId) bool {
            return self.data.contains(id);
        }

        pub fn iterator(self: *Self) AutoHashMap(EntityId, T).Iterator {
            return self.data.iterator();
        }
    };
}

test "DenseStorage operations" {
    const TestComponent = struct { value: i32 };

    var storage = try DenseStorage(TestComponent).init(std.testing.allocator, 10);
    defer storage.deinit();

    const e1 = EntityId{ .index = 0, .generation = 1 };
    const e2 = EntityId{ .index = 1, .generation = 1 };

    try storage.add(e1, .{ .value = 42 });
    try storage.add(e2, .{ .value = 100 });

    try std.testing.expect(storage.get(e1).?.value == 42);
    try std.testing.expect(storage.get(e2).?.value == 100);
    try std.testing.expect(storage.count == 2);

    _ = storage.remove(e1);
    try std.testing.expect(storage.get(e1) == null);
    try std.testing.expect(storage.count == 1);
}

test "SparseStorage operations" {
    const TestComponent = struct { value: f32 };

    var storage = SparseStorage(TestComponent).init(std.testing.allocator);
    defer storage.deinit();

    const e1 = EntityId{ .index = 100, .generation = 1 };
    const e2 = EntityId{ .index = 200, .generation = 1 };

    try storage.add(e1, .{ .value = 3.14 });
    try storage.add(e2, .{ .value = 2.71 });

    try std.testing.expect(storage.get(e1).?.value == 3.14);
    try std.testing.expect(storage.has(e2));

    _ = storage.remove(e1);
    try std.testing.expect(!storage.has(e1));
}