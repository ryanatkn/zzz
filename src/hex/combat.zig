const std = @import("std");
const log_throttle = @import("../lib/debug/log_throttle.zig");
const math = @import("../lib/math/mod.zig");
const projectiles = @import("../lib/game/projectiles/mod.zig");
const behaviors = @import("behaviors.zig");
const physics = @import("physics.zig");
const effects = @import("effects.zig");
const constants = @import("constants.zig");
const ecs = @import("../lib/game/ecs.zig");

const Vec2 = math.Vec2;
const HexWorld = @import("hex_world.zig").HexWorld;

// Re-export BulletPool from lib/game/projectiles
pub const BulletPool = projectiles.BulletPool;

pub fn fireBullet(world: *HexWorld, target_pos: Vec2, pool: *BulletPool) bool {
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

pub fn fireBulletAtMouse(world: *HexWorld, mouse_pos: Vec2, pool: *BulletPool) bool {
    return fireBullet(world, mouse_pos, pool);
}

pub fn respawnPlayer(game_state: anytype) void {
    const world = &game_state.world;
    const effect_system = &game_state.effect_system;
    const nearest: ?physics.LifestoneResult = physics.findNearestAttunedLifestone(world);

    var respawn_pos: Vec2 = undefined;

    if (nearest) |result| {
        if (result.zone_index != world.current_zone) {
            game_state.travelToZone(result.zone_index) catch |err| {
                std.log.err("Failed to travel to zone {}: {}", .{ result.zone_index, err });
            };
            log_throttle.logInfo("travel_to_lifestone", "Traveling to zone {} for nearest lifestone", .{result.zone_index});
        }
        respawn_pos = result.pos;
    } else {
        if (world.current_zone != 0) {
            game_state.travelToZone(0) catch |err| {
                std.log.err("Failed to travel to overworld: {}", .{err});
            };
            log_throttle.logInfo("no_lifestones", "No lifestones found, returning to overworld spawn", .{});
        }
        respawn_pos = Vec2{ .x = constants.SCREEN_CENTER_X, .y = constants.SCREEN_CENTER_Y };
    }

    // Common respawn logic
    // Set player position and alive status using ECS
    world.setPlayerPos(respawn_pos);
    world.setPlayerAlive(true);
    world.setPlayerColor(constants.COLOR_PLAYER_ALIVE);
    effect_system.addPlayerSpawnEffect(respawn_pos, world.getPlayerRadius());
    log_throttle.logInfo("player_respawn", "Player respawned!", .{});
}

pub fn handlePlayerDeath(world: *HexWorld) void {
    world.setPlayerAlive(false);
    log_throttle.logInfo("player_death", "Player died! Press R or click to respawn", .{});
}

pub fn handlePlayerDeathOnHazard(world: *HexWorld) void {
    world.setPlayerAlive(false);
    log_throttle.logInfo("player_hazard_death", "Player died on hazard! Press R or click to respawn", .{});
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
    log_throttle.logInfo("unit_hazard_death", "Unit died on hazard!", .{});
}
