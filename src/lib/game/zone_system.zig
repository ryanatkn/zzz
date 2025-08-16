const std = @import("std");
const ecs = @import("ecs.zig");
const EntityId = ecs.EntityId;

/// Generic zone management system for games with zone-based worlds
/// 
/// Provides:
/// - Fixed-size zone arrays for compile-time optimization
/// - Zone-local entity storage with isolation guarantees
/// - Entity transfer mechanisms between zones
/// - Component extraction/injection for transfers
pub fn ZoneSystem(comptime Config: type) type {
    return struct {
        zones: [Config.max_zones]ZoneData,
        current_zone: u8,
        entity_allocator: ecs.EntityAllocator,
        allocator: std.mem.Allocator,
        
        const Self = @This();
        
        pub const ZoneData = struct {
            // Archetype storage - configured per game
            archetypes: Config.ArchetypeStorage,
            
            // Zone metadata
            metadata: Config.ZoneMetadata,
            
            // Entity count tracking
            entity_count: usize,
            
            pub fn init(allocator: std.mem.Allocator, metadata: Config.ZoneMetadata) !ZoneData {
                return .{
                    .archetypes = try Config.ArchetypeStorage.init(allocator),
                    .metadata = metadata,
                    .entity_count = 0,
                };
            }
            
            pub fn deinit(self: *ZoneData) void {
                self.archetypes.deinit();
            }
        };
        
        /// Component bundle for entity transfer
        pub const EntityComponents = struct {
            entity_id: EntityId,
            components: Config.ComponentBundle,
            
            pub fn extract(zone: *ZoneData, entity_id: EntityId) ?EntityComponents {
                // Extract all components from entity in source zone
                return Config.extractComponents(&zone.archetypes, entity_id);
            }
            
            pub fn inject(zone: *ZoneData, self: EntityComponents) !void {
                // Inject all components into entity in destination zone
                try Config.injectComponents(&zone.archetypes, self.entity_id, self.components);
                zone.entity_count += 1;
            }
        };
        
        pub fn init(allocator: std.mem.Allocator, zone_configs: [Config.max_zones]Config.ZoneMetadata) !Self {
            var system = Self{
                .zones = undefined,
                .current_zone = 0,
                .entity_allocator = ecs.EntityAllocator.init(),
                .allocator = allocator,
            };
            
            // Initialize all zones
            for (&system.zones, zone_configs) |*zone, config| {
                zone.* = try ZoneData.init(allocator, config);
            }
            
            return system;
        }
        
        pub fn deinit(self: *Self) void {
            for (&self.zones) |*zone| {
                zone.deinit();
            }
        }
        
        // Direct zone access - no abstraction layers
        pub fn getCurrentZone(self: *Self) *ZoneData {
            std.debug.assert(self.current_zone < Config.max_zones);
            return &self.zones[self.current_zone];
        }
        
        pub fn getCurrentZoneConst(self: *const Self) *const ZoneData {
            std.debug.assert(self.current_zone < Config.max_zones);
            return &self.zones[self.current_zone];
        }
        
        pub fn getZone(self: *Self, zone_index: u8) ?*ZoneData {
            if (zone_index >= Config.max_zones) return null;
            return &self.zones[zone_index];
        }
        
        pub fn getZoneConst(self: *const Self, zone_index: u8) ?*const ZoneData {
            if (zone_index >= Config.max_zones) return null;
            return &self.zones[zone_index];
        }
        
        pub fn setCurrentZone(self: *Self, zone_index: u8) void {
            if (zone_index >= Config.max_zones) {
                std.log.err("setCurrentZone: Invalid zone_index {}", .{zone_index});
                return;
            }
            self.current_zone = zone_index;
            std.log.debug("Zone switched to: {}", .{zone_index});
        }
        
        /// Transfer entity from one zone to another
        /// Extracts all components from source zone and recreates entity in destination zone
        pub fn transferEntity(self: *Self, entity_id: EntityId, source_zone: u8, dest_zone: u8) !bool {
            if (source_zone >= Config.max_zones or dest_zone >= Config.max_zones) {
                std.log.err("transferEntity: Invalid zone indices {} -> {}", .{ source_zone, dest_zone });
                return false;
            }
            
            if (source_zone == dest_zone) {
                // No transfer needed
                return true;
            }
            
            const source = &self.zones[source_zone];
            const dest = &self.zones[dest_zone];
            
            // Extract components from source zone
            const components = EntityComponents.extract(source, entity_id) orelse {
                std.log.warn("transferEntity: Failed to extract entity {} from zone {}", .{ entity_id, source_zone });
                return false;
            };
            
            // Remove from source zone
            Config.removeEntity(&source.archetypes, entity_id);
            source.entity_count -%= 1;
            
            // Inject into destination zone
            try components.inject(dest);
            
            std.log.debug("Entity {} transferred from zone {} to zone {}", .{ entity_id, source_zone, dest_zone });
            return true;
        }
        
        /// Get total entity count across all zones
        pub fn getTotalEntityCount(self: *const Self) usize {
            var total: usize = 0;
            for (self.zones) |zone| {
                total += zone.entity_count;
            }
            return total;
        }
        
        /// Debug: Log entity counts for all zones
        pub fn debugLogZoneCounts(self: *const Self) void {
            for (self.zones, 0..) |zone, i| {
                if (zone.entity_count > 0) {
                    std.log.debug("Zone {}: {} entities", .{ i, zone.entity_count });
                }
            }
            std.log.debug("Total entities: {}", .{self.getTotalEntityCount()});
        }
    };
}

/// Configuration interface that games must implement
/// Example usage in hex game:
/// 
/// const HexZoneConfig = struct {
///     const max_zones = 7;
///     const ZoneMetadata = struct { zone_type: ZoneType, camera_mode: CameraMode, ... };
///     const ArchetypeStorage = struct { players: PlayerArchetype, units: UnitArchetype, ... };
///     const ComponentBundle = struct { transform: ?Transform, health: ?Health, ... };
///     
///     fn extractComponents(archetypes: *ArchetypeStorage, entity_id: EntityId) ?ComponentBundle { ... }
///     fn injectComponents(archetypes: *ArchetypeStorage, entity_id: EntityId, components: ComponentBundle) !void { ... }
///     fn removeEntity(archetypes: *ArchetypeStorage, entity_id: EntityId) void { ... }
/// };
/// 
/// const HexZoneSystem = ZoneSystem(HexZoneConfig);
pub const ZoneSystemConfig = struct {
    /// Maximum number of zones
    max_zones: comptime_int,
    
    /// Zone metadata type (camera settings, background color, etc.)
    ZoneMetadata: type,
    
    /// Archetype storage container (all entity archetypes for the zone)
    ArchetypeStorage: type,
    
    /// Component bundle for entity transfer
    ComponentBundle: type,
    
    /// Extract all components from an entity (returns null if entity not found)
    extractComponents: fn (archetypes: *ArchetypeStorage, entity_id: EntityId) ?ComponentBundle,
    
    /// Inject components into entity in destination zone
    injectComponents: fn (archetypes: *ArchetypeStorage, entity_id: EntityId, components: ComponentBundle) !void,
    
    /// Remove entity from archetype storage
    removeEntity: fn (archetypes: *ArchetypeStorage, entity_id: EntityId) void,
};