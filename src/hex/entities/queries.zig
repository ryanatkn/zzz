const std = @import("std");

// Core capabilities
const math = @import("../../lib/math/mod.zig");

// Game system capabilities
const storage = @import("../../lib/game/storage/mod.zig");

// Hex game modules
const world_state_mod = @import("../world_state.zig");

const Vec2 = math.Vec2;
const EntityId = world_state_mod.EntityId;
const HexGame = world_state_mod.HexGame;
const EntityIterator = storage.EntityIterator;

/// Entity query utilities extracted from hex_game.zig and entity_queries.zig
pub const EntityQueries = struct {
    /// Check if an entity is alive in the current game world
    pub fn isEntityAlive(game: *const HexGame, entity_id: EntityId) bool {
        const zone = game.getCurrentZoneConst();
        return zone.isAlive(entity_id);
    }

    /// Get entity position if it has a transform component
    pub fn getEntityPosition(game: *const HexGame, entity_id: EntityId) ?Vec2 {
        const zone = game.getCurrentZoneConst();

        // Check each storage type for the entity
        if (zone.players.getComponent(entity_id, .transform)) |transform| {
            return transform.pos;
        }
        if (zone.units.getComponent(entity_id, .transform)) |transform| {
            return transform.pos;
        }
        if (zone.projectiles.getComponent(entity_id, .transform)) |transform| {
            return transform.pos;
        }
        if (zone.terrain.getComponent(entity_id, .transform)) |transform| {
            return transform.pos;
        }
        if (zone.lifestones.getComponent(entity_id, .transform)) |transform| {
            return transform.pos;
        }
        if (zone.portals.getComponent(entity_id, .transform)) |transform| {
            return transform.pos;
        }

        return null;
    }

    /// Get entity radius if it has a transform component
    pub fn getEntityRadius(game: *const HexGame, entity_id: EntityId) ?f32 {
        const zone = game.getCurrentZoneConst();

        // Check each storage type for the entity
        if (zone.players.getComponent(entity_id, .transform)) |transform| {
            return transform.radius;
        }
        if (zone.units.getComponent(entity_id, .transform)) |transform| {
            return transform.radius;
        }
        if (zone.projectiles.getComponent(entity_id, .transform)) |transform| {
            return transform.radius;
        }
        if (zone.terrain.getComponent(entity_id, .transform)) |transform| {
            return transform.radius;
        }
        if (zone.lifestones.getComponent(entity_id, .transform)) |transform| {
            return transform.radius;
        }
        if (zone.portals.getComponent(entity_id, .transform)) |transform| {
            return transform.radius;
        }

        return null;
    }

    /// Find all entities within a radius of a position
    pub fn findEntitiesInRadius(game: *const HexGame, center: Vec2, radius: f32, allocator: std.mem.Allocator) ![]EntityId {
        const zone = game.getCurrentZoneConst();
        var found_entities = std.ArrayList(EntityId).init(allocator);
        defer found_entities.deinit();

        const radius_squared = radius * radius;

        // Check all entity types
        var player_iter = zone.players.entityIterator();
        while (player_iter.next()) |entity_id| {
            if (zone.players.getComponent(entity_id, .transform)) |transform| {
                const dist_sq = center.sub(transform.pos).lengthSquared();
                if (dist_sq <= radius_squared) {
                    try found_entities.append(entity_id);
                }
            }
        }

        var unit_iter = zone.units.entityIterator();
        while (unit_iter.next()) |entity_id| {
            if (zone.units.getComponent(entity_id, .transform)) |transform| {
                const dist_sq = center.sub(transform.pos).lengthSquared();
                if (dist_sq <= radius_squared) {
                    try found_entities.append(entity_id);
                }
            }
        }

        // Add other entity types as needed...

        return try found_entities.toOwnedSlice();
    }

    /// Count entities of a specific type in the current zone
    pub fn countEntities(game: *const HexGame, entity_type: EntityType) usize {
        const zone = game.getCurrentZoneConst();

        return switch (entity_type) {
            .player => zone.players.count,
            .unit => zone.units.count,
            .projectile => zone.projectiles.count,
            .terrain => zone.terrain.count,
            .lifestone => zone.lifestones.count,
            .portal => zone.portals.count,
        };
    }

    /// Iterator for units in current zone
    pub fn iterateUnitsInCurrentZone(game: *HexGame) EntityIterator {
        return game.getCurrentZone().units.entityIterator();
    }

    /// Iterator for lifestones in current zone
    pub fn iterateLifestonesInCurrentZone(game: *HexGame) EntityIterator {
        return game.getCurrentZone().lifestones.entityIterator();
    }

    /// Iterator for portals in current zone
    pub fn iteratePortalsInCurrentZone(game: *HexGame) EntityIterator {
        return game.getCurrentZone().portals.entityIterator();
    }

    /// Iterator for terrain in current zone
    pub fn iterateTerrainInCurrentZone(game: *HexGame) EntityIterator {
        return game.getCurrentZone().terrain.entityIterator();
    }

    /// Debug helper to log zone entity counts
    pub fn debugLogZoneEntities(game: *HexGame, zone_index: usize) void {
        if (zone_index >= HexGame.MAX_ZONES) return;

        const zone = game.zone_manager.getZone(zone_index);
        var count: usize = 0;

        // Count lifestones
        var lifestone_iter = zone.lifestones.entityIterator();
        while (lifestone_iter.next()) |_| {
            count += 1;
        }
        game.logger.debug("zone_lifestones", "Zone {}: {} lifestones", .{ zone_index, count });

        // Count units
        count = 0;
        var unit_iter = zone.units.entityIterator();
        while (unit_iter.next()) |_| {
            count += 1;
        }
        game.logger.debug("zone_units", "Zone {}: {} units", .{ zone_index, count });

        // Count portals
        count = 0;
        var portal_iter = zone.portals.entityIterator();
        while (portal_iter.next()) |_| {
            count += 1;
        }
        game.logger.debug("zone_portals", "Zone {}: {} portals", .{ zone_index, count });

        game.logger.debug("zone_entities", "Zone {}: {} total entities", .{ zone_index, zone.entity_count });
    }
};

pub const EntityType = enum {
    player,
    unit,
    projectile,
    terrain,
    lifestone,
    portal,
};
