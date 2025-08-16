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
        // Players need enough slots for entity IDs that may be allocated after other entities
        const player_capacity = @max(100, entities_per_archetype);

        return World{
            .entities = try EntityAllocator.init(allocator, max_entities),
            .players = try PlayerArchetype.init(allocator, player_capacity), // Sufficient capacity for zone transitions
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
        health: f32,
    ) !EntityId {
        const entity = try self.createEntity();
        errdefer self.destroyEntity(entity) catch {};

        const required_data = UnitArchetype.RequiredComponentData{
            .transform = components.Transform.init(pos, radius),
            .health = components.Health.init(health),
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
        damage: f32,
        owner: EntityId,
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

        // Create visual component with proper lifestone color - same shade of blue, darker base
        const base_blue = colors.Color{ .r = 0, .g = 80, .b = 160, .a = 255 }; // Darker blue for both states
        const color = base_blue; // Same color for both attuned and unattuned - effect system handles glow

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