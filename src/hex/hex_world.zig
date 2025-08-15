const std = @import("std");
const colors = @import("../lib/core/colors.zig");
const math = @import("../lib/math/mod.zig");
const ecs = @import("../lib/game/ecs.zig");
const constants = @import("constants.zig");
const combat = @import("combat.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const EntityId = ecs.EntityId;
const World = ecs.World;
const components = ecs.components;
const BulletPool = combat.BulletPool;

/// HexWorld - ECS-based world for the hex game
/// Wraps the generic ECS World with hex-specific functionality
pub const HexWorld = struct {
    // Core ECS world
    world: World,
    
    // Game-specific tracking
    player_entity: ?EntityId,
    player_start_pos: Vec2, // Original spawn position for full reset (matching old interface)
    current_zone: usize,
    zones: [7]Zone, // Overworld + 6 dungeons
    
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
        
        // Entity lists for this zone (for zone reset functionality)
        unit_entities: std.ArrayList(EntityId),
        portal_entities: std.ArrayList(EntityId),
        lifestone_entities: std.ArrayList(EntityId),
        obstacle_entities: std.ArrayList(EntityId),
        
        pub fn init(allocator: std.mem.Allocator, zone_type: ZoneType) Zone {
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
                .unit_entities = std.ArrayList(EntityId).init(allocator),
                .portal_entities = std.ArrayList(EntityId).init(allocator),
                .lifestone_entities = std.ArrayList(EntityId).init(allocator),
                .obstacle_entities = std.ArrayList(EntityId).init(allocator),
            };
        }
        
        pub fn deinit(self: *Zone) void {
            self.unit_entities.deinit();
            self.portal_entities.deinit();
            self.lifestone_entities.deinit();
            self.obstacle_entities.deinit();
        }
        
        /// Reset units in this zone (placeholder - will be called by HexWorld.resetCurrentZone)
        pub fn resetUnits(self: *Zone) void {
            // This is a placeholder - actual reset is handled by HexWorld.resetCurrentZone
            _ = self;
        }
    };

    pub fn init(allocator: std.mem.Allocator) !HexWorld {
        var hex_world = HexWorld{
            .world = try World.init(allocator, 50000), // High capacity for bullets, particles, terrain
            .player_entity = null,
            .player_start_pos = Vec2{ .x = constants.SCREEN_CENTER_X, .y = constants.SCREEN_CENTER_Y },
            .current_zone = 0,
            .zones = undefined,
            .allocator = allocator,
            .bullet_pool = BulletPool.init(),
        };
        
        // Initialize zones
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
            zone.* = Zone.init(allocator, zone_type);
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
            if (self.world.transforms.get(player)) |transform| {
                return transform.pos;
            }
        }
        return Vec2.ZERO;
    }
    
    /// Get player position (const version)
    pub fn getPlayerPosConst(self: *const HexWorld) Vec2 {
        if (self.player_entity) |player| {
            if (self.world.transforms.getConst(player)) |transform| {
                return transform.pos;
            }
        }
        return Vec2.ZERO;
    }
    
    /// Set player position
    pub fn setPlayerPos(self: *HexWorld, pos: Vec2) void {
        if (self.player_entity) |player| {
            if (self.world.transforms.get(player)) |transform| {
                transform.pos = pos;
            }
        }
    }
    
    /// Get player velocity
    pub fn getPlayerVel(self: *HexWorld) Vec2 {
        if (self.player_entity) |player| {
            if (self.world.transforms.get(player)) |transform| {
                return transform.vel;
            }
        }
        return Vec2.ZERO;
    }
    
    /// Get player velocity (const version)
    pub fn getPlayerVelConst(self: *const HexWorld) Vec2 {
        if (self.player_entity) |player| {
            if (self.world.transforms.getConst(player)) |transform| {
                return transform.vel;
            }
        }
        return Vec2.ZERO;
    }
    
    /// Set player velocity
    pub fn setPlayerVel(self: *HexWorld, vel: Vec2) void {
        if (self.player_entity) |player| {
            if (self.world.transforms.get(player)) |transform| {
                transform.vel = vel;
            }
        }
    }
    
    /// Check if player is alive
    pub fn getPlayerAlive(self: *HexWorld) bool {
        if (self.player_entity) |player| {
            if (self.world.healths.get(player)) |health| {
                return health.alive;
            }
        }
        return false;
    }
    
    /// Check if player is alive (const version)
    pub fn getPlayerAliveConst(self: *const HexWorld) bool {
        if (self.player_entity) |player| {
            if (self.world.healths.getConst(player)) |health| {
                return health.alive;
            }
        }
        return false;
    }
    
    /// Set player alive status
    pub fn setPlayerAlive(self: *HexWorld, alive: bool) void {
        if (self.player_entity) |player| {
            if (self.world.healths.get(player)) |health| {
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
            if (self.world.transforms.get(player)) |transform| {
                return transform.radius;
            }
        }
        return constants.PLAYER_RADIUS;
    }
    
    /// Get player radius (const version)
    pub fn getPlayerRadiusConst(self: *const HexWorld) f32 {
        if (self.player_entity) |player| {
            if (self.world.transforms.getConst(player)) |transform| {
                return transform.radius;
            }
        }
        return constants.PLAYER_RADIUS;
    }
    
    /// Get player color (from Visual component)
    pub fn getPlayerColor(self: *HexWorld) Color {
        if (self.player_entity) |player| {
            if (self.world.visuals.get(player)) |visual| {
                return visual.color;
            }
        }
        return constants.COLOR_PLAYER_ALIVE;
    }
    
    /// Get player color (const version)
    pub fn getPlayerColorConst(self: *const HexWorld) Color {
        if (self.player_entity) |player| {
            if (self.world.visuals.getConst(player)) |visual| {
                return visual.color;
            }
        }
        return constants.COLOR_PLAYER_ALIVE;
    }
    
    /// Set player color
    pub fn setPlayerColor(self: *HexWorld, color: Color) void {
        if (self.player_entity) |player| {
            if (self.world.visuals.get(player)) |visual| {
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
        health: f32,
        unit_type: components.Unit.UnitType,
    ) !EntityId {
        const unit = try self.world.createUnit(pos, radius, health, unit_type);
        
        // Add to current zone's unit list for reset functionality
        try self.zones[self.current_zone].unit_entities.append(unit);
        
        return unit;
    }

    /// Create an obstacle entity in the current zone
    pub fn createObstacle(
        self: *HexWorld,
        pos: Vec2,
        size: Vec2,
        is_deadly: bool,
    ) !EntityId {
        const obstacle = try self.world.createObstacle(pos, size, is_deadly);
        
        // Add to current zone's obstacle list for reset functionality
        try self.zones[self.current_zone].obstacle_entities.append(obstacle);
        
        return obstacle;
    }

    /// Create a lifestone entity in the current zone
    pub fn createLifestone(
        self: *HexWorld,
        pos: Vec2,
        radius: f32,
        attuned: bool,
    ) !EntityId {
        const lifestone = try self.world.createLifestone(pos, radius, attuned);
        
        // Add to current zone's lifestone list for future reference
        try self.zones[self.current_zone].lifestone_entities.append(lifestone);
        
        return lifestone;
    }

    /// Create a portal entity in the current zone
    pub fn createPortal(
        self: *HexWorld,
        pos: Vec2,
        radius: f32,
        destination_zone: u8,
    ) !EntityId {
        const portal = try self.world.createPortal(pos, radius, destination_zone);
        
        // Add to current zone's portal list for future reference
        try self.zones[self.current_zone].portal_entities.append(portal);
        
        return portal;
    }

    /// Get current zone
    pub fn getCurrentZone(self: *HexWorld) *Zone {
        return &self.zones[self.current_zone];
    }
    
    /// Get current zone (const)
    pub fn getCurrentZoneConst(self: *const HexWorld) *const Zone {
        return &self.zones[self.current_zone];
    }

    pub fn getECSWorld(self: *const HexWorld) *const World {
        return &self.world;
    }
    
    pub fn getECSWorldMut(self: *HexWorld) *World {
        return &self.world;
    }

    /// Get current zone (mutable) - alias for getCurrentZone
    pub fn getCurrentZoneMut(self: *HexWorld) *Zone {
        return &self.zones[self.current_zone];
    }

    /// Travel to a different zone
    pub fn travelToZone(self: *HexWorld, zone_index: usize, spawn_pos: Vec2) !void {
        if (zone_index >= self.zones.len) return;
        
        // Clear all projectiles when traveling between zones
        var projectile_iter = self.world.projectiles.iterator();
        while (projectile_iter.next()) |entry| {
            try self.world.destroyEntity(entry.key_ptr.*);
        }
        
        self.current_zone = zone_index;
        
        // Move player to spawn position
        if (self.player_entity) |player| {
            if (self.world.transforms.get(player)) |transform| {
                transform.pos = spawn_pos;
                transform.vel = Vec2.ZERO;
            }
        }
    }

    /// Reset current zone (respawn units, reset state)
    pub fn resetCurrentZone(self: *HexWorld) !void {
        const zone = &self.zones[self.current_zone];
        
        // Destroy all units in current zone
        for (zone.unit_entities.items) |unit_entity| {
            try self.world.destroyEntity(unit_entity);
        }
        zone.unit_entities.clearRetainingCapacity();
        
        // Destroy all obstacles in current zone
        for (zone.obstacle_entities.items) |obstacle_entity| {
            try self.world.destroyEntity(obstacle_entity);
        }
        zone.obstacle_entities.clearRetainingCapacity();
        
        // Destroy all portals in current zone
        for (zone.portal_entities.items) |portal_entity| {
            try self.world.destroyEntity(portal_entity);
        }
        zone.portal_entities.clearRetainingCapacity();
        
        // Destroy all lifestones in current zone
        for (zone.lifestone_entities.items) |lifestone_entity| {
            try self.world.destroyEntity(lifestone_entity);
        }
        zone.lifestone_entities.clearRetainingCapacity();
        
        // Destroy all projectiles
        var projectile_iter = self.world.projectiles.iterator();
        while (projectile_iter.next()) |entry| {
            try self.world.destroyEntity(entry.key_ptr.*);
        }
        
        // Zone will be repopulated by the loader
    }

    /// Update all projectiles (lifetime, movement)
    pub fn updateProjectiles(self: *HexWorld, dt: f32) !void {
        var to_destroy = std.ArrayList(EntityId).init(self.allocator);
        defer to_destroy.deinit();
        
        // Iterate over all projectiles to update them
        var projectile_iter = self.world.projectiles.iterator();
        while (projectile_iter.next()) |projectile_entry| {
            const entity_id = projectile_entry.key_ptr.*;
            if (self.world.transforms.get(entity_id)) |transform| {
                // Update projectile lifetime
                if (!projectile_entry.value_ptr.update(dt)) {
                    try to_destroy.append(entity_id);
                    continue;
                }
                
                // Move projectile
                transform.pos.x += transform.vel.x * dt;
                transform.pos.y += transform.vel.y * dt;
                
                // Check collision with units
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

    /// Check if projectile collides with any unit (and damage them)
    fn checkProjectileUnitCollision(self: *HexWorld, projectile_id: EntityId, projectile_transform: *const components.Transform) bool {
        // Query all units for collision
        var unit_iter = self.world.units.iterator();
        while (unit_iter.next()) |entry| {
            const unit_id = entry.key_ptr.*;
            
            // Skip if unit is not alive
            if (!self.world.isAlive(unit_id)) continue;
            
            // Get unit transform and health
            if (self.world.transforms.get(unit_id)) |unit_transform| {
                if (self.world.healths.get(unit_id)) |health| {
                    if (!health.alive) continue;
                    
                    // Check circle-circle collision
                    const to_unit = unit_transform.pos.sub(projectile_transform.pos);
                    const distance_sq = to_unit.lengthSquared();
                    const radius_sum = projectile_transform.radius + unit_transform.radius;
                    
                    if (distance_sq < radius_sum * radius_sum) {
                        // Collision detected - damage the unit
                        if (self.world.combats.get(projectile_id)) |projectile_combat| {
                            // Deal damage to unit
                            health.current -= projectile_combat.damage;
                            
                            if (health.current <= 0) {
                                // Unit is killed
                                health.alive = false;
                                if (self.world.visuals.get(unit_id)) |visual| {
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

    /// Update all effects on entities
    pub fn updateEffects(self: *HexWorld, dt: f32) void {
        var effects_iter = self.world.effects.iterator();
        while (effects_iter.next()) |entry| {
            entry.component.update(dt);
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

    /// Get all entities with Transform and Visual components for rendering
    pub fn getRenderableEntities(self: *HexWorld) World.Query2(components.Transform, components.Visual) {
        return self.world.query2(components.Transform, components.Visual);
    }

    /// Get all units for AI processing
    pub fn getUnits(self: *HexWorld) World.Query2(components.Unit, components.Transform) {
        return self.world.query2(components.Unit, components.Transform);
    }

    /// Get all interactable entities for spell effects
    pub fn getInteractables(self: *HexWorld) World.Query2(components.Interactable, components.Transform) {
        return self.world.query2(components.Interactable, components.Transform);
    }

    /// Reset all zones to original state
    pub fn resetAllZones(self: *HexWorld) !void {
        for (&self.zones) |*zone| {
            // Destroy all units in this zone
            for (zone.unit_entities.items) |unit_entity| {
                try self.world.destroyEntity(unit_entity);
            }
            zone.unit_entities.clearRetainingCapacity();
        }
        
        // Destroy all projectiles
        var projectile_iter = self.world.projectiles.iterator();
        while (projectile_iter.next()) |entry| {
            try self.world.destroyEntity(entry.key_ptr.*);
        }
        
        // All zones will be repopulated by the loader
    }
    
    // ===== ECS Query Helpers for Obstacles, Lifestones, Portals =====
    
    /// Query obstacles in current zone using ECS components
    pub fn queryObstaclesInCurrentZone(self: *const HexWorld, comptime CallbackFn: type, callback: CallbackFn) void {
        const zone = self.getCurrentZoneConst();
        self.queryObstaclesInZone(zone, CallbackFn, callback);
    }
    
    /// Query obstacles in specific zone using ECS components
    pub fn queryObstaclesInZone(self: *const HexWorld, zone: *const Zone, comptime CallbackFn: type, callback: CallbackFn) void {
        _ = zone; // TODO: Zone-specific filtering when we add zone tracking to entities
        
        // Query all terrain entities with transform and visual
        var terrain_iter = @constCast(&self.world.terrains).iterator();
        while (terrain_iter.next()) |entry| {
            const entity_id = entry.key_ptr.*;
            const terrain = entry.value_ptr.*;
            
            // Skip if not an obstacle
            if (terrain.terrain_type != .block and terrain.terrain_type != .deadly) continue;
            
            // Get components
            if (self.world.transforms.getConst(entity_id)) |transform| {
                if (self.world.visuals.getConst(entity_id)) |visual| {
                    // Call callback with obstacle data
                    callback.call(entity_id, transform, visual, terrain);
                }
            }
        }
    }
    
    /// Query lifestones in current zone using ECS components  
    pub fn queryLifestonesInCurrentZone(self: *const HexWorld, comptime CallbackFn: type, callback: CallbackFn) void {
        const zone = self.getCurrentZoneConst();
        self.queryLifestonesInZone(zone, CallbackFn, callback);
    }
    
    /// Query lifestones in specific zone using ECS components
    pub fn queryLifestonesInZone(self: *const HexWorld, zone: *const Zone, comptime CallbackFn: type, callback: CallbackFn) void {
        _ = zone; // TODO: Zone-specific filtering when we add zone tracking to entities
        
        // Query terrain entities that are interact type (lifestones)
        var terrain_iter = @constCast(&self.world.terrains).iterator();
        while (terrain_iter.next()) |entry| {
            const entity_id = entry.key_ptr.*;
            const terrain = entry.value_ptr.*;
            
            // Skip if not a lifestone (interact terrain with interactable component)
            if (terrain.terrain_type != .interact) continue;
            if (!self.world.interactables.contains(entity_id)) continue;
            
            // Get components
            if (self.world.transforms.getConst(entity_id)) |transform| {
                if (self.world.visuals.getConst(entity_id)) |visual| {
                    if (self.world.interactables.getConst(entity_id)) |interactable| {
                        // Call callback with lifestone data
                        callback.call(entity_id, transform, visual, terrain, interactable);
                    }
                }
            }
        }
    }
    
    /// Query portals in current zone using ECS components
    pub fn queryPortalsInCurrentZone(self: *const HexWorld, comptime CallbackFn: type, callback: CallbackFn) void {
        const zone = self.getCurrentZoneConst();
        self.queryPortalsInZone(zone, CallbackFn, callback);
    }
    
    /// Query portals in specific zone using ECS components
    pub fn queryPortalsInZone(self: *const HexWorld, zone: *const Zone, comptime CallbackFn: type, callback: CallbackFn) void {
        _ = zone; // TODO: Zone-specific filtering when we add zone tracking to entities
        
        // Query terrain entities that are door type (portals)
        var terrain_iter = @constCast(&self.world.terrains).iterator();
        while (terrain_iter.next()) |entry| {
            const entity_id = entry.key_ptr.*;
            const terrain = entry.value_ptr.*;
            
            // Skip if not a portal (door terrain with interactable component)
            if (terrain.terrain_type != .door) continue;
            if (!self.world.interactables.contains(entity_id)) continue;
            
            // Get components
            if (self.world.transforms.getConst(entity_id)) |transform| {
                if (self.world.visuals.getConst(entity_id)) |visual| {
                    if (self.world.interactables.getConst(entity_id)) |interactable| {
                        // Call callback with portal data
                        callback.call(entity_id, transform, visual, terrain, interactable);
                    }
                }
            }
        }
    }
};