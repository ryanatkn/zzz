//! Line collision detection functions
//!
//! All collision detection involving line segments, including line-line intersections
//! and utility functions used by other collision modules.

const std = @import("std");
const math = @import("../../../math/mod.zig");
const types = @import("../types.zig");

const Vec2 = math.Vec2;
const LineSegment = types.LineSegment;
const CollisionResult = types.CollisionResult;
const FLOATING_POINT_TOLERANCE = types.FLOATING_POINT_TOLERANCE;
const PARALLEL_LINE_TOLERANCE = types.PARALLEL_LINE_TOLERANCE;

/// Line-line intersection detection using parametric line equations
///
/// Determines if two line segments intersect using cross product calculations.
/// Handles edge cases including:
/// - Degenerate lines (zero length)
/// - Parallel lines
/// - Coincident lines
///
/// Algorithm uses parametric representation: P = start + t * (end - start)
/// Lines intersect if both parameters t1 and t2 are in range [0, 1].
///
/// Example:
/// ```zig
/// const line1 = LineSegment.init(Vec2.init(0, 0), Vec2.init(10, 10));
/// const line2 = LineSegment.init(Vec2.init(0, 10), Vec2.init(10, 0));
/// const intersecting = lineLineIntersect(line1, line2); // true (cross at center)
/// ```
pub fn lineLineIntersect(line1: LineSegment, line2: LineSegment) bool {
    // Input validation - check for degenerate lines
    const d1 = line1.end.sub(line1.start);
    const d2 = line2.end.sub(line2.start);

    // Degenerate lines (zero length) cannot intersect meaningfully
    if (d1.lengthSquared() < FLOATING_POINT_TOLERANCE or d2.lengthSquared() < FLOATING_POINT_TOLERANCE) {
        return false;
    }

    const start_diff = line2.start.sub(line1.start);
    const denominator = types.vec2Cross(d1, d2);

    // Lines are parallel (or coincident)
    if (@abs(denominator) < PARALLEL_LINE_TOLERANCE) {
        return false;
    }

    // Calculate parameters for intersection
    const t1 = types.vec2Cross(start_diff, d2) / denominator;
    const t2 = types.vec2Cross(start_diff, d1) / denominator;

    // Check if intersection point is within both line segments
    return (t1 >= 0.0 and t1 <= 1.0) and (t2 >= 0.0 and t2 <= 1.0);
}

/// Detailed line-line intersection
pub fn lineLineDetailed(line1: LineSegment, line2: LineSegment) CollisionResult {
    if (!lineLineIntersect(line1, line2)) {
        return CollisionResult{ .collided = false };
    }

    // For line-line intersection, find the intersection point
    const d1 = line1.end.sub(line1.start);
    const d2 = line2.end.sub(line2.start);
    const start_diff = line2.start.sub(line1.start);

    const denominator = types.vec2Cross(d1, d2);
    const t1 = types.vec2Cross(start_diff, d2) / denominator;

    const intersection_point = line1.start.add(d1.scale(t1));

    return CollisionResult{
        .collided = true,
        .penetration_depth = 0.01, // Minimal overlap for intersection
        .normal = d1.perpendicular().normalize(), // Perpendicular to line1
        .contact_point = intersection_point,
    };
}

// Tests for line collision functions
test "line-line intersection detection" {
    const line1 = LineSegment.init(Vec2.init(0.0, 0.0), Vec2.init(10.0, 10.0));
    const line2 = LineSegment.init(Vec2.init(0.0, 10.0), Vec2.init(10.0, 0.0));
    const line3 = LineSegment.init(Vec2.init(15.0, 15.0), Vec2.init(20.0, 20.0));
    const parallel_line = LineSegment.init(Vec2.init(1.0, 1.0), Vec2.init(11.0, 11.0));

    // Intersecting lines
    try std.testing.expect(lineLineIntersect(line1, line2));

    // Non-intersecting lines
    try std.testing.expect(!lineLineIntersect(line1, line3));

    // Parallel lines
    try std.testing.expect(!lineLineIntersect(line1, parallel_line));
}

test "degenerate line cases" {
    const normal_line = LineSegment.init(Vec2.init(0.0, 0.0), Vec2.init(10.0, 10.0));
    const degenerate_line = LineSegment.init(Vec2.init(5.0, 5.0), Vec2.init(5.0, 5.0));

    // Degenerate line (zero length) should not intersect
    try std.testing.expect(!lineLineIntersect(normal_line, degenerate_line));
    try std.testing.expect(!lineLineIntersect(degenerate_line, normal_line));
}

test "detailed line-line collision" {
    const line1 = LineSegment.init(Vec2.init(0.0, 0.0), Vec2.init(10.0, 10.0));
    const line2 = LineSegment.init(Vec2.init(0.0, 10.0), Vec2.init(10.0, 0.0));
    const line3 = LineSegment.init(Vec2.init(15.0, 15.0), Vec2.init(20.0, 20.0));

    // Intersecting lines should have collision point
    const result1 = lineLineDetailed(line1, line2);
    try std.testing.expect(result1.collided);
    try std.testing.expect(result1.penetration_depth > 0.0);

    // Non-intersecting lines
    const result2 = lineLineDetailed(line1, line3);
    try std.testing.expect(!result2.collided);
}
