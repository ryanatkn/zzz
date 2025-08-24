const std = @import("std");

// Core capabilities
const math = @import("../../lib/math/mod.zig");
const colors = @import("../../lib/core/colors.zig");

// Game system capabilities
const zones = @import("../../lib/game/zones/mod.zig");
const storage = @import("../../lib/game/storage/mod.zig");

// Hex game modules
const world_state_mod = @import("../world_state.zig");
const constants = @import("../constants.zig");
const unit_ext = @import("../unit_ext.zig");
const disposition = @import("../disposition.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const Unit = unit_ext.HexUnit;
const Disposition = disposition.Disposition;

/// Zone management functionality extracted from hex_game.zig
pub const ZoneManager = struct {
    /// Zone data structure with entity storage and metadata
    pub const ZoneData = struct {
        // Direct fixed-size archetype storage - no dynamic allocation
        units: storage.UnitStorage(world_state_mod.MAX_ENTITIES_PER_ARCHETYPE, Unit),
        projectiles: storage.ProjectileStorage(world_state_mod.MAX_ENTITIES_PER_ARCHETYPE, world_state_mod.HexProjectile),
        terrain: storage.TerrainStorage(world_state_mod.MAX_ENTITIES_PER_ARCHETYPE),
        lifestones: storage.InteractiveStorage(world_state_mod.MAX_ENTITIES_PER_ARCHETYPE),
        portals: storage.InteractiveStorage(world_state_mod.MAX_ENTITIES_PER_ARCHETYPE),

        // Zone metadata
        zone_type: ZoneType,
        camera_mode: constants.CameraMode,
        spawn_pos: Vec2,
        background_color: Color,

        // World bounds in meters
        world_width: f32,
        world_height: f32,

        // Entity count tracking
        entity_count: usize,

        pub const ZoneType = enum {
            overworld,
            dungeon_fire,
            dungeon_ice,
            dungeon_storm,
            dungeon_nature,
            dungeon_shadow,
            dungeon_arcane,
        };

        pub fn init(zone_type: ZoneType) ZoneData {
            return .{
                .units = storage.UnitStorage(world_state_mod.MAX_ENTITIES_PER_ARCHETYPE, Unit).init(),
                .projectiles = storage.ProjectileStorage(world_state_mod.MAX_ENTITIES_PER_ARCHETYPE, world_state_mod.HexProjectile).init(),
                .terrain = storage.TerrainStorage(world_state_mod.MAX_ENTITIES_PER_ARCHETYPE).init(),
                .lifestones = storage.InteractiveStorage(world_state_mod.MAX_ENTITIES_PER_ARCHETYPE).init(),
                .portals = storage.InteractiveStorage(world_state_mod.MAX_ENTITIES_PER_ARCHETYPE).init(),
                .zone_type = zone_type,
                // Defaults for normal dungeons - overworld will override in ZON
                .camera_mode = .follow, // Default: follow camera for tactical gameplay
                .spawn_pos = Vec2{ .x = 0.0, .y = 0.0 }, // Default: origin spawn, arrange terrain around player
                .background_color = getZoneBackgroundColorForType(zone_type),
                .world_width = constants.DEFAULT_VIEWPORT_WIDTH, // Default: 16 meters (tactical scale)
                .world_height = constants.DEFAULT_VIEWPORT_HEIGHT, // Default: 9 meters (tactical scale)
                .entity_count = 0,
            };
        }

        pub fn deinit(self: *ZoneData) void {
            // No cleanup needed for fixed arrays
            _ = self;
        }

        /// Check if an entity is alive by searching through all storage types
        pub fn isAlive(self: *const ZoneData, entity_id: world_state_mod.EntityId) bool {
            // Check each storage type to see if entity exists and is alive
            if (self.units.containsEntity(entity_id)) return true;
            if (self.projectiles.containsEntity(entity_id)) return true;
            if (self.terrain.containsEntity(entity_id)) return true;
            if (self.lifestones.containsEntity(entity_id)) return true;
            if (self.portals.containsEntity(entity_id)) return true;
            return false;
        }

        fn getZoneBackgroundColorForType(zone_type: ZoneType) Color {
            return switch (zone_type) {
                .overworld => .{ .r = 0, .g = 0, .b = 0, .a = 255 },
                .dungeon_fire => .{ .r = 64, .g = 16, .b = 16, .a = 255 },
                .dungeon_ice => .{ .r = 16, .g = 32, .b = 64, .a = 255 },
                .dungeon_storm => .{ .r = 32, .g = 32, .b = 48, .a = 255 },
                .dungeon_nature => .{ .r = 16, .g = 32, .b = 16, .a = 255 },
                .dungeon_shadow => .{ .r = 16, .g = 16, .b = 32, .a = 255 },
                .dungeon_arcane => .{ .r = 32, .g = 16, .b = 48, .a = 255 },
            };
        }
    };

    /// Initialize all zones with default types
    pub fn initializeDefaultZones(zone_manager: *zones.ZoneManager(ZoneData, world_state_mod.MAX_ZONES)) void {
        const zone_types = [_]ZoneData.ZoneType{
            .overworld,
            .dungeon_fire,
            .dungeon_ice,
            .dungeon_storm,
            .dungeon_nature,
            .dungeon_shadow,
            .dungeon_arcane,
        };

        for (&zone_manager.zones, zone_types) |*zone, zone_type| {
            zone.* = ZoneData.init(zone_type);
        }
    }

    /// Get zone background color for rendering
    pub fn getZoneBackgroundColor(zone_data: *const ZoneData) Color {
        return zone_data.background_color;
    }

    /// Check if zone index is valid
    pub fn isValidZoneIndex(zone_index: usize) bool {
        return zone_index < world_state_mod.MAX_ZONES;
    }

    /// Get zone spawn position
    pub fn getZoneSpawn(zone_data: *const ZoneData) Vec2 {
        return zone_data.spawn_pos;
    }

    /// Get zone camera mode
    pub fn getZoneCameraMode(zone_data: *const ZoneData) constants.CameraMode {
        return zone_data.camera_mode;
    }

    /// Get zone world dimensions
    pub fn getZoneWorldDimensions(zone_data: *const ZoneData) struct { width: f32, height: f32 } {
        return .{ .width = zone_data.world_width, .height = zone_data.world_height };
    }
};
