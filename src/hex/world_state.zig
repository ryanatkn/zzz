const std = @import("std");

// Core capabilities
const math = @import("../lib/math/mod.zig");
const colors = @import("../lib/core/colors.zig");
const frame = @import("../lib/core/frame.zig");
const object_pools = @import("../lib/core/object_pools.zig");

// Game system capabilities
const components = @import("../lib/game/components/mod.zig");
const hex_components = @import("components/mod.zig");
const zones = @import("../lib/game/zones/mod.zig");
const storage = @import("../lib/game/storage/mod.zig");
const world = @import("../lib/game/world/mod.zig");
const GameParticleSystem = @import("../lib/particles/game_particles.zig").GameParticleSystem;

// Debug capabilities
const loggers = @import("../lib/debug/loggers.zig");

// Hex game modules
const constants = @import("constants.zig");
const combat = @import("combat/mod.zig");
const faction_presets = @import("faction_presets.zig");
const faction_integration = @import("faction_integration.zig");
const controller_mod = @import("controller.zig");
const unit_ext = @import("unit_ext.zig");
const disposition = @import("disposition.zig");
const entity_queries = @import("entity_queries.zig");
const factions = @import("factions.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const ProjectilePool = combat.projectiles.ProjectilePool;
const FrameContext = frame.FrameContext;
const EntityIterator = storage.EntityIterator;

// Player creation configuration
pub const PlayerConfig = struct {
    position: Vec2,
    radius: f32,
    speed: f32,
    energy: constants.EnergyLevel,
    disposition: disposition.Disposition,
};

// Logging setup
const Logger = @import("../lib/debug/logger.zig").Logger;
const outputs = @import("../lib/debug/outputs.zig");
const filters = @import("../lib/debug/filters.zig");

const ModuleLogger = Logger(.{
    .output = outputs.Console,
    .filter = filters.Throttle,
});

// Entity system - now using extracted modules
const entities = @import("entities/mod.zig");
pub const EntityId = entities.EntityId;
const INVALID_ENTITY = entities.INVALID_ENTITY;
const EntityAllocator = entities.EntityAllocator;

// Use components from lib/game/components.zig
pub const Transform = components.Transform;
pub const Health = components.Health;
pub const Visual = components.Visual;
pub const Movement = components.Movement;
pub const Combat = components.Combat;
pub const Statuses = components.Statuses;
// Remove duplicate - using HexProjectile as Projectile alias below
pub const Terrain = components.Terrain;
pub const Interactable = hex_components.Interactable;

// Use extended Unit with hex-specific fields
pub const Unit = unit_ext.HexUnit;
pub const UnitType = components.Unit.UnitType;
pub const Disposition = disposition.Disposition;

// Use PlayerInput from lib components
pub const PlayerInput = components.PlayerInput;

// Hex-specific projectile with damage field and ricochet capability
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
const UnitStorage = storage.UnitStorage(MAX_ENTITIES_PER_ARCHETYPE, Unit);

const ProjectileStorage = storage.ProjectileStorage(MAX_ENTITIES_PER_ARCHETYPE, HexProjectile);

const TerrainStorage = storage.TerrainStorage(MAX_ENTITIES_PER_ARCHETYPE);

const LifestoneStorage = storage.InteractiveStorage(MAX_ENTITIES_PER_ARCHETYPE, hex_components.Interactable);

const PortalStorage = storage.InteractiveStorage(MAX_ENTITIES_PER_ARCHETYPE, hex_components.Interactable);

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
        return Vec2.screenCenter(constants.SCREEN_WIDTH, constants.SCREEN_HEIGHT);
    }

    pub fn transferPlayer(game: *HexGame, destination_zone: usize, spawn_pos: Vec2) world.ZoneTravelInterface.TravelResult {
        game.travelToZone(destination_zone, spawn_pos) catch |err| {
            loggers.getGameLog().err("zone_travel_failed", "Zone travel failed: {}", .{err});
            return world.ZoneTravelInterface.TravelResult.failed(.zone_not_loaded);
        };
        return world.ZoneTravelInterface.TravelResult.ok();
    }

    pub fn clearParticles(game: *HexGame) void {
        if (game.particle_system_ref) |particle_system| {
            particle_system.clear();
            loggers.getGameLog().debug("particles_cleared", "Travel particles cleared", .{});
        } else {
            loggers.getGameLog().debug("particles_cleared", "Travel particles cleared (no particle system available)", .{});
        }
    }

    pub fn createTravelParticles(game: *HexGame, origin_pos: Vec2, radius: f32) void {
        if (game.particle_system_ref) |particle_system| {
            particle_system.addPortalTravelParticle(origin_pos, radius);
            loggers.getGameLog().debug("travel_particles_created", "Travel particles created at {any} with radius {}", .{ origin_pos, radius });
        } else {
            loggers.getGameLog().debug("travel_particles_created", "Travel particles created at {any} with radius {} (no particle system available)", .{ origin_pos, radius });
        }
    }
};

// Entity allocator now imported from entities module

/// Simplified hex game structure using generic zone manager
pub const HexGame = struct {
    // Generic zone management from lib
    zone_manager: zones.ZoneManager(ZoneData, MAX_ZONES),

    // Controller system (unified entity management)
    primary_controller: controller_mod.Controller,

    // Game systems
    projectile_pool: ProjectilePool,
    entity_allocator: EntityAllocator,
    allocator: std.mem.Allocator,
    logger: ModuleLogger,
    frame_pool: object_pools.FramePool,

    zone_travel_manager: world.ZoneTravelManager(HexGame, MAX_ENTITIES_PER_ARCHETYPE),

    // Optional effect system reference for travel effects
    particle_system_ref: ?*GameParticleSystem,

    pub const ZoneData = struct {
        // Direct fixed-size archetype storage - no dynamic allocation
        units: UnitStorage,
        projectiles: ProjectileStorage,
        terrain: TerrainStorage,
        lifestones: LifestoneStorage,
        portals: PortalStorage,

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
                .units = UnitStorage.init(),
                .projectiles = ProjectileStorage.init(),
                .terrain = TerrainStorage.init(),
                .lifestones = LifestoneStorage.init(),
                .portals = PortalStorage.init(),
                .zone_type = zone_type,
                // Defaults for normal dungeons - overworld will override in ZON
                .camera_mode = .follow, // Default: follow camera for tactical gameplay
                .spawn_pos = Vec2{ .x = constants.DEFAULT_VIEWPORT_WIDTH / 2.0, .y = constants.DEFAULT_VIEWPORT_HEIGHT / 2.0 }, // Default: center of default viewport
                .background_color = getZoneBackgroundColor(zone_type),
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
        pub fn isAlive(self: *const ZoneData, entity_id: EntityId) bool {
            // Check each storage type to see if entity exists and is alive
            if (self.units.containsEntity(entity_id)) return true;
            if (self.projectiles.containsEntity(entity_id)) return true;
            if (self.terrain.containsEntity(entity_id)) return true;
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
            .primary_controller = controller_mod.createPlayerController(),
            .projectile_pool = ProjectilePool.init(),
            .entity_allocator = EntityAllocator{},
            .allocator = allocator,
            .logger = ModuleLogger.init(allocator),
            .frame_pool = object_pools.FramePool.init(allocator),

            .zone_travel_manager = world.ZoneTravelManager(HexGame, MAX_ENTITIES_PER_ARCHETYPE).init(1.0, // 1 second cooldown
                world.zone_travel_manager.TravelInterfaceHelpers.createTravelInterface(
                    HexGame,
                    HexTravelInterface.validateZone,
                    HexTravelInterface.getZoneSpawn,
                    HexTravelInterface.transferPlayer,
                    HexTravelInterface.clearParticles,
                    HexTravelInterface.createTravelParticles,
                )),
            .particle_system_ref = null,
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
    pub fn setParticleSystemRef(self: *HexGame, particle_system: *GameParticleSystem) void {
        self.particle_system_ref = particle_system;
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

    // Entity creation methods - delegated to world.EntityManager (Phase 3)
    pub fn createLifestone(self: *HexGame, zone_index: usize, pos: Vec2, radius: f32, attuned: bool) !EntityId {
        const world_modules = @import("world/mod.zig");
        return world_modules.EntityManager.createLifestone(self, zone_index, pos, radius, attuned);
    }

    pub fn createUnit(self: *HexGame, zone_index: usize, pos: Vec2, radius: f32, unit_disposition: Disposition) !EntityId {
        const world_modules = @import("world/mod.zig");
        return world_modules.EntityManager.createUnit(self, zone_index, pos, radius, unit_disposition);
    }

    pub fn createTerrain(self: *HexGame, zone_index: usize, pos: Vec2, size: Vec2, is_deadly: bool) !EntityId {
        const world_modules = @import("world/mod.zig");
        return world_modules.EntityManager.createTerrain(self, zone_index, pos, size, is_deadly);
    }

    pub fn createPortal(self: *HexGame, zone_index: usize, pos: Vec2, radius: f32, destination: usize) !EntityId {
        const world_modules = @import("world/mod.zig");
        return world_modules.EntityManager.createPortal(self, zone_index, pos, radius, destination);
    }

    pub fn createPlayer(self: *HexGame, config: PlayerConfig) !EntityId {
        const world_modules = @import("world/mod.zig");
        return world_modules.EntityManager.createPlayer(self, config);
    }

    pub fn createProjectile(self: *HexGame, zone_index: usize, pos: Vec2, radius: f32, velocity: Vec2, lifetime: f32, shooter_id: EntityId) !EntityId {
        const world_modules = @import("world/mod.zig");
        return world_modules.EntityManager.createProjectile(self, zone_index, pos, radius, velocity, lifetime, shooter_id);
    }

    // Zone travel - delegated to world.ZoneTransitions (Phase 3)
    pub fn travelToZone(self: *HexGame, zone_index: usize, spawn_pos: Vec2) !void {
        const world_modules = @import("world/mod.zig");
        return world_modules.ZoneTransitions.travelToZone(self, zone_index, spawn_pos);
    }

    // Legacy player compatibility functions removed - use controlled entity methods instead

    // Controller-based methods (new architecture)

    /// Get the currently controlled entity (replaces getPlayer)
    pub fn getControlledEntity(self: *const HexGame) ?EntityId {
        return self.primary_controller.getControlledEntity();
    }

    /// Check if there's a controlled entity that's alive
    pub fn hasLiveControlledEntity(self: *const HexGame) bool {
        if (self.getControlledEntity()) |entity_id| {
            return entity_queries.isEntityAlive(self, entity_id);
        }
        return false;
    }

    /// Get faction perspective of controlled entity
    pub fn getControlledEntityFactions(self: *const HexGame) ?factions.EntityFactions {
        return self.primary_controller.getWorldView();
    }

    /// Cycle to next controllable entity (for Tab key possession)
    pub fn cyclePossession(self: *HexGame) bool {
        const next_entity = controller_mod.findNextControllableEntity(self, self.getControlledEntity());
        if (next_entity) |entity_id| {
            return self.primary_controller.possess(self, entity_id);
        }
        return false;
    }

    /// Release control (enter autonomous mode)
    pub fn releaseControl(self: *HexGame) void {
        self.primary_controller.releaseAny(self);
    }

    pub fn canFireProjectile(self: *const HexGame) bool {
        return self.projectile_pool.canFire();
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
                    var unit_hit = false;
                    var unit_iter = zone.units.entityIterator();
                    while (unit_iter.next()) |unit_id| {
                        if (zone.units.getComponentMut(unit_id, .transform)) |unit_transform| {
                            if (zone.units.getComponentMut(unit_id, .health)) |unit_health| {
                                if (!unit_health.alive) continue;

                                // Skip collision with the entity that fired this projectile
                                if (unit_id == projectile.base.owner) continue;

                                const dist_sq = transform.pos.sub(unit_transform.pos).lengthSquared();
                                const collision_dist = transform.radius + unit_transform.radius;

                                if (dist_sq <= collision_dist * collision_dist) {
                                    // Check if projectile should damage this unit (friendly fire protection)
                                    var should_damage = true;
                                    var should_destroy_projectile = true;

                                    if (zone.units.getComponent(unit_id, .unit)) |unit_comp| {
                                        // Friendly units should not be damaged and projectiles pass through them
                                        if (unit_comp.disposition == .friendly) {
                                            should_damage = false;
                                            should_destroy_projectile = false;
                                        }
                                    }

                                    if (should_damage) {
                                        // Unit hit by projectile - deal damage
                                        unit_health.alive = false;

                                        // Update unit visual color
                                        if (zone.units.getComponentMut(unit_id, .visual)) |unit_visual| {
                                            unit_visual.color = constants.COLOR_DEAD;
                                        }
                                    }

                                    // Only remove projectile if it should be destroyed (not for friendlies)
                                    if (should_destroy_projectile) {
                                        if (remove_count < projectiles_to_remove.len) {
                                            projectiles_to_remove[remove_count] = projectile_id;
                                            remove_count += 1;
                                        }
                                        unit_hit = true;
                                        break;
                                    }
                                }
                            }
                        }
                    }

                    // Skip terrain collision if unit was hit
                    if (unit_hit) continue;

                    // Check collision with terrain using ECS iteration
                    var terrain_iter = zone.terrain.entityIterator();
                    while (terrain_iter.next()) |terrain_id| {
                        if (zone.terrain.getComponent(terrain_id, .terrain)) |terrain| {
                            if (zone.terrain.getComponent(terrain_id, .transform)) |terrain_transform| {
                                const collision_mod = @import("../lib/physics/collision/mod.zig");

                                const projectile_circle = collision_mod.Shape{ .circle = .{ .center = transform.pos, .radius = transform.radius } };
                                const terrain_rect = collision_mod.Shape{ .rectangle = .{ .position = terrain_transform.pos, .size = terrain.size } };

                                if (collision_mod.checkCollision(projectile_circle, terrain_rect)) {
                                    // Terrain hit - check terrain type for collision behavior
                                    if (terrain.terrain_type == .pit) {
                                        // Pits allow projectiles to pass through unimpeded
                                        continue;
                                    } else if (terrain.allows_ricochet) {
                                        // Calculate ricochet off solid terrain (rocks, doors)
                                        const detailed_result = collision_mod.checkCollisionDetailed(projectile_circle, terrain_rect);

                                        if (detailed_result.collided) {
                                            // Reflect velocity using: new_vel = vel - 2 * dot(vel, normal) * normal
                                            const dot_product = transform.vel.dot(detailed_result.normal);
                                            const reflection = detailed_result.normal.scale(2.0 * dot_product);
                                            transform.vel = transform.vel.sub(reflection);

                                            // Optional: reduce speed slightly per ricochet (10% reduction)
                                            transform.vel = transform.vel.scale(0.9);

                                            // Move projectile slightly away from surface to prevent re-collision
                                            const separation = detailed_result.normal.scale(detailed_result.penetration_depth + 0.01);
                                            transform.pos = transform.pos.add(separation);
                                        }
                                        break;
                                    } else {
                                        // Solid terrain without ricochet capability - destroy projectile
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

    /// Iterator methods - now delegated to EntityQueries
    pub fn iterateUnitsInCurrentZone(self: *HexGame) EntityIterator {
        return entities.EntityQueries.iterateUnitsInCurrentZone(self);
    }

    pub fn iterateLifestonesInCurrentZone(self: *HexGame) EntityIterator {
        return entities.EntityQueries.iterateLifestonesInCurrentZone(self);
    }

    pub fn iteratePortalsInCurrentZone(self: *HexGame) EntityIterator {
        return entities.EntityQueries.iteratePortalsInCurrentZone(self);
    }

    /// Load portals from current zone into the zone travel manager - delegated to ZoneTransitions (Phase 3)
    pub fn loadPortalsIntoTravelManager(self: *HexGame) !void {
        const world_modules = @import("world/mod.zig");
        return world_modules.ZoneTransitions.reloadPortals(self);
    }

    /// Iterator for terrain in current zone
    pub fn iterateTerrainInCurrentZone(self: *HexGame) EntityIterator {
        return entities.EntityQueries.iterateTerrainInCurrentZone(self);
    }

    /// Context-aware projectile pool update function
    pub fn updateProjectilePool(self: *HexGame, frame_ctx: FrameContext) void {
        const deltaTime = frame_ctx.effectiveDelta();
        self.projectile_pool.update(deltaTime);
    }

    // Debug helpers - now delegated to EntityQueries
    pub fn debugLogZoneEntities(self: *HexGame, zone_index: usize) void {
        entities.EntityQueries.debugLogZoneEntities(self, zone_index);
    }
};
