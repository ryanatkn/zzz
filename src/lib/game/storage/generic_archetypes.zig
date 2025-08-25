const std = @import("std");
const components = @import("../components/mod.zig");

/// Generic archetype storages for common entity patterns
/// Games can instantiate these with their own component types and size limits
const EntityId = u32;
const INVALID_ENTITY: EntityId = std.math.maxInt(u32);

// Use EntityIterator from entity_storage.zig to avoid duplication
const EntityIterator = @import("entity_storage.zig").EntityIterator;

/// Unit archetype storage
pub fn UnitStorage(comptime max_entities: usize, comptime UnitType: type) type {
    return struct {
        const Self = @This();

        entities: [max_entities]EntityId,
        transforms: [max_entities]components.Transform,
        healths: [max_entities]components.Health,
        units: [max_entities]UnitType,
        visuals: [max_entities]components.Visual,
        count: usize,

        pub fn init() Self {
            return .{
                .entities = [_]EntityId{INVALID_ENTITY} ** max_entities,
                .transforms = undefined,
                .healths = undefined,
                .units = undefined,
                .visuals = undefined,
                .count = 0,
            };
        }

        pub fn addEntity(self: *Self, entity: EntityId, transform: components.Transform, health: components.Health, unit: UnitType, visual: components.Visual) !void {
            if (self.count >= max_entities) return error.StorageFull;
            const index = self.count;
            self.entities[index] = entity;
            self.transforms[index] = transform;
            self.healths[index] = health;
            self.units[index] = unit;
            self.visuals[index] = visual;
            self.count += 1;
        }

        pub fn removeEntity(self: *Self, entity: EntityId) void {
            for (0..self.count) |i| {
                if (self.entities[i] == entity) {
                    const last = self.count - 1;
                    self.entities[i] = self.entities[last];
                    self.transforms[i] = self.transforms[last];
                    self.healths[i] = self.healths[last];
                    self.units[i] = self.units[last];
                    self.visuals[i] = self.visuals[last];
                    self.count -= 1;
                    return;
                }
            }
        }

        pub fn getComponent(self: *const Self, entity_id: EntityId, comptime component_type: enum { transform, health, unit, visual }) ?*const (switch (component_type) {
            .transform => components.Transform,
            .health => components.Health,
            .unit => UnitType,
            .visual => components.Visual,
        }) {
            for (0..self.count) |i| {
                if (self.entities[i] == entity_id) {
                    return switch (component_type) {
                        .transform => &self.transforms[i],
                        .health => &self.healths[i],
                        .unit => &self.units[i],
                        .visual => &self.visuals[i],
                    };
                }
            }
            return null;
        }

        pub fn getComponentMut(self: *Self, entity_id: EntityId, comptime component_type: enum { transform, health, unit, visual }) ?*(switch (component_type) {
            .transform => components.Transform,
            .health => components.Health,
            .unit => UnitType,
            .visual => components.Visual,
        }) {
            for (0..self.count) |i| {
                if (self.entities[i] == entity_id) {
                    return switch (component_type) {
                        .transform => &self.transforms[i],
                        .health => &self.healths[i],
                        .unit => &self.units[i],
                        .visual => &self.visuals[i],
                    };
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

/// Projectile archetype storage
pub fn ProjectileStorage(comptime max_entities: usize, comptime ProjectileType: type) type {
    return struct {
        const Self = @This();

        entities: [max_entities]EntityId,
        transforms: [max_entities]components.Transform,
        projectiles: [max_entities]ProjectileType,
        visuals: [max_entities]components.Visual,
        count: usize,

        pub fn init() Self {
            return .{
                .entities = [_]EntityId{INVALID_ENTITY} ** max_entities,
                .transforms = undefined,
                .projectiles = undefined,
                .visuals = undefined,
                .count = 0,
            };
        }

        pub fn addEntity(self: *Self, entity: EntityId, transform: components.Transform, projectile: ProjectileType, visual: components.Visual) !void {
            if (self.count >= max_entities) return error.StorageFull;
            const index = self.count;
            self.entities[index] = entity;
            self.transforms[index] = transform;
            self.projectiles[index] = projectile;
            self.visuals[index] = visual;
            self.count += 1;
        }

        pub fn removeEntity(self: *Self, entity: EntityId) void {
            for (0..self.count) |i| {
                if (self.entities[i] == entity) {
                    const last = self.count - 1;
                    self.entities[i] = self.entities[last];
                    self.transforms[i] = self.transforms[last];
                    self.projectiles[i] = self.projectiles[last];
                    self.visuals[i] = self.visuals[last];
                    self.count -= 1;
                    return;
                }
            }
        }

        pub fn getComponent(self: *const Self, entity_id: EntityId, comptime component_type: enum { transform, projectile, visual }) ?*const (switch (component_type) {
            .transform => components.Transform,
            .projectile => ProjectileType,
            .visual => components.Visual,
        }) {
            for (0..self.count) |i| {
                if (self.entities[i] == entity_id) {
                    return switch (component_type) {
                        .transform => &self.transforms[i],
                        .projectile => &self.projectiles[i],
                        .visual => &self.visuals[i],
                    };
                }
            }
            return null;
        }

        pub fn getComponentMut(self: *Self, entity_id: EntityId, comptime component_type: enum { transform, projectile, visual }) ?*(switch (component_type) {
            .transform => components.Transform,
            .projectile => ProjectileType,
            .visual => components.Visual,
        }) {
            for (0..self.count) |i| {
                if (self.entities[i] == entity_id) {
                    return switch (component_type) {
                        .transform => &self.transforms[i],
                        .projectile => &self.projectiles[i],
                        .visual => &self.visuals[i],
                    };
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

/// Simple storage for objects with just transform, terrain, and visual
pub fn TerrainStorage(comptime max_entities: usize) type {
    return struct {
        const Self = @This();

        entities: [max_entities]EntityId,
        transforms: [max_entities]components.Transform,
        terrains: [max_entities]components.Terrain,
        visuals: [max_entities]components.Visual,
        count: usize,

        pub fn init() Self {
            return .{
                .entities = [_]EntityId{INVALID_ENTITY} ** max_entities,
                .transforms = undefined,
                .terrains = undefined,
                .visuals = undefined,
                .count = 0,
            };
        }

        pub fn addEntity(self: *Self, entity: EntityId, transform: components.Transform, terrain: components.Terrain, visual: components.Visual) !void {
            if (self.count >= max_entities) return error.StorageFull;
            const index = self.count;
            self.entities[index] = entity;
            self.transforms[index] = transform;
            self.terrains[index] = terrain;
            self.visuals[index] = visual;
            self.count += 1;
        }

        pub fn removeEntity(self: *Self, entity: EntityId) void {
            for (0..self.count) |i| {
                if (self.entities[i] == entity) {
                    const last = self.count - 1;
                    self.entities[i] = self.entities[last];
                    self.transforms[i] = self.transforms[last];
                    self.terrains[i] = self.terrains[last];
                    self.visuals[i] = self.visuals[last];
                    self.count -= 1;
                    return;
                }
            }
        }

        pub fn getComponent(self: *const Self, entity_id: EntityId, comptime component_type: enum { transform, terrain, visual }) ?*const (switch (component_type) {
            .transform => components.Transform,
            .terrain => components.Terrain,
            .visual => components.Visual,
        }) {
            for (0..self.count) |i| {
                if (self.entities[i] == entity_id) {
                    return switch (component_type) {
                        .transform => &self.transforms[i],
                        .terrain => &self.terrains[i],
                        .visual => &self.visuals[i],
                    };
                }
            }
            return null;
        }

        pub fn getComponentMut(self: *Self, entity_id: EntityId, comptime component_type: enum { transform, terrain, visual }) ?*(switch (component_type) {
            .transform => components.Transform,
            .terrain => components.Terrain,
            .visual => components.Visual,
        }) {
            for (0..self.count) |i| {
                if (self.entities[i] == entity_id) {
                    return switch (component_type) {
                        .transform => &self.transforms[i],
                        .terrain => &self.terrains[i],
                        .visual => &self.visuals[i],
                    };
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

/// Interactive storage for portals and lifestones - generic with game-defined interactable type
pub fn InteractiveStorage(comptime max_entities: usize, comptime InteractableType: type) type {
    return struct {
        const Self = @This();

        entities: [max_entities]EntityId,
        transforms: [max_entities]components.Transform,
        visuals: [max_entities]components.Visual,
        terrains: [max_entities]components.Terrain,
        interactables: [max_entities]InteractableType,
        count: usize,

        pub fn init() Self {
            return .{
                .entities = [_]EntityId{INVALID_ENTITY} ** max_entities,
                .transforms = undefined,
                .visuals = undefined,
                .terrains = undefined,
                .interactables = undefined,
                .count = 0,
            };
        }

        pub fn addEntity(self: *Self, entity: EntityId, transform: components.Transform, visual: components.Visual, terrain: components.Terrain, interactable: InteractableType) !void {
            if (self.count >= max_entities) return error.StorageFull;
            const index = self.count;
            self.entities[index] = entity;
            self.transforms[index] = transform;
            self.visuals[index] = visual;
            self.terrains[index] = terrain;
            self.interactables[index] = interactable;
            self.count += 1;
        }

        pub fn removeEntity(self: *Self, entity: EntityId) void {
            for (0..self.count) |i| {
                if (self.entities[i] == entity) {
                    const last = self.count - 1;
                    self.entities[i] = self.entities[last];
                    self.transforms[i] = self.transforms[last];
                    self.visuals[i] = self.visuals[last];
                    self.terrains[i] = self.terrains[last];
                    self.interactables[i] = self.interactables[last];
                    self.count -= 1;
                    return;
                }
            }
        }

        pub fn getComponent(self: *const Self, entity_id: EntityId, comptime component_type: enum { transform, visual, terrain, interactable }) ?*const (switch (component_type) {
            .transform => components.Transform,
            .visual => components.Visual,
            .terrain => components.Terrain,
            .interactable => InteractableType,
        }) {
            for (0..self.count) |i| {
                if (self.entities[i] == entity_id) {
                    return switch (component_type) {
                        .transform => &self.transforms[i],
                        .visual => &self.visuals[i],
                        .terrain => &self.terrains[i],
                        .interactable => &self.interactables[i],
                    };
                }
            }
            return null;
        }

        pub fn getComponentMut(self: *Self, entity_id: EntityId, comptime component_type: enum { transform, visual, terrain, interactable }) ?*(switch (component_type) {
            .transform => components.Transform,
            .visual => components.Visual,
            .terrain => components.Terrain,
            .interactable => InteractableType,
        }) {
            for (0..self.count) |i| {
                if (self.entities[i] == entity_id) {
                    return switch (component_type) {
                        .transform => &self.transforms[i],
                        .visual => &self.visuals[i],
                        .terrain => &self.terrains[i],
                        .interactable => &self.interactables[i],
                    };
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

        pub fn isAlive(self: *const Self, entity_id: EntityId) bool {
            return self.containsEntity(entity_id);
        }
    };
}
