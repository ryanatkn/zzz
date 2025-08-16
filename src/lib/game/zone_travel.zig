const std = @import("std");
const EntityId = @import("entity.zig").EntityId;
const Game = @import("game.zig").Game;
const Zone = @import("zone.zig").Zone;
const entity_transfer = @import("entity_transfer.zig");
const components = @import("components.zig");

/// Zone travel management system
pub const ZoneTravel = struct {
    game: *Game,
    tracked_entities: std.AutoHashMap(EntityId, TrackedEntity),
    allocator: std.mem.Allocator,

    /// Tracked entity information
    pub const TrackedEntity = struct {
        tag: []const u8, // e.g., "player", "companion"
        zone_id: u8,
        entity_id: EntityId,
    };

    pub fn init(allocator: std.mem.Allocator, game: *Game) ZoneTravel {
        return .{
            .game = game,
            .tracked_entities = std.AutoHashMap(EntityId, TrackedEntity).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ZoneTravel) void {
        self.tracked_entities.deinit();
    }

    /// Track an entity across zone transitions
    pub fn trackEntity(self: *ZoneTravel, entity: EntityId, tag: []const u8, zone_id: u8) !void {
        try self.tracked_entities.put(entity, .{
            .tag = tag,
            .zone_id = zone_id,
            .entity_id = entity,
        });
    }

    /// Untrack an entity
    pub fn untrackEntity(self: *ZoneTravel, entity: EntityId) void {
        _ = self.tracked_entities.remove(entity);
    }

    /// Get tracked entity by tag
    pub fn getTrackedEntity(self: *const ZoneTravel, tag: []const u8) ?EntityId {
        var iter = self.tracked_entities.iterator();
        while (iter.next()) |entry| {
            if (std.mem.eql(u8, entry.value_ptr.tag, tag)) {
                return entry.value_ptr.entity_id;
            }
        }
        return null;
    }

    /// Travel to a zone with entity management
    pub fn travelToZone(
        self: *ZoneTravel,
        destination_zone_id: u8,
        spawn_pos: components.Vec2,
        entities_to_transfer: []const EntityId,
    ) !void {
        // Set the current zone
        self.game.setCurrentZone(destination_zone_id);

        // Verify destination zone exists
        _ = self.game.getZone(destination_zone_id) orelse {
            std.log.err("Destination zone {} not found", .{destination_zone_id});
            return error.ZoneNotFound;
        };

        // Transfer each entity
        for (entities_to_transfer) |entity| {
            try self.transferEntity(entity, destination_zone_id, spawn_pos);
        }

        // Clear all projectiles in all zones
        try self.clearAllProjectiles();
    }

    /// Transfer a specific entity to a zone
    fn transferEntity(
        self: *ZoneTravel,
        entity: EntityId,
        destination_zone_id: u8,
        spawn_pos: components.Vec2,
    ) !void {
        // Find source zone containing the entity
        var source_zone: ?*Zone = null;
        for (self.game.zones.items) |*zone| {
            if (zone.world.isAlive(entity)) {
                source_zone = zone;
                break;
            }
        }

        const src_zone = source_zone orelse {
            std.log.warn("Entity {any} not found in any zone", .{entity});
            return;
        };

        const dest_zone = self.game.getZone(destination_zone_id) orelse {
            return error.ZoneNotFound;
        };

        // Don't transfer if already in destination
        if (src_zone.id == destination_zone_id) {
            // Just update position
            if (src_zone.world.players.getComponentMut(entity, .transform)) |transform| {
                transform.pos = spawn_pos;
                transform.vel = components.Vec2.ZERO;
            }
            return;
        }

        // Transfer the entity
        const new_entity = try entity_transfer.EntityTransfer.transferEntity(src_zone, dest_zone, entity);

        // Update position in new zone
        if (dest_zone.world.players.getComponentMut(new_entity, .transform)) |transform| {
            transform.pos = spawn_pos;
            transform.vel = components.Vec2.ZERO;
        }

        // Update tracking if this was a tracked entity
        if (self.tracked_entities.get(entity)) |tracked| {
            // Remove old tracking
            _ = self.tracked_entities.remove(entity);
            // Add new tracking with updated entity ID
            try self.tracked_entities.put(new_entity, .{
                .tag = tracked.tag,
                .zone_id = destination_zone_id,
                .entity_id = new_entity,
            });
        }

        std.log.info("Transferred entity from {any} to {any} in zone {}", .{ entity, new_entity, destination_zone_id });
    }

    /// Clear all projectiles in all zones
    fn clearAllProjectiles(self: *ZoneTravel) !void {
        for (self.game.zones.items) |*zone| {
            var projectiles_to_destroy = std.ArrayList(EntityId).init(self.allocator);
            defer projectiles_to_destroy.deinit();

            var projectile_iter = zone.world.projectiles.entityIterator();
            while (projectile_iter.next()) |entity_id| {
                try projectiles_to_destroy.append(entity_id);
            }

            for (projectiles_to_destroy.items) |entity_id| {
                try zone.world.destroyEntity(entity_id);
            }
        }
    }

    /// Find player entity in any zone
    pub fn findPlayerEntity(self: *const ZoneTravel) ?EntityId {
        // First check tracked entities
        if (self.getTrackedEntity("player")) |player| {
            return player;
        }

        // Fallback: search all zones for a player entity
        for (self.game.zones.items) |*zone| {
            var player_iter = zone.world.players.entityIterator();
            if (player_iter.next()) |player| {
                return player;
            }
        }

        return null;
    }
};