const std = @import("std");
const math = @import("../lib/math/mod.zig");
const collision = @import("../lib/physics/collision.zig");
const ecs = @import("../lib/game/ecs.zig");
const hex_game_mod = @import("hex_game.zig");
const HexGame = hex_game_mod.HexGame;
const constants = @import("constants.zig");

// Basic circle-circle collision
pub fn checkCircleCollision(pos1: math.Vec2, radius1: f32, pos2: math.Vec2, radius2: f32) bool {
    const distance_sq = math.distanceSquared(pos1, pos2);
    const radius_sum = radius1 + radius2;
    return distance_sq < radius_sum * radius_sum;
}

// Check if player can move to position (obstacle collision)
pub fn canPlayerMoveTo(game: *HexGame, new_pos: math.Vec2, player_radius: f32) bool {
    const zone = game.getCurrentZone();
    
    // Check collision with all obstacles in current zone
    for (0..zone.obstacles.count) |i| {
        const terrain = &zone.obstacles.terrains[i];
        // Only check solid terrain for movement blocking
        if (!terrain.solid) continue;

        const transform = &zone.obstacles.transforms[i];
        // Check collision with this obstacle
        const circle = collision.Shape{ .circle = .{ .center = new_pos, .radius = player_radius } };
        const rect = collision.Shape{ .rectangle = .{ .position = transform.pos, .size = terrain.size } };
        if (collision.checkCollision(circle, rect)) {
            return false;
        }
    }
    return true;
}

// Player-unit collision check
pub fn checkPlayerUnitCollision(world: *hex_game_mod.HexGame) bool {
    const player_pos = world.getPlayerPos();
    const player_radius = world.getPlayerRadius();
    const zone_storage = world.getZoneStorage();

    // Use idiomatic Zig iterator pattern
    var unit_iter = world.iterateUnitsInCurrentZone();
    while (unit_iter.next()) |entity_id| {
        if (zone_storage.units.getComponent(entity_id, .transform)) |transform| {
            if (zone_storage.units.getComponent(entity_id, .health)) |health| {
                // Only check alive units
                if (!health.alive) continue;
                
                // Check collision with this unit
                if (checkCircleCollision(player_pos, player_radius, transform.pos, transform.radius)) {
                    return true;
                }
            }
        }
    }
    return false;
}

// Portal collision check
pub fn checkPlayerPortalCollision(player_pos: math.Vec2, player_radius: f32, portal_transform: *const hex_game_mod.Transform) bool {
    return checkCircleCollision(player_pos, player_radius, portal_transform.pos, portal_transform.radius);
}

// Unit-obstacle collision check
pub fn checkUnitObstacleCollision(world: *hex_game_mod.HexGame, unit_id: hex_game_mod.EntityId, unit_transform: *hex_game_mod.Transform, unit_health: *hex_game_mod.Health, old_pos: math.Vec2) bool {
    const zone_storage = world.getZoneStorage();
    
    // Use idiomatic Zig iterator pattern
    var obstacle_iter = world.iterateObstaclesInCurrentZone();
    while (obstacle_iter.next()) |entity_id| {
        if (zone_storage.obstacles.getComponent(entity_id, .terrain)) |terrain| {
            if (zone_storage.obstacles.getComponent(entity_id, .transform)) |transform| {
                const circle = collision.Shape{ .circle = .{ .center = unit_transform.pos, .radius = unit_transform.radius } };
                const rect = collision.Shape{ .rectangle = .{ .position = transform.pos, .size = terrain.size } };

                if (collision.checkCollision(circle, rect)) {
                    // Check if it's a deadly obstacle
                    if (terrain.terrain_type == .pit) {
                        unit_health.alive = false;
                        if (zone_storage.units.getComponentMut(unit_id, .visual)) |unit_visual| {
                            unit_visual.color = constants.COLOR_DEAD;
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
pub fn collidesWithDeadlyObstacle(pos: math.Vec2, radius: f32, world: *hex_game_mod.HexGame) bool {
    const zone_storage = world.getZoneStorage();
    
    // Use idiomatic Zig iterator pattern
    var obstacle_iter = world.iterateObstaclesInCurrentZone();
    while (obstacle_iter.next()) |entity_id| {
        if (zone_storage.obstacles.getComponent(entity_id, .terrain)) |terrain| {
            // Only check deadly terrain
            if (terrain.terrain_type != .pit) continue;

            if (zone_storage.obstacles.getComponent(entity_id, .transform)) |transform| {
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

// Find nearest attuned lifestone across all zones
pub fn findNearestAttunedLifestone(game: *HexGame) ?LifestoneResult {
    const player_pos = game.getPlayerPos();
    var nearest_distance_sq: f32 = std.math.inf(f32);
    var nearest_lifestone: ?LifestoneResult = null;

    // Search all zones for attuned lifestones
    for (0..hex_game_mod.MAX_ZONES) |zone_index| {
        const zone = &game.zones[zone_index];
        
        // Check all lifestones in this zone
        for (0..zone.lifestones.count) |i| {
            const interactable = &zone.lifestones.interactables[i];
            const terrain = &zone.lifestones.terrains[i];
            const transform = &zone.lifestones.transforms[i];
            
            // Check if lifestone is attuned
            if (terrain.terrain_type == .altar and interactable.attuned) {
                const distance_sq = math.distanceSquared(player_pos, transform.pos);
                if (distance_sq < nearest_distance_sq) {
                    nearest_distance_sq = distance_sq;
                    nearest_lifestone = LifestoneResult{
                        .pos = transform.pos,
                        .zone_index = @intCast(zone_index),
                    };
                }
            }
        }
    }

    return nearest_lifestone;
}
