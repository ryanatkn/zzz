const std = @import("std");
const storage_mod = @import("storage.zig");
const component_registry = @import("component_registry.zig");
const entity_mod = @import("entity.zig");

const EntityId = entity_mod.EntityId;
const DenseStorage = storage_mod.DenseStorage;
const SparseStorage = storage_mod.SparseStorage;
const ComponentRegistry = component_registry.ComponentRegistry;
const ArchetypeRegistry = component_registry.ArchetypeRegistry;

/// Archetype-based storage for better cache locality and query performance
/// Each archetype groups commonly co-occurring components together
pub fn ArchetypeStorage(comptime archetype_type: ArchetypeRegistry.ArchetypeType) type {
    const archetype_info = ArchetypeRegistry.getInfo(archetype_type);
    const required_components = archetype_info.required_components;
    const optional_components = archetype_info.optional_components;

    return struct {
        const Self = @This();

        // Required component storages (generated at comptime)
        required_storages: RequiredStorages,

        // Optional component storages (generated at comptime)
        optional_storages: OptionalStorages,

        // Entity tracking
        entities: std.ArrayList(EntityId),
        entity_to_index: std.AutoHashMap(EntityId, u32),

        allocator: std.mem.Allocator,

        /// Required storages struct (generated at comptime)
        const RequiredStorages = blk: {
            var fields: []const std.builtin.Type.StructField = &.{};
            for (required_components) |component_type| {
                const info = ComponentRegistry.getInfo(component_type);
                const storage_type = switch (info.strategy) {
                    .dense => DenseStorage(info.type),
                    .sparse => SparseStorage(info.type),
                };
                
                fields = fields ++ &[_]std.builtin.Type.StructField{.{
                    .name = info.name ++ "",
                    .type = storage_type,
                    .default_value_ptr = null,
                    .is_comptime = false,
                    .alignment = @alignOf(storage_type),
                }};
            }
            
            break :blk @Type(.{
                .@"struct" = .{
                    .layout = .auto,
                    .fields = fields,
                    .decls = &.{},
                    .is_tuple = false,
                },
            });
        };

        /// Optional storages struct (generated at comptime)
        const OptionalStorages = blk: {
            var fields: []const std.builtin.Type.StructField = &.{};
            for (optional_components) |component_type| {
                const info = ComponentRegistry.getInfo(component_type);
                const storage_type = switch (info.strategy) {
                    .dense => DenseStorage(info.type),
                    .sparse => SparseStorage(info.type),
                };
                
                fields = fields ++ &[_]std.builtin.Type.StructField{.{
                    .name = info.name ++ "",
                    .type = storage_type,
                    .default_value_ptr = null,
                    .is_comptime = false,
                    .alignment = @alignOf(storage_type),
                }};
            }
            
            break :blk @Type(.{
                .@"struct" = .{
                    .layout = .auto,
                    .fields = fields,
                    .decls = &.{},
                    .is_tuple = false,
                },
            });
        };

        pub fn init(allocator: std.mem.Allocator, max_entities: usize) !Self {
            var required_storages: RequiredStorages = undefined;
            var optional_storages: OptionalStorages = undefined;

            // Initialize required storages
            inline for (required_components) |component_type| {
                const info = ComponentRegistry.getInfo(component_type);
                const storage_ptr = &@field(required_storages, info.name);
                storage_ptr.* = switch (info.strategy) {
                    .dense => try DenseStorage(info.type).init(allocator, max_entities),
                    .sparse => SparseStorage(info.type).init(allocator),
                };
            }

            // Initialize optional storages
            inline for (optional_components) |component_type| {
                const info = ComponentRegistry.getInfo(component_type);
                const storage_ptr = &@field(optional_storages, info.name);
                storage_ptr.* = switch (info.strategy) {
                    .dense => try DenseStorage(info.type).init(allocator, max_entities),
                    .sparse => SparseStorage(info.type).init(allocator),
                };
            }

            return Self{
                .required_storages = required_storages,
                .optional_storages = optional_storages,
                .entities = std.ArrayList(EntityId).init(allocator),
                .entity_to_index = std.AutoHashMap(EntityId, u32).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            // Deinit required storages
            inline for (required_components) |component_type| {
                const info = ComponentRegistry.getInfo(component_type);
                @field(self.required_storages, info.name).deinit();
            }

            // Deinit optional storages
            inline for (optional_components) |component_type| {
                const info = ComponentRegistry.getInfo(component_type);
                @field(self.optional_storages, info.name).deinit();
            }

            self.entities.deinit();
            self.entity_to_index.deinit();
        }

        /// Add entity to this archetype with all required components
        pub fn addEntity(self: *Self, entity: EntityId, required_data: RequiredComponentData) !void {
            if (self.entity_to_index.contains(entity)) return error.EntityAlreadyExists;

            const index = @as(u32, @intCast(self.entities.items.len));
            try self.entities.append(entity);
            try self.entity_to_index.put(entity, index);

            // Add required components
            inline for (required_components) |component_type| {
                const info = ComponentRegistry.getInfo(component_type);
                const storage_ptr = &@field(self.required_storages, info.name);
                const component_data = @field(required_data, info.name);
                try storage_ptr.add(entity, component_data);
            }
        }

        /// Remove entity from this archetype
        pub fn removeEntity(self: *Self, entity: EntityId) bool {
            const index = self.entity_to_index.get(entity) orelse return false;
            
            // Remove from required storages
            inline for (required_components) |component_type| {
                const info = ComponentRegistry.getInfo(component_type);
                const storage_ptr = &@field(self.required_storages, info.name);
                _ = storage_ptr.remove(entity);
            }

            // Remove from optional storages
            inline for (optional_components) |component_type| {
                const info = ComponentRegistry.getInfo(component_type);
                const storage_ptr = &@field(self.optional_storages, info.name);
                _ = storage_ptr.remove(entity);
            }

            // Remove from entity tracking
            _ = self.entity_to_index.remove(entity);
            _ = self.entities.swapRemove(index);

            // Update index mapping for swapped entity
            if (index < self.entities.items.len) {
                const swapped_entity = self.entities.items[index];
                self.entity_to_index.put(swapped_entity, index) catch {};
            }

            return true;
        }

        /// Get required component storage
        pub fn getRequiredStorage(self: *Self, comptime component_type: ComponentRegistry.ComponentType) *StorageTypeFor(component_type) {
            const info = ComponentRegistry.getInfo(component_type);
            if (!ArchetypeRegistry.isRequired(archetype_type, component_type)) {
                @compileError("Component " ++ info.name ++ " is not required for archetype " ++ @tagName(archetype_type));
            }
            return &@field(self.required_storages, info.name);
        }

        /// Get optional component storage
        pub fn getOptionalStorage(self: *Self, comptime component_type: ComponentRegistry.ComponentType) *StorageTypeFor(component_type) {
            const info = ComponentRegistry.getInfo(component_type);
            if (!ArchetypeRegistry.isOptional(archetype_type, component_type)) {
                @compileError("Component " ++ info.name ++ " is not optional for archetype " ++ @tagName(archetype_type));
            }
            return &@field(self.optional_storages, info.name);
        }

        /// Helper to get storage type for a component
        fn StorageTypeFor(comptime component_type: ComponentRegistry.ComponentType) type {
            const info = ComponentRegistry.getInfo(component_type);
            return switch (info.strategy) {
                .dense => DenseStorage(info.type),
                .sparse => SparseStorage(info.type),
            };
        }

        /// Get component (from either required or optional storage)
        pub fn getComponent(self: *Self, entity: EntityId, comptime component_type: ComponentRegistry.ComponentType) ?*ComponentRegistry.getType(component_type) {
            const info = ComponentRegistry.getInfo(component_type);
            
            // Use comptime branching to ensure correct field access
            comptime {
                if (ArchetypeRegistry.isRequired(archetype_type, component_type)) {
                    // This component is required for this archetype
                } else if (ArchetypeRegistry.isOptional(archetype_type, component_type)) {
                    // This component is optional for this archetype
                } else {
                    @compileError("Component " ++ info.name ++ " is not part of archetype " ++ @tagName(archetype_type));
                }
            }
            
            if (comptime ArchetypeRegistry.isRequired(archetype_type, component_type)) {
                const storage_ptr = &@field(self.required_storages, info.name);
                return storage_ptr.get(entity);
            } else {
                const storage_ptr = &@field(self.optional_storages, info.name);
                return storage_ptr.get(entity);
            }
        }

        /// Get component (const version for read-only access)
        pub fn getComponentConst(self: *const Self, entity: EntityId, comptime component_type: ComponentRegistry.ComponentType) ?*const ComponentRegistry.getType(component_type) {
            const info = ComponentRegistry.getInfo(component_type);
            
            // Use comptime branching to ensure correct field access
            comptime {
                if (ArchetypeRegistry.isRequired(archetype_type, component_type)) {
                    // This component is required for this archetype
                } else if (ArchetypeRegistry.isOptional(archetype_type, component_type)) {
                    // This component is optional for this archetype
                } else {
                    @compileError("Component " ++ info.name ++ " is not part of archetype " ++ @tagName(archetype_type));
                }
            }
            
            if (comptime ArchetypeRegistry.isRequired(archetype_type, component_type)) {
                const storage_ptr = &@field(self.required_storages, info.name);
                return storage_ptr.getConst(entity);
            } else {
                const storage_ptr = &@field(self.optional_storages, info.name);
                return storage_ptr.getConst(entity);
            }
        }

        /// Add optional component to entity
        pub fn addOptionalComponent(self: *Self, entity: EntityId, comptime component_type: ComponentRegistry.ComponentType, component: ComponentRegistry.getType(component_type)) !void {
            if (!self.entity_to_index.contains(entity)) return error.EntityNotFound;
            
            const info = ComponentRegistry.getInfo(component_type);
            
            // Use comptime check to validate this component is optional for this archetype
            comptime {
                if (!ArchetypeRegistry.isOptional(archetype_type, component_type)) {
                    @compileError("Component " ++ info.name ++ " is not optional for archetype " ++ @tagName(archetype_type));
                }
            }
            
            const storage_ptr = &@field(self.optional_storages, info.name);
            try storage_ptr.add(entity, component);
        }

        /// Check if entity exists in this archetype
        pub fn hasEntity(self: *const Self, entity: EntityId) bool {
            return self.entity_to_index.contains(entity);
        }

        /// Get number of entities in this archetype
        pub fn count(self: *const Self) usize {
            return self.entities.items.len;
        }

        /// Iterator for all entities in this archetype
        pub fn entityIterator(self: *Self) EntityIterator {
            return EntityIterator{ .entities = self.entities.items, .index = 0 };
        }

        pub const EntityIterator = struct {
            entities: []EntityId,
            index: usize,

            pub fn next(it: *EntityIterator) ?EntityId {
                if (it.index >= it.entities.len) return null;
                const entity = it.entities[it.index];
                it.index += 1;
                return entity;
            }
        };

        /// Required component data struct for entity creation
        pub const RequiredComponentData = blk: {
            var fields: []const std.builtin.Type.StructField = &.{};
            for (required_components) |component_type| {
                const info = ComponentRegistry.getInfo(component_type);
                fields = fields ++ &[_]std.builtin.Type.StructField{.{
                    .name = info.name ++ "",
                    .type = info.type,
                    .default_value_ptr = null,
                    .is_comptime = false,
                    .alignment = @alignOf(info.type),
                }};
            }
            
            break :blk @Type(.{
                .@"struct" = .{
                    .layout = .auto,
                    .fields = fields,
                    .decls = &.{},
                    .is_tuple = false,
                },
            });
        };
    };
}

// Type aliases for specific archetypes
pub const PlayerArchetype = ArchetypeStorage(.player);
pub const UnitArchetype = ArchetypeStorage(.unit);
pub const ProjectileArchetype = ArchetypeStorage(.projectile);
pub const ObstacleArchetype = ArchetypeStorage(.obstacle);
pub const LifestoneArchetype = ArchetypeStorage(.lifestone);
pub const PortalArchetype = ArchetypeStorage(.portal);

test "archetype storage basic operations" {
    const testing = std.testing;
    const components = @import("components.zig");
    
    var player_archetype = try PlayerArchetype.init(testing.allocator, 100);
    defer player_archetype.deinit();

    const entity = EntityId{ .index = 1, .generation = 1 };
    
    // Create required component data
    const required_data = PlayerArchetype.RequiredComponentData{
        .transform = components.Transform.init(.{ .x = 100, .y = 200 }, 16),
        .health = components.Health.init(100),
        .movement = components.Movement.init(200),
        .visual = components.Visual.init(.{ .r = 255, .g = 255, .b = 255, .a = 255 }),
        .player_input = components.PlayerInput.init(0),
        .combat = components.Combat.init(25, 2.0),
    };

    // Add entity
    try player_archetype.addEntity(entity, required_data);
    try testing.expect(player_archetype.hasEntity(entity));
    try testing.expect(player_archetype.count() == 1);

    // Get components
    const transform = player_archetype.getComponent(entity, .transform).?;
    try testing.expect(transform.pos.x == 100);

    const health = player_archetype.getComponent(entity, .health).?;
    try testing.expect(health.max == 100);

    // Add optional component
    try player_archetype.addOptionalComponent(entity, .effects, components.Effects.init());

    // Remove entity
    try testing.expect(player_archetype.removeEntity(entity));
    try testing.expect(!player_archetype.hasEntity(entity));
    try testing.expect(player_archetype.count() == 0);
}