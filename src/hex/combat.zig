const std = @import("std");

const loggers = @import("../lib/debug/loggers.zig");
const math = @import("../lib/math/mod.zig");
const time = @import("../lib/core/time.zig");
const camera = @import("../lib/game/camera/camera.zig");
const BulletPoolImpl = @import("../lib/game/projectiles/bullet_pool.zig").BulletPool;
const combat = @import("../lib/game/combat/mod.zig");
const physics = @import("physics.zig");
const constants = @import("constants.zig");
const game_systems = @import("../lib/game/systems/mod.zig");
const entity_queries = @import("entity_queries.zig");
const world_state_mod = @import("world_state.zig");
const game_loop_mod = @import("game_loop.zig");

const Vec2 = math.Vec2;
const Camera = camera.Camera;
const HexGame = world_state_mod.HexGame;
const EntityId = world_state_mod.EntityId;
const GameState = game_loop_mod.GameState;

// Re-export BulletPool from lib/game/projectiles for compatibility
pub const BulletPool = BulletPoolImpl;

// Hex-specific interface implementations for generic combat system
const HexCombatInterface = struct {
    pub fn getShooterPos(game: *HexGame) ?Vec2 {
        // Use controlled entity instead of hardcoded player
        if (game.getControlledEntity()) |entity_id| {
            return entity_queries.getEntityPos(game, entity_id);
        }
        return null;
    }

    pub fn isShooterAlive(game: *HexGame) bool {
        // Use controlled entity instead of hardcoded player
        return game.hasLiveControlledEntity();
    }

    pub fn createProjectileFromCombat(game: *HexGame, pos: Vec2, velocity: Vec2, radius: f32, lifetime: f32, _: f32) anyerror!u32 {
        // Get the shooter entity ID to properly set projectile ownership
        const shooter_id = game.getControlledEntity() orelse return error.NoShooter;
        return game.createProjectile(game.zone_manager.getCurrentZoneIndex(), pos, radius, velocity, lifetime, shooter_id);
    }
};

pub fn fireProjectile(game: *HexGame, target_pos: Vec2, pool: *BulletPoolImpl, bypass_cooldown: bool) bool {
    // Check if there's a controlled entity that can shoot
    if (!HexCombatInterface.isShooterAlive(game)) return false;

    // Get shooter position (controlled entity)
    const shooter_pos = HexCombatInterface.getShooterPos(game) orelse return false;

    // Use generic combat system
    const config = combat.CombatActions.ShootConfig.fromShooterToTarget(
        shooter_pos,
        target_pos,
        constants.PROJECTILE_SPEED,
        constants.PROJECTILE_RADIUS,
        constants.PROJECTILE_LIFETIME,
        constants.PROJECTILE_DAMAGE,
    );

    // Check if shooting is possible using generic interface
    if (!combat.CombatActions.canShoot(config)) return false;

    // Handle timing based on bypass_cooldown flag
    const current_time_ms = @as(u64, @intFromFloat(time.Time.getTimeMs()));

    if (bypass_cooldown) {
        // Skill-based: only check bullet count
        if (pool.getCurrentCount() == 0) return false;
        // Manually consume bullet without cooldown
        pool.current_bullets -= 1;
        game.logger.info("projectile_fired", "Projectile fired immediate (skill-based)! ID pending, pos: {any}, target: {any}", .{ config.shooter_pos, target_pos });
    } else {
        // Rhythm: check both bullet count and cooldown timing
        if (!pool.canFire()) return false;
        // Use normal fire which applies cooldown
        pool.fire();
        game.logger.info("projectile_fired", "Projectile fired rhythm! ID pending, pos: {any}, target: {any}", .{ config.shooter_pos, target_pos });
    }

    // Track shot time for both modes (shared timing reference)
    pool.last_fire_time_ms = current_time_ms;

    // Calculate velocity using generic system
    const velocity = combat.CombatActions.calculateProjectileVelocity(config);

    // Create bullet entity using hex-specific implementation
    const bullet_id = HexCombatInterface.createProjectileFromCombat(game, config.shooter_pos, velocity, config.projectile_radius, config.projectile_lifetime, config.damage) catch return false;

    game.logger.info("projectile_confirmed", "Projectile created with ID: {}", .{bullet_id});
    return true;
}

pub fn fireProjectileAtMouse(game: *HexGame, mouse_pos: Vec2, pool: *BulletPoolImpl, bypass_cooldown: bool) bool {
    return fireProjectile(game, mouse_pos, pool, bypass_cooldown);
}

/// Fire projectile with proper screen-to-world coordinate conversion
pub fn fireProjectileAtScreenPos(game: *HexGame, screen_pos: Vec2, cam: *const Camera, pool: *BulletPoolImpl, bypass_cooldown: bool) bool {
    const world_pos = cam.screenToWorldSafe(screen_pos);
    return fireProjectile(game, world_pos, pool, bypass_cooldown);
}

/// Convert hex lifestone to generic checkpoint data
fn lifestoneToCheckpoint(lifestone_result: physics.LifestoneResult) game_systems.respawn.RespawnInterface.CheckpointData {
    return game_systems.respawn.RespawnInterface.CheckpointData
        .init(lifestone_result.pos)
        .withZone(lifestone_result.zone_index);
}

/// Find best respawn checkpoint using generic patterns applied to hex lifestones
fn findBestRespawnCheckpoint(game: *HexGame) ?game_systems.respawn.RespawnInterface.CheckpointResult {
    // Use controlled entity position (controller always has an entity possessed)
    const entity_pos = if (game.getControlledEntity()) |entity_id| blk: {
        break :blk entity_queries.getEntityPos(game, entity_id) orelse return null;
    } else return null;

    // Use hex-specific lifestone search
    if (physics.findNearestAttunedLifestone(game)) |lifestone_result| {
        const checkpoint = lifestoneToCheckpoint(lifestone_result);
        return game_systems.respawn.RespawnInterface.CheckpointResult.init(checkpoint, entity_pos);
    }

    return null;
}

pub fn respawnPlayer(game_state: *GameState) void {
    const world = &game_state.hex_game;
    const particle_system = &game_state.particle_system;

    // Use generic checkpoint finding with hex-specific lifestone implementation
    const checkpoint_result = findBestRespawnCheckpoint(world);
    var respawn_pos: Vec2 = undefined;

    if (checkpoint_result) |result| {
        const checkpoint = result.checkpoint;
        respawn_pos = checkpoint.position;

        // Handle zone travel if checkpoint is in different zone
        if (checkpoint.zone_index) |target_zone| {
            if (target_zone != world.getCurrentZoneIndex()) {
                loggers.getGameLog().info("respawn_travel", "Respawning: traveling to zone {} for checkpoint at {any}", .{ target_zone, respawn_pos });

                // Travel to zone with spawn position
                game_state.travelToZoneWithSpawn(target_zone, respawn_pos) catch |err| {
                    loggers.getGameLog().err("respawn_travel_failed", "Failed to travel to zone {} for respawn: {}", .{ target_zone, err });
                };
            }
        }
    } else {
        // No checkpoints found - use fallback respawn logic
        if (world.getCurrentZoneIndex() != 0) {
            loggers.getGameLog().info("respawn_overworld", "No checkpoints found, returning to overworld spawn", .{});
            game_state.travelToZone(0) catch |err| {
                loggers.getGameLog().err("respawn_overworld_failed", "Failed to travel to overworld for respawn: {}", .{err});
            };
        }
        respawn_pos = Vec2.screenCenter(constants.SCREEN_WIDTH, constants.SCREEN_HEIGHT);
    }

    // Common respawn logic - create respawn effects
    const controlled_radius = if (world.getControlledEntity()) |controlled_entity| blk: {
        const zone = world.getCurrentZoneConst();
        if (zone.units.getComponent(controlled_entity, .transform)) |transform| {
            break :blk transform.radius;
        }
        break :blk 0.7; // Default radius
    } else 0.7;

    const respawn_effect = game_systems.respawn.RespawnVisuals.RespawnVisualData.init(respawn_pos, controlled_radius);

    // Set controlled entity position and alive status using ECS
    if (world.getControlledEntity()) |controlled_entity| {
        const zone = world.getCurrentZone();
        if (zone.units.getComponentMut(controlled_entity, .transform)) |transform| {
            transform.pos = respawn_pos;
        }
        if (zone.units.getComponentMut(controlled_entity, .health)) |health| {
            health.alive = true;
            health.current = health.max;
        }
        if (zone.units.getComponentMut(controlled_entity, .visual)) |visual| {
            visual.color = constants.COLOR_PLAYER_ALIVE;
        }
    }
    particle_system.addPlayerSpawnParticle(respawn_effect.position, respawn_effect.radius);
    loggers.getGameLog().info("player_respawn", "Player respawned at checkpoint!", .{});
}

/// Handle player death using generic death patterns
pub fn handlePlayerDeath(world: *HexGame) void {
    // Use generic death handling pattern (config available for future use)
    _ = combat.DamageSystem.DamageConfig.environmental(999); // Lethal damage

    world.setPlayerAlive(false);
    loggers.getGameLog().info("player_death", "Player died! Press R or click to respawn", .{});
}

/// Handle player death on hazard using generic damage system
pub fn handlePlayerDeathOnHazard(world: *HexGame) void {
    // Use generic environmental damage pattern (config available for future use)
    _ = combat.DamageSystem.DamageConfig.environmental(999);

    world.setPlayerAlive(false);
    loggers.getGameLog().info("player_hazard_death", "Player died on hazard! Press R or click to respawn", .{});
}

/// Handle unit death on hazard using generic damage system
pub fn handleUnitDeathOnHazard(unit_entity: EntityId, world: *HexGame) void {
    const zone = world.getCurrentZone();

    // Use generic death handling for units
    if (zone.units.getComponentMut(unit_entity, .health)) |health| {
        const damage_config = combat.DamageSystem.DamageConfig.environmental(999);
        const result = combat.DamageSystem.applyDamage(health, damage_config);

        if (result.target_killed) {
            // Update visual to show death
            if (zone.units.getComponentMut(unit_entity, .visual)) |visual| {
                visual.color = constants.COLOR_DEAD;
            }
            loggers.getGameLog().info("unit_hazard_death", "Unit died on hazard!", .{});
        }
    }
}
