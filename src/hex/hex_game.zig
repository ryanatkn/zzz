const std = @import("std");
const math = @import("../lib/math/mod.zig");
const colors = @import("../lib/core/colors.zig");
const constants = @import("constants.zig");
const combat = @import("combat.zig");
const object_pools = @import("../lib/core/object_pools.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const BulletPool = combat.BulletPool;

// Logging setup
const Logger = @import("../lib/debug/logger.zig").Logger;
const outputs = @import("../lib/debug/outputs.zig");
const filters = @import("../lib/debug/filters.zig");

const ModuleLogger = Logger(.{
    .output = outputs.Console,
    .filter = filters.Throttle,
});

// Simplified entity and component system
pub const EntityId = u32;
const INVALID_ENTITY: EntityId = std.math.maxInt(u32);

// Direct component definitions - no ECS complexity
pub const Transform = extern struct {
    pos: Vec2,
    vel: Vec2,
    radius: f32,
    _padding: f32 = 0,

    pub fn init(pos: Vec2, radius: f32) Transform {
        return .{ .pos = pos, .vel = Vec2.ZERO, .radius = radius };
    }
};

pub const Health = struct {
    current: f32,
    max: f32,
    alive: bool,

    pub fn init(max_health: f32) Health {
        return .{ .current = max_health, .max = max_health, .alive = true };
    }
};

pub const Visual = struct {
    color: Color,
    scale: f32 = 1.0,
    visible: bool = true,

    pub fn init(color: Color) Visual {
        return .{ .color = color, .visible = true };
    }
};

/// Behavior profile types for hex units
pub const BehaviorProfile = enum {
    idle, // Default - basic aggro when player in range
    aggressive, // Chase-focused, minimal flee
    defensive, // Flee-focused, guard home
    patrolling, // Patrol routes, guard when threatened
    wandering, // Wander randomly, flee when threatened
    guardian, // Guard specific area, intercept threats
};

pub const Unit = struct {
    unit_type: UnitType,
    behavior_profile: BehaviorProfile = .idle, // Default to idle
    aggro_range: f32,
    aggro_factor: f32,
    home_pos: Vec2,
    target: ?EntityId,

    // AI behavior state
    state: UnitState,
    target_pos: Vec2,
    chase_timer: f32,

    pub const UnitType = enum { player, enemy, friendly, neutral };
    pub const UnitState = enum { returning_home, chasing, at_home };

    pub fn init(unit_type: UnitType, home_pos: Vec2, behavior: BehaviorProfile) Unit {
        return .{
            .unit_type = unit_type,
            .behavior_profile = behavior, // Store behavior from ZON
            .aggro_range = if (unit_type == .enemy) 150.0 else 0.0,
            .aggro_factor = 1.0,
            .home_pos = home_pos,
            .target = null,
            .state = .at_home,
            .target_pos = home_pos,
            .chase_timer = 0.0,
        };
    }
};

const PlayerInput = struct {
    controller_id: u8,

    pub fn init(controller_id: u8) PlayerInput {
        return .{ .controller_id = controller_id };
    }
};

const Projectile = struct {
    owner: EntityId,
    lifetime: f32,
    max_lifetime: f32,
    damage: f32,

    pub fn init(owner: EntityId, max_lifetime: f32, damage: f32) Projectile {
        return .{ .owner = owner, .lifetime = 0, .max_lifetime = max_lifetime, .damage = damage };
    }
};

const Terrain = struct {
    terrain_type: TerrainType,
    size: Vec2,
    solid: bool,

    pub const TerrainType = enum { wall, floor, door, water, pit, altar };

    pub fn init(terrain_type: TerrainType, size: Vec2) Terrain {
        return .{
            .terrain_type = terrain_type,
            .size = size,
            .solid = (terrain_type == .wall or terrain_type == .door),
        };
    }
};

const Interactable = struct {
    interaction_type: InteractionType,
    destination_zone: ?u8,
    attuned: bool,

    pub const InteractionType = enum { deflectable, telekinetic, transformable, combinable };

    pub fn init(interaction_type: InteractionType) Interactable {
        return .{
            .interaction_type = interaction_type,
            .destination_zone = null,
            .attuned = false,
        };
    }
};

// Simple fixed-size storage for each archetype
const PlayerStorage = struct {
    entities: [MAX_ENTITIES_PER_ARCHETYPE]EntityId,
    transforms: [MAX_ENTITIES_PER_ARCHETYPE]Transform,
    healths: [MAX_ENTITIES_PER_ARCHETYPE]Health,
    player_inputs: [MAX_ENTITIES_PER_ARCHETYPE]PlayerInput,
    visuals: [MAX_ENTITIES_PER_ARCHETYPE]Visual,
    count: usize,

    pub fn init() PlayerStorage {
        return .{
            .entities = [_]EntityId{INVALID_ENTITY} ** MAX_ENTITIES_PER_ARCHETYPE,
            .transforms = undefined,
            .healths = undefined,
            .player_inputs = undefined,
            .visuals = undefined,
            .count = 0,
        };
    }

    pub fn addEntity(self: *PlayerStorage, entity: EntityId, transform: Transform, health: Health, player_input: PlayerInput, visual: Visual) !void {
        if (self.count >= MAX_ENTITIES_PER_ARCHETYPE) return error.StorageFull;
        const index = self.count;
        self.entities[index] = entity;
        self.transforms[index] = transform;
        self.healths[index] = health;
        self.player_inputs[index] = player_input;
        self.visuals[index] = visual;
        self.count += 1;
    }

    pub fn removeEntity(self: *PlayerStorage, entity: EntityId) void {
        for (0..self.count) |i| {
            if (self.entities[i] == entity) {
                // Swap remove
                const last = self.count - 1;
                self.entities[i] = self.entities[last];
                self.transforms[i] = self.transforms[last];
                self.healths[i] = self.healths[last];
                self.player_inputs[i] = self.player_inputs[last];
                self.visuals[i] = self.visuals[last];
                self.count -= 1;
                return;
            }
        }
    }

    pub fn getTransformMut(self: *PlayerStorage, entity: EntityId) ?*Transform {
        for (0..self.count) |i| {
            if (self.entities[i] == entity) return &self.transforms[i];
        }
        return null;
    }

    pub fn getHealthMut(self: *PlayerStorage, entity: EntityId) ?*Health {
        for (0..self.count) |i| {
            if (self.entities[i] == entity) return &self.healths[i];
        }
        return null;
    }

    pub fn getVisualMut(self: *PlayerStorage, entity: EntityId) ?*Visual {
        for (0..self.count) |i| {
            if (self.entities[i] == entity) return &self.visuals[i];
        }
        return null;
    }

    pub fn getTransform(self: *const PlayerStorage, entity: EntityId) ?*const Transform {
        for (0..self.count) |i| {
            if (self.entities[i] == entity) return &self.transforms[i];
        }
        return null;
    }

    pub fn getHealth(self: *const PlayerStorage, entity: EntityId) ?*const Health {
        for (0..self.count) |i| {
            if (self.entities[i] == entity) return &self.healths[i];
        }
        return null;
    }

    pub fn entityIterator(self: *const PlayerStorage) EntityIterator {
        return EntityIterator{ .entities = self.entities[0..self.count], .index = 0 };
    }

    pub fn clear(self: *PlayerStorage) void {
        self.count = 0;
    }

    pub fn containsEntity(self: *const PlayerStorage, entity_id: EntityId) bool {
        for (0..self.count) |i| {
            if (self.entities[i] == entity_id) return true;
        }
        return false;
    }
};

const UnitStorage = struct {
    entities: [MAX_ENTITIES_PER_ARCHETYPE]EntityId,
    transforms: [MAX_ENTITIES_PER_ARCHETYPE]Transform,
    healths: [MAX_ENTITIES_PER_ARCHETYPE]Health,
    units: [MAX_ENTITIES_PER_ARCHETYPE]Unit,
    visuals: [MAX_ENTITIES_PER_ARCHETYPE]Visual,
    count: usize,

    pub fn init() UnitStorage {
        return .{
            .entities = [_]EntityId{INVALID_ENTITY} ** MAX_ENTITIES_PER_ARCHETYPE,
            .transforms = undefined,
            .healths = undefined,
            .units = undefined,
            .visuals = undefined,
            .count = 0,
        };
    }

    pub fn addEntity(self: *UnitStorage, entity: EntityId, transform: Transform, health: Health, unit: Unit, visual: Visual) !void {
        if (self.count >= MAX_ENTITIES_PER_ARCHETYPE) return error.StorageFull;
        const index = self.count;
        self.entities[index] = entity;
        self.transforms[index] = transform;
        self.healths[index] = health;
        self.units[index] = unit;
        self.visuals[index] = visual;
        self.count += 1;
    }

    pub fn removeEntity(self: *UnitStorage, entity: EntityId) void {
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

    pub fn entityIterator(self: *const UnitStorage) EntityIterator {
        return EntityIterator{ .entities = self.entities[0..self.count], .index = 0 };
    }

    pub fn clear(self: *UnitStorage) void {
        self.count = 0;
    }

    pub fn containsEntity(self: *const UnitStorage, entity_id: EntityId) bool {
        for (0..self.count) |i| {
            if (self.entities[i] == entity_id) return true;
        }
        return false;
    }

    pub fn getComponentMut(self: *UnitStorage, entity_id: EntityId, comptime component_type: enum { transform, health, unit, visual }) ?*(switch (component_type) {
        .transform => Transform,
        .health => Health,
        .unit => Unit,
        .visual => Visual,
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

    pub fn getComponent(self: *const UnitStorage, entity_id: EntityId, comptime component_type: enum { transform, health, unit, visual }) ?*const (switch (component_type) {
        .transform => Transform,
        .health => Health,
        .unit => Unit,
        .visual => Visual,
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
};

const ProjectileStorage = struct {
    entities: [MAX_ENTITIES_PER_ARCHETYPE]EntityId,
    transforms: [MAX_ENTITIES_PER_ARCHETYPE]Transform,
    projectiles: [MAX_ENTITIES_PER_ARCHETYPE]Projectile,
    visuals: [MAX_ENTITIES_PER_ARCHETYPE]Visual,
    count: usize,

    pub fn init() ProjectileStorage {
        return .{
            .entities = [_]EntityId{INVALID_ENTITY} ** MAX_ENTITIES_PER_ARCHETYPE,
            .transforms = undefined,
            .projectiles = undefined,
            .visuals = undefined,
            .count = 0,
        };
    }

    pub fn addEntity(self: *ProjectileStorage, entity: EntityId, transform: Transform, projectile: Projectile, visual: Visual) !void {
        if (self.count >= MAX_ENTITIES_PER_ARCHETYPE) return error.StorageFull;
        const index = self.count;
        self.entities[index] = entity;
        self.transforms[index] = transform;
        self.projectiles[index] = projectile;
        self.visuals[index] = visual;
        self.count += 1;
    }

    pub fn removeEntity(self: *ProjectileStorage, entity: EntityId) void {
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

    pub fn entityIterator(self: *const ProjectileStorage) EntityIterator {
        return EntityIterator{ .entities = self.entities[0..self.count], .index = 0 };
    }

    pub fn clear(self: *ProjectileStorage) void {
        self.count = 0;
    }

    pub fn containsEntity(self: *const ProjectileStorage, entity_id: EntityId) bool {
        for (0..self.count) |i| {
            if (self.entities[i] == entity_id) return true;
        }
        return false;
    }

    pub fn getComponentMut(self: *ProjectileStorage, entity_id: EntityId, comptime component_type: enum { transform, projectile, visual }) ?*(switch (component_type) {
        .transform => Transform,
        .projectile => Projectile,
        .visual => Visual,
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

    pub fn getComponent(self: *const ProjectileStorage, entity_id: EntityId, comptime component_type: enum { transform, projectile, visual }) ?*const (switch (component_type) {
        .transform => Transform,
        .projectile => Projectile,
        .visual => Visual,
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
};

const ObstacleStorage = struct {
    entities: [MAX_ENTITIES_PER_ARCHETYPE]EntityId,
    transforms: [MAX_ENTITIES_PER_ARCHETYPE]Transform,
    terrains: [MAX_ENTITIES_PER_ARCHETYPE]Terrain,
    visuals: [MAX_ENTITIES_PER_ARCHETYPE]Visual,
    count: usize,

    pub fn init() ObstacleStorage {
        return .{
            .entities = [_]EntityId{INVALID_ENTITY} ** MAX_ENTITIES_PER_ARCHETYPE,
            .transforms = undefined,
            .terrains = undefined,
            .visuals = undefined,
            .count = 0,
        };
    }

    pub fn addEntity(self: *ObstacleStorage, entity: EntityId, transform: Transform, terrain: Terrain, visual: Visual) !void {
        if (self.count >= MAX_ENTITIES_PER_ARCHETYPE) return error.StorageFull;
        const index = self.count;
        self.entities[index] = entity;
        self.transforms[index] = transform;
        self.terrains[index] = terrain;
        self.visuals[index] = visual;
        self.count += 1;
    }

    pub fn removeEntity(self: *ObstacleStorage, entity: EntityId) void {
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

    pub fn entityIterator(self: *const ObstacleStorage) EntityIterator {
        return EntityIterator{ .entities = self.entities[0..self.count], .index = 0 };
    }

    pub fn clear(self: *ObstacleStorage) void {
        self.count = 0;
    }

    pub fn containsEntity(self: *const ObstacleStorage, entity_id: EntityId) bool {
        for (0..self.count) |i| {
            if (self.entities[i] == entity_id) return true;
        }
        return false;
    }

    pub fn getComponent(self: *const ObstacleStorage, entity_id: EntityId, comptime component_type: enum { transform, terrain, visual }) ?*const (switch (component_type) {
        .transform => Transform,
        .terrain => Terrain,
        .visual => Visual,
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
};

const LifestoneStorage = struct {
    entities: [MAX_ENTITIES_PER_ARCHETYPE]EntityId,
    transforms: [MAX_ENTITIES_PER_ARCHETYPE]Transform,
    visuals: [MAX_ENTITIES_PER_ARCHETYPE]Visual,
    terrains: [MAX_ENTITIES_PER_ARCHETYPE]Terrain,
    interactables: [MAX_ENTITIES_PER_ARCHETYPE]Interactable,
    count: usize,

    pub fn init() LifestoneStorage {
        return .{
            .entities = [_]EntityId{INVALID_ENTITY} ** MAX_ENTITIES_PER_ARCHETYPE,
            .transforms = undefined,
            .visuals = undefined,
            .terrains = undefined,
            .interactables = undefined,
            .count = 0,
        };
    }

    pub fn addEntity(self: *LifestoneStorage, entity: EntityId, transform: Transform, visual: Visual, terrain: Terrain, interactable: Interactable) !void {
        if (self.count >= MAX_ENTITIES_PER_ARCHETYPE) return error.StorageFull;
        const index = self.count;
        self.entities[index] = entity;
        self.transforms[index] = transform;
        self.visuals[index] = visual;
        self.terrains[index] = terrain;
        self.interactables[index] = interactable;
        self.count += 1;
    }

    pub fn removeEntity(self: *LifestoneStorage, entity: EntityId) void {
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

    pub fn entityIterator(self: *const LifestoneStorage) EntityIterator {
        return EntityIterator{ .entities = self.entities[0..self.count], .index = 0 };
    }

    pub fn clear(self: *LifestoneStorage) void {
        self.count = 0;
    }

    pub fn containsEntity(self: *const LifestoneStorage, entity_id: EntityId) bool {
        for (0..self.count) |i| {
            if (self.entities[i] == entity_id) return true;
        }
        return false;
    }

    pub fn getComponent(self: *const LifestoneStorage, entity_id: EntityId, comptime component_type: enum { transform, visual, terrain, interactable }) ?*const (switch (component_type) {
        .transform => Transform,
        .visual => Visual,
        .terrain => Terrain,
        .interactable => Interactable,
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

    pub fn getComponentMut(self: *LifestoneStorage, entity_id: EntityId, comptime component_type: enum { transform, visual, terrain, interactable }) ?*(switch (component_type) {
        .transform => Transform,
        .visual => Visual,
        .terrain => Terrain,
        .interactable => Interactable,
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
};

const PortalStorage = struct {
    entities: [MAX_ENTITIES_PER_ARCHETYPE]EntityId,
    transforms: [MAX_ENTITIES_PER_ARCHETYPE]Transform,
    visuals: [MAX_ENTITIES_PER_ARCHETYPE]Visual,
    terrains: [MAX_ENTITIES_PER_ARCHETYPE]Terrain,
    interactables: [MAX_ENTITIES_PER_ARCHETYPE]Interactable,
    count: usize,

    pub fn init() PortalStorage {
        return .{
            .entities = [_]EntityId{INVALID_ENTITY} ** MAX_ENTITIES_PER_ARCHETYPE,
            .transforms = undefined,
            .visuals = undefined,
            .terrains = undefined,
            .interactables = undefined,
            .count = 0,
        };
    }

    pub fn addEntity(self: *PortalStorage, entity: EntityId, transform: Transform, visual: Visual, terrain: Terrain, interactable: Interactable) !void {
        if (self.count >= MAX_ENTITIES_PER_ARCHETYPE) return error.StorageFull;
        const index = self.count;
        self.entities[index] = entity;
        self.transforms[index] = transform;
        self.visuals[index] = visual;
        self.terrains[index] = terrain;
        self.interactables[index] = interactable;
        self.count += 1;
    }

    pub fn removeEntity(self: *PortalStorage, entity: EntityId) void {
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

    pub fn entityIterator(self: *const PortalStorage) EntityIterator {
        return EntityIterator{ .entities = self.entities[0..self.count], .index = 0 };
    }

    pub fn clear(self: *PortalStorage) void {
        self.count = 0;
    }

    pub fn containsEntity(self: *const PortalStorage, entity_id: EntityId) bool {
        for (0..self.count) |i| {
            if (self.entities[i] == entity_id) return true;
        }
        return false;
    }

    pub fn getComponent(self: *const PortalStorage, entity_id: EntityId, comptime component_type: enum { transform, visual, terrain, interactable }) ?*const (switch (component_type) {
        .transform => Transform,
        .visual => Visual,
        .terrain => Terrain,
        .interactable => Interactable,
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
};

// Simple entity iterator
const EntityIterator = struct {
    entities: []const EntityId,
    index: usize,

    pub fn next(self: *EntityIterator) ?EntityId {
        if (self.index >= self.entities.len) return null;
        const entity = self.entities[self.index];
        self.index += 1;
        return entity;
    }
};

// Portal iterator removed - using EntityIterator instead

pub const MAX_ZONES = 7;
pub const MAX_ENTITIES_PER_ARCHETYPE = 256;

// Simple entity allocator
const EntityAllocator = struct {
    next_id: EntityId = 1, // Start from 1, 0 is invalid

    pub fn create(self: *EntityAllocator) EntityId {
        const id = self.next_id;
        self.next_id += 1;
        return id;
    }
};

/// Simplified hex game structure with direct zone access
pub const HexGame = struct {
    // Direct zone storage - no intermediate layers
    zones: [MAX_ZONES]ZoneData,
    current_zone: u8,

    // Player tracking
    player_entity: ?EntityId,
    player_zone: u8,
    player_start_pos: Vec2,

    // Game systems
    bullet_pool: BulletPool,
    entity_allocator: EntityAllocator,
    allocator: std.mem.Allocator,
    logger: ModuleLogger,
    frame_pool: object_pools.FramePool,

    pub const ZoneData = struct {
        // Direct fixed-size archetype storage - no dynamic allocation
        players: PlayerStorage,
        units: UnitStorage,
        projectiles: ProjectileStorage,
        obstacles: ObstacleStorage,
        lifestones: LifestoneStorage,
        portals: PortalStorage,

        // Zone metadata
        zone_type: ZoneType,
        camera_mode: constants.CameraMode,
        camera_scale: f32,
        spawn_pos: Vec2,
        background_color: Color,

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
                .players = PlayerStorage.init(),
                .units = UnitStorage.init(),
                .projectiles = ProjectileStorage.init(),
                .obstacles = ObstacleStorage.init(),
                .lifestones = LifestoneStorage.init(),
                .portals = PortalStorage.init(),
                .zone_type = zone_type,
                .camera_mode = switch (zone_type) {
                    .overworld => .fixed,
                    else => .follow,
                },
                .camera_scale = switch (zone_type) {
                    .overworld => 1.0,
                    else => 2.0,
                },
                .spawn_pos = Vec2{ .x = 400, .y = 300 },
                .background_color = getZoneBackgroundColor(zone_type),
                .entity_count = 0,
            };
        }

        pub fn deinit(self: *ZoneData) void {
            // No cleanup needed for fixed arrays
            _ = self;
        }

        /// Check if an entity is alive by searching through all storage types
        pub fn isAlive(self: *const ZoneData, entity_id: EntityId) bool {
            // Check each storage type to see if entity exists and is alive
            if (self.players.containsEntity(entity_id)) return true;
            if (self.units.containsEntity(entity_id)) return true;
            if (self.projectiles.containsEntity(entity_id)) return true;
            if (self.obstacles.containsEntity(entity_id)) return true;
            if (self.lifestones.containsEntity(entity_id)) return true;
            if (self.portals.containsEntity(entity_id)) return true;
            return false;
        }

        fn getZoneBackgroundColor(zone_type: ZoneType) Color {
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

    pub fn init(allocator: std.mem.Allocator) HexGame {
        var game = HexGame{
            .zones = undefined,
            .current_zone = 0,
            .player_entity = null,
            .player_zone = 0,
            .player_start_pos = Vec2{ .x = constants.SCREEN_CENTER_X, .y = constants.SCREEN_CENTER_Y },
            .bullet_pool = BulletPool.init(),
            .entity_allocator = EntityAllocator{},
            .allocator = allocator,
            .logger = ModuleLogger.init(allocator),
            .frame_pool = object_pools.FramePool.init(allocator),
        };

        // Initialize all zones
        const zone_types = [_]ZoneData.ZoneType{
            .overworld,
            .dungeon_fire,
            .dungeon_ice,
            .dungeon_storm,
            .dungeon_nature,
            .dungeon_shadow,
            .dungeon_arcane,
        };

        for (&game.zones, zone_types) |*zone, zone_type| {
            zone.* = ZoneData.init(zone_type);
        }

        return game;
    }

    pub fn deinit(self: *HexGame) void {
        for (&self.zones) |*zone| {
            zone.deinit();
        }
        self.frame_pool.deinit();
        self.logger.deinit();
    }

    // Direct zone access - no abstraction layers
    pub fn getCurrentZone(self: *HexGame) *ZoneData {
        std.debug.assert(self.current_zone < MAX_ZONES);
        return &self.zones[self.current_zone];
    }

    pub fn getCurrentZoneConst(self: *const HexGame) *const ZoneData {
        std.debug.assert(self.current_zone < MAX_ZONES);
        return &self.zones[self.current_zone];
    }

    pub fn getZone(self: *HexGame, zone_index: u8) ?*ZoneData {
        if (zone_index >= MAX_ZONES) return null;
        return &self.zones[zone_index];
    }

    pub fn setCurrentZone(self: *HexGame, zone_index: u8) void {
        if (zone_index >= MAX_ZONES) {
            self.logger.err("zone_invalid", "setCurrentZone: Invalid zone_index {}", .{zone_index});
            return;
        }
        self.current_zone = zone_index;
        self.logger.debug("zone_switched", "Zone switched to: {}", .{zone_index});
    }

    pub fn getCurrentZoneIndex(self: *const HexGame) u8 {
        return self.current_zone;
    }

    // Compatibility methods for effects system
    pub fn getZoneStorageConst(self: *const HexGame) *const ZoneData {
        return self.getCurrentZoneConst();
    }

    // iteratePortalsInCurrentZone moved to use EntityIterator below

    // Entity creation methods
    pub fn createLifestone(self: *HexGame, zone_index: u8, pos: Vec2, radius: f32, attuned: bool) !EntityId {
        if (zone_index >= MAX_ZONES) return error.InvalidZone;

        const zone = &self.zones[zone_index];
        const entity = self.entity_allocator.create();

        // Determine color based on attunement
        const color = if (attuned)
            constants.COLOR_LIFESTONE_ATTUNED
        else
            constants.COLOR_LIFESTONE_UNATTUNED;

        // Create lifestone with explicit attunement
        const transform = Transform.init(pos, radius);
        const visual = Visual.init(color);
        const terrain = Terrain.init(.altar, Vec2{ .x = radius * 2, .y = radius * 2 });
        var interactable = Interactable.init(.transformable);
        interactable.attuned = attuned;

        try zone.lifestones.addEntity(entity, transform, visual, terrain, interactable);
        zone.entity_count += 1;

        self.logger.debug("lifestone_created", "Created lifestone in zone {} at {any}, attuned: {}", .{ zone_index, pos, attuned });

        return entity;
    }

    pub fn createUnit(self: *HexGame, zone_index: u8, pos: Vec2, radius: f32, behavior: BehaviorProfile) !EntityId {
        if (zone_index >= MAX_ZONES) return error.InvalidZone;

        const zone = &self.zones[zone_index];
        const entity = self.entity_allocator.create();

        const transform = Transform.init(pos, radius);
        const health = Health.init(50);
        const unit = Unit.init(.enemy, pos, behavior); // Use provided behavior
        const visual = Visual.init(constants.COLOR_UNIT_DEFAULT);

        try zone.units.addEntity(entity, transform, health, unit, visual);
        zone.entity_count += 1;

        return entity;
    }

    pub fn createObstacle(self: *HexGame, zone_index: u8, pos: Vec2, size: Vec2, is_deadly: bool) !EntityId {
        if (zone_index >= MAX_ZONES) return error.InvalidZone;

        const zone = &self.zones[zone_index];
        const entity = self.entity_allocator.create();

        const terrain_type: Terrain.TerrainType = if (is_deadly) .pit else .wall;
        const color = if (is_deadly) constants.COLOR_OBSTACLE_DEADLY else constants.COLOR_OBSTACLE_BLOCKING;

        const transform = Transform.init(pos, 0);
        const terrain = Terrain.init(terrain_type, size);
        const visual = Visual.init(color);

        try zone.obstacles.addEntity(entity, transform, terrain, visual);
        zone.entity_count += 1;

        return entity;
    }

    pub fn createPortal(self: *HexGame, zone_index: u8, pos: Vec2, radius: f32, destination: u8) !EntityId {
        if (zone_index >= MAX_ZONES) return error.InvalidZone;

        const zone = &self.zones[zone_index];
        const entity = self.entity_allocator.create();

        const transform = Transform.init(pos, radius);
        const visual = Visual.init(constants.COLOR_PORTAL);
        const terrain = Terrain.init(.altar, Vec2{ .x = radius * 2, .y = radius * 2 });
        var interactable = Interactable.init(.transformable);
        interactable.destination_zone = destination;

        try zone.portals.addEntity(entity, transform, visual, terrain, interactable);
        zone.entity_count += 1;

        return entity;
    }

    pub fn createPlayer(self: *HexGame, pos: Vec2, radius: f32) !EntityId {
        const zone = self.getCurrentZone();
        const entity = self.entity_allocator.create();

        const transform = Transform.init(pos, radius);
        const health = Health.init(100);
        const player_input = PlayerInput.init(0);
        const visual = Visual.init(constants.COLOR_PLAYER_ALIVE);

        try zone.players.addEntity(entity, transform, health, player_input, visual);
        zone.entity_count += 1;

        self.player_entity = entity;
        self.player_zone = self.current_zone;
        self.player_start_pos = pos;

        return entity;
    }

    pub fn createProjectile(self: *HexGame, zone_index: u8, pos: Vec2, radius: f32, velocity: Vec2, lifetime: f32) !EntityId {
        if (zone_index >= MAX_ZONES) return error.InvalidZone;

        const zone = &self.zones[zone_index];
        const entity = self.entity_allocator.create();

        var transform = Transform.init(pos, radius);
        transform.vel = velocity;
        const projectile = Projectile.init(entity, lifetime, constants.BULLET_DAMAGE);
        const visual = Visual.init(constants.COLOR_BULLET);

        try zone.projectiles.addEntity(entity, transform, projectile, visual);
        zone.entity_count += 1;

        return entity;
    }

    // Zone travel
    pub fn travelToZone(self: *HexGame, zone_index: u8, spawn_pos: Vec2) !void {
        if (zone_index >= MAX_ZONES) return;

        // Clear projectiles in all zones (bullets should not persist across zone travel)
        for (&self.zones) |*zone| {
            zone.projectiles.clear();
        }

        // Move player if exists
        if (self.player_entity) |player_entity| {
            if (self.player_zone != zone_index) {
                // Perform actual entity transfer between zones
                try self.transferPlayerToZone(player_entity, self.player_zone, zone_index, spawn_pos);
                self.player_zone = zone_index;

                self.logger.info("player_travel", "Player traveled from zone {} to zone {}", .{ self.current_zone, zone_index });
            }
        }

        self.setCurrentZone(zone_index);

        // Update player position in new zone if no transfer was needed
        if (self.player_entity) |player| {
            if (self.player_zone == zone_index) {
                const zone = self.getCurrentZone();
                if (zone.players.getTransformMut(player)) |transform| {
                    transform.pos = spawn_pos;
                    transform.vel = Vec2.ZERO;
                }
            }
        }
    }

    // Helper method for proper entity transfer between zones
    fn transferPlayerToZone(self: *HexGame, player_entity: EntityId, source_zone: u8, dest_zone: u8, new_pos: Vec2) !void {
        if (source_zone >= MAX_ZONES or dest_zone >= MAX_ZONES) return;

        const source = &self.zones[source_zone];
        const dest = &self.zones[dest_zone];

        // Extract player components from source zone
        const transform = source.players.getTransform(player_entity);
        const health = source.players.getHealth(player_entity);
        const visual = source.players.getVisualMut(player_entity); // We need mutable to copy

        if (transform == null or health == null or visual == null) {
            self.logger.err("transfer_failed", "transferPlayerToZone: Player entity missing required components", .{});
            return;
        }

        // Create new player data with updated position
        const new_transform = Transform.init(new_pos, transform.?.radius);
        const new_health = health.?.*;
        const player_input = PlayerInput.init(0); // Reset input state
        const new_visual = visual.?.*;

        // Remove from source zone
        source.players.removeEntity(player_entity);
        source.entity_count -%= 1;

        // Add to destination zone
        try dest.players.addEntity(player_entity, new_transform, new_health, player_input, new_visual);
        dest.entity_count += 1;

        self.logger.debug("player_transferred", "Player entity {} transferred from zone {} to zone {}", .{ player_entity, source_zone, dest_zone });
    }

    // Player accessors
    pub fn getPlayerPos(self: *const HexGame) Vec2 {
        if (self.player_entity) |player| {
            if (self.player_zone == self.current_zone) {
                const zone = self.getCurrentZoneConst();
                if (zone.players.getTransform(player)) |transform| {
                    return transform.pos;
                }
            }
        }
        return Vec2.ZERO;
    }

    pub fn getPlayerRadius(self: *const HexGame) f32 {
        if (self.player_entity) |player| {
            if (self.player_zone == self.current_zone) {
                const zone = self.getCurrentZoneConst();
                if (zone.players.getTransform(player)) |transform| {
                    return transform.radius;
                }
            }
        }
        return constants.PLAYER_RADIUS;
    }

    pub fn getPlayerAlive(self: *const HexGame) bool {
        if (self.player_entity) |player| {
            if (self.player_zone == self.current_zone) {
                const zone = self.getCurrentZoneConst();
                if (zone.players.getHealth(player)) |health| {
                    return health.alive;
                }
            }
        }
        return false;
    }

    pub fn getPlayer(self: *const HexGame) ?EntityId {
        if (self.player_entity) |player| {
            if (self.player_zone == self.current_zone) {
                return player;
            }
        }
        return null;
    }

    pub fn setPlayerPos(self: *HexGame, pos: Vec2) void {
        if (self.player_entity) |player| {
            if (self.player_zone == self.current_zone) {
                const zone = self.getCurrentZone();
                if (zone.players.getTransformMut(player)) |transform| {
                    transform.pos = pos;
                }
            }
        }
    }

    pub fn setPlayerVel(self: *HexGame, vel: Vec2) void {
        if (self.player_entity) |player| {
            if (self.player_zone == self.current_zone) {
                const zone = self.getCurrentZone();
                if (zone.players.getTransformMut(player)) |transform| {
                    transform.vel = vel;
                }
            }
        }
    }

    pub fn getPlayerVelConst(self: *const HexGame) Vec2 {
        if (self.player_entity) |player| {
            if (self.player_zone == self.current_zone) {
                const zone = &self.zones[self.current_zone];
                if (zone.players.getTransformConst(player)) |transform| {
                    return transform.vel;
                }
            }
        }
        return Vec2.ZERO;
    }

    pub fn setPlayerAlive(self: *HexGame, alive: bool) void {
        if (self.player_entity) |player| {
            if (self.player_zone == self.current_zone) {
                const zone = self.getCurrentZone();
                if (zone.players.getHealthMut(player)) |health| {
                    health.alive = alive;
                    if (alive) {
                        health.current = health.max;
                    }
                }
                if (zone.players.getVisualMut(player)) |visual| {
                    visual.color = if (alive)
                        constants.COLOR_PLAYER_ALIVE
                    else
                        constants.COLOR_DEAD;
                }
            }
        }
    }

    pub fn setPlayerColor(self: *HexGame, color: Color) void {
        if (self.player_entity) |player| {
            if (self.player_zone == self.current_zone) {
                const zone = self.getCurrentZone();
                if (zone.players.getVisualMut(player)) |visual| {
                    visual.color = color;
                }
            }
        }
    }

    pub fn canFireBullet(self: *const HexGame) bool {
        return self.bullet_pool.canFire();
    }

    pub fn updateProjectiles(self: *HexGame, deltaTime: f32) !void {
        const zone = self.getCurrentZone();

        // Use frame pool for temporary allocation - no frame-by-frame heap allocation
        const frame_allocator = self.frame_pool.allocator();
        var projectiles_to_remove = std.ArrayList(EntityId).init(frame_allocator);

        // Update projectile positions and check collisions using ECS iteration
        var projectile_iter = zone.projectiles.entityIterator();
        while (projectile_iter.next()) |projectile_id| {
            // Get components
            if (zone.projectiles.getComponentMut(projectile_id, .transform)) |transform| {
                if (zone.projectiles.getComponentMut(projectile_id, .projectile)) |projectile| {
                    // Update position
                    transform.pos = transform.pos.add(transform.vel.scale(deltaTime));

                    // Update lifetime
                    projectile.lifetime += deltaTime;

                    // Check if projectile expired
                    if (projectile.lifetime >= projectile.max_lifetime) {
                        try projectiles_to_remove.append(projectile_id);
                        continue;
                    }

                    // Check collision with units using ECS iteration
                    var unit_iter = zone.units.entityIterator();
                    while (unit_iter.next()) |unit_id| {
                        if (zone.units.getComponentMut(unit_id, .transform)) |unit_transform| {
                            if (zone.units.getComponentMut(unit_id, .health)) |unit_health| {
                                if (!unit_health.alive) continue;

                                const dist_sq = transform.pos.sub(unit_transform.pos).lengthSquared();
                                const collision_dist = transform.radius + unit_transform.radius;

                                if (dist_sq <= collision_dist * collision_dist) {
                                    // Unit hit by bullet
                                    unit_health.alive = false;

                                    // Update unit visual color
                                    if (zone.units.getComponentMut(unit_id, .visual)) |unit_visual| {
                                        unit_visual.color = constants.COLOR_DEAD;
                                    }

                                    // Remove projectile
                                    try projectiles_to_remove.append(projectile_id);
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }

        // Remove expired/hit projectiles
        for (projectiles_to_remove.items) |projectile_id| {
            zone.projectiles.removeEntity(projectile_id);
            zone.entity_count -= 1;
        }
    }

    pub fn getZoneStorage(self: *HexGame) *ZoneData {
        return self.getCurrentZone();
    }

    /// Iterator for units in current zone
    pub fn iterateUnitsInCurrentZone(self: *HexGame) EntityIterator {
        return self.getCurrentZone().units.entityIterator();
    }

    /// Iterator for lifestones in current zone
    pub fn iterateLifestonesInCurrentZone(self: *HexGame) EntityIterator {
        return self.getCurrentZone().lifestones.entityIterator();
    }

    /// Iterator for portals in current zone
    pub fn iteratePortalsInCurrentZone(self: *HexGame) EntityIterator {
        return self.getCurrentZone().portals.entityIterator();
    }

    /// Iterator for obstacles in current zone
    pub fn iterateObstaclesInCurrentZone(self: *HexGame) EntityIterator {
        return self.getCurrentZone().obstacles.entityIterator();
    }

    pub fn updateBulletPool(self: *HexGame, deltaTime: f32) void {
        self.bullet_pool.update(deltaTime);
    }

    // Debug helpers
    pub fn debugLogZoneEntities(self: *HexGame, zone_index: u8) void {
        if (zone_index >= MAX_ZONES) return;

        const zone = &self.zones[zone_index];
        var count: usize = 0;

        // Count lifestones
        var lifestone_iter = zone.lifestones.entityIterator();
        while (lifestone_iter.next()) |_| {
            count += 1;
        }
        self.logger.debug("zone_lifestones", "Zone {}: {} lifestones", .{ zone_index, count });

        // Count units
        count = 0;
        var unit_iter = zone.units.entityIterator();
        while (unit_iter.next()) |_| {
            count += 1;
        }
        self.logger.debug("zone_units", "Zone {}: {} units", .{ zone_index, count });

        // Count portals
        count = 0;
        var portal_iter = zone.portals.entityIterator();
        while (portal_iter.next()) |_| {
            count += 1;
        }
        self.logger.debug("zone_portals", "Zone {}: {} portals", .{ zone_index, count });

        self.logger.debug("zone_entities", "Zone {}: {} total entities", .{ zone_index, zone.entity_count });
    }
};
