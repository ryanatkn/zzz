const std = @import("std");
const components = @import("../lib/game/components/mod.zig");
const storage = @import("../lib/game/storage/generic_archetypes.zig");
const factions = @import("factions.zig");

// Re-export base storage types for convenience
const EntityId = u32;
const INVALID_ENTITY: EntityId = std.math.maxInt(u32);

/// Extended player storage that includes factions and capabilities
pub fn PlayerStorageExt(comptime max_entities: usize) type {
    return struct {
        const Self = @This();

        // Base storage from generic archetypes
        base: storage.PlayerStorage(max_entities),

        // Extended components for faction system
        capabilities: [max_entities]components.Capabilities,
        factions: [max_entities]factions.EntityFactions,

        pub fn init() Self {
            return .{
                .base = storage.PlayerStorage(max_entities).init(),
                .capabilities = undefined,
                .factions = undefined,
            };
        }

        /// Add entity with all components including new faction system
        pub fn addEntity(self: *Self, entity: EntityId, transform: components.Transform, health: components.Health, player_input: components.PlayerInput, visual: components.Visual, movement: components.Movement, capabilities: components.Capabilities, entity_factions: factions.EntityFactions) !void {
            // Add to base storage first
            try self.base.addEntity(entity, transform, health, player_input, visual, movement);

            // Add extended components (they use the same index as base)
            const index = self.base.count - 1; // count was incremented by base.addEntity
            self.capabilities[index] = capabilities;
            self.factions[index] = entity_factions;
        }

        pub fn removeEntity(self: *Self, entity: EntityId) void {
            // Find entity index
            var found_index: ?usize = null;
            for (0..self.base.count) |i| {
                if (self.base.entities[i] == entity) {
                    found_index = i;
                    break;
                }
            }

            if (found_index) |index| {
                // Move last element to fill gap in extended arrays
                const last = self.base.count - 1;
                if (index != last) {
                    self.capabilities[index] = self.capabilities[last];
                    self.factions[index] = self.factions[last];
                }
            }

            // Remove from base storage (this handles the core components)
            self.base.removeEntity(entity);
        }

        /// Get base component (delegate to base storage)
        pub fn getComponent(self: *const Self, entity_id: EntityId, comptime component_type: anytype) ?*const @TypeOf(self.base.getComponent(entity_id, component_type).*) {
            return self.base.getComponent(entity_id, component_type);
        }

        /// Get mutable base component (delegate to base storage)
        pub fn getComponentMut(self: *Self, entity_id: EntityId, comptime component_type: anytype) ?*@TypeOf(self.base.getComponentMut(entity_id, component_type).*) {
            return self.base.getComponentMut(entity_id, component_type);
        }

        /// Get capabilities component
        pub fn getCapabilities(self: *const Self, entity_id: EntityId) ?*const components.Capabilities {
            for (0..self.base.count) |i| {
                if (self.base.entities[i] == entity_id) {
                    return &self.capabilities[i];
                }
            }
            return null;
        }

        /// Get mutable capabilities component
        pub fn getCapabilitiesMut(self: *Self, entity_id: EntityId) ?*components.Capabilities {
            for (0..self.base.count) |i| {
                if (self.base.entities[i] == entity_id) {
                    return &self.capabilities[i];
                }
            }
            return null;
        }

        /// Get factions component
        pub fn getFactions(self: *const Self, entity_id: EntityId) ?*const factions.EntityFactions {
            for (0..self.base.count) |i| {
                if (self.base.entities[i] == entity_id) {
                    return &self.factions[i];
                }
            }
            return null;
        }

        /// Get mutable factions component
        pub fn getFactionsMut(self: *Self, entity_id: EntityId) ?*factions.EntityFactions {
            for (0..self.base.count) |i| {
                if (self.base.entities[i] == entity_id) {
                    return &self.factions[i];
                }
            }
            return null;
        }

        // Delegate remaining methods to base storage
        pub fn entityIterator(self: *const Self) @TypeOf(self.base.entityIterator()) {
            return self.base.entityIterator();
        }

        pub fn clear(self: *Self) void {
            self.base.clear();
        }

        pub fn containsEntity(self: *const Self, entity_id: EntityId) bool {
            return self.base.containsEntity(entity_id);
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.base.isEmpty();
        }

        pub fn isFull(self: *const Self) bool {
            return self.base.isFull();
        }

        pub fn count(self: *const Self) usize {
            return self.base.count;
        }
    };
}

/// Extended unit storage that includes factions and capabilities
pub fn UnitStorageExt(comptime max_entities: usize, comptime UnitType: type) type {
    return struct {
        const Self = @This();

        // Base storage from generic archetypes
        base: storage.UnitStorage(max_entities, UnitType),

        // Extended components for faction system
        capabilities: [max_entities]components.Capabilities,
        factions: [max_entities]factions.EntityFactions,

        pub fn init() Self {
            return .{
                .base = storage.UnitStorage(max_entities, UnitType).init(),
                .capabilities = undefined,
                .factions = undefined,
            };
        }

        /// Add entity with all components including new faction system
        pub fn addEntity(self: *Self, entity: EntityId, transform: components.Transform, health: components.Health, unit: UnitType, visual: components.Visual, capabilities: components.Capabilities, entity_factions: factions.EntityFactions) !void {
            // Add to base storage first
            try self.base.addEntity(entity, transform, health, unit, visual);

            // Add extended components (they use the same index as base)
            const index = self.base.count - 1; // count was incremented by base.addEntity
            self.capabilities[index] = capabilities;
            self.factions[index] = entity_factions;
        }

        pub fn removeEntity(self: *Self, entity: EntityId) void {
            // Find entity index
            var found_index: ?usize = null;
            for (0..self.base.count) |i| {
                if (self.base.entities[i] == entity) {
                    found_index = i;
                    break;
                }
            }

            if (found_index) |index| {
                // Move last element to fill gap in extended arrays
                const last = self.base.count - 1;
                if (index != last) {
                    self.capabilities[index] = self.capabilities[last];
                    self.factions[index] = self.factions[last];
                }
            }

            // Remove from base storage (this handles the core components)
            self.base.removeEntity(entity);
        }

        /// Get base component (delegate to base storage)
        pub fn getComponent(self: *const Self, entity_id: EntityId, comptime component_type: anytype) ?*const @TypeOf(self.base.getComponent(entity_id, component_type).*) {
            return self.base.getComponent(entity_id, component_type);
        }

        /// Get mutable base component (delegate to base storage)
        pub fn getComponentMut(self: *Self, entity_id: EntityId, comptime component_type: anytype) ?*@TypeOf(self.base.getComponentMut(entity_id, component_type).*) {
            return self.base.getComponentMut(entity_id, component_type);
        }

        /// Get capabilities component
        pub fn getCapabilities(self: *const Self, entity_id: EntityId) ?*const components.Capabilities {
            for (0..self.base.count) |i| {
                if (self.base.entities[i] == entity_id) {
                    return &self.capabilities[i];
                }
            }
            return null;
        }

        /// Get mutable capabilities component
        pub fn getCapabilitiesMut(self: *Self, entity_id: EntityId) ?*components.Capabilities {
            for (0..self.base.count) |i| {
                if (self.base.entities[i] == entity_id) {
                    return &self.capabilities[i];
                }
            }
            return null;
        }

        /// Get factions component
        pub fn getFactions(self: *const Self, entity_id: EntityId) ?*const factions.EntityFactions {
            for (0..self.base.count) |i| {
                if (self.base.entities[i] == entity_id) {
                    return &self.factions[i];
                }
            }
            return null;
        }

        /// Get mutable factions component
        pub fn getFactionsMut(self: *Self, entity_id: EntityId) ?*factions.EntityFactions {
            for (0..self.base.count) |i| {
                if (self.base.entities[i] == entity_id) {
                    return &self.factions[i];
                }
            }
            return null;
        }

        // Delegate remaining methods to base storage
        pub fn entityIterator(self: *const Self) @TypeOf(self.base.entityIterator()) {
            return self.base.entityIterator();
        }

        pub fn clear(self: *Self) void {
            self.base.clear();
        }

        pub fn containsEntity(self: *const Self, entity_id: EntityId) bool {
            return self.base.containsEntity(entity_id);
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.base.isEmpty();
        }

        pub fn isFull(self: *const Self) bool {
            return self.base.isFull();
        }

        pub fn count(self: *const Self) usize {
            return self.base.count;
        }
    };
}
