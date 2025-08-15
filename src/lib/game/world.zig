const std = @import("std");
const entity_mod = @import("entity.zig");
const archetype_storage = @import("archetype_storage.zig");
const component_registry = @import("component_registry.zig");
const components = @import("components.zig");
const colors = @import("../core/colors.zig");

const EntityId = entity_mod.EntityId;
const EntityAllocator = entity_mod.EntityAllocator;
const PlayerArchetype = archetype_storage.PlayerArchetype;
const UnitArchetype = archetype_storage.UnitArchetype;
const ProjectileArchetype = archetype_storage.ProjectileArchetype;
const ObstacleArchetype = archetype_storage.ObstacleArchetype;
const LifestoneArchetype = archetype_storage.LifestoneArchetype;
const PortalArchetype = archetype_storage.PortalArchetype;

/// Pure ECS world with archetype-based storage
/// Contains entities and components with no zone-specific logic
pub const World = struct {
    // Entity allocation
    entities: EntityAllocator,

    // Archetype-based storage for better cache locality
    players: PlayerArchetype,
    units: UnitArchetype,
    projectiles: ProjectileArchetype,
    obstacles: ObstacleArchetype,
    lifestones: LifestoneArchetype,
    portals: PortalArchetype,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, max_entities: usize) !World {
        const entities_per_archetype = max_entities / 6; // Distribute capacity across archetypes

        return World{
            .entities = try EntityAllocator.init(allocator, max_entities),
            .players = try PlayerArchetype.init(allocator, 10), // Few players expected
            .units = try UnitArchetype.init(allocator, entities_per_archetype),
            .projectiles = try ProjectileArchetype.init(allocator, entities_per_archetype),
            .obstacles = try ObstacleArchetype.init(allocator, entities_per_archetype),
            .lifestones = try LifestoneArchetype.init(allocator, entities_per_archetype),
            .portals = try PortalArchetype.init(allocator, entities_per_archetype),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *World) void {
        self.entities.deinit();
        self.players.deinit();
        self.units.deinit();
        self.projectiles.deinit();
        self.obstacles.deinit();
        self.lifestones.deinit();
        self.portals.deinit();
    }

    /// Create a new entity
    pub fn createEntity(self: *World) !EntityId {
        return try self.entities.create();
    }

    /// Destroy an entity and remove it from all archetypes
    pub fn destroyEntity(self: *World, entity: EntityId) !void {
        // Remove from all archetypes (only one should contain it)
        _ = self.players.removeEntity(entity);
        _ = self.units.removeEntity(entity);
        _ = self.projectiles.removeEntity(entity);
        _ = self.obstacles.removeEntity(entity);
        _ = self.lifestones.removeEntity(entity);
        _ = self.portals.removeEntity(entity);

        // Destroy in entity allocator
        try self.entities.destroy(entity);
    }

    /// Check if entity is alive
    pub fn isAlive(self: *const World, entity: EntityId) bool {
        return self.entities.isAlive(entity);
    }

    /// Find which archetype contains an entity
    pub fn findEntityArchetype(self: *const World, entity: EntityId) ?ArchetypeType {
        if (self.players.hasEntity(entity)) return .player;
        if (self.units.hasEntity(entity)) return .unit;
        if (self.projectiles.hasEntity(entity)) return .projectile;
        if (self.obstacles.hasEntity(entity)) return .obstacle;
        if (self.lifestones.hasEntity(entity)) return .lifestone;
        if (self.portals.hasEntity(entity)) return .portal;
        return null;
    }

    pub const ArchetypeType = enum {
        player,
        unit,
        projectile,
        obstacle,
        lifestone,
        portal,
    };

    /// Create a player entity
    pub fn createPlayer(
        self: *World,
        pos: components.Vec2,
        radius: f32,
        health: f32,
        controller_id: u8,
    ) !EntityId {
        const entity = try self.createEntity();
        errdefer self.destroyEntity(entity) catch {};

        const required_data = PlayerArchetype.RequiredComponentData{
            .transform = components.Transform.init(pos, radius),
            .health = components.Health.init(health),
            .movement = components.Movement.init(200), // Default player speed
            .visual = components.Visual.init(.{ .r = 51, .g = 178, .b = 255, .a = 255 }), // Blue player
            .player_input = components.PlayerInput.init(controller_id),
            .combat = components.Combat.init(25, 2.0), // 25 damage, 2 attacks/sec
        };

        try self.players.addEntity(entity, required_data);
        return entity;
    }

    /// Create a unit entity
    pub fn createUnit(
        self: *World,
        pos: components.Vec2,
        radius: f32,
    ) !EntityId {
        const entity = try self.createEntity();
        errdefer self.destroyEntity(entity) catch {};

        const required_data = UnitArchetype.RequiredComponentData{
            .transform = components.Transform.init(pos, radius),
            .health = components.Health.init(1.0), // Simple 1-hit units
            .visual = components.Visual.init(.{ .r = 1, .g = 1, .b = 1, .a = 1 }),
            .unit = components.Unit.init(.enemy, pos),
        };

        try self.units.addEntity(entity, required_data);
        return entity;
    }

    /// Create a projectile entity
    pub fn createProjectile(
        self: *World,
        pos: components.Vec2,
        vel: components.Vec2,
        radius: f32,
        owner: EntityId,
        damage: f32,
        lifetime: f32,
    ) !EntityId {
        const entity = try self.createEntity();
        errdefer self.destroyEntity(entity) catch {};

        const required_data = ProjectileArchetype.RequiredComponentData{
            .transform = components.Transform{
                .pos = pos,
                .vel = vel,
                .radius = radius,
            },
            .visual = components.Visual.init(.{ .r = 255, .g = 255, .b = 0, .a = 255 }), // Yellow projectile
            .projectile = components.Projectile.init(owner, lifetime),
            .combat = components.Combat.init(damage, 0), // Projectiles don't attack repeatedly
        };

        try self.projectiles.addEntity(entity, required_data);

        // Make projectiles deflectable by default
        try self.projectiles.addOptionalComponent(entity, .interactable, components.Interactable.init(.deflectable));

        return entity;
    }

    /// Create an obstacle entity
    pub fn createObstacle(
        self: *World,
        pos: components.Vec2,
        size: components.Vec2,
        is_deadly: bool,
    ) !EntityId {
        const entity = try self.createEntity();
        errdefer self.destroyEntity(entity) catch {};

        // Create rectangular obstacle using width/height as radius for collision detection
        const radius = @max(size.x, size.y) / 2.0; // Use larger dimension for collision

        // Create visual component
        const color = if (is_deadly)
            colors.Color{ .r = 200, .g = 0, .b = 0, .a = 255 } // Red for deadly
        else
            colors.Color{ .r = 100, .g = 100, .b = 100, .a = 255 }; // Gray for blocking

        // Create terrain component with size information
        const terrain_type = if (is_deadly) components.Terrain.TerrainType.pit else components.Terrain.TerrainType.wall;

        const required_data = ObstacleArchetype.RequiredComponentData{
            .transform = components.Transform.init(pos, radius),
            .visual = components.Visual.init(color),
            .terrain = components.Terrain.init(terrain_type, size),
        };

        try self.obstacles.addEntity(entity, required_data);
        return entity;
    }

    /// Create a lifestone entity
    pub fn createLifestone(
        self: *World,
        pos: components.Vec2,
        radius: f32,
        attuned: bool,
    ) !EntityId {
        const entity = try self.createEntity();
        errdefer self.destroyEntity(entity) catch {};

        // Create visual component with proper lifestone color
        const color = if (attuned)
            colors.Color{ .r = 0, .g = 255, .b = 255, .a = 255 } // Cyan for attuned
        else
            colors.Color{ .r = 128, .g = 128, .b = 255, .a = 255 }; // Light blue for unattuned

        // Lifestones are circular, so create square size from radius
        const lifestone_size = components.Vec2{ .x = radius * 2.0, .y = radius * 2.0 };

        // Add interactable component for attunement
        var interactable = components.Interactable.init(components.Interactable.InteractionType.transformable);
        interactable.attuned = attuned;

        const required_data = LifestoneArchetype.RequiredComponentData{
            .transform = components.Transform.init(pos, radius),
            .visual = components.Visual.init(color),
            .terrain = components.Terrain.init(components.Terrain.TerrainType.altar, lifestone_size),
            .interactable = interactable,
        };

        try self.lifestones.addEntity(entity, required_data);
        return entity;
    }

    /// Create a portal entity
    pub fn createPortal(
        self: *World,
        pos: components.Vec2,
        radius: f32,
        destination_zone: u8,
    ) !EntityId {
        const entity = try self.createEntity();
        errdefer self.destroyEntity(entity) catch {};

        // Create visual component with portal color (purple/magenta)
        const color = colors.Color{ .r = 255, .g = 0, .b = 255, .a = 255 }; // Magenta

        // Portals are circular, so create square size from radius
        const portal_size = components.Vec2{ .x = radius * 2.0, .y = radius * 2.0 };

        const required_data = PortalArchetype.RequiredComponentData{
            .transform = components.Transform.init(pos, radius),
            .visual = components.Visual.init(color),
            .terrain = components.Terrain.init(components.Terrain.TerrainType.door, portal_size),
            .interactable = components.Interactable.initPortal(destination_zone),
        };

        try self.portals.addEntity(entity, required_data);
        return entity;
    }

    /// Get player entity (there should be only one per zone typically)
    pub fn getPlayer(self: *World) ?EntityId {
        var iter = self.players.entityIterator();
        return iter.next();
    }

    /// Get total entity count
    pub fn getTotalEntityCount(self: *const World) usize {
        return self.players.count() +
            self.units.count() +
            self.projectiles.count() +
            self.obstacles.count() +
            self.lifestones.count() +
            self.portals.count();
    }
};

/// Zone metadata and configuration
pub const ZoneMetadata = struct {
    pub const ZoneType = enum {
        overworld,
        dungeon_fire,
        dungeon_ice,
        dungeon_storm,
        dungeon_nature,
        dungeon_shadow,
        dungeon_arcane,
    };

    pub const CameraMode = enum {
        fixed,
        follow,
    };

    zone_type: ZoneType,
    camera_mode: CameraMode,
    camera_scale: f32,
    spawn_pos: components.Vec2,
    background_color: colors.Color,
};

/// Lightweight zone that composes a World with metadata
pub const Zone = struct {
    id: u32,
    world: World,
    metadata: ZoneMetadata,

    pub const Config = struct {
        id: u32,
        metadata: ZoneMetadata,
        max_entities: usize,
    };

    pub fn init(allocator: std.mem.Allocator, config: Config) !Zone {
        return .{
            .id = config.id,
            .world = try World.init(allocator, config.max_entities),
            .metadata = config.metadata,
        };
    }

    pub fn deinit(self: *Zone) void {
        self.world.deinit();
    }

    // Delegate entity creation methods to world
    pub fn createPlayer(self: *Zone, pos: components.Vec2, radius: f32, health: f32, controller_id: u8) !EntityId {
        return self.world.createPlayer(pos, radius, health, controller_id);
    }

    pub fn createUnit(self: *Zone, pos: components.Vec2, radius: f32) !EntityId {
        return self.world.createUnit(pos, radius);
    }

    pub fn createProjectile(self: *Zone, pos: components.Vec2, vel: components.Vec2, radius: f32, owner: EntityId, damage: f32, lifetime: f32) !EntityId {
        return self.world.createProjectile(pos, vel, radius, owner, damage, lifetime);
    }

    pub fn createObstacle(self: *Zone, pos: components.Vec2, size: components.Vec2, is_deadly: bool) !EntityId {
        return self.world.createObstacle(pos, size, is_deadly);
    }

    pub fn createLifestone(self: *Zone, pos: components.Vec2, radius: f32, attuned: bool) !EntityId {
        return self.world.createLifestone(pos, radius, attuned);
    }

    pub fn createPortal(self: *Zone, pos: components.Vec2, radius: f32, destination_zone: u8) !EntityId {
        return self.world.createPortal(pos, radius, destination_zone);
    }

    // Delegate other methods to world
    pub fn destroyEntity(self: *Zone, entity: EntityId) !void {
        return self.world.destroyEntity(entity);
    }

    pub fn isAlive(self: *const Zone, entity: EntityId) bool {
        return self.world.isAlive(entity);
    }

    pub fn getPlayer(self: *Zone) ?EntityId {
        return self.world.getPlayer();
    }

    pub fn getTotalEntityCount(self: *const Zone) usize {
        return self.world.getTotalEntityCount();
    }
};

/// Entity with zone context for global iteration
pub const EntityWithZone = struct {
    entity: EntityId,
    zone_id: u32,
};

/// Global game container with zone management and global iterators
pub const Game = struct {
    zones: std.ArrayList(Zone),
    current_zone_id: u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Game {
        var game = Game{
            .zones = std.ArrayList(Zone).init(allocator),
            .current_zone_id = 0,
            .allocator = allocator,
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
                    .background_color = .{ .r = 32, .g = 32, .b = 32, .a = 255 },
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
                    .background_color = .{ .r = 16, .g = 64, .b = 16, .a = 255 },
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
                    .background_color = .{ .r = 16, .g = 8, .b = 32, .a = 255 },
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
                    .background_color = .{ .r = 64, .g = 32, .b = 64, .a = 255 },
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
    }

    /// Add a new zone
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
            // Return zone 0 as fallback
            return &self.zones.items[0];
        }
        return &self.zones.items[self.current_zone_id];
    }

    /// Get zone by ID
    pub fn getZone(self: *Game, zone_id: u32) ?*Zone {
        for (self.zones.items) |*zone| {
            if (zone.id == zone_id) return zone;
        }
        return null;
    }

    /// Get zone by ID (const)
    pub fn getZoneConst(self: *const Game, zone_id: u32) ?*const Zone {
        for (self.zones.items) |*zone| {
            if (zone.id == zone_id) return zone;
        }
        return null;
    }

    /// Switch to a different zone
    pub fn setCurrentZone(self: *Game, zone_id: u32) void {
        for (self.zones.items) |zone| {
            if (zone.id == zone_id) {
                self.current_zone_id = zone_id;
                break;
            }
        }
    }

    /// Get current zone ID
    pub fn getCurrentZoneId(self: *const Game) u32 {
        return self.current_zone_id;
    }

    /// Global iterator for all units across all zones
    pub fn iterateAllUnits(self: *Game) UnitIterator {
        return UnitIterator.init(self.zones.items);
    }

    /// Global iterator for all projectiles across all zones
    pub fn iterateAllProjectiles(self: *Game) ProjectileIterator {
        return ProjectileIterator.init(self.zones.items);
    }

    /// Global iterator for all entities of a specific archetype
    pub fn iterateArchetype(self: *Game, comptime archetype: World.ArchetypeType) ArchetypeIterator(archetype) {
        return ArchetypeIterator(archetype).init(self.zones.items);
    }

    /// Clear all projectiles from all zones
    pub fn clearAllProjectiles(self: *Game) !void {
        for (self.zones.items) |*zone| {
            var projectiles_to_destroy = std.ArrayList(EntityId).init(self.allocator);
            defer projectiles_to_destroy.deinit();

            var iter = zone.world.projectiles.entityIterator();
            while (iter.next()) |entity| {
                try projectiles_to_destroy.append(entity);
            }

            for (projectiles_to_destroy.items) |entity| {
                try zone.destroyEntity(entity);
            }
        }
    }

    /// Move an entity from one zone to another
    pub fn moveEntityToZone(self: *Game, entity: EntityId, new_zone_id: u32) !void {
        // Find the source zone containing the entity
        var source_zone_index: ?usize = null;
        for (self.zones.items, 0..) |*zone, i| {
            if (zone.world.isAlive(entity)) {
                source_zone_index = i;
                break;
            }
        }

        // If entity not found in any zone, do nothing
        const source_index = source_zone_index orelse return;
        
        // Find the destination zone
        var dest_zone_index: ?usize = null;
        for (self.zones.items, 0..) |zone, i| {
            if (zone.id == new_zone_id) {
                dest_zone_index = i;
                break;
            }
        }

        // If destination zone not found, do nothing
        const dest_index = dest_zone_index orelse return;
        
        // Don't move if already in the target zone
        if (source_index == dest_index) return;

        // For now, this is a placeholder that just destroys the entity
        // A full implementation would preserve the entity's components
        // and recreate it in the new zone, but that's complex for the current architecture
        try self.zones.items[source_index].destroyEntity(entity);
    }

    /// Get total entity count across all zones
    pub fn getTotalEntityCount(self: *const Game) usize {
        var total: usize = 0;
        for (self.zones.items) |zone| {
            total += zone.getTotalEntityCount();
        }
        return total;
    }

    // Global iterators for different entity types
    pub const UnitIterator = struct {
        zones: []Zone,
        zone_index: usize,
        current_iter: ?UnitArchetype.EntityIterator,

        pub fn init(zones: []Zone) UnitIterator {
            var iter = UnitIterator{
                .zones = zones,
                .zone_index = 0,
                .current_iter = null,
            };
            iter.findNextIterator();
            return iter;
        }

        pub fn next(self: *UnitIterator) ?EntityWithZone {
            while (self.current_iter) |*iter| {
                if (iter.next()) |entity| {
                    return EntityWithZone{
                        .entity = entity,
                        .zone_id = self.zones[self.zone_index].id,
                    };
                }
                
                // Current iterator exhausted, move to next zone
                self.zone_index += 1;
                self.findNextIterator();
            }
            return null;
        }

        fn findNextIterator(self: *UnitIterator) void {
            self.current_iter = null;
            while (self.zone_index < self.zones.len) {
                if (self.zones[self.zone_index].world.units.count() > 0) {
                    self.current_iter = self.zones[self.zone_index].world.units.entityIterator();
                    break;
                }
                self.zone_index += 1;
            }
        }
    };

    pub const ProjectileIterator = struct {
        zones: []Zone,
        zone_index: usize,
        current_iter: ?ProjectileArchetype.EntityIterator,

        pub fn init(zones: []Zone) ProjectileIterator {
            var iter = ProjectileIterator{
                .zones = zones,
                .zone_index = 0,
                .current_iter = null,
            };
            iter.findNextIterator();
            return iter;
        }

        pub fn next(self: *ProjectileIterator) ?EntityWithZone {
            while (self.current_iter) |*iter| {
                if (iter.next()) |entity| {
                    return EntityWithZone{
                        .entity = entity,
                        .zone_id = self.zones[self.zone_index].id,
                    };
                }
                
                self.zone_index += 1;
                self.findNextIterator();
            }
            return null;
        }

        fn findNextIterator(self: *ProjectileIterator) void {
            self.current_iter = null;
            while (self.zone_index < self.zones.len) {
                if (self.zones[self.zone_index].world.projectiles.count() > 0) {
                    self.current_iter = self.zones[self.zone_index].world.projectiles.entityIterator();
                    break;
                }
                self.zone_index += 1;
            }
        }
    };

    // Generic archetype iterator
    pub fn ArchetypeIterator(comptime archetype: World.ArchetypeType) type {
        return struct {
            const Self = @This();
            const ArchetypeType = switch (archetype) {
                .player => PlayerArchetype,
                .unit => UnitArchetype,
                .projectile => ProjectileArchetype,
                .obstacle => ObstacleArchetype,
                .lifestone => LifestoneArchetype,
                .portal => PortalArchetype,
            };

            zones: []Zone,
            zone_index: usize,
            current_iter: ?ArchetypeType.EntityIterator,

            pub fn init(zones: []Zone) Self {
                var iter = Self{
                    .zones = zones,
                    .zone_index = 0,
                    .current_iter = null,
                };
                iter.findNextIterator();
                return iter;
            }

            pub fn next(self: *Self) ?EntityWithZone {
                while (self.current_iter) |*iter| {
                    if (iter.next()) |entity| {
                        return EntityWithZone{
                            .entity = entity,
                            .zone_id = self.zones[self.zone_index].id,
                        };
                    }
                    
                    self.zone_index += 1;
                    self.findNextIterator();
                }
                return null;
            }

            fn findNextIterator(self: *Self) void {
                self.current_iter = null;
                while (self.zone_index < self.zones.len) {
                    const storage = switch (archetype) {
                        .player => &self.zones[self.zone_index].world.players,
                        .unit => &self.zones[self.zone_index].world.units,
                        .projectile => &self.zones[self.zone_index].world.projectiles,
                        .obstacle => &self.zones[self.zone_index].world.obstacles,
                        .lifestone => &self.zones[self.zone_index].world.lifestones,
                        .portal => &self.zones[self.zone_index].world.portals,
                    };
                    
                    if (storage.count() > 0) {
                        self.current_iter = storage.entityIterator();
                        break;
                    }
                    self.zone_index += 1;
                }
            }
        };
    }
};

test "world basic operations" {
    const testing = std.testing;

    var world = try World.init(testing.allocator, 100);
    defer world.deinit();

    // Create player
    const player = try world.createPlayer(.{ .x = 100, .y = 100 }, 16, 100, 0);
    try testing.expect(world.isAlive(player));
    try testing.expect(world.findEntityArchetype(player) == .player);

    // Create unit
    const unit = try world.createUnit(.{ .x = 200, .y = 200 }, 15);
    try testing.expect(world.isAlive(unit));
    try testing.expect(world.findEntityArchetype(unit) == .unit);

    // Test counts
    try testing.expect(world.players.count() == 1);
    try testing.expect(world.units.count() == 1);
    try testing.expect(world.getTotalEntityCount() == 2);

    // Destroy entities
    try world.destroyEntity(player);
    try world.destroyEntity(unit);
    try testing.expect(!world.isAlive(player));
    try testing.expect(!world.isAlive(unit));
    try testing.expect(world.getTotalEntityCount() == 0);
}

test "game with zones operations" {
    const testing = std.testing;

    var game = Game.init(testing.allocator);
    defer game.deinit();

    // Add zones
    try game.addZone(.{
        .id = 0,
        .metadata = .{
            .zone_type = .overworld,
            .camera_mode = .fixed,
            .camera_scale = 1.0,
            .spawn_pos = .{ .x = 400, .y = 300 },
            .background_color = .{ .r = 0, .g = 0, .b = 0, .a = 255 },
        },
        .max_entities = 100,
    });

    try game.addZone(.{
        .id = 1,
        .metadata = .{
            .zone_type = .dungeon_fire,
            .camera_mode = .follow,
            .camera_scale = 2.0,
            .spawn_pos = .{ .x = 200, .y = 200 },
            .background_color = .{ .r = 64, .g = 16, .b = 16, .a = 255 },
        },
        .max_entities = 100,
    });

    // Create entity in zone 0
    const zone0 = game.getZone(0).?;
    _ = try zone0.createPlayer(.{ .x = 100, .y = 100 }, 16, 100, 0);

    // Create unit in zone 1
    game.setCurrentZone(1);
    const zone1 = game.getCurrentZone();
    const unit = try zone1.createUnit(.{ .x = 200, .y = 200 }, 15);

    // Test global iteration
    var unit_iter = game.iterateAllUnits();
    var unit_count: usize = 0;
    while (unit_iter.next()) |entity_with_zone| {
        unit_count += 1;
        try testing.expect(entity_with_zone.zone_id == 1);
        try testing.expect(entity_with_zone.entity.eql(unit));
    }
    try testing.expect(unit_count == 1);

    // Check total entity count
    try testing.expect(game.getTotalEntityCount() == 2);
}