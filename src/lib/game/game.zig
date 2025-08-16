const std = @import("std");
const Zone = @import("zone.zig").Zone;
const ZoneMetadata = @import("zone.zig").ZoneMetadata;
const EntityId = @import("entity.zig").EntityId;
const components = @import("components.zig");
const colors = @import("../core/colors.zig");

/// Multi-zone game manager
pub const Game = struct {
    zones: std.ArrayList(Zone),
    current_zone_id: u8,
    allocator: std.mem.Allocator,
    tracked_entities: std.StringHashMap(TrackedEntity),

    /// Tracked entity info
    pub const TrackedEntity = struct {
        entity_id: EntityId,
        zone_id: u8,
    };

    pub fn init(allocator: std.mem.Allocator) Game {
        var game = Game{
            .zones = std.ArrayList(Zone).init(allocator),
            .current_zone_id = 0,
            .allocator = allocator,
            .tracked_entities = std.StringHashMap(TrackedEntity).init(allocator),
        };
        
        // Pre-create all 7 zones to ensure they exist before loader access
        game.initializeAllZones() catch |err| {
            std.log.err("Failed to initialize zones: {}", .{err});
            // Return incomplete game - let caller handle the error
            return game;
        };
        
        return game;
    }
    
    /// Initialize all 7 zones with default metadata
    fn initializeAllZones(self: *Game) !void {
        const zone_configs = [_]Zone.Config{
            // Zone 0: Overworld
            .{
                .id = 0,
                .metadata = .{
                    .zone_type = .overworld,
                    .camera_mode = .fixed,
                    .camera_scale = 1.0,
                    .spawn_pos = .{ .x = 400, .y = 300 },
                    .background_color = .{ .r = 0, .g = 0, .b = 0, .a = 255 },
                },
                .max_entities = 1000,
            },
            // Zone 1: Fire Dungeon
            .{
                .id = 1,
                .metadata = .{
                    .zone_type = .dungeon_fire,
                    .camera_mode = .follow,
                    .camera_scale = 2.0,
                    .spawn_pos = .{ .x = 400, .y = 300 },
                    .background_color = .{ .r = 64, .g = 16, .b = 16, .a = 255 },
                },
                .max_entities = 500,
            },
            // Zone 2: Ice Dungeon
            .{
                .id = 2,
                .metadata = .{
                    .zone_type = .dungeon_ice,
                    .camera_mode = .follow,
                    .camera_scale = 2.0,
                    .spawn_pos = .{ .x = 400, .y = 300 },
                    .background_color = .{ .r = 16, .g = 32, .b = 64, .a = 255 },
                },
                .max_entities = 500,
            },
            // Zone 3: Storm Dungeon
            .{
                .id = 3,
                .metadata = .{
                    .zone_type = .dungeon_storm,
                    .camera_mode = .follow,
                    .camera_scale = 2.0,
                    .spawn_pos = .{ .x = 400, .y = 300 },
                    .background_color = .{ .r = 32, .g = 32, .b = 48, .a = 255 },
                },
                .max_entities = 500,
            },
            // Zone 4: Nature Dungeon
            .{
                .id = 4,
                .metadata = .{
                    .zone_type = .dungeon_nature,
                    .camera_mode = .follow,
                    .camera_scale = 2.0,
                    .spawn_pos = .{ .x = 400, .y = 300 },
                    .background_color = .{ .r = 16, .g = 32, .b = 16, .a = 255 },
                },
                .max_entities = 500,
            },
            // Zone 5: Shadow Dungeon
            .{
                .id = 5,
                .metadata = .{
                    .zone_type = .dungeon_shadow,
                    .camera_mode = .follow,
                    .camera_scale = 2.0,
                    .spawn_pos = .{ .x = 400, .y = 300 },
                    .background_color = .{ .r = 16, .g = 16, .b = 32, .a = 255 },
                },
                .max_entities = 500,
            },
            // Zone 6: Arcane Dungeon
            .{
                .id = 6,
                .metadata = .{
                    .zone_type = .dungeon_arcane,
                    .camera_mode = .follow,
                    .camera_scale = 2.0,
                    .spawn_pos = .{ .x = 400, .y = 300 },
                    .background_color = .{ .r = 32, .g = 16, .b = 48, .a = 255 },
                },
                .max_entities = 500,
            },
        };
        
        // Create all zones
        for (zone_configs) |config| {
            try self.addZone(config);
        }
    }

    pub fn deinit(self: *Game) void {
        for (self.zones.items) |*zone| {
            zone.deinit();
        }
        self.zones.deinit();
        self.tracked_entities.deinit();
    }

    pub fn addZone(self: *Game, config: Zone.Config) !void {
        const zone = try Zone.init(self.allocator, config);
        try self.zones.append(zone);
    }

    /// Get current zone
    pub fn getCurrentZone(self: *Game) *Zone {
        if (self.current_zone_id >= self.zones.items.len) {
            std.log.err("getCurrentZone: current_zone_id {} >= zones.len {}", .{ self.current_zone_id, self.zones.items.len });
            // Return zone 0 as fallback
            self.current_zone_id = 0;
        }
        return &self.zones.items[self.current_zone_id];
    }

    /// Get current zone (const)
    pub fn getCurrentZoneConst(self: *const Game) *const Zone {
        if (self.current_zone_id >= self.zones.items.len) {
            std.log.err("getCurrentZoneConst: current_zone_id {} >= zones.len {}", .{ self.current_zone_id, self.zones.items.len });
            // Can't modify const self, so return zone 0
            return &self.zones.items[0];
        }
        return &self.zones.items[self.current_zone_id];
    }

    /// Get zone by ID
    pub fn getZone(self: *Game, zone_id: u8) ?*Zone {
        if (zone_id >= self.zones.items.len) return null;
        return &self.zones.items[zone_id];
    }

    /// Set current zone
    pub fn setCurrentZone(self: *Game, zone_id: u8) void {
        if (zone_id >= self.zones.items.len) {
            std.log.err("setCurrentZone: Invalid zone_id {}", .{zone_id});
            return;
        }
        self.current_zone_id = zone_id;
    }

    /// Get current zone index
    pub fn getCurrentZoneIndex(self: *const Game) u8 {
        return self.current_zone_id;
    }

    /// Move an entity from one zone to another (with optional source zone hint)
    pub fn moveEntityToZone(self: *Game, entity: EntityId, new_zone_id: u32, source_zone_id: ?u8) !void {
        const entity_transfer = @import("entity_transfer.zig");
        
        std.log.info("moveEntityToZone: Moving entity {any} to zone {} (source hint: {?})", .{ entity, new_zone_id, source_zone_id });
        
        // Find the source zone - use hint if provided
        var source_zone_index: ?usize = null;
        
        // First try the hint if provided
        if (source_zone_id) |hint_id| {
            for (self.zones.items, 0..) |*zone, i| {
                if (zone.id == hint_id and zone.world.isAlive(entity)) {
                    source_zone_index = i;
                    std.log.info("moveEntityToZone: Found entity in hinted source zone {}", .{i});
                    break;
                }
            }
        }
        
        // If not found with hint, search all zones
        if (source_zone_index == null) {
            for (self.zones.items, 0..) |*zone, i| {
                if (zone.world.isAlive(entity)) {
                    source_zone_index = i;
                    std.log.info("moveEntityToZone: Found entity in source zone {} (no hint or hint incorrect)", .{i});
                    break;
                }
            }
        }

        // If entity not found in any zone, do nothing
        const source_index = source_zone_index orelse {
            std.log.warn("moveEntityToZone: Entity {any} not found in any zone", .{entity});
            return;
        };
        
        // Find the destination zone
        var dest_zone_index: ?usize = null;
        for (self.zones.items, 0..) |zone, i| {
            if (zone.id == new_zone_id) {
                dest_zone_index = i;
                std.log.info("moveEntityToZone: Found destination zone {} at index {}", .{ new_zone_id, i });
                break;
            }
        }

        // If destination zone not found, do nothing
        const dest_index = dest_zone_index orelse {
            std.log.warn("moveEntityToZone: Destination zone {} not found", .{new_zone_id});
            return;
        };
        
        // Don't move if already in the target zone
        if (source_index == dest_index) {
            std.log.info("moveEntityToZone: Entity already in target zone, no move needed", .{});
            return;
        }

        const source_zone = &self.zones.items[source_index];
        const dest_zone = &self.zones.items[dest_index];
        
        // Use entity_transfer module to handle the transfer
        _ = try entity_transfer.EntityTransfer.transferEntity(source_zone, dest_zone, entity);
        std.log.info("moveEntityToZone: Successfully transferred entity to new zone", .{});
    }

    /// Clear all projectiles from all zones
    pub fn clearAllProjectiles(self: *Game) !void {
        for (self.zones.items) |*zone| {
            // Get all projectile entities
            var projectile_iter = zone.world.projectiles.entityIterator();
            var to_destroy = std.ArrayList(EntityId).init(self.allocator);
            defer to_destroy.deinit();
            
            while (projectile_iter.next()) |entity_id| {
                try to_destroy.append(entity_id);
            }
            
            // Destroy all projectiles
            for (to_destroy.items) |entity_id| {
                try zone.world.destroyEntity(entity_id);
            }
        }
    }

    /// Track an entity with a tag
    pub fn trackEntity(self: *Game, tag: []const u8, entity_id: EntityId, zone_id: u8) !void {
        try self.tracked_entities.put(tag, .{
            .entity_id = entity_id,
            .zone_id = zone_id,
        });
    }

    /// Get tracked entity by tag
    pub fn getTrackedEntity(self: *const Game, tag: []const u8) ?TrackedEntity {
        return self.tracked_entities.get(tag);
    }

    /// Update tracked entity ID (after zone transfer)
    pub fn updateTrackedEntity(self: *Game, tag: []const u8, new_entity_id: EntityId, new_zone_id: u8) !void {
        try self.tracked_entities.put(tag, .{
            .entity_id = new_entity_id,
            .zone_id = new_zone_id,
        });
    }

    /// Remove tracked entity
    pub fn untrackEntity(self: *Game, tag: []const u8) void {
        _ = self.tracked_entities.remove(tag);
    }

    /// Find player entity across all zones
    pub fn findPlayerEntity(self: *const Game) ?EntityId {
        // First check tracked entities
        if (self.getTrackedEntity("player")) |tracked| {
            return tracked.entity_id;
        }

        // Fallback: search all zones
        for (self.zones.items) |*zone| {
            var player_iter = zone.world.players.entityIterator();
            if (player_iter.next()) |player| {
                return player;
            }
        }
        return null;
    }
};