const std = @import("std");
const colors = @import("../lib/core/colors.zig");
const math = @import("../lib/math/mod.zig");
const ecs = @import("../lib/game/ecs.zig");
const constants = @import("constants.zig");
const combat = @import("combat.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const EntityId = ecs.EntityId;
const ZonedWorld = ecs.ZonedWorld;
const ZoneStorage = ecs.ZoneStorage;
const components = ecs.components;
const BulletPool = combat.BulletPool;

// ZoneEntityIterator removed - use direct zone storage access instead:
// world.getZoneStorageConst().units.iterator() etc.

/// HexWorld - Zone-segmented ECS world for the hex game
/// Wraps ZonedWorld with per-zone SOA storage for optimal cache locality
pub const HexWorld = struct {
    // Core zone-segmented ECS world
    world: ZonedWorld,

    // Game-specific tracking
    player_entity: ?EntityId,
    player_start_pos: Vec2, // Original spawn position for full reset (matching old interface)
    zones: [7]Zone, // Zone metadata only (entities now stored in world.zones)

    // Allocator for cleanup
    allocator: std.mem.Allocator,

    // Bullet pool system for firing rate limiting
    bullet_pool: BulletPool,

    pub const Zone = struct {
        pub const ZoneType = enum {
            overworld,
            dungeon_fire,
            dungeon_ice,
            dungeon_storm,
            dungeon_nature,
            dungeon_shadow,
            dungeon_arcane,
        };

        zone_type: ZoneType,
        camera_mode: constants.CameraMode,
        camera_scale: f32,
        spawn_pos: Vec2,
        background_color: Color,

        pub fn init(zone_type: ZoneType) Zone {
            return .{
                .zone_type = zone_type,
                .camera_mode = switch (zone_type) {
                    .overworld => .fixed,
                    else => .follow,
                },
                .camera_scale = switch (zone_type) {
                    .overworld => 1.0,
                    else => 2.0,
                },
                .spawn_pos = Vec2{ .x = 400, .y = 300 }, // Default, overridden by loader
                .background_color = Color{ .r = 0, .g = 0, .b = 0, .a = 1 }, // Default black
            };
        }

        pub fn deinit(self: *Zone) void {
            // No entity storage to clean up - entities are in ZonedWorld
            _ = self;
        }
    };

    pub fn init(allocator: std.mem.Allocator) !HexWorld {
        var hex_world = HexWorld{
            .world = try ZonedWorld.init(allocator, 50000), // High capacity for bullets, particles, terrain
            .player_entity = null,
            .player_start_pos = Vec2{ .x = constants.SCREEN_CENTER_X, .y = constants.SCREEN_CENTER_Y },
            .zones = undefined,
            .allocator = allocator,
            .bullet_pool = BulletPool.init(),
        };

        // Initialize zone metadata
        for (&hex_world.zones, 0..) |*zone, i| {
            const zone_type: Zone.ZoneType = switch (i) {
                0 => .overworld,
                1 => .dungeon_fire,
                2 => .dungeon_ice,
                3 => .dungeon_storm,
                4 => .dungeon_nature,
                5 => .dungeon_shadow,
                6 => .dungeon_arcane,
                else => unreachable,
            };
            zone.* = Zone.init(zone_type);
        }

        return hex_world;
    }

    pub fn deinit(self: *HexWorld) void {
        for (&self.zones) |*zone| {
            zone.deinit();
        }
        self.world.deinit();
    }

    /// Create player entity
    pub fn createPlayer(self: *HexWorld, pos: Vec2) !EntityId {
        return self.createPlayerWithRadius(pos, constants.PLAYER_RADIUS);
    }

    /// Create player entity with custom radius
    pub fn createPlayerWithRadius(self: *HexWorld, pos: Vec2, radius: f32) !EntityId {
        const player = try self.world.createPlayer(pos, radius, 100, 0);
        self.player_entity = player;
        self.player_start_pos = pos; // Remember initial position
        return player;
    }

    /// Get player entity (convenience method)
    pub fn getPlayer(self: *HexWorld) ?EntityId {
        return self.player_entity;
    }

    // Player access helper methods (matching old interface)

    /// Get player position (returns Vec2{0,0} if no player)
    pub fn getPlayerPos(self: *HexWorld) Vec2 {
        if (self.player_entity) |player| {
            const zone_storage = self.world.getCurrentZone();
            if (zone_storage.transforms.get(player)) |transform| {
                return transform.pos;
            }
        }
        return Vec2.ZERO;
    }

    /// Get player position (const version)
    pub fn getPlayerPosConst(self: *const HexWorld) Vec2 {
        if (self.player_entity) |player| {
            const zone_storage = self.world.getCurrentZoneConst();
            if (zone_storage.transforms.getConst(player)) |transform| {
                return transform.pos;
            }
        }
        return Vec2.ZERO;
    }

    /// Set player position
    pub fn setPlayerPos(self: *HexWorld, pos: Vec2) void {
        if (self.player_entity) |player| {
            const zone_storage = self.world.getCurrentZone();
            if (zone_storage.transforms.get(player)) |transform| {
                transform.pos = pos;
            }
        }
    }

    /// Get player velocity
    pub fn getPlayerVel(self: *HexWorld) Vec2 {
        if (self.player_entity) |player| {
            const zone_storage = self.world.getCurrentZone();
            if (zone_storage.transforms.get(player)) |transform| {
                return transform.vel;
            }
        }
        return Vec2.ZERO;
    }

    /// Get player velocity (const version)
    pub fn getPlayerVelConst(self: *const HexWorld) Vec2 {
        if (self.player_entity) |player| {
            const zone_storage = self.world.getCurrentZoneConst();
            if (zone_storage.transforms.getConst(player)) |transform| {
                return transform.vel;
            }
        }
        return Vec2.ZERO;
    }

    /// Set player velocity
    pub fn setPlayerVel(self: *HexWorld, vel: Vec2) void {
        if (self.player_entity) |player| {
            const zone_storage = self.world.getCurrentZone();
            if (zone_storage.transforms.get(player)) |transform| {
                transform.vel = vel;
            }
        }
    }

    /// Check if player is alive
    pub fn getPlayerAlive(self: *HexWorld) bool {
        if (self.player_entity) |player| {
            const zone_storage = self.world.getCurrentZone();
            if (zone_storage.healths.get(player)) |health| {
                return health.alive;
            }
        }
        return false;
    }

    /// Check if player is alive (const version)
    pub fn getPlayerAliveConst(self: *const HexWorld) bool {
        if (self.player_entity) |player| {
            const zone_storage = self.world.getCurrentZoneConst();
            if (zone_storage.healths.getConst(player)) |health| {
                return health.alive;
            }
        }
        return false;
    }

    /// Set player alive status
    pub fn setPlayerAlive(self: *HexWorld, alive: bool) void {
        if (self.player_entity) |player| {
            const zone_storage = self.world.getCurrentZone();
            if (zone_storage.healths.get(player)) |health| {
                health.alive = alive;
                if (alive) {
                    health.current = health.max; // Full heal on resurrection
                }
            }
        }
    }

    /// Get player radius
    pub fn getPlayerRadius(self: *HexWorld) f32 {
        if (self.player_entity) |player| {
            const zone_storage = self.world.getCurrentZone();
            if (zone_storage.transforms.get(player)) |transform| {
                return transform.radius;
            }
        }
        return constants.PLAYER_RADIUS;
    }

    /// Get player radius (const version)
    pub fn getPlayerRadiusConst(self: *const HexWorld) f32 {
        if (self.player_entity) |player| {
            const zone_storage = self.world.getCurrentZoneConst();
            if (zone_storage.transforms.getConst(player)) |transform| {
                return transform.radius;
            }
        }
        return constants.PLAYER_RADIUS;
    }

    /// Get player color (from Visual component)
    pub fn getPlayerColor(self: *HexWorld) Color {
        if (self.player_entity) |player| {
            const zone_storage = self.world.getCurrentZone();
            if (zone_storage.visuals.get(player)) |visual| {
                return visual.color;
            }
        }
        return constants.COLOR_PLAYER_ALIVE;
    }

    /// Get player color (const version)
    pub fn getPlayerColorConst(self: *const HexWorld) Color {
        if (self.player_entity) |player| {
            const zone_storage = self.world.getCurrentZoneConst();
            if (zone_storage.visuals.getConst(player)) |visual| {
                return visual.color;
            }
        }
        return constants.COLOR_PLAYER_ALIVE;
    }

    /// Set player color
    pub fn setPlayerColor(self: *HexWorld, color: Color) void {
        if (self.player_entity) |player| {
            const zone_storage = self.world.getCurrentZone();
            if (zone_storage.visuals.get(player)) |visual| {
                visual.color = color;
            }
        }
    }

    /// Reset player to start position (full reset functionality)
    pub fn resetPlayerToStart(self: *HexWorld) void {
        self.setPlayerPos(self.player_start_pos);
        self.setPlayerVel(Vec2.ZERO);
        self.setPlayerAlive(true);
        self.setPlayerColor(constants.COLOR_PLAYER_ALIVE);
    }

    /// Fire a bullet from an entity
    pub fn fireBullet(
        self: *HexWorld,
        pos: Vec2,
        target_pos: Vec2,
        owner: EntityId,
        damage: f32,
        speed: f32,
        lifetime: f32,
    ) !EntityId {
        const direction = math.vec2_normalize(math.vec2_subtract(target_pos, pos));
        const velocity = math.vec2_multiply(direction, speed);

        return try self.world.createProjectile(
            pos,
            velocity,
            constants.BULLET_RADIUS,
            owner,
            damage,
            lifetime,
        );
    }

    /// Create a unit entity in the current zone
    pub fn createUnit(
        self: *HexWorld,
        pos: Vec2,
        radius: f32,
    ) !EntityId {
        return try self.world.createUnit(pos, radius);
    }

    /// Create an obstacle entity in the current zone
    pub fn createObstacle(
        self: *HexWorld,
        pos: Vec2,
        size: Vec2,
        is_deadly: bool,
    ) !EntityId {
        return try self.world.createObstacle(pos, size, is_deadly);
    }

    /// Create a lifestone entity in the current zone
    pub fn createLifestone(
        self: *HexWorld,
        pos: Vec2,
        radius: f32,
        attuned: bool,
    ) !EntityId {
        return try self.world.createLifestone(pos, radius, attuned);
    }

    /// Create a portal entity in the current zone
    pub fn createPortal(
        self: *HexWorld,
        pos: Vec2,
        radius: f32,
        destination_zone: u8,
    ) !EntityId {
        return try self.world.createPortal(pos, radius, destination_zone);
    }

    /// Get current zone index
    pub fn getCurrentZoneIndex(self: *const HexWorld) usize {
        return self.world.current_zone;
    }

    /// Temporary compatibility: direct access to current_zone field
    pub fn current_zone(self: *const HexWorld) usize {
        return self.world.current_zone;
    }

    /// Get current zone metadata
    pub fn getCurrentZone(self: *HexWorld) *Zone {
        return &self.zones[self.world.current_zone];
    }

    /// Get current zone metadata (const)
    pub fn getCurrentZoneConst(self: *const HexWorld) *const Zone {
        return &self.zones[self.world.current_zone];
    }

    // DEPRECATED: These methods provide access to the old global API
    // Use getZoneStorage() methods for better cache locality
    pub fn getECSWorld(self: *const HexWorld) *const ZoneStorage {
        return self.world.getCurrentZoneConst();
    }

    pub fn getECSWorldMut(self: *HexWorld) *ZoneStorage {
        return self.world.getCurrentZone();
    }

    /// Get current zone's storage (preferred method)
    pub fn getZoneStorage(self: *HexWorld) *ZoneStorage {
        return self.world.getCurrentZone();
    }

    /// Get current zone's storage (const version)
    pub fn getZoneStorageConst(self: *const HexWorld) *const ZoneStorage {
        return self.world.getCurrentZoneConst();
    }

    /// Get specific zone's storage
    pub fn getZoneStorageByIndex(self: *HexWorld, zone_index: usize) *ZoneStorage {
        return self.world.getZone(zone_index);
    }

    /// Get underlying ZonedWorld (for advanced operations)
    pub fn getZonedWorld(self: *HexWorld) *ZonedWorld {
        return &self.world;
    }

    /// Get current zone (mutable) - alias for getCurrentZone
    pub fn getCurrentZoneMut(self: *HexWorld) *Zone {
        return &self.zones[self.world.current_zone];
    }

    /// Travel to a different zone
    pub fn travelToZone(self: *HexWorld, zone_index: usize, spawn_pos: Vec2) !void {
        if (zone_index >= self.zones.len) return;

        // Clear all projectiles when traveling between zones
        // Iterate through all zones to find and destroy all projectiles
        for (&self.world.zones) |*zone_storage| {
            var projectiles_to_destroy = std.ArrayList(EntityId).init(self.allocator);
            defer projectiles_to_destroy.deinit();

            var projectile_iter = zone_storage.projectiles.iterator();
            while (projectile_iter.next()) |entry| {
                try projectiles_to_destroy.append(entry.key_ptr.*);
            }

            for (projectiles_to_destroy.items) |entity_id| {
                try self.world.destroyEntity(entity_id);
            }
        }

        // Move player to the new zone if they exist
        if (self.player_entity) |player| {
            try self.world.moveEntityToZone(player, zone_index);

            // Update player position in new zone
            const new_zone = self.world.getZone(zone_index);
            if (new_zone.transforms.get(player)) |transform| {
                transform.pos = spawn_pos;
                transform.vel = Vec2.ZERO;
            }
        }

        // Switch to the new zone
        self.world.setCurrentZone(zone_index);
    }

    /// Reset current zone (respawn units, reset state)
    pub fn resetCurrentZone(self: *HexWorld) !void {
        const zone_storage = self.world.getCurrentZone();
        var entities_to_destroy = std.ArrayList(EntityId).init(self.allocator);
        defer entities_to_destroy.deinit();

        // Collect all entities in current zone for destruction
        // Units
        var unit_iter = zone_storage.units.iterator();
        while (unit_iter.next()) |entry| {
            try entities_to_destroy.append(entry.key_ptr.*);
        }

        // Terrains (obstacles, lifestones, portals)
        var terrain_iter = zone_storage.terrains.iterator();
        while (terrain_iter.next()) |entry| {
            try entities_to_destroy.append(entry.key_ptr.*);
        }

        // Projectiles  
        var projectile_iter = zone_storage.projectiles.iterator();
        while (projectile_iter.next()) |entry| {
            try entities_to_destroy.append(entry.key_ptr.*);
        }

        // Destroy all collected entities
        for (entities_to_destroy.items) |entity_id| {
            try self.world.destroyEntity(entity_id);
        }

        // Zone will be repopulated by the loader
    }

    /// Update all projectiles (lifetime, movement) - now zone-aware
    pub fn updateProjectiles(self: *HexWorld, dt: f32) !void {
        var to_destroy = std.ArrayList(EntityId).init(self.allocator);
        defer to_destroy.deinit();

        // Only update projectiles in current zone for performance
        const zone_storage = self.world.getCurrentZone();
        var projectile_iter = zone_storage.projectiles.iterator();
        while (projectile_iter.next()) |projectile_entry| {
            const entity_id = projectile_entry.key_ptr.*;
            if (zone_storage.transforms.get(entity_id)) |transform| {
                // Update projectile lifetime
                if (!projectile_entry.value_ptr.update(dt)) {
                    try to_destroy.append(entity_id);
                    continue;
                }

                // Move projectile
                transform.pos.x += transform.vel.x * dt;
                transform.pos.y += transform.vel.y * dt;

                // Check collision with units (zone-local)
                if (self.checkProjectileUnitCollision(entity_id, transform)) {
                    try to_destroy.append(entity_id);
                }
            }
        }

        // Destroy expired projectiles
        for (to_destroy.items) |entity| {
            try self.world.destroyEntity(entity);
        }
    }

    /// Check if projectile collides with any unit (and damage them) - zone-aware
    fn checkProjectileUnitCollision(self: *HexWorld, projectile_id: EntityId, projectile_transform: *const components.Transform) bool {
        // Query units in current zone only for performance
        const zone_storage = self.world.getCurrentZone();
        var unit_iter = zone_storage.units.iterator();
        while (unit_iter.next()) |entry| {
            const unit_id = entry.key_ptr.*;

            // Skip if unit is not alive
            if (!self.world.isAlive(unit_id)) continue;

            // Get unit transform and health from zone storage
            if (zone_storage.transforms.get(unit_id)) |unit_transform| {
                if (zone_storage.healths.get(unit_id)) |health| {
                    if (!health.alive) continue;

                    // Check circle-circle collision
                    const to_unit = unit_transform.pos.sub(projectile_transform.pos);
                    const distance_sq = to_unit.lengthSquared();
                    const radius_sum = projectile_transform.radius + unit_transform.radius;

                    if (distance_sq < radius_sum * radius_sum) {
                        // Collision detected - damage the unit
                        if (zone_storage.combats.get(projectile_id)) |projectile_combat| {
                            // Deal damage to unit
                            health.current -= projectile_combat.damage;

                            if (health.current <= 0) {
                                // Unit is killed
                                health.alive = false;
                                if (zone_storage.visuals.get(unit_id)) |visual| {
                                    visual.color = constants.COLOR_DEAD;
                                }
                            }

                            return true; // Projectile should be destroyed
                        }
                    }
                }
            }
        }
        return false; // No collision
    }

    /// Update all effects on entities - zone-aware
    pub fn updateEffects(self: *HexWorld, dt: f32) void {
        const zone_storage = self.world.getCurrentZone();
        var effects_iter = zone_storage.effects.iterator();
        while (effects_iter.next()) |entry| {
            entry.value_ptr.update(dt);
        }
    }

    /// Update bullet pool system
    pub fn updateBulletPool(self: *HexWorld, dt: f32) void {
        self.bullet_pool.update(dt);
    }

    /// Check if bullet pool can fire
    pub fn canFireBullet(self: *const HexWorld) bool {
        return self.bullet_pool.canFire();
    }

    /// Use a bullet from the pool (decrements counter)
    pub fn useBullet(self: *HexWorld) void {
        self.bullet_pool.fire();
    }

    // NOTE: Query methods removed - use direct zone storage iteration instead
    // Example: for (world.getZoneStorage().units.iterator().next()) |unit| { ... }

    /// Reset all zones to original state
    pub fn resetAllZones(self: *HexWorld) !void {
        // Destroy all entities in all zones
        for (&self.world.zones) |*zone_storage| {
            var entities_to_destroy = std.ArrayList(EntityId).init(self.allocator);
            defer entities_to_destroy.deinit();

            // Collect all entities in this zone
            var unit_iter = zone_storage.units.iterator();
            while (unit_iter.next()) |entry| {
                try entities_to_destroy.append(entry.key_ptr.*);
            }

            var terrain_iter = zone_storage.terrains.iterator();
            while (terrain_iter.next()) |entry| {
                try entities_to_destroy.append(entry.key_ptr.*);
            }

            var projectile_iter = zone_storage.projectiles.iterator();
            while (projectile_iter.next()) |entry| {
                try entities_to_destroy.append(entry.key_ptr.*);
            }

            // Destroy all entities in this zone
            for (entities_to_destroy.items) |entity_id| {
                try self.world.destroyEntity(entity_id);
            }
        }

        // All zones will be repopulated by the loader
    }

    // ===== Temporary Compatibility Layer for Migration =====
    
    /// Temporary wrapper for iterating obstacles - delegates to zone storage
    pub fn iterateObstaclesInCurrentZone(self: *HexWorld) @TypeOf(self.world.getCurrentZone().terrains.iterator()) {
        return self.world.getCurrentZone().terrains.iterator();
    }

    /// Temporary wrapper for iterating units - delegates to zone storage
    pub fn iterateUnitsInCurrentZone(self: *HexWorld) @TypeOf(self.world.getCurrentZone().units.iterator()) {
        return self.world.getCurrentZone().units.iterator();
    }

    /// Temporary wrapper for iterating lifestones - filters terrains for altars (mutable)
    pub fn iterateLifestonesInCurrentZone(self: *HexWorld) @TypeOf(self.world.getCurrentZone().terrains.iterator()) {
        // NOTE: This is less efficient than the old approach but maintains compatibility
        // In the new design, you should iterate terrains and filter for .altar type
        return self.world.getCurrentZone().terrains.iterator();
    }

    /// Temporary wrapper for iterating portals - filters terrains for doors (mutable)
    pub fn iteratePortalsInCurrentZone(self: *HexWorld) @TypeOf(self.world.getCurrentZone().terrains.iterator()) {
        // NOTE: This is less efficient than the old approach but maintains compatibility
        // In the new design, you should iterate terrains and filter for .door type
        return self.world.getCurrentZone().terrains.iterator();
    }

    /// Clear all projectile entities (used when traveling between zones)
    pub fn clearAllProjectiles(self: *HexWorld) !void {
        // Clear projectiles from all zones
        for (&self.world.zones) |*zone_storage| {
            var projectiles_to_destroy = std.ArrayList(EntityId).init(self.allocator);
            defer projectiles_to_destroy.deinit();

            // Collect all projectile entity IDs in this zone
            var iter = zone_storage.projectiles.iterator();
            while (iter.next()) |entry| {
                try projectiles_to_destroy.append(entry.key_ptr.*);
            }

            // Destroy all collected projectiles
            for (projectiles_to_destroy.items) |entity_id| {
                try self.world.destroyEntity(entity_id);
            }
        }
    }
};
