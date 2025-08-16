const std = @import("std");
const HexGame = @import("hex_game.zig").HexGame;
const math = @import("../lib/math/mod.zig");
const collision = @import("../lib/physics/collision.zig");
const Vec2 = math.Vec2;

// Check circle-circle collision
pub fn checkCircleCollision(center1: Vec2, radius1: f32, center2: Vec2, radius2: f32) bool {
    const to_center = math.vec2_subtract(center2, center1);
    const distance_sq = math.vec2_lengthSquared(to_center);
    const radius_sum = radius1 + radius2;
    return distance_sq < radius_sum * radius_sum;
}

// Check if player can move to position (obstacle collision)
pub fn canPlayerMoveTo(game: *HexGame, new_pos: Vec2, player_radius: f32) bool {
    const zone = game.getCurrentZone();
    
    // Direct iteration over obstacles in current zone
    for (0..zone.obstacles.count) |i| {
        const terrain = &zone.obstacles.terrains[i];
        const transform = &zone.obstacles.transforms[i];
        
        // Only check solid terrain
        if (!terrain.solid) continue;
        
        // Check collision
        const circle = collision.Shape{ .circle = .{ .center = new_pos, .radius = player_radius } };
        const rect = collision.Shape{ .rectangle = .{ .position = transform.pos, .size = terrain.size } };
        if (collision.checkCollision(circle, rect)) {
            return false;
        }
    }
    return true;
}

// Check if position collides with deadly obstacles
pub fn collidesWithDeadlyObstacle(pos: Vec2, radius: f32, game: *HexGame) bool {
    const zone = game.getCurrentZone();
    
    for (0..zone.obstacles.count) |i| {
        const terrain = &zone.obstacles.terrains[i];
        const transform = &zone.obstacles.transforms[i];
        
        // Only check deadly terrain (pits)
        if (terrain.terrain_type != .pit) continue;
        
        const circle = collision.Shape{ .circle = .{ .center = pos, .radius = radius } };
        const rect = collision.Shape{ .rectangle = .{ .position = transform.pos, .size = terrain.size } };
        if (collision.checkCollision(circle, rect)) {
            return true;
        }
    }
    return false;
}

// Check lifestone collisions
pub fn checkLifestoneCollisions(game: *HexGame, player_pos: Vec2, player_radius: f32) void {
    const zone = game.getCurrentZone();
    
    for (0..zone.lifestones.count) |i| {
        const interactable = &zone.lifestones.interactables[i];
        const transform = &zone.lifestones.transforms[i];
        const visual = &zone.lifestones.visuals[i];
        
        // Skip already attuned lifestones
        if (interactable.attuned) continue;
        
        // Check collision
        if (checkCircleCollision(player_pos, player_radius, transform.pos, transform.radius)) {
            // Attune the lifestone
            interactable.attuned = true;
            
            // Update visual
            const constants = @import("constants.zig");
            visual.color = constants.COLOR_LIFESTONE_ATTUNED;
            
            std.log.info("Lifestone attuned at {any}!", .{transform.pos});
        }
    }
}

// Check portal collisions
pub fn checkPortalCollision(game: *HexGame, player_pos: Vec2, player_radius: f32) ?u8 {
    const zone = game.getCurrentZone();
    
    for (0..zone.portals.count) |i| {
        const transform = &zone.portals.transforms[i];
        const interactable = &zone.portals.interactables[i];
        
        if (checkCircleCollision(player_pos, player_radius, transform.pos, transform.radius)) {
            return interactable.destination_zone;
        }
    }
    return null;
}