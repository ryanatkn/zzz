//! Point collision detection functions
//!
//! All collision detection involving points, including point-point and point-line collisions.

const std = @import("std");
const math = @import("../../../math/mod.zig");
const types = @import("../types.zig");

const Vec2 = math.Vec2;
const Point = types.Point;
const LineSegment = types.LineSegment;
const CollisionResult = types.CollisionResult;
const FLOATING_POINT_TOLERANCE = types.FLOATING_POINT_TOLERANCE;
const LINE_THICKNESS_TOLERANCE = types.LINE_THICKNESS_TOLERANCE;

/// Point-point collision detection (exact match)
pub fn pointPoint(p1: Point, p2: Point) bool {
    return p1.equals(p2, FLOATING_POINT_TOLERANCE);
}

/// Point-line collision detection
pub fn pointLine(point: Point, line: LineSegment) bool {
    const distance = line.distanceToPoint(point);
    return distance <= LINE_THICKNESS_TOLERANCE;
}

/// Detailed point-point collision
pub fn pointPointDetailed(p1: Point, p2: Point) CollisionResult {
    const distance = math.distance(p1, p2);
    const tolerance = FLOATING_POINT_TOLERANCE;

    if (distance > tolerance) {
        return CollisionResult{ .collided = false };
    }

    return CollisionResult{
        .collided = true,
        .penetration_depth = tolerance - distance,
        .normal = Vec2{ .x = 1, .y = 0 }, // Arbitrary normal for point collision
        .contact_point = p1,
    };
}

/// Detailed point-line collision
pub fn pointLineDetailed(point: Point, line: LineSegment) CollisionResult {
    const distance = line.distanceToPoint(point);
    const tolerance = LINE_THICKNESS_TOLERANCE;

    if (distance > tolerance) {
        return CollisionResult{ .collided = false };
    }

    const closest_point = line.closestPointTo(point);
    const normal = if (math.distance(point, closest_point) > FLOATING_POINT_TOLERANCE)
        math.directionBetween(closest_point, point)
    else
        Vec2.init(0.0, 1.0); // Default normal

    return CollisionResult{
        .collided = true,
        .penetration_depth = tolerance - distance,
        .normal = normal,
        .contact_point = closest_point,
    };
}

// Tests for point collision functions
test "point-point collision detection" {
    const p1 = Vec2.init(5.0, 5.0);
    const p2 = Vec2.init(5.0, 5.0);
    const p3 = Vec2.init(5.0001, 5.0);
    const p4 = Vec2.init(10.0, 10.0);

    // Same point
    try std.testing.expect(pointPoint(p1, p2));

    // Very close points (within tolerance)
    try std.testing.expect(pointPoint(p1, p3));

    // Distant points
    try std.testing.expect(!pointPoint(p1, p4));
}

test "point-line collision detection" {
    const line = LineSegment.init(Vec2.init(0.0, 0.0), Vec2.init(10.0, 10.0));
    const point_on = Vec2.init(5.0, 5.0);
    const point_near = Vec2.init(5.1, 4.9); // Close to line
    const point_far = Vec2.init(0.0, 10.0); // Far from line

    // Point on line
    try std.testing.expect(pointLine(point_on, line));

    // Point near line (within tolerance)
    try std.testing.expect(pointLine(point_near, line));

    // Point far from line
    try std.testing.expect(!pointLine(point_far, line));
}

test "detailed point collision results" {
    const p1 = Vec2.init(5.0, 5.0);
    const p2 = Vec2.init(5.0, 5.0);
    const p3 = Vec2.init(10.0, 10.0);

    // Same points should have minimal penetration
    const result1 = pointPointDetailed(p1, p2);
    try std.testing.expect(result1.collided);
    try std.testing.expect(result1.penetration_depth >= 0.0);

    // Distant points
    const result2 = pointPointDetailed(p1, p3);
    try std.testing.expect(!result2.collided);
}

test "detailed point-line collision" {
    const line = LineSegment.init(Vec2.init(0.0, 0.0), Vec2.init(10.0, 10.0));
    const point_on = Vec2.init(5.0, 5.0);
    const point_far = Vec2.init(0.0, 10.0);

    // Point on line should have collision
    const result1 = pointLineDetailed(point_on, line);
    try std.testing.expect(result1.collided);
    try std.testing.expect(result1.penetration_depth >= 0.0);

    // Point far from line
    const result2 = pointLineDetailed(point_far, line);
    try std.testing.expect(!result2.collided);
}
