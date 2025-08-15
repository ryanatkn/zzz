const std = @import("std");

const entities = @import("entities.zig");
const types = @import("../lib/core/types.zig");
const math = @import("../lib/math/mod.zig");
const collision = @import("../lib/physics/collision.zig");
const hex_world = @import("hex_world.zig");
const ecs = @import("../lib/game/ecs.zig");
const constants = @import("constants.zig");

const Vec2 = types.Vec2;

// Check circle-circle collision (now using shared math functions)
pub fn checkCircleCollision(pos1: Vec2, radius1: f32, pos2: Vec2, radius2: f32) bool {
    const distance_sq = math.distanceSquared(pos1, pos2);
    const radius_sum = radius1 + radius2;
    return distance_sq < radius_sum * radius_sum;
}

// Check circle-rectangle collision (now using shared collision system)
pub fn checkCircleRectCollision(circle_pos: Vec2, circle_radius: f32, rect_pos: Vec2, rect_size: Vec2) bool {
    const circle = collision.Shape{ .circle = .{ .center = circle_pos, .radius = circle_radius } };
    const rect = collision.Shape{ .rectangle = .{ .position = rect_pos, .size = rect_size } };
    return collision.checkCollision(circle, rect);
}

// Check player-unit collision (legacy)
pub fn checkPlayerUnitCollision(player_pos: Vec2, player_radius: f32, unit: *const entities.Unit) bool {
    if (!unit.active or !unit.alive) return false;
    return checkCircleCollision(player_pos, player_radius, unit.pos, unit.radius);
}

// ECS-based player-unit collision check
pub fn checkPlayerUnitCollisionECS(world: *hex_world.HexWorld) bool {
    const player_pos = world.getPlayerPos();
    const player_radius = world.getPlayerRadius();
    
    // Query all units (sparse storage uses different iterator API)
    var unit_iter = world.world.units.iterator();
    while (unit_iter.next()) |entry| {
        const unit_id = entry.key_ptr.*;
        
        // Skip if entity is not alive
        if (!world.world.isAlive(unit_id)) continue;
        
        // Get unit transform
        if (world.world.transforms.get(unit_id)) |transform| {
            // Get unit health to check if alive
            if (world.world.healths.get(unit_id)) |health| {
                if (!health.alive) continue;
                
                // Check collision
                if (checkCircleCollision(player_pos, player_radius, transform.pos, transform.radius)) {
                    return true;
                }
            }
        }
    }
    
    return false;
}

// Check bullet-unit collision
pub fn checkBulletUnitCollision(bullet: *const entities.Bullet, unit: *const entities.Unit) bool {
    if (!bullet.active or !unit.active or !unit.alive) return false;
    return checkCircleCollision(bullet.pos, bullet.radius, unit.pos, unit.radius);
}


// Check unit-obstacle collision
pub fn checkUnitObstacleCollision(unit: *const entities.Unit, obstacle: *const entities.Obstacle) bool {
    if (!unit.active or !obstacle.active) return false;
    return checkCircleRectCollision(unit.pos, unit.radius, obstacle.pos, obstacle.size);
}

// Check player-portal collision
pub fn checkPlayerPortalCollision(player_pos: Vec2, player_radius: f32, portal: *const entities.Portal) bool {
    if (!portal.active) return false;
    return checkCircleCollision(player_pos, player_radius, portal.pos, portal.radius);
}

// Check player-lifestone collision
pub fn checkPlayerLifestoneCollision(player_pos: Vec2, player_radius: f32, lifestone: *const entities.Lifestone) bool {
    if (!lifestone.active) return false;
    return checkCircleCollision(player_pos, player_radius, lifestone.pos, lifestone.radius);
}

// Check player-obstacle collision
pub fn checkPlayerObstacleCollision(player_pos: Vec2, player_radius: f32, obstacle: *const entities.Obstacle) bool {
    if (!obstacle.active) return false;
    return checkCircleRectCollision(player_pos, player_radius, obstacle.pos, obstacle.size);
}

// Process all collisions for a zone
pub fn processCollisions(world: *entities.World) void {
    const zone = world.getCurrentZone();
    const player = &world.player;

    // Skip player collisions if dead
    if (!player.alive) return;

    // Player-Unit collisions
    for (0..zone.unit_count) |i| {
        if (checkPlayerUnitCollision(player, &zone.units[i])) {
            // Player dies on unit contact
            return; // Caller should handle player death
        }
    }

    // Player-Obstacle collisions (handled in movement to prevent penetration)
    // These are checked before movement is applied

    // Player-Portal collisions
    for (0..zone.portal_count) |i| {
        if (checkPlayerPortalCollision(player, &zone.portals[i])) {
            // Portal collision detected - caller handles zone travel
            return;
        }
    }

    // Player-Lifestone collisions
    for (0..zone.lifestone_count) |i| {
        if (checkPlayerLifestoneCollision(player, &zone.lifestones[i])) {
            if (!zone.lifestones[i].attuned) {
                // Lifestone collision detected - caller handles attunement
                return;
            }
        }
    }
}

// Process bullet collisions
pub fn processBulletCollisions(world: *entities.World) void {
    const zone = world.getCurrentZoneMut();

    for (0..entities.MAX_BULLETS) |i| {
        if (!world.bullets[i].active) continue;

        const bullet = &world.bullets[i];

        // Check collision with obstacles first (bullets destroyed on contact)
        for (0..zone.obstacle_count) |j| {
            const obstacle = &zone.obstacles[j];
            if (!obstacle.active) continue;

            if (checkCircleRectCollision(bullet.pos, bullet.radius, obstacle.pos, obstacle.size)) {
                bullet.active = false;
                break; // Bullet destroyed, no need to check other collisions
            }
        }

        // If bullet still active, check collision with units
        if (!bullet.active) continue;

        for (0..zone.unit_count) |j| {
            const unit = &zone.units[j];
            // Skip dead/inactive units before expensive collision check
            if (!unit.active or !unit.alive) continue;

            if (checkCircleCollision(bullet.pos, bullet.radius, unit.pos, unit.radius)) {
                bullet.active = false;
                unit.alive = false;
                unit.color = .{ .r = 100, .g = 100, .b = 100, .a = 255 }; // GRAY
                break; // Bullet can only hit one unit
            }
        }
    }
}

// Check if position would collide with any blocking obstacle
pub fn wouldCollideWithObstacle(pos: Vec2, radius: f32, zone: *const entities.Zone) bool {
    for (0..zone.obstacle_count) |i| {
        const obstacle = &zone.obstacles[i];
        if (!obstacle.active or obstacle.is_deadly) continue; // Only check blocking obstacles

        if (checkCircleRectCollision(pos, radius, obstacle.pos, obstacle.size)) {
            return true;
        }
    }
    return false;
}

// Check if position collides with deadly obstacle using ECS queries
pub fn collidesWithDeadlyObstacle(pos: Vec2, radius: f32, world: *const hex_world.HexWorld) bool {
    // Query all terrain entities for deadly obstacles (pit terrain type)
    const ecs_world = world.getECSWorld();
    var terrain_iter = @constCast(&ecs_world.terrains).iterator();
    
    while (terrain_iter.next()) |entry| {
        const entity_id = entry.key_ptr.*;
        const terrain = entry.value_ptr.*;
        
        // Only check deadly obstacles (pit terrain)
        if (terrain.terrain_type != .pit) continue;
        
        // Get transform component for position and collision
        if (ecs_world.transforms.getConst(entity_id)) |transform| {
            // Convert from circular collision to rectangular
            const half_size = transform.radius;
            const obstacle_size = Vec2{ .x = half_size * 2, .y = half_size * 2 };
            
            if (checkCircleRectCollision(pos, radius, transform.pos, obstacle_size)) {
                return true;
            }
        }
    }
    return false;
}

// Find nearest attuned lifestone across all zones
pub const LifestoneResult = struct {
    zone_index: usize,
    pos: Vec2,
};

pub fn findNearestAttunedLifestone(world: *const hex_world.HexWorld) ?LifestoneResult {
    const current_pos = world.getPlayerPosConst();
    var nearest_distance: f32 = std.math.floatMax(f32);
    var nearest_lifestone: ?LifestoneResult = null;

    // Query all lifestone entities using ECS
    const ecs_world = world.getECSWorld();
    var terrain_iter = @constCast(&ecs_world.terrains).iterator();
    
    while (terrain_iter.next()) |entry| {
        const entity_id = entry.key_ptr.*;
        const terrain = entry.value_ptr.*;
        
        // Only check lifestones (altar terrain with interactable component)
        if (terrain.terrain_type != .altar) continue;
        if (!ecs_world.interactables.has(entity_id)) continue;
        
        // Get components
        if (ecs_world.transforms.getConst(entity_id)) |transform| {
            if (ecs_world.interactables.getConst(entity_id)) |interactable| {
                // Check if lifestone is attuned (using transformable state as attuned indicator)
                if (interactable.interaction_type != .transformable) continue;
                // TODO: Add proper attuned state to Interactable component
                // For now, assume all transformable lifestones are attuned
                
                const dx = current_pos.x - transform.pos.x;
                const dy = current_pos.y - transform.pos.y;
                const distance = dx * dx + dy * dy;
                
                if (distance < nearest_distance) {
                    nearest_distance = distance;
                    nearest_lifestone = LifestoneResult{
                        .zone_index = world.current_zone, // TODO: Get actual zone from entity
                        .pos = transform.pos,
                    };
                }
            }
        }
    }

    return nearest_lifestone;
}

// Check unit collision with obstacles using ECS queries
pub fn checkUnitObstacleCollisionECS(
    world: *hex_world.HexWorld,
    unit_id: ecs.EntityId,
    transform: *ecs.components.Transform,
    health: *ecs.components.Health,
    old_pos: Vec2
) bool {
    const ecs_world = world.getECSWorldMut();
    var terrain_iter = @constCast(&ecs_world.terrains).iterator();
    
    while (terrain_iter.next()) |entry| {
        const obstacle_id = entry.key_ptr.*;
        const terrain = entry.value_ptr.*;
        
        // Only check obstacles (wall/pit terrain)
        if (terrain.terrain_type != .wall and terrain.terrain_type != .pit) continue;
        
        // Get obstacle transform
        if (ecs_world.transforms.getConst(obstacle_id)) |obstacle_transform| {
            // Convert from circular collision to rectangular
            const half_size = obstacle_transform.radius;
            const obstacle_size = Vec2{ .x = half_size * 2, .y = half_size * 2 };
            
            if (checkCircleRectCollision(transform.pos, transform.radius, obstacle_transform.pos, obstacle_size)) {
                if (terrain.terrain_type == .pit) {
                    // Unit dies on deadly obstacle
                    health.alive = false;
                    // Update visual color to indicate death
                    if (ecs_world.visuals.get(unit_id)) |visual| {
                        visual.color = constants.COLOR_DEAD;
                    }
                } else {
                    // Revert position for blocking obstacles
                    transform.pos = old_pos;
                }
                return true; // Collision occurred
            }
        }
    }
    return false; // No collision
}

// Check if player can move to a position without colliding with obstacles
pub fn canPlayerMoveTo(world: *const hex_world.HexWorld, new_pos: Vec2, player_radius: f32) bool {
    const ecs_world = world.getECSWorld();
    const current_zone = &world.zones[world.current_zone];
    
    // Only check obstacles in the current zone
    for (current_zone.obstacle_entities.items) |obstacle_id| {
        // Check if entity is still alive
        if (!@constCast(ecs_world).isAlive(obstacle_id)) continue;
        
        // Get terrain component
        if (ecs_world.terrains.getConst(obstacle_id)) |terrain| {
            // Only check wall obstacles (walls block movement, pits don't prevent movement but kill on contact)
            if (terrain.terrain_type != .wall) continue;
            
            // Get obstacle transform
            if (ecs_world.transforms.getConst(obstacle_id)) |obstacle_transform| {
                // Convert from circular collision to rectangular
                const half_size = obstacle_transform.radius;
                const obstacle_size = Vec2{ .x = half_size * 2, .y = half_size * 2 };
                
                if (checkCircleRectCollision(new_pos, player_radius, obstacle_transform.pos, obstacle_size)) {
                    return false; // Collision detected, cannot move
                }
            }
        }
    }
    
    return true; // No collision, can move
}

// Check player collision with portal using ECS transform component
pub fn checkPlayerPortalCollisionECS(player_pos: Vec2, player_radius: f32, portal_transform: *const ecs.components.Transform) bool {
    return checkCircleCollision(player_pos, player_radius, portal_transform.pos, portal_transform.radius);
}
