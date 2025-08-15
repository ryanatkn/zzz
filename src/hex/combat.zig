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
        if (result.zone_index != world.getCurrentZoneIndex()) {
            game_state.travelToZone(result.zone_index) catch |err| {
                std.log.err("Failed to travel to zone {}: {}", .{ result.zone_index, err });
            };
            loggers.getGameLog().info("travel_to_lifestone", "Traveling to zone {} for nearest lifestone", .{result.zone_index});
        }
        respawn_pos = result.pos;
    } else {
        if (world.getCurrentZoneIndex() != 0) {
            game_state.travelToZone(0) catch |err| {
                std.log.err("Failed to travel to overworld: {}", .{err});
            };
            loggers.getGameLog().info("no_lifestones", "No lifestones found, returning to overworld spawn", .{});
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
    const ecs_world = world.getECSWorldMut();
    if (ecs_world.healths.get(unit_entity)) |health| {
        health.alive = false;
    }
    if (ecs_world.visuals.get(unit_entity)) |visual| {
        visual.color = constants.COLOR_DEAD;
    }
    loggers.getGameLog().info("unit_hazard_death", "Unit died on hazard!", .{});
}
