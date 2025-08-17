const std = @import("std");
const loggers = @import("../lib/debug/loggers.zig");
const math = @import("../lib/math/mod.zig");
const BulletPoolImpl = @import("../lib/game/projectiles/bullet_pool.zig").BulletPool;
const physics = @import("physics.zig");
const constants = @import("constants.zig");
const ecs = @import("../lib/game/ecs.zig");
const game_systems = @import("../lib/game/systems/mod.zig");

const Vec2 = math.Vec2;
const HexGame = @import("hex_game.zig").HexGame;

// Re-export BulletPool from lib/game/projectiles for compatibility
pub const BulletPool = BulletPoolImpl;

pub fn fireBullet(game: *HexGame, target_pos: Vec2, pool: *BulletPoolImpl) bool {
    if (!game.getPlayerAlive()) return false;
    if (!pool.canFire()) return false;

    // Create bullet projectile in current zone
    const player_pos = game.getPlayerPos();
    const direction = target_pos.sub(player_pos).normalize();
    const bullet_speed = constants.BULLET_SPEED;
    const bullet_vel = direction.scale(bullet_speed);
    
    // Create bullet entity in current zone
    const bullet_id = game.createProjectile(
        game.current_zone,
        player_pos,
        constants.BULLET_RADIUS,
        bullet_vel,
        constants.BULLET_LIFETIME
    ) catch return false;
    
    // Consume from bullet pool
    pool.fire();
    
    game.logger.info("bullet_fired", "Bullet fired! ID: {}, pos: {any}, target: {any}", .{ bullet_id, player_pos, target_pos });
    return true;
}

pub fn fireBulletAtMouse(game: *HexGame, mouse_pos: Vec2, pool: *BulletPoolImpl) bool {
    return fireBullet(game, mouse_pos, pool);
}

/// Convert hex lifestone to generic checkpoint data
fn lifestoneToCheckpoint(lifestone_result: physics.LifestoneResult) game_systems.respawn.RespawnInterface.CheckpointData {
    return game_systems.respawn.RespawnInterface.CheckpointData
        .init(lifestone_result.pos)
        .withZone(lifestone_result.zone_index);
}

/// Find best respawn checkpoint using generic patterns applied to hex lifestones
fn findBestRespawnCheckpoint(game: *HexGame) ?game_systems.respawn.RespawnInterface.CheckpointResult {
    const player_pos = game.getPlayerPos();
    
    // Use hex-specific lifestone search
    if (physics.findNearestAttunedLifestone(game)) |lifestone_result| {
        const checkpoint = lifestoneToCheckpoint(lifestone_result);
        return game_systems.respawn.RespawnInterface.CheckpointResult.init(checkpoint, player_pos);
    }
    
    return null;
}

pub fn respawnPlayer(game_state: anytype) void {
    const world = &game_state.hex_game;
    const effect_system = &game_state.effect_system;
    
    // Use generic checkpoint finding with hex-specific lifestone implementation
    const checkpoint_result = findBestRespawnCheckpoint(world);
    var respawn_pos: Vec2 = undefined;

    if (checkpoint_result) |result| {
        const checkpoint = result.checkpoint;
        respawn_pos = checkpoint.position;
        
        // Handle zone travel if checkpoint is in different zone
        if (checkpoint.zone_index) |target_zone| {
            if (target_zone != world.getCurrentZoneIndex()) {
                loggers.getGameLog().info("respawn_travel", "Respawning: traveling to zone {} for checkpoint at {any}", .{target_zone, respawn_pos});
                
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
        respawn_pos = Vec2{ .x = constants.SCREEN_CENTER_X, .y = constants.SCREEN_CENTER_Y };
    }

    // Common respawn logic - create respawn effects
    const respawn_effect = game_systems.respawn.RespawnEffects.RespawnEffectData.init(respawn_pos, world.getPlayerRadius());
    
    // Set player position and alive status using ECS
    world.setPlayerPos(respawn_pos);
    world.setPlayerAlive(true);
    world.setPlayerColor(constants.COLOR_PLAYER_ALIVE);
    effect_system.addPlayerSpawnEffect(respawn_effect.position, respawn_effect.radius);
    loggers.getGameLog().info("player_respawn", "Player respawned at checkpoint!", .{});
}

pub fn handlePlayerDeath(world: *HexGame) void {
    world.setPlayerAlive(false);
    loggers.getGameLog().info("player_death", "Player died! Press R or click to respawn", .{});
}

pub fn handlePlayerDeathOnHazard(world: *HexGame) void {
    world.setPlayerAlive(false);
    loggers.getGameLog().info("player_hazard_death", "Player died on hazard! Press R or click to respawn", .{});
}

// Unit death on hazard
pub fn handleUnitDeathOnHazard(unit_entity: ecs.EntityId, world: *HexGame) void {
    const zone_storage = world.getZoneStorage();
    if (zone_storage.healths.get(unit_entity)) |health| {
        health.alive = false;
    }
    if (zone_storage.visuals.get(unit_entity)) |visual| {
        visual.color = constants.COLOR_DEAD;
    }
    loggers.getGameLog().info("unit_hazard_death", "Unit died on hazard!", .{});
}
