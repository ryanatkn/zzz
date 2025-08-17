const std = @import("std");

// Core capabilities
const math = @import("../lib/math/mod.zig");
const colors = @import("../lib/core/colors.zig");
const frame = @import("../lib/core/frame.zig");
const object_pools = @import("../lib/core/object_pools.zig");

// Game system capabilities
const components = @import("../lib/game/components.zig");
const zones = @import("../lib/game/zones/mod.zig");
const storage = @import("../lib/game/storage/mod.zig");
const world = @import("../lib/game/world/mod.zig");
const GameEffectSystem = @import("../lib/effects/game_effects.zig").GameEffectSystem;

// Debug capabilities
const loggers = @import("../lib/debug/loggers.zig");

// Hex game modules
const constants = @import("constants.zig");
const combat = @import("combat.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const BulletPool = combat.BulletPool;
const FrameContext = frame.FrameContext;
const EntityIterator = storage.EntityIterator;

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

// Use components from lib/game/components.zig
pub const Transform = components.Transform;
pub const Health = components.Health;
pub const Visual = components.Visual;
pub const Movement = components.Movement;
pub const Combat = components.Combat;
pub const Effects = components.Effects;
// Remove duplicate - using HexProjectile as Projectile alias below
pub const Terrain = components.Terrain;
pub const Interactable = components.Interactable;

/// Behavior profile types for hex units
pub const BehaviorProfile = enum {
    idle, // Default - basic aggro when player in range
    aggressive, // Chase-focused, minimal flee
    defensive, // Flee-focused, guard home
    patrolling, // Patrol routes, guard when threatened
    wandering, // Wander randomly, flee when threatened
    guardian, // Guard specific area, intercept threats
};

/// Hex-specific unit component extending lib's Unit
pub const HexUnit = struct {
    // Core unit data from lib
    base: components.Unit,
    
    // Hex-specific additions
    behavior_profile: BehaviorProfile = .idle,
    target_pos: Vec2,
    chase_timer: f32,

    pub const UnitState = enum { returning_home, chasing, at_home };
    pub const UnitType = components.Unit.UnitType;

    pub fn init(utype: components.Unit.UnitType, home_pos: Vec2, behavior: BehaviorProfile) HexUnit {
        return .{
            .base = components.Unit.init(utype, home_pos),
            .behavior_profile = behavior,
            .target_pos = home_pos,
            .chase_timer = 0.0,
        };
    }
    
    // Convenience accessors for compatibility
    pub fn getState(self: HexUnit) UnitState {
        return switch (self.base.behavior_state) {
            .idle => .at_home,
            .chasing, .attacking => .chasing,
            .fleeing, .patrolling => .returning_home,
        };
    }
};

// Alias for compatibility with existing code
pub const Unit = HexUnit;

// Use PlayerInput from lib components
pub const PlayerInput = components.PlayerInput;

// Hex-specific projectile with damage field
pub const HexProjectile = struct {
    base: components.Projectile,
    damage: f32,

    pub fn init(owner: EntityId, max_lifetime: f32, damage: f32) HexProjectile {
        return .{
            .base = components.Projectile.init(owner, max_lifetime),
            .damage = damage,
        };
    }
    
    // Compatibility methods
    pub fn update(self: *HexProjectile, dt: f32) bool {
        return self.base.update(dt);
    }
    
    pub fn canPierce(self: HexProjectile) bool {
        return self.base.canPierce();
    }
    
    pub fn pierce(self: *HexProjectile) void {
        self.base.pierce();
    }
};

// For compatibility with existing code that expects direct field access
pub const Projectile = HexProjectile;

// Use generic archetype storages from lib/game/storage
const PlayerStorage = storage.PlayerStorage(MAX_ENTITIES_PER_ARCHETYPE);

const UnitStorage = storage.UnitStorage(MAX_ENTITIES_PER_ARCHETYPE, Unit);

const ProjectileStorage = storage.ProjectileStorage(MAX_ENTITIES_PER_ARCHETYPE, HexProjectile);

const ObstacleStorage = storage.TerrainStorage(MAX_ENTITIES_PER_ARCHETYPE);

const LifestoneStorage = storage.InteractiveStorage(MAX_ENTITIES_PER_ARCHETYPE);

const PortalStorage = storage.InteractiveStorage(MAX_ENTITIES_PER_ARCHETYPE);

// EntityIterator is now provided by storage module

// Portal iterator removed - using EntityIterator instead

pub const MAX_ZONES = 7;
pub const MAX_ENTITIES_PER_ARCHETYPE = 256;

// Hex-specific travel interface implementations for the generic zone travel manager
const HexTravelInterface = struct {
    
    pub fn validateZone(zone_index: usize) bool {
        return zone_index < MAX_ZONES;
    }
    
    pub fn getZoneSpawn(game: *HexGame, zone_index: usize) Vec2 {
        if (zone_index < MAX_ZONES) {
            const zone = game.zone_manager.getZoneConst(zone_index);
            return zone.spawn_pos;
        }
        // Fallback to screen center
        return Vec2{ .x = constants.SCREEN_CENTER_X, .y = constants.SCREEN_CENTER_Y };
    }
    
    pub fn transferPlayer(game: *HexGame, destination_zone: usize, spawn_pos: Vec2) world.ZoneTravelInterface.TravelResult {
        game.travelToZone(destination_zone, spawn_pos) catch |err| {
            loggers.getGameLog().err("zone_travel_failed", "Zone travel failed: {}", .{err});
            return world.ZoneTravelInterface.TravelResult.failed(.zone_not_loaded);
        };
        return world.ZoneTravelInterface.TravelResult.ok();
    }
    
    pub fn clearEffects(game: *HexGame) void {
        if (game.effect_system_ref) |effect_system| {
            effect_system.clear();
            loggers.getGameLog().debug("effects_cleared", "Travel effects cleared", .{});
        } else {
            loggers.getGameLog().debug("effects_cleared", "Travel effects cleared (no effect system available)", .{});
        }
    }
    
    pub fn createTravelEffects(game: *HexGame, origin_pos: Vec2, radius: f32) void {
        if (game.effect_system_ref) |effect_system| {
            effect_system.addPortalTravelEffect(origin_pos, radius);
            loggers.getGameLog().debug("travel_effects_created", "Travel effects created at {any} with radius {}", .{ origin_pos, radius });
        } else {
            loggers.getGameLog().debug("travel_effects_created", "Travel effects created at {any} with radius {} (no effect system available)", .{ origin_pos, radius });
        }
    }
};

// Simple entity allocator
const EntityAllocator = struct {
    next_id: EntityId = 1, // Start from 1, 0 is invalid

    pub fn create(self: *EntityAllocator) EntityId {
        const id = self.next_id;
        self.next_id += 1;
        return id;
    }
};

/// Simplified hex game structure using generic zone manager
pub const HexGame = struct {
    // Generic zone management from lib
    zone_manager: zones.ZoneManager(ZoneData, MAX_ZONES),

    // Player tracking
    player_entity: ?EntityId,
    player_zone: usize,
    player_start_pos: Vec2,

    // Game systems
    bullet_pool: BulletPool,
    entity_allocator: EntityAllocator,
    allocator: std.mem.Allocator,
    logger: ModuleLogger,
    frame_pool: object_pools.FramePool,
    zone_travel_manager: world.ZoneTravelManager(HexGame, MAX_ENTITIES_PER_ARCHETYPE),
    
    // Optional effect system reference for travel effects
    effect_system_ref: ?*GameEffectSystem,

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
            .zone_manager = zones.ZoneManager(ZoneData, MAX_ZONES).init(),
            .player_entity = null,
            .player_zone = 0,
            .player_start_pos = Vec2{ .x = constants.SCREEN_CENTER_X, .y = constants.SCREEN_CENTER_Y },
            .bullet_pool = BulletPool.init(),
            .entity_allocator = EntityAllocator{},
            .allocator = allocator,
            .logger = ModuleLogger.init(allocator),
            .frame_pool = object_pools.FramePool.init(allocator),
            .zone_travel_manager = world.ZoneTravelManager(HexGame, MAX_ENTITIES_PER_ARCHETYPE).init(
                1.0, // 1 second cooldown
                world.zone_travel_manager.TravelInterfaceHelpers.createTravelInterface(
                    HexGame,
                    HexTravelInterface.validateZone,
                    HexTravelInterface.getZoneSpawn,
                    HexTravelInterface.transferPlayer,
                    HexTravelInterface.clearEffects,
                    HexTravelInterface.createTravelEffects,
                )
            ),
            .effect_system_ref = null,
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

        for (&game.zone_manager.zones, zone_types) |*zone, zone_type| {
            zone.* = ZoneData.init(zone_type);
        }

        return game;
    }
    
    /// Set the effect system reference for travel effects
    pub fn setEffectSystemRef(self: *HexGame, effect_system: *GameEffectSystem) void {
        self.effect_system_ref = effect_system;
    }

    pub fn deinit(self: *HexGame) void {
        for (&self.zone_manager.zones) |*zone| {
            zone.deinit();
        }
        self.frame_pool.deinit();
        self.logger.deinit();
    }

    // Direct zone access - no abstraction layers
    pub fn getCurrentZone(self: *HexGame) *ZoneData {
        std.debug.assert(self.zone_manager.getCurrentZoneIndex() < MAX_ZONES);
        return self.zone_manager.getCurrentZone();
    }

    pub fn getCurrentZoneConst(self: *const HexGame) *const ZoneData {
        std.debug.assert(self.zone_manager.getCurrentZoneIndex() < MAX_ZONES);
        return self.zone_manager.getCurrentZoneConst();
    }

    pub fn getZone(self: *HexGame, zone_index: usize) ?*ZoneData {
        if (zone_index >= MAX_ZONES) return null;
        return self.zone_manager.getZone(zone_index);
    }

    pub fn setCurrentZone(self: *HexGame, zone_index: usize) void {
        if (zone_index >= MAX_ZONES) {
            self.logger.err("zone_invalid", "setCurrentZone: Invalid zone_index {}", .{zone_index});
            return;
        }
        self.zone_manager.current_zone_index = zone_index;
        self.logger.debug("zone_switched", "Zone switched to: {}", .{zone_index});
    }

    pub fn getCurrentZoneIndex(self: *const HexGame) usize {
        return self.zone_manager.getCurrentZoneIndex();
    }

    // Compatibility methods for effects system
    pub fn getZoneStorageConst(self: *const HexGame) *const ZoneData {
        return self.getCurrentZoneConst();
    }

    // iteratePortalsInCurrentZone moved to use EntityIterator below

    // Entity creation methods
    pub fn createLifestone(self: *HexGame, zone_index: usize, pos: Vec2, radius: f32, attuned: bool) !EntityId {
        if (zone_index >= MAX_ZONES) return error.InvalidZone;

        const zone = self.zone_manager.getZone(zone_index);
        const entity = self.entity_allocator.create();

        // Determine color based on attunement
        const color = if (attuned)
            constants.COLOR_LIFESTONE_ATTUNED
        else
            constants.COLOR_LIFESTONE_UNATTUNED;

        // Create components directly
        const transform = components.Transform.init(pos, radius);
        const visual = components.Visual.init(color);
        const terrain = components.Terrain.init(.floor, Vec2.init(radius * 2, radius * 2));
        var interactable = components.Interactable.init(.deflectable);
        interactable.state = .normal; // Use available state
        interactable.attuned = attuned; // Set attuned field directly

        try zone.lifestones.addEntity(entity, transform, visual, terrain, interactable);
        zone.entity_count += 1;

        self.logger.debug("lifestone_created", "Created lifestone in zone {} at {any}, attuned: {}", .{ zone_index, pos, attuned });

        return entity;
    }

    pub fn createUnit(self: *HexGame, zone_index: usize, pos: Vec2, radius: f32, behavior: BehaviorProfile) !EntityId {
        if (zone_index >= MAX_ZONES) return error.InvalidZone;

        const zone = self.zone_manager.getZone(zone_index);
        const entity = self.entity_allocator.create();

        // Create components directly
        const transform = components.Transform.init(pos, radius);
        const health = components.Health.init(50);
        const visual = components.Visual.init(constants.COLOR_UNIT_DEFAULT);
        const unit = Unit.init(.enemy, pos, behavior); // Hex-specific HexUnit

        try zone.units.addEntity(entity, transform, health, unit, visual);
        zone.entity_count += 1;

        return entity;
    }

    pub fn createObstacle(self: *HexGame, zone_index: usize, pos: Vec2, size: Vec2, is_deadly: bool) !EntityId {
        if (zone_index >= MAX_ZONES) return error.InvalidZone;

        const zone = self.zone_manager.getZone(zone_index);
        const entity = self.entity_allocator.create();

        const color = if (is_deadly) constants.COLOR_OBSTACLE_DEADLY else constants.COLOR_OBSTACLE_BLOCKING;

        // Use generic factory pattern for obstacle creation
        // Create components directly
        const radius = @max(size.x, size.y) / 2.0; // Convert size to radius
        const transform = components.Transform.init(pos, radius);
        const terrain_type: components.Terrain.TerrainType = if (is_deadly) .pit else .wall;
        const terrain = components.Terrain.init(terrain_type, size);
        const visual = components.Visual.init(color);

        try zone.obstacles.addEntity(entity, transform, terrain, visual);
        zone.entity_count += 1;

        return entity;
    }

    pub fn createPortal(self: *HexGame, zone_index: usize, pos: Vec2, radius: f32, destination: usize) !EntityId {
        if (zone_index >= MAX_ZONES) return error.InvalidZone;

        const zone = self.zone_manager.getZone(zone_index);
        const entity = self.entity_allocator.create();

        // Use generic factory pattern for portal creation
        // Create components directly
        const transform = components.Transform.init(pos, radius);
        const visual = components.Visual.init(constants.COLOR_PORTAL);
        const terrain = components.Terrain.init(.floor, Vec2.init(radius * 2, radius * 2));
        var interactable = components.Interactable.init(.deflectable);
        interactable.destination_zone = destination;

        try zone.portals.addEntity(entity, transform, visual, terrain, interactable);
        zone.entity_count += 1;

        return entity;
    }

    pub fn createPlayer(self: *HexGame, pos: Vec2, radius: f32) !EntityId {
        const zone = self.getCurrentZone();
        const entity = self.entity_allocator.create();

        // Create components directly
        const transform = components.Transform.init(pos, radius);
        const health = components.Health.init(100);
        const player_input = components.PlayerInput.init(0); // Controller ID 0
        const visual = components.Visual.init(constants.COLOR_PLAYER_ALIVE);
        const movement = components.Movement.init(constants.PLAYER_SPEED);

        try zone.players.addEntity(entity, transform, health, player_input, visual, movement);
        zone.entity_count += 1;

        self.player_entity = entity;
        self.player_zone = self.zone_manager.getCurrentZoneIndex();
        self.player_start_pos = pos;

        return entity;
    }

    pub fn createProjectile(self: *HexGame, zone_index: usize, pos: Vec2, _: f32, velocity: Vec2, lifetime: f32) !EntityId {
        if (zone_index >= MAX_ZONES) return error.InvalidZone;

        const zone = self.zone_manager.getZone(zone_index);
        const entity = self.entity_allocator.create();

        // Create components directly  
        var transform = components.Transform.init(pos, 3.0); // Small bullet radius
        transform.vel = velocity;
        const visual = components.Visual.init(.{ .r = 255, .g = 255, .b = 0, .a = 255 }); // Yellow bullet
        
        // Create hex-specific projectile with damage
        const projectile = Projectile.init(entity, lifetime, constants.BULLET_DAMAGE);

        try zone.projectiles.addEntity(entity, transform, projectile, visual);
        zone.entity_count += 1;

        return entity;
    }

    // Zone travel
    pub fn travelToZone(self: *HexGame, zone_index: usize, spawn_pos: Vec2) !void {
        if (zone_index >= MAX_ZONES) return;

        // Clear projectiles in all zones (bullets should not persist across zone travel)
        for (&self.zone_manager.zones) |*zone| {
            zone.projectiles.clear();
        }

        // Move player if exists
        if (self.player_entity) |player_entity| {
            if (self.player_zone != zone_index) {
                // Perform actual entity transfer between zones
                try self.transferPlayerToZone(player_entity, self.player_zone, zone_index, spawn_pos);
                self.player_zone = zone_index;

                self.logger.info("player_travel", "Player traveled from zone {} to zone {}", .{ self.zone_manager.getCurrentZoneIndex(), zone_index });
            }
        }

        self.setCurrentZone(zone_index);

        // Reload portals from new zone into zone travel manager
        self.loadPortalsIntoTravelManager() catch |err| {
            self.logger.err("portal_reload_failed", "Failed to reload portals after zone travel: {}", .{err});
        };

        // Update player position in new zone if no transfer was needed
        if (self.player_entity) |player| {
            if (self.player_zone == zone_index) {
                const zone = self.getCurrentZone();
                if (zone.players.getComponentMut(player, .transform)) |transform| {
                    transform.pos = spawn_pos;
                    transform.vel = Vec2.ZERO;
                }
            }
        }
    }

    // Helper method for proper entity transfer between zones
    fn transferPlayerToZone(self: *HexGame, player_entity: EntityId, source_zone: usize, dest_zone: usize, new_pos: Vec2) !void {
        if (source_zone >= MAX_ZONES or dest_zone >= MAX_ZONES) return;

        const source = self.zone_manager.getZone(source_zone);
        const dest = self.zone_manager.getZone(dest_zone);

        // Extract player components from source zone
        const transform = source.players.getComponent(player_entity, .transform);
        const health = source.players.getComponent(player_entity, .health);
        const visual = source.players.getComponent(player_entity, .visual); // We need mutable to copy

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
        const movement = Movement.init(constants.PLAYER_SPEED);
        try dest.players.addEntity(player_entity, new_transform, new_health, player_input, new_visual, movement);
        dest.entity_count += 1;

        self.logger.debug("player_transferred", "Player entity {} transferred from zone {} to zone {}", .{ player_entity, source_zone, dest_zone });
    }

    // Player accessors
    pub fn getPlayerPos(self: *const HexGame) Vec2 {
        if (self.player_entity) |player| {
            if (self.player_zone == self.zone_manager.getCurrentZoneIndex()) {
                const zone = self.getCurrentZoneConst();
                if (zone.players.getComponent(player, .transform)) |transform| {
                    return transform.pos;
                }
            }
        }
        return Vec2.ZERO;
    }

    pub fn getPlayerRadius(self: *const HexGame) f32 {
        if (self.player_entity) |player| {
            if (self.player_zone == self.zone_manager.getCurrentZoneIndex()) {
                const zone = self.getCurrentZoneConst();
                if (zone.players.getComponent(player, .transform)) |transform| {
                    return transform.radius;
                }
            }
        }
        return constants.PLAYER_RADIUS;
    }

    pub fn getPlayerAlive(self: *const HexGame) bool {
        if (self.player_entity) |player| {
            if (self.player_zone == self.zone_manager.getCurrentZoneIndex()) {
                const zone = self.getCurrentZoneConst();
                if (zone.players.getComponent(player, .health)) |health| {
                    return health.alive;
                }
            }
        }
        return false;
    }

    pub fn getPlayer(self: *const HexGame) ?EntityId {
        if (self.player_entity) |player| {
            if (self.player_zone == self.zone_manager.getCurrentZoneIndex()) {
                return player;
            }
        }
        return null;
    }

    pub fn setPlayerPos(self: *HexGame, pos: Vec2) void {
        if (self.player_entity) |player| {
            if (self.player_zone == self.zone_manager.getCurrentZoneIndex()) {
                const zone = self.getCurrentZone();
                if (zone.players.getComponentMut(player, .transform)) |transform| {
                    transform.pos = pos;
                }
            }
        }
    }

    pub fn setPlayerVel(self: *HexGame, vel: Vec2) void {
        if (self.player_entity) |player| {
            if (self.player_zone == self.zone_manager.getCurrentZoneIndex()) {
                const zone = self.getCurrentZone();
                if (zone.players.getComponentMut(player, .transform)) |transform| {
                    transform.vel = vel;
                }
            }
        }
    }

    pub fn getPlayerVelConst(self: *const HexGame) Vec2 {
        if (self.player_entity) |player| {
            if (self.player_zone == self.zone_manager.getCurrentZoneIndex()) {
                const zone = self.zone_manager.getCurrentZone();
                if (zone.players.getTransformConst(player)) |transform| {
                    return transform.vel;
                }
            }
        }
        return Vec2.ZERO;
    }

    pub fn setPlayerAlive(self: *HexGame, alive: bool) void {
        if (self.player_entity) |player| {
            if (self.player_zone == self.zone_manager.getCurrentZoneIndex()) {
                const zone = self.getCurrentZone();
                if (zone.players.getComponentMut(player, .health)) |health| {
                    health.alive = alive;
                    if (alive) {
                        health.current = health.max;
                    }
                }
                if (zone.players.getComponentMut(player, .visual)) |visual| {
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
            if (self.player_zone == self.zone_manager.getCurrentZoneIndex()) {
                const zone = self.getCurrentZone();
                if (zone.players.getComponentMut(player, .visual)) |visual| {
                    visual.color = color;
                }
            }
        }
    }

    pub fn canFireBullet(self: *const HexGame) bool {
        return self.bullet_pool.canFire();
    }

    /// Context-aware projectiles update function  
    pub fn updateProjectiles(self: *HexGame, frame_ctx: FrameContext) void {
        const deltaTime = frame_ctx.effectiveDelta();
        
        const zone = self.getCurrentZone();

        // Use fixed-size array to avoid any allocations
        var projectiles_to_remove: [MAX_ENTITIES_PER_ARCHETYPE]EntityId = undefined;
        var remove_count: usize = 0;

        // Update projectile positions and check collisions using ECS iteration
        var projectile_iter = zone.projectiles.entityIterator();
        while (projectile_iter.next()) |projectile_id| {
            // Get components
            if (zone.projectiles.getComponentMut(projectile_id, .transform)) |transform| {
                if (zone.projectiles.getComponentMut(projectile_id, .projectile)) |projectile| {
                    // Update position
                    transform.pos = transform.pos.add(transform.vel.scale(deltaTime));

                    // Update lifetime
                    projectile.base.lifetime += deltaTime;

                    // Check if projectile expired
                    if (projectile.base.lifetime >= projectile.base.max_lifetime) {
                        if (remove_count < projectiles_to_remove.len) {
                            projectiles_to_remove[remove_count] = projectile_id;
                            remove_count += 1;
                        }
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
                                    if (remove_count < projectiles_to_remove.len) {
                                        projectiles_to_remove[remove_count] = projectile_id;
                                        remove_count += 1;
                                    }
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }

        // Remove expired/hit projectiles
        for (projectiles_to_remove[0..remove_count]) |projectile_id| {
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

    /// Load portals from current zone into the zone travel manager
    pub fn loadPortalsIntoTravelManager(self: *HexGame) !void {
        self.zone_travel_manager.clear();
        
        const zone = self.getCurrentZone();
        var portal_iter = zone.portals.entityIterator();
        
        while (portal_iter.next()) |portal_id| {
            // Get components from hex storage
            if (zone.portals.getComponent(portal_id, .transform)) |transform| {
                if (zone.portals.getComponent(portal_id, .interactable)) |interactable| {
                    if (interactable.destination_zone) |dest_zone| {
                        // Add portal to zone travel manager
                        try self.zone_travel_manager.addTeleporter(
                            transform.pos,
                            transform.radius,
                            dest_zone,
                            null // Use zone default spawn
                        );
                    }
                }
            }
        }
        
        self.logger.info("portals_loaded", "Loaded {} portals into zone travel manager for zone {}", .{ self.zone_travel_manager.getTeleporterCount(), self.zone_manager.getCurrentZoneIndex() });
    }

    /// Iterator for obstacles in current zone
    pub fn iterateObstaclesInCurrentZone(self: *HexGame) EntityIterator {
        return self.getCurrentZone().obstacles.entityIterator();
    }

    /// Context-aware bullet pool update function
    pub fn updateBulletPool(self: *HexGame, frame_ctx: FrameContext) void {
        const deltaTime = frame_ctx.effectiveDelta();
        self.bullet_pool.update(deltaTime);
    }

    // Debug helpers
    pub fn debugLogZoneEntities(self: *HexGame, zone_index: usize) void {
        if (zone_index >= MAX_ZONES) return;

        const zone = self.zone_manager.getZone(zone_index);
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
