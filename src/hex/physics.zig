const std = @import("std");
const math = @import("../lib/math/mod.zig");
const collision = @import("../lib/physics/collision.zig");
const ecs = @import("../lib/game/ecs.zig");
const hex_world = @import("hex_world.zig");
const constants = @import("constants.zig");

// Basic circle-circle collision
pub fn checkCircleCollision(pos1: math.Vec2, radius1: f32, pos2: math.Vec2, radius2: f32) bool {
    const distance_sq = math.distanceSquared(pos1, pos2);
    const radius_sum = radius1 + radius2;
    return distance_sq < radius_sum * radius_sum;
}

// Check if player can move to position (obstacle collision)
pub fn canPlayerMoveTo(world: *hex_world.HexWorld, new_pos: math.Vec2, player_radius: f32) bool {
    // Check collision with solid obstacles using ECS
    const ecs_world = world.getECSWorldMut();
    var obstacle_iter = ecs_world.terrains.iterator();
    while (obstacle_iter.next()) |entry| {
        const obstacle_id = entry.key_ptr.*;
        const terrain = entry.value_ptr;
        if (!ecs_world.isAlive(obstacle_id)) continue;

        // Only check solid terrain for movement blocking
        if (!terrain.solid) continue;

        if (ecs_world.transforms.get(obstacle_id)) |transform| {
            const circle = collision.Shape{ .circle = .{ .center = new_pos, .radius = player_radius } };
            const rect = collision.Shape{ .rectangle = .{ .position = transform.pos, .size = terrain.size } };
            if (collision.checkCollision(circle, rect)) {
                return false;
            }
        }
    }
    return true;
}

// ECS player-unit collision check
pub fn checkPlayerUnitCollisionECS(world: *hex_world.HexWorld) bool {
    const player_pos = world.getPlayerPos();
    const player_radius = world.getPlayerRadius();
    const ecs_world = world.getECSWorldMut();

    var unit_iter = ecs_world.units.iterator();
    while (unit_iter.next()) |entry| {
        const unit_id = entry.key_ptr.*;
        if (!ecs_world.isAlive(unit_id)) continue;

        if (ecs_world.transforms.get(unit_id)) |transform| {
            if (ecs_world.healths.get(unit_id)) |health| {
                if (!health.alive) continue;
                if (checkCircleCollision(player_pos, player_radius, transform.pos, transform.radius)) {
                    return true;
                }
            }
        }
    }
    return false;
}

// ECS portal collision check
pub fn checkPlayerPortalCollisionECS(player_pos: math.Vec2, player_radius: f32, portal_transform: *const ecs.components.Transform) bool {
    return checkCircleCollision(player_pos, player_radius, portal_transform.pos, portal_transform.radius);
}

// ECS unit-obstacle collision check
pub fn checkUnitObstacleCollisionECS(world: *hex_world.HexWorld, unit_id: ecs.EntityId, unit_transform: *ecs.components.Transform, unit_health: *ecs.components.Health, old_pos: math.Vec2) bool {
    const ecs_world = world.getECSWorldMut();
    var obstacle_iter = ecs_world.terrains.iterator();
    while (obstacle_iter.next()) |entry| {
        const obstacle_id = entry.key_ptr.*;
        if (!ecs_world.isAlive(obstacle_id)) continue;

        if (ecs_world.transforms.get(obstacle_id)) |obstacle_transform| {
            if (ecs_world.terrains.get(obstacle_id)) |terrain| {
                const circle = collision.Shape{ .circle = .{ .center = unit_transform.pos, .radius = unit_transform.radius } };
                const rect = collision.Shape{ .rectangle = .{ .position = obstacle_transform.pos, .size = terrain.size } };

                if (collision.checkCollision(circle, rect)) {
                    // Check if it's a deadly obstacle
                    if (terrain.terrain_type == .pit) {
                        unit_health.alive = false;
                        if (ecs_world.visuals.get(unit_id)) |visual| {
                            visual.color = constants.COLOR_DEAD;
                        }
                    } else {
                        // Non-deadly obstacle - revert position
                        unit_transform.pos = old_pos;
                        unit_transform.vel = math.Vec2.ZERO;
                    }
                    return true;
                }
            }
        }
    }
    return false;
}

// Check if position collides with deadly obstacles
pub fn collidesWithDeadlyObstacle(pos: math.Vec2, radius: f32, world: *hex_world.HexWorld) bool {
    const ecs_world = world.getECSWorldMut();
    var obstacle_iter = ecs_world.terrains.iterator();
    while (obstacle_iter.next()) |entry| {
        const obstacle_id = entry.key_ptr.*;
        if (!ecs_world.isAlive(obstacle_id)) continue;

        if (ecs_world.terrains.get(obstacle_id)) |terrain| {
            if (terrain.terrain_type != .pit) continue;

            if (ecs_world.transforms.get(obstacle_id)) |transform| {
                const circle = collision.Shape{ .circle = .{ .center = pos, .radius = radius } };
                const rect = collision.Shape{ .rectangle = .{ .position = transform.pos, .size = terrain.size } };
                if (collision.checkCollision(circle, rect)) {
                    return true;
                }
            }
        }
    }
    return false;
}

// Lifestone search result
pub const LifestoneResult = struct {
    pos: math.Vec2,
    zone_index: u32,
};

// Find nearest attuned lifestone
pub fn findNearestAttunedLifestone(world: *hex_world.HexWorld) ?LifestoneResult {
    const player_pos = world.getPlayerPos();
    var nearest_distance_sq: f32 = std.math.inf(f32);
    var nearest_lifestone: ?LifestoneResult = null;

    const ecs_world = world.getECSWorldMut();
    var lifestone_iter = ecs_world.interactables.iterator();
    while (lifestone_iter.next()) |entry| {
        const lifestone_id = entry.key_ptr.*;
        const interactable = entry.value_ptr;
        if (!ecs_world.isAlive(lifestone_id)) continue;

        // Check if it's a lifestone by looking for altar terrain type
        if (ecs_world.terrains.get(lifestone_id)) |terrain| {
            if (terrain.terrain_type == .altar and interactable.attuned) {
                if (ecs_world.transforms.get(lifestone_id)) |transform| {
                    const distance_sq = math.distanceSquared(player_pos, transform.pos);
                    if (distance_sq < nearest_distance_sq) {
                        nearest_distance_sq = distance_sq;
                        nearest_lifestone = LifestoneResult{
                            .pos = transform.pos,
                            .zone_index = @intCast(world.current_zone),
                        };
                    }
                }
            }
        }
    }

    return nearest_lifestone;
}
