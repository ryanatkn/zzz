const std = @import("std");
const loggers = @import("../lib/debug/loggers.zig");
const math = @import("../lib/math/mod.zig");
const BulletPoolImpl = @import("../lib/game/projectiles/bullet_pool.zig").BulletPool;
const behaviors = @import("behaviors.zig");
const physics = @import("physics.zig");
const constants = @import("constants.zig");
const ecs = @import("../lib/game/ecs.zig");

const Vec2 = math.Vec2;
const HexWorld = @import("hex_world.zig").HexWorld;

// Re-export BulletPool from lib/game/projectiles for compatibility
pub const BulletPool = BulletPoolImpl;

pub fn fireBullet(world: *HexWorld, target_pos: Vec2, pool: *BulletPoolImpl) bool {
    if (!world.getPlayerAlive()) return false;
    if (!pool.canFire()) return false;

    // Fire bullet as ECS entity
    const player_pos = world.getPlayerPos();
    if (world.getPlayer()) |player_entity| {
        const bullet_id = world.fireBullet(
            player_pos,
            target_pos,
            player_entity,
            constants.BULLET_DAMAGE, // damage - one-shot kill
            constants.BULLET_SPEED,
            constants.BULLET_LIFETIME, // lifetime
        ) catch |err| {
            std.log.err("Failed to create bullet: {}", .{err});
            return false;
        };

        std.log.info("Created bullet entity: {}", .{bullet_id});
        pool.fire();
        return true;
    }
    return false;
}

pub fn fireBulletAtMouse(world: *HexWorld, mouse_pos: Vec2, pool: *BulletPoolImpl) bool {
    return fireBullet(world, mouse_pos, pool);
}

pub fn respawnPlayer(game_state: anytype) void {
    const world = &game_state.world;
    const effect_system = &game_state.effect_system;
    const nearest: ?physics.LifestoneResult = physics.findNearestAttunedLifestone(world);

    var respawn_pos: Vec2 = undefined;

    if (nearest) |result| {
        respawn_pos = result.pos;
        if (result.zone_index != world.getCurrentZoneIndex()) {
            loggers.getGameLog().info("respawn_travel", "Respawning: traveling to zone {} for nearest lifestone at {any}", .{result.zone_index, respawn_pos});
            
            // Travel to zone with spawn position
            game_state.travelToZoneWithSpawn(result.zone_index, respawn_pos) catch |err| {
                std.log.err("Failed to travel to zone {}: {}", .{ result.zone_index, err });
                loggers.getGameLog().err("respawn_travel_failed", "Failed to travel for respawn: {}", .{err});
            };
        }
    } else {
        if (world.getCurrentZoneIndex() != 0) {
            loggers.getGameLog().info("respawn_overworld", "No lifestones found, returning to overworld spawn", .{});
            game_state.travelToZone(0) catch |err| {
                std.log.err("Failed to travel to overworld: {}", .{err});
                loggers.getGameLog().err("respawn_overworld_failed", "Failed to travel to overworld for respawn: {}", .{err});
            };
        }
        respawn_pos = Vec2{ .x = constants.SCREEN_CENTER_X, .y = constants.SCREEN_CENTER_Y };
    }

    // Common respawn logic
    // Set player position and alive status using ECS
    world.setPlayerPos(respawn_pos);
    world.setPlayerAlive(true);
    world.setPlayerColor(constants.COLOR_PLAYER_ALIVE);
    effect_system.addPlayerSpawnEffect(respawn_pos, world.getPlayerRadius());
    loggers.getGameLog().info("player_respawn", "Player respawned!", .{});
}

pub fn handlePlayerDeath(world: *HexWorld) void {
    world.setPlayerAlive(false);
    loggers.getGameLog().info("player_death", "Player died! Press R or click to respawn", .{});
}

pub fn handlePlayerDeathOnHazard(world: *HexWorld) void {
    world.setPlayerAlive(false);
    loggers.getGameLog().info("player_hazard_death", "Player died on hazard! Press R or click to respawn", .{});
}

// ECS-compatible unit death on hazard
pub fn handleUnitDeathOnHazardECS(unit_entity: ecs.EntityId, world: *HexWorld) void {
    const zone_storage = world.getZoneStorage();
    if (zone_storage.healths.get(unit_entity)) |health| {
        health.alive = false;
    }
    if (zone_storage.visuals.get(unit_entity)) |visual| {
        visual.color = constants.COLOR_DEAD;
    }
    loggers.getGameLog().info("unit_hazard_death", "Unit died on hazard!", .{});
}
