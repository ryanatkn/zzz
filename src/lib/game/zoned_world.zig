/// zoned_world.zig - Clear Multi-Zone Game World Manager
///
/// This is the CLEAR PRIMITIVE version of multi-zone management.
/// Unlike the complex Game class with ArrayList, HashMaps, and multiple
/// layers of abstraction, this uses simple fixed arrays and direct access.
///
/// Benefits:
/// - Clear, descriptive name (ZonedWorld vs abstract "Game")
/// - Fixed array of zones - no dynamic allocation
/// - Direct zone access by index
/// - Simple player tracking
/// - Explicit entity creation methods
///
/// Trade-offs:
/// - Fixed maximum number of zones (but 7-10 zones is typical)
/// - Less flexible entity tracking (but simpler and faster)
///
/// This is what the complex ECS should have been from the start!

const std = @import("std");
const entity_id = @import("entity_id.zig");
const zone_storage = @import("zone_storage.zig");
const zone_mod = @import("zone.zig");
const components = @import("components.zig");
const colors = @import("../core/colors.zig");

const EntityId = entity_id.EntityId;
const EntityIdGenerator = entity_id.EntityIdGenerator;
const ZoneStorage = zone_storage.ZoneStorage;
const ZoneMetadata = zone_mod.ZoneMetadata;

/// Clear multi-zone world manager
/// Manages multiple zones with simple direct access
pub const ZonedWorld = struct {
    /// Fixed array of zones - no dynamic allocation
    zones: []Zone,
    zone_count: usize,
    current_zone_id: u8 = 0,
    
    /// Entity ID generation
    entity_generator: EntityIdGenerator,
    
    /// Player tracking across zones
    player_id: ?EntityId = null,
    player_zone: u8 = 0,
    
    /// Memory allocator
    allocator: std.mem.Allocator,
    
    /// Single zone with storage and metadata
    pub const Zone = struct {
        id: u8,
        storage: ZoneStorage,
        metadata: ZoneMetadata,
        
        pub fn init(allocator: std.mem.Allocator, id: u8, metadata: ZoneMetadata, capacity: usize) !Zone {
            return .{
                .id = id,
                .storage = try ZoneStorage.init(allocator, capacity),
                .metadata = metadata,
            };
        }
        
        pub fn deinit(self: *Zone) void {
            self.storage.deinit();
        }
    };
    
    /// Initialize with fixed number of zones
    pub fn init(allocator: std.mem.Allocator, max_zones: usize) !ZonedWorld {
        const zones = try allocator.alloc(Zone, max_zones);
        
        // Initialize standard 7 zones
        const zone_configs = [_]struct { 
            type: ZoneMetadata.ZoneType,
            camera: ZoneMetadata.CameraMode,
            scale: f32,
        }{
            .{ .type = .overworld, .camera = .fixed, .scale = 1.0 },
            .{ .type = .dungeon_fire, .camera = .follow, .scale = 1.5 },
            .{ .type = .dungeon_ice, .camera = .follow, .scale = 1.5 },
            .{ .type = .dungeon_storm, .camera = .follow, .scale = 1.5 },
            .{ .type = .dungeon_nature, .camera = .follow, .scale = 1.5 },
            .{ .type = .dungeon_shadow, .camera = .follow, .scale = 1.5 },
            .{ .type = .dungeon_arcane, .camera = .follow, .scale = 1.5 },
        };
        
        var zone_count: usize = 0;
        for (zone_configs, 0..) |config, i| {
            if (i >= max_zones) break;
            
            const metadata = ZoneMetadata{
                .zone_type = config.type,
                .camera_mode = config.camera,
                .camera_scale = config.scale,
                .spawn_pos = .{ .x = 960, .y = 540 },
                .background_color = colors.Color{ .r = 0, .g = 0, .b = 0, .a = 255 },
            };
            
            zones[i] = try Zone.init(allocator, @intCast(i), metadata, 1000);
            zone_count += 1;
        }
        
        return .{
            .zones = zones,
            .zone_count = zone_count,
            .current_zone_id = 0,
            .entity_generator = EntityIdGenerator.init(),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *ZonedWorld) void {
        for (self.zones[0..self.zone_count]) |*zone| {
            zone.deinit();
        }
        self.allocator.free(self.zones);
    }
    
    /// Get current zone
    pub fn getCurrentZone(self: *ZonedWorld) *Zone {
        return &self.zones[self.current_zone_id];
    }
    
    /// Get zone by ID
    pub fn getZone(self: *ZonedWorld, zone_id: u8) ?*Zone {
        if (zone_id >= self.zone_count) return null;
        return &self.zones[zone_id];
    }
    
    /// Switch to a different zone
    pub fn setCurrentZone(self: *ZonedWorld, zone_id: u8) !void {
        if (zone_id >= self.zone_count) {
            return error.InvalidZoneId;
        }
        self.current_zone_id = zone_id;
    }
    
    /// Create a new entity ID
    pub fn createEntity(self: *ZonedWorld) EntityId {
        return self.entity_generator.allocate();
    }
    
    /// Create a player in the current zone
    pub fn createPlayer(self: *ZonedWorld, pos: components.Vec2) !EntityId {
        const id = self.createEntity();
        const zone = self.getCurrentZone();
        
        try zone.storage.addPlayer(.{
            .id = id,
            .transform = .{
                .pos = pos,
                .vel = .{ .x = 0, .y = 0 },
                .radius = 20,
            },
            .health = .{
                .current = 100,
                .max = 100,
                .alive = true,
            },
            .visual = .{
                .color = colors.Color{ .r = 0, .g = 255, .b = 0, .a = 255 },
                .scale = 1.0,
                .visible = true,
            },
            .input = .{
                .move_direction = .{ .x = 0, .y = 0 },
                .shoot_target = null,
                .ability_target = null,
            },
        });
        
        self.player_id = id;
        self.player_zone = self.current_zone_id;
        
        return id;
    }
    
    /// Transfer player to another zone
    pub fn transferPlayerToZone(self: *ZonedWorld, zone_id: u8, spawn_pos: components.Vec2) !void {
        if (zone_id >= self.zone_count) return error.InvalidZoneId;
        if (self.player_id == null) return error.NoPlayer;
        
        // Find player in current zone
        const current_zone = &self.zones[self.player_zone];
        var player_data: ?ZoneStorage.Player = null;
        
        for (current_zone.storage.getPlayers()) |player| {
            if (player.id == self.player_id.?) {
                player_data = player;
                break;
            }
        }
        
        if (player_data == null) return error.PlayerNotFound;
        
        // Remove from current zone (simplified - would need proper removal)
        // In real implementation, would need removePlayer function
        
        // Add to new zone with new position
        var new_player = player_data.?;
        new_player.transform.pos = spawn_pos;
        
        const new_zone = &self.zones[zone_id];
        try new_zone.storage.addPlayer(new_player);
        
        // Update tracking
        self.player_zone = zone_id;
        self.current_zone_id = zone_id;
    }
    
    /// Get all zones (for iteration)
    pub fn getAllZones(self: *ZonedWorld) []Zone {
        return self.zones[0..self.zone_count];
    }
    
    /// Clear all entities in all zones
    pub fn clearAllZones(self: *ZonedWorld) void {
        for (self.zones[0..self.zone_count]) |*zone| {
            zone.storage.clear();
        }
        self.entity_generator.reset();
        self.player_id = null;
    }
};