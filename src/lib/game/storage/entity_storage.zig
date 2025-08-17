const std = @import("std");

/// Generic typed entity storage for component arrays
/// This eliminates duplication in game-specific storage types
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

/// Advanced multi-component entity storage with flexible component access
pub fn ArchetypeStorage(comptime ComponentArrays: type, comptime max_entities: usize) type {
    const component_fields = std.meta.fields(ComponentArrays);
    
    return struct {
        const Self = @This();
        const EntityId = u32;
        const INVALID_ENTITY: EntityId = std.math.maxInt(u32);
        
        entities: [max_entities]EntityId,
        components: ComponentArrays,
        count: usize,
        
        pub fn init() Self {
            return .{
                .entities = [_]EntityId{INVALID_ENTITY} ** max_entities,
                .components = undefined,
                .count = 0,
            };
        }
        
        /// Add entity with all component values provided as separate parameters
        pub fn addEntity(self: *Self, entity: EntityId, args: anytype) !void {
            if (self.count >= max_entities) return error.StorageFull;
            const index = self.count;
            self.entities[index] = entity;
            
            // Assign each component from args tuple
            const args_info = @typeInfo(@TypeOf(args));
            if (args_info != .Struct) @compileError("Args must be a struct/tuple");
            
            inline for (component_fields, 0..) |field, i| {
                @field(self.components, field.name)[index] = args[i];
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
        
        /// Get component with enum-style access pattern
        pub fn getComponent(self: *const Self, entity: EntityId, comptime component_type: anytype) ?*const ComponentTypeFromEnum(@TypeOf(component_type), ComponentArrays) {
            for (0..self.count) |i| {
                if (self.entities[i] == entity) {
                    const field_name = componentEnumToFieldName(component_type);
                    return &@field(self.components, field_name)[i];
                }
            }
            return null;
        }
        
        pub fn getComponentMut(self: *Self, entity: EntityId, comptime component_type: anytype) ?*ComponentTypeFromEnum(@TypeOf(component_type), ComponentArrays) {
            for (0..self.count) |i| {
                if (self.entities[i] == entity) {
                    const field_name = componentEnumToFieldName(component_type);
                    return &@field(self.components, field_name)[i];
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
        
        pub fn containsEntity(self: *const Self, entity_id: EntityId) bool {
            for (0..self.count) |i| {
                if (self.entities[i] == entity_id) return true;
            }
            return false;
        }
        
        pub fn isEmpty(self: *const Self) bool {
            return self.count == 0;
        }
        
        pub fn isFull(self: *const Self) bool {
            return self.count >= max_entities;
        }
    };
}

/// Helper to convert component enum to field name 
fn componentEnumToFieldName(component_type: anytype) []const u8 {
    return switch (component_type) {
        .transform => "transforms",
        .health => "healths", 
        .unit => "units",
        .visual => "visuals",
        .player_input => "player_inputs",
        .movement => "movements",
        .projectile => "projectiles",
        .terrain => "terrains",
        .interactable => "interactables",
        else => @compileError("Unknown component type"),
    };
}

/// Helper to get component type from enum and arrays struct
fn ComponentTypeFromEnum(comptime EnumType: type, comptime ComponentArrays: type) type {
    const enum_info = @typeInfo(EnumType);
    if (enum_info != .Enum) @compileError("Expected enum type");
    
    // This is a bit of a hack - we'll determine the type at the call site
    // For now, return a generic type that will be resolved by the caller
    return std.meta.Child(@TypeOf(@field(@as(ComponentArrays, undefined), "transforms")));
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
    
    var storage = ArchetypeStorage(Components, 10).init();
    
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