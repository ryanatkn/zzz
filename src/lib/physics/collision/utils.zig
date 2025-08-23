//! High-level collision utility functions
//!
//! Convenience functions for common collision queries and operations
//! built on top of the primitive collision detection functions.

const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("types.zig");
const detection = @import("detection.zig");
const detailed = @import("detailed.zig");

const Vec2 = math.Vec2;
const Shape = types.Shape;
const Circle = types.Circle;
const CollisionResult = types.CollisionResult;
const MOVING_COLLISION_STEPS = types.MOVING_COLLISION_STEPS;
const COLLISION_RESOLUTION_BUFFER = types.COLLISION_RESOLUTION_BUFFER;

/// Check if a position is safe to move to (no collisions with obstacles)
pub fn isPositionSafe(
    pos: Vec2,
    radius: f32,
    obstacles: []const Shape,
) bool {
    const entity_shape = Shape{ .circle = .{ .center = pos, .radius = radius } };

    for (obstacles) |obstacle| {
        if (detection.checkCollision(entity_shape, obstacle)) {
            return false;
        }
    }
    return true;
}

/// Find the nearest obstacle to a position
pub fn findNearestObstacle(
    pos: Vec2,
    obstacles: []const Shape,
) ?struct { index: usize, distance_sq: f32 } {
    var nearest_index: ?usize = null;
    var nearest_distance_sq: f32 = std.math.inf(f32);

    for (obstacles, 0..) |obstacle, i| {
        const obstacle_center = switch (obstacle) {
            .circle => |c| c.center,
            .rectangle => |r| r.center(),
            .point => |p| p,
            .line => continue, // Skip line segments for now
        };

        const dist_sq = math.distanceSquared(pos, obstacle_center);
        if (dist_sq < nearest_distance_sq) {
            nearest_distance_sq = dist_sq;
            nearest_index = i;
        }
    }

    if (nearest_index) |index| {
        return .{ .index = index, .distance_sq = nearest_distance_sq };
    }
    return null;
}

/// Check collision between a moving circle and static obstacles
pub fn checkMovingCircleCollision(
    start_pos: Vec2,
    end_pos: Vec2,
    radius: f32,
    obstacles: []const Shape,
) ?Vec2 {
    // Simple approach: check multiple points along the path
    const step_count = MOVING_COLLISION_STEPS;
    const step = end_pos.sub(start_pos).scale(1.0 / @as(f32, @floatFromInt(step_count)));

    var current_pos = start_pos;
    for (0..step_count + 1) |_| {
        if (!isPositionSafe(current_pos, radius, obstacles)) {
            return current_pos; // First collision point
        }
        current_pos = current_pos.add(step);
    }

    return null; // No collision
}

/// Resolve collision by pushing an entity out of an obstacle
pub fn resolveCollision(
    entity_pos: Vec2,
    entity_radius: f32,
    obstacle: Shape,
) ?Vec2 {
    const entity_shape = Shape{ .circle = .{ .center = entity_pos, .radius = entity_radius } };
    const result = detailed.checkCollisionDetailed(entity_shape, obstacle);

    if (!result.collided) return null;

    // Push entity out along collision normal (reverse direction to push away from obstacle)
    const push_distance = result.penetration_depth + COLLISION_RESOLUTION_BUFFER;
    const corrected_pos = entity_pos.add(result.normal.scale(-push_distance));

    return corrected_pos;
}

// Tests for collision utility functions
test "position safety checks" {
    const obstacles = [_]Shape{
        Shape{ .circle = types.Circle{ .center = Vec2.init(10.0, 10.0), .radius = 5.0 } },
        Shape{ .rectangle = types.Rectangle.fromXYWH(20.0, 20.0, 10.0, 10.0) },
    };

    // Safe position
    try std.testing.expect(isPositionSafe(Vec2.init(0.0, 0.0), 2.0, &obstacles));

    // Unsafe position (inside circle)
    try std.testing.expect(!isPositionSafe(Vec2.init(10.0, 10.0), 2.0, &obstacles));

    // Unsafe position (inside rectangle)
    try std.testing.expect(!isPositionSafe(Vec2.init(25.0, 25.0), 2.0, &obstacles));
}

test "find nearest obstacle" {
    const obstacles = [_]Shape{
        Shape{ .circle = types.Circle{ .center = Vec2.init(10.0, 10.0), .radius = 5.0 } },
        Shape{ .circle = types.Circle{ .center = Vec2.init(50.0, 50.0), .radius = 3.0 } },
        Shape{ .rectangle = types.Rectangle.fromXYWH(20.0, 20.0, 10.0, 10.0) },
    };

    const query_pos = Vec2.init(5.0, 5.0);
    const result = findNearestObstacle(query_pos, &obstacles);

    try std.testing.expect(result != null);
    if (result) |r| {
        try std.testing.expect(r.index == 0); // Should be the first circle (closest)
    }
}

test "moving circle collision detection" {
    const obstacles = [_]Shape{
        Shape{ .circle = types.Circle{ .center = Vec2.init(10.0, 0.0), .radius = 3.0 } },
    };

    const start_pos = Vec2.init(0.0, 0.0);
    const end_pos = Vec2.init(20.0, 0.0);
    const radius = 2.0;

    // Should detect collision as path goes through obstacle
    const collision_point = checkMovingCircleCollision(start_pos, end_pos, radius, &obstacles);
    try std.testing.expect(collision_point != null);

    // Path that clearly avoids obstacle (going higher)
    const safe_end = Vec2.init(20.0, 15.0);
    const safe_collision = checkMovingCircleCollision(start_pos, safe_end, radius, &obstacles);
    try std.testing.expect(safe_collision == null);
}

test "collision resolution" {
    const obstacle = Shape{ .circle = types.Circle{ .center = Vec2.init(10.0, 0.0), .radius = 5.0 } };
    const entity_pos = Vec2.init(8.0, 0.0);
    const entity_radius = 3.0;

    // Entity overlapping obstacle should be pushed out
    const resolved_pos = resolveCollision(entity_pos, entity_radius, obstacle);
    try std.testing.expect(resolved_pos != null);

    if (resolved_pos) |pos| {
        // Resolved position should be further from obstacle center
        const original_dist = math.distance(entity_pos, obstacle.circle.center);
        const resolved_dist = math.distance(pos, obstacle.circle.center);
        try std.testing.expect(resolved_dist > original_dist);

        // Should no longer be colliding
        const entity_shape = Shape{ .circle = .{ .center = pos, .radius = entity_radius } };
        try std.testing.expect(!detection.checkCollision(entity_shape, obstacle));
    }
}
