const std = @import("std");

const entities = @import("entities.zig");
const types = @import("../lib/core/types.zig");
const maths = @import("../lib/core/maths.zig");
const collision = @import("../lib/physics/collision.zig");
const hex_world = @import("hex_world.zig");

const Vec2 = types.Vec2;

// Check circle-circle collision (now using shared math functions)
pub fn checkCircleCollision(pos1: Vec2, radius1: f32, pos2: Vec2, radius2: f32) bool {
    const distance_sq = maths.distanceSquared(pos1, pos2);
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

// Check if position collides with deadly obstacle
pub fn collidesWithDeadlyObstacle(pos: Vec2, radius: f32, zone: *const hex_world.HexWorld.Zone) bool {
    for (0..zone.obstacle_count) |i| {
        const obstacle = &zone.obstacles.items[i];
        if (!obstacle.active or !obstacle.is_deadly) continue; // Only check deadly obstacles

        if (checkCircleRectCollision(pos, radius, obstacle.pos, obstacle.size)) {
            return true;
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

    // First check current zone
    const current_zone = world.getCurrentZoneConst();
    for (0..current_zone.lifestone_count) |i| {
        const lifestone = &current_zone.lifestones.items[i];
        if (!lifestone.active or !lifestone.attuned) continue;

        const dx = current_pos.x - lifestone.pos.x;
        const dy = current_pos.y - lifestone.pos.y;
        const distance = dx * dx + dy * dy;

        if (distance < nearest_distance) {
            nearest_distance = distance;
            nearest_lifestone = LifestoneResult{
                .zone_index = world.current_zone,
                .pos = lifestone.pos,
            };
        }
    }

    // If found in current zone, return it
    if (nearest_lifestone != null) {
        return nearest_lifestone;
    }

    // Otherwise, search other zones with distance penalty
    for (world.zones, 0..) |zone, zone_idx| {
        if (zone_idx == world.current_zone) continue;

        for (0..zone.lifestone_count) |i| {
            const lifestone = &zone.lifestones.items[i];
            if (!lifestone.active or !lifestone.attuned) continue;

            // Add penalty for being in different zone
            const dx = current_pos.x - lifestone.pos.x;
            const dy = current_pos.y - lifestone.pos.y;
            const distance = (dx * dx + dy * dy) + 1000000.0; // Large penalty

            if (distance < nearest_distance) {
                nearest_distance = distance;
                nearest_lifestone = LifestoneResult{
                    .zone_index = zone_idx,
                    .pos = lifestone.pos,
                };
            }
        }
    }

    return nearest_lifestone;
}
