const std = @import("std");

/// Generic typed entity storage for component arrays
/// This eliminates the duplication in hex's various storage types
pub fn EntityStorage(comptime ComponentTuple: type, comptime max_entities: usize) type {
    return struct {
        const Self = @This();
        const EntityId = u32;
        const INVALID_ENTITY: EntityId = std.math.maxInt(u32);
        
        entities: [max_entities]EntityId,
        components: ComponentTuple,
        count: usize,
        
        pub fn init() Self {
            return .{
                .entities = [_]EntityId{INVALID_ENTITY} ** max_entities,
                .components = undefined, // Caller must initialize component arrays
                .count = 0,
            };
        }
        
        pub fn addEntity(self: *Self, entity: EntityId, components: ComponentTuple) !void {
            if (self.count >= max_entities) return error.StorageFull;
            const index = self.count;
            self.entities[index] = entity;
            self.components[index] = components;
            self.count += 1;
        }
        
        pub fn removeEntity(self: *Self, entity: EntityId) void {
            for (0..self.count) |i| {
                if (self.entities[i] == entity) {
                    const last = self.count - 1;
                    self.entities[i] = self.entities[last];
                    self.components[i] = self.components[last];
                    self.count -= 1;
                    return;
                }
            }
        }
        
        pub fn findEntity(self: *const Self, entity: EntityId) ?usize {
            for (0..self.count) |i| {
                if (self.entities[i] == entity) return i;
            }
            return null;
        }
        
        pub fn getComponent(self: *const Self, entity: EntityId) ?*const ComponentTuple {
            if (self.findEntity(entity)) |index| {
                return &self.components[index];
            }
            return null;
        }
        
        pub fn getComponentMut(self: *Self, entity: EntityId) ?*ComponentTuple {
            if (self.findEntity(entity)) |index| {
                return &self.components[index];
            }
            return null;
        }
        
        pub fn entityIterator(self: *const Self) EntityIterator {
            return EntityIterator{ .entities = self.entities[0..self.count], .index = 0 };
        }
        
        pub fn clear(self: *Self) void {
            self.count = 0;
        }
        
        pub fn containsEntity(self: *const Self, entity_id: EntityId) bool {
            return self.findEntity(entity_id) != null;
        }
        
        pub fn isEmpty(self: *const Self) bool {
            return self.count == 0;
        }
        
        pub fn isFull(self: *const Self) bool {
            return self.count >= max_entities;
        }
    };
}

/// Simple entity iterator for any storage type
pub const EntityIterator = struct {
    entities: []const u32,
    index: usize,
    
    pub fn next(self: *EntityIterator) ?u32 {
        if (self.index >= self.entities.len) return null;
        const entity = self.entities[self.index];
        self.index += 1;
        return entity;
    }
    
    pub fn reset(self: *EntityIterator) void {
        self.index = 0;
    }
};

/// Multi-component entity storage with individual component access
pub fn MultiComponentStorage(comptime ComponentTypes: type, comptime max_entities: usize) type {
    const component_fields = std.meta.fields(ComponentTypes);
    
    return struct {
        const Self = @This();
        const EntityId = u32;
        const INVALID_ENTITY: EntityId = std.math.maxInt(u32);
        
        entities: [max_entities]EntityId,
        components: ComponentTypes,
        count: usize,
        
        pub fn init() Self {
            return .{
                .entities = [_]EntityId{INVALID_ENTITY} ** max_entities,
                .components = undefined,
                .count = 0,
            };
        }
        
        pub fn addEntity(self: *Self, entity: EntityId, components: ComponentTypes) !void {
            if (self.count >= max_entities) return error.StorageFull;
            const index = self.count;
            self.entities[index] = entity;
            
            // Copy each component to its array
            inline for (component_fields) |field| {
                @field(self.components, field.name)[index] = @field(components, field.name);
            }
            
            self.count += 1;
        }
        
        pub fn removeEntity(self: *Self, entity: EntityId) void {
            for (0..self.count) |i| {
                if (self.entities[i] == entity) {
                    const last = self.count - 1;
                    self.entities[i] = self.entities[last];
                    
                    // Move each component
                    inline for (component_fields) |field| {
                        @field(self.components, field.name)[i] = @field(self.components, field.name)[last];
                    }
                    
                    self.count -= 1;
                    return;
                }
            }
        }
        
        pub fn getComponent(self: *const Self, entity: EntityId, comptime component_name: []const u8) ?*const @TypeOf(@field(self.components, component_name)[0]) {
            for (0..self.count) |i| {
                if (self.entities[i] == entity) {
                    return &@field(self.components, component_name)[i];
                }
            }
            return null;
        }
        
        pub fn getComponentMut(self: *Self, entity: EntityId, comptime component_name: []const u8) ?*@TypeOf(@field(self.components, component_name)[0]) {
            for (0..self.count) |i| {
                if (self.entities[i] == entity) {
                    return &@field(self.components, component_name)[i];
                }
            }
            return null;
        }
        
        pub fn entityIterator(self: *const Self) EntityIterator {
            return EntityIterator{ .entities = self.entities[0..self.count], .index = 0 };
        }
        
        pub fn clear(self: *Self) void {
            self.count = 0;
        }
    };
}

test "entity storage basic operations" {
    const TestComponent = struct {
        value: i32,
        name: []const u8,
    };
    
    var storage = EntityStorage(TestComponent, 10).init();
    
    try storage.addEntity(1, TestComponent{ .value = 42, .name = "test" });
    try std.testing.expect(storage.count == 1);
    
    const component = storage.getComponent(1);
    try std.testing.expect(component != null);
    try std.testing.expect(component.?.value == 42);
    
    storage.removeEntity(1);
    try std.testing.expect(storage.count == 0);
}

test "multi-component storage" {
    const Components = struct {
        transforms: [10]struct { x: f32, y: f32 },
        healths: [10]struct { current: f32, max: f32 },
    };
    
    var storage = MultiComponentStorage(Components, 10).init();
    
    const test_components = Components{
        .transforms = undefined,
        .healths = undefined,
    };
    
    // Initialize first elements for test
    var components = test_components;
    components.transforms[0] = .{ .x = 100, .y = 200 };
    components.healths[0] = .{ .current = 50, .max = 100 };
    
    try storage.addEntity(1, components);
    
    const transform = storage.getComponent(1, "transforms");
    try std.testing.expect(transform != null);
    try std.testing.expect(transform.?.x == 100);
}