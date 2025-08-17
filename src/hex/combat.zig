const std = @import("std");
const loggers = @import("../lib/debug/loggers.zig");
const math = @import("../lib/math/mod.zig");
const BulletPoolImpl = @import("../lib/game/projectiles/bullet_pool.zig").BulletPool;
const combat = @import("../lib/game/combat/mod.zig");
const physics = @import("physics.zig");
const constants = @import("constants.zig");
const game_systems = @import("../lib/game/systems/mod.zig");

const Vec2 = math.Vec2;
const HexGame = @import("hex_game.zig").HexGame;

// Re-export BulletPool from lib/game/projectiles for compatibility
pub const BulletPool = BulletPoolImpl;

// Hex-specific interface implementations for generic combat system
const HexCombatInterface = struct {
    pub fn getPlayerPos(game: *HexGame) Vec2 {
        return game.getPlayerPos();
    }
    
    pub fn isPlayerAlive(game: *HexGame) bool {
        return game.getPlayerAlive();
    }
    
    pub fn createProjectileFromCombat(game: *HexGame, pos: Vec2, velocity: Vec2, radius: f32, lifetime: f32, _: f32) anyerror!u32 {
        return game.createProjectile(game.zone_manager.getCurrentZoneIndex(), pos, radius, velocity, lifetime);
    }
};

pub fn fireBullet(game: *HexGame, target_pos: Vec2, pool: *BulletPoolImpl) bool {
    // Use generic combat system
    const config = combat.CombatActions.ShootConfig.fromShooterToTarget(
        HexCombatInterface.getPlayerPos(game),
        target_pos,
        constants.BULLET_SPEED,
        constants.BULLET_RADIUS,
        constants.BULLET_LIFETIME,
        constants.BULLET_DAMAGE,
    );
    
    // Check if shooting is possible using generic interface
    if (!combat.CombatActions.canShoot(config)) return false;
    if (!pool.canFire()) return false;
    
    // Calculate velocity using generic system
    const velocity = combat.CombatActions.calculateProjectileVelocity(config);
    
    // Create bullet entity using hex-specific implementation
    const bullet_id = HexCombatInterface.createProjectileFromCombat(
        game, 
        config.shooter_pos, 
        velocity, 
        config.projectile_radius, 
        config.projectile_lifetime, 
        config.damage
    ) catch return false;

    // Consume from bullet pool
    pool.fire();

    game.logger.info("bullet_fired", "Bullet fired! ID: {}, pos: {any}, target: {any}", .{ bullet_id, config.shooter_pos, target_pos });
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
pub fn handleUnitDeathOnHazard(unit_entity: @import("hex_game.zig").EntityId, world: *HexGame) void {
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
