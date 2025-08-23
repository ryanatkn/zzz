//! Rectangle collision detection functions
//!
//! All collision detection involving rectangles, including rectangle-rectangle,
//! rectangle-point, and rectangle-line collisions.

const std = @import("std");
const math = @import("../../../math/mod.zig");
const types = @import("../types.zig");

const Vec2 = math.Vec2;
const Rectangle = types.Rectangle;
const Point = types.Point;
const LineSegment = types.LineSegment;
const CollisionResult = types.CollisionResult;
const FLOATING_POINT_TOLERANCE = types.FLOATING_POINT_TOLERANCE;

// Need line intersection function for rectangle-line collision
const lineLineIntersect = @import("line.zig").lineLineIntersect;

/// Rectangle-rectangle collision detection (AABB)
pub fn rectangleRectangle(r1: Rectangle, r2: Rectangle) bool {
    // Input validation - rectangles must have non-negative dimensions
    if (r1.size.x < 0.0 or r1.size.y < 0.0 or r2.size.x < 0.0 or r2.size.y < 0.0) {
        return false;
    }

    return r1.position.x < r2.position.x + r2.size.x and
        r1.position.x + r1.size.x > r2.position.x and
        r1.position.y < r2.position.y + r2.size.y and
        r1.position.y + r1.size.y > r2.position.y;
}

/// Rectangle-point collision detection
pub fn rectanglePoint(rect: Rectangle, point: Point) bool {
    // Input validation - rectangle must have non-negative dimensions
    if (rect.size.x < 0.0 or rect.size.y < 0.0) {
        return false;
    }

    return rect.contains(point);
}

/// Rectangle-line collision detection (AABB vs line segment)
pub fn rectangleLine(rect: Rectangle, line: LineSegment) bool {
    // Input validation - rectangle must have non-negative dimensions, line must not be degenerate
    if (rect.size.x < 0.0 or rect.size.y < 0.0) {
        return false;
    }

    const line_length = line.start.distanceSquared(line.end);
    if (line_length < FLOATING_POINT_TOLERANCE) {
        return false; // Degenerate line
    }

    // Check if line endpoints are inside rectangle
    if (rect.contains(line.start) or rect.contains(line.end)) {
        return true;
    }

    // Check if line intersects any rectangle edge
    const rect_lines = [_]LineSegment{
        LineSegment.init(rect.position, Vec2.init(rect.position.x + rect.size.x, rect.position.y)),
        LineSegment.init(Vec2.init(rect.position.x + rect.size.x, rect.position.y), rect.position.add(rect.size)),
        LineSegment.init(rect.position.add(rect.size), Vec2.init(rect.position.x, rect.position.y + rect.size.y)),
        LineSegment.init(Vec2.init(rect.position.x, rect.position.y + rect.size.y), rect.position),
    };

    for (rect_lines) |rect_line| {
        if (lineLineIntersect(line, rect_line)) {
            return true;
        }
    }

    return false;
}

/// Detailed rectangle-rectangle collision
pub fn rectangleRectangleDetailed(r1: Rectangle, r2: Rectangle) CollisionResult {
    if (!rectangleRectangle(r1, r2)) {
        return CollisionResult{ .collided = false };
    }

    // Calculate overlap amounts
    const overlap_x = @min(r1.position.x + r1.size.x, r2.position.x + r2.size.x) - @max(r1.position.x, r2.position.x);
    const overlap_y = @min(r1.position.y + r1.size.y, r2.position.y + r2.size.y) - @max(r1.position.y, r2.position.y);

    // Use minimum overlap as penetration depth
    const penetration = @min(overlap_x, overlap_y);

    // Normal points from r1 to r2 along minimum separation axis
    const normal = if (overlap_x < overlap_y)
        Vec2{ .x = if (r1.center().x < r2.center().x) @as(f32, -1) else 1, .y = 0 }
    else
        Vec2{ .x = 0, .y = if (r1.center().y < r2.center().y) @as(f32, -1) else 1 };

    const contact_x = @max(r1.position.x, r2.position.x) + overlap_x / 2.0;
    const contact_y = @max(r1.position.y, r2.position.y) + overlap_y / 2.0;

    return CollisionResult{
        .collided = true,
        .penetration_depth = penetration,
        .normal = normal,
        .contact_point = Vec2{ .x = contact_x, .y = contact_y },
    };
}

/// Detailed rectangle-point collision
pub fn rectanglePointDetailed(rect: Rectangle, point: Point) CollisionResult {
    // Input validation - rectangle must have non-negative dimensions
    if (rect.size.x < 0.0 or rect.size.y < 0.0) {
        return CollisionResult{ .collided = false };
    }

    if (!rect.contains(point)) {
        return CollisionResult{ .collided = false };
    }

    // Calculate distances to each edge
    const left_dist = point.x - rect.position.x;
    const right_dist = (rect.position.x + rect.size.x) - point.x;
    const top_dist = point.y - rect.position.y;
    const bottom_dist = (rect.position.y + rect.size.y) - point.y;

    // Find minimum distance (penetration depth)
    const min_dist = @min(@min(left_dist, right_dist), @min(top_dist, bottom_dist));

    // Normal points away from closest edge
    const normal = if (min_dist == left_dist) Vec2{ .x = -1, .y = 0 } else if (min_dist == right_dist) Vec2{ .x = 1, .y = 0 } else if (min_dist == top_dist) Vec2{ .x = 0, .y = -1 } else Vec2{ .x = 0, .y = 1 };

    return CollisionResult{
        .collided = true,
        .penetration_depth = min_dist,
        .normal = normal,
        .contact_point = point,
    };
}

/// Detailed rectangle-line collision
pub fn rectangleLineDetailed(rect: Rectangle, line: LineSegment) CollisionResult {
    if (!rectangleLine(rect, line)) {
        return CollisionResult{ .collided = false };
    }

    // For simplicity, use basic collision info
    // A full implementation would calculate precise penetration depth
    return CollisionResult{
        .collided = true,
        .penetration_depth = 1.0, // Minimal penetration
        .normal = Vec2.init(0.0, -1.0), // Default up normal
        .contact_point = line.midpoint(),
    };
}

// Tests for rectangle collision functions
test "rectangle-rectangle collision detection" {
    const r1 = Rectangle.fromXYWH(0.0, 0.0, 10.0, 10.0);
    const r2 = Rectangle.fromXYWH(5.0, 5.0, 10.0, 10.0);
    const r3 = Rectangle.fromXYWH(20.0, 20.0, 10.0, 10.0);
    const r4 = Rectangle.fromXYWH(10.0, 0.0, 10.0, 10.0);

    // Overlapping rectangles
    try std.testing.expect(rectangleRectangle(r1, r2));

    // Non-overlapping rectangles
    try std.testing.expect(!rectangleRectangle(r1, r3));

    // Edge-touching rectangles
    try std.testing.expect(!rectangleRectangle(r1, r4));

    // Same rectangle
    try std.testing.expect(rectangleRectangle(r1, r1));
}

test "rectangle-point collision detection" {
    const rect = Rectangle.fromXYWH(10.0, 10.0, 20.0, 20.0);
    const inside_point = Vec2.init(15.0, 15.0);
    const outside_point = Vec2.init(5.0, 5.0);
    const edge_point = Vec2.init(10.0, 15.0);

    try std.testing.expect(rectanglePoint(rect, inside_point));
    try std.testing.expect(!rectanglePoint(rect, outside_point));
    try std.testing.expect(rectanglePoint(rect, edge_point));
}

test "rectangle-line collision detection" {
    const rect = Rectangle.fromXYWH(5.0, 5.0, 10.0, 10.0);
    const line_through = LineSegment.init(Vec2.init(0.0, 10.0), Vec2.init(20.0, 10.0));
    const line_inside = LineSegment.init(Vec2.init(7.0, 7.0), Vec2.init(13.0, 13.0));
    const line_outside = LineSegment.init(Vec2.init(0.0, 0.0), Vec2.init(3.0, 3.0));

    // Line intersecting rectangle
    try std.testing.expect(rectangleLine(rect, line_through));

    // Line entirely inside rectangle
    try std.testing.expect(rectangleLine(rect, line_inside));

    // Line outside rectangle
    try std.testing.expect(!rectangleLine(rect, line_outside));
}

test "rectangle edge cases and boundary conditions" {

    // Zero size rectangle
    const zero_rect = Rectangle.fromXYWH(0.0, 0.0, 0.0, 0.0);
    const point = Vec2.init(0.0, 0.0);

    // Point at zero-size rectangle origin should be contained
    try std.testing.expect(rectanglePoint(zero_rect, point));
}

test "detailed rectangle collision results" {
    const r1 = Rectangle.fromXYWH(0.0, 0.0, 10.0, 10.0);
    const r2 = Rectangle.fromXYWH(5.0, 5.0, 10.0, 10.0);
    const r3 = Rectangle.fromXYWH(20.0, 20.0, 10.0, 10.0);

    // Overlapping rectangles should have penetration depth
    const result1 = rectangleRectangleDetailed(r1, r2);
    try std.testing.expect(result1.collided);
    try std.testing.expect(result1.penetration_depth > 0.0);

    // Non-overlapping rectangles
    const result2 = rectangleRectangleDetailed(r1, r3);
    try std.testing.expect(!result2.collided);
    try std.testing.expect(result2.penetration_depth == 0.0);
}
