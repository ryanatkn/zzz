//! Comprehensive edge case tests for collision detection
//!
//! Tests extreme values, precision limits, error conditions, and boundary cases
//! that might not be covered in the basic functionality tests.

const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("types.zig");
const detection = @import("detection.zig");
const detailed = @import("detailed.zig");
const primitives = @import("primitives/mod.zig");

const Vec2 = math.Vec2;
const Shape = types.Shape;
const Circle = types.Circle;
const Rectangle = types.Rectangle;
const Point = types.Point;
const LineSegment = types.LineSegment;
const CollisionResult = types.CollisionResult;

// Test extreme floating-point values
test "collision detection with extreme floating-point values" {
    // Very large values
    const huge_circle = Circle{ .center = Vec2.init(1e10, 1e10), .radius = 1e9 };
    const normal_circle = Circle{ .center = Vec2.init(9.5e9, 9.5e9), .radius = 1e8 };

    const huge_shape = Shape{ .circle = huge_circle };
    const normal_shape = Shape{ .circle = normal_circle };

    // Should still work correctly with large numbers
    const collides = detection.checkCollision(huge_shape, normal_shape);
    try std.testing.expect(collides); // These should overlap

    // Very small values
    const tiny_circle1 = Circle{ .center = Vec2.init(1e-6, 1e-6), .radius = 1e-7 };
    const tiny_circle2 = Circle{ .center = Vec2.init(1e-6 + 5e-8, 1e-6), .radius = 1e-7 };

    const tiny_shape1 = Shape{ .circle = tiny_circle1 };
    const tiny_shape2 = Shape{ .circle = tiny_circle2 };

    const tiny_collides = detection.checkCollision(tiny_shape1, tiny_shape2);
    try std.testing.expect(tiny_collides); // These should overlap
}

test "collision detection with zero-sized shapes" {
    // Zero radius circle
    const zero_circle = Circle{ .center = Vec2.init(0.0, 0.0), .radius = 0.0 };
    const normal_circle = Circle{ .center = Vec2.init(1.0, 0.0), .radius = 2.0 };

    // Zero circle inside normal circle should collide
    try std.testing.expect(primitives.circleCircle(zero_circle, normal_circle));

    // Zero circle outside normal circle should not collide
    const far_zero_circle = Circle{ .center = Vec2.init(10.0, 0.0), .radius = 0.0 };
    try std.testing.expect(!primitives.circleCircle(far_zero_circle, normal_circle));

    // Zero-size rectangle
    const zero_rect = Rectangle.fromXYWH(0.0, 0.0, 0.0, 0.0);
    const point_at_origin = Vec2.init(0.0, 0.0);
    const point_away = Vec2.init(1.0, 1.0);

    // Point at origin should be contained in zero-size rectangle at origin
    try std.testing.expect(primitives.rectanglePoint(zero_rect, point_at_origin));
    // Point away should not be contained
    try std.testing.expect(!primitives.rectanglePoint(zero_rect, point_away));
}

test "collision detection with negative dimensions" {
    // Negative radius should return false
    const negative_circle = Circle{ .center = Vec2.init(0.0, 0.0), .radius = -5.0 };
    const normal_circle = Circle{ .center = Vec2.init(0.0, 0.0), .radius = 5.0 };

    try std.testing.expect(!primitives.circleCircle(negative_circle, normal_circle));
    try std.testing.expect(!primitives.circleCircle(normal_circle, negative_circle));

    // Negative rectangle dimensions should return false
    const negative_rect = Rectangle{ .position = Vec2.init(0.0, 0.0), .size = Vec2.init(-10.0, 5.0) };
    const normal_rect = Rectangle.fromXYWH(0.0, 0.0, 10.0, 10.0);

    try std.testing.expect(!primitives.rectangleRectangle(negative_rect, normal_rect));
    try std.testing.expect(!primitives.rectangleRectangle(normal_rect, negative_rect));
}

test "detailed collision with extreme penetration" {
    // Circles with complete overlap (one inside the other)
    const small_circle = Circle{ .center = Vec2.init(0.0, 0.0), .radius = 2.0 };
    const large_circle = Circle{ .center = Vec2.init(0.0, 0.0), .radius = 10.0 };

    const small_shape = Shape{ .circle = small_circle };
    const large_shape = Shape{ .circle = large_circle };

    const result = detailed.checkCollisionDetailed(small_shape, large_shape);
    try std.testing.expect(result.collided);
    try std.testing.expect(result.penetration_depth == 12.0); // Sum of radii

    // Very slight overlap
    const circle1 = Circle{ .center = Vec2.init(0.0, 0.0), .radius = 5.0 };
    const circle2 = Circle{ .center = Vec2.init(9.99, 0.0), .radius = 5.0 };

    const shape1 = Shape{ .circle = circle1 };
    const shape2 = Shape{ .circle = circle2 };

    const slight_result = detailed.checkCollisionDetailed(shape1, shape2);
    try std.testing.expect(slight_result.collided);
    try std.testing.expect(slight_result.penetration_depth > 0.0);
    try std.testing.expect(slight_result.penetration_depth < 0.1); // Very small penetration
}

test "collision detection near floating-point precision limits" {
    const epsilon = std.math.floatEps(f32);

    // Circles separated by a small but measurable amount
    const circle1 = Circle{ .center = Vec2.init(0.0, 0.0), .radius = 1.0 };
    const circle2 = Circle{ .center = Vec2.init(2.0 + 1e-5, 0.0), .radius = 1.0 };

    // Should not collide (just barely separated)
    try std.testing.expect(!primitives.circleCircle(circle1, circle2));

    // Circles overlapping by epsilon
    const circle3 = Circle{ .center = Vec2.init(2.0 - epsilon, 0.0), .radius = 1.0 };

    // Should collide (just barely overlapping)
    try std.testing.expect(primitives.circleCircle(circle1, circle3));
}

test "line intersection with nearly parallel lines" {
    const tolerance = types.PARALLEL_LINE_TOLERANCE;

    // Lines that are almost parallel (within tolerance)
    const line1 = LineSegment.init(Vec2.init(0.0, 0.0), Vec2.init(10.0, 1.0));
    const almost_parallel = LineSegment.init(Vec2.init(0.0, 1.0), Vec2.init(10.0, 1.0 + tolerance * 0.5));

    // Should not intersect due to parallel tolerance
    try std.testing.expect(!primitives.lineLineIntersect(line1, almost_parallel));

    // Lines that actually intersect (diagonal crossing)
    const line2 = LineSegment.init(Vec2.init(0.0, 0.0), Vec2.init(10.0, 10.0));

    // Should intersect
    try std.testing.expect(primitives.lineLineIntersect(line1, line2));
}

test "collision detection with NaN and infinity handling" {
    // Create shapes with NaN coordinates
    const nan_circle = Circle{ .center = Vec2.init(std.math.nan(f32), 0.0), .radius = 5.0 };
    const normal_circle = Circle{ .center = Vec2.init(0.0, 0.0), .radius = 5.0 };

    // NaN should result in no collision (fail-safe behavior)
    try std.testing.expect(!primitives.circleCircle(nan_circle, normal_circle));

    // Create shapes with infinity coordinates
    const inf_circle = Circle{ .center = Vec2.init(std.math.inf(f32), 0.0), .radius = 5.0 };

    // Infinity should result in no collision (fail-safe behavior)
    try std.testing.expect(!primitives.circleCircle(inf_circle, normal_circle));

    // NaN radius
    const nan_radius_circle = Circle{ .center = Vec2.init(0.0, 0.0), .radius = std.math.nan(f32) };
    try std.testing.expect(!primitives.circleCircle(nan_radius_circle, normal_circle));
}

test "edge cases for point collision tolerance" {
    const tolerance = types.FLOATING_POINT_TOLERANCE;

    // Points exactly at tolerance distance
    const point1 = Vec2.init(0.0, 0.0);
    const point2 = Vec2.init(tolerance, 0.0);
    const point3 = Vec2.init(tolerance * 1.1, 0.0); // Just outside tolerance

    // Should collide within tolerance
    try std.testing.expect(primitives.pointPoint(point1, point2));

    // Should not collide outside tolerance
    try std.testing.expect(!primitives.pointPoint(point1, point3));
}

test "rectangle collision with zero-width or zero-height rectangles" {
    // Zero width rectangle (vertical line)
    const zero_width = Rectangle{ .position = Vec2.init(0.0, 0.0), .size = Vec2.init(0.0, 10.0) };
    const normal_rect = Rectangle.fromXYWH(-1.0, 5.0, 2.0, 2.0);

    // Should still detect collision if they overlap
    try std.testing.expect(primitives.rectangleRectangle(zero_width, normal_rect));

    // Zero height rectangle (horizontal line)
    const zero_height = Rectangle{ .position = Vec2.init(0.0, 0.0), .size = Vec2.init(10.0, 0.0) };
    const normal_rect2 = Rectangle.fromXYWH(5.0, -1.0, 2.0, 2.0);

    try std.testing.expect(primitives.rectangleRectangle(zero_height, normal_rect2));
}

test "circle-rectangle collision at corners and edges" {
    const rect = Rectangle.fromXYWH(0.0, 0.0, 10.0, 10.0);

    // Circle exactly touching corner
    const corner_circle = Circle{ .center = Vec2.init(-5.0, -5.0), .radius = 5.0 * @sqrt(2.0) };
    try std.testing.expect(primitives.circleRectangle(corner_circle, rect));

    // Circle just missing corner
    const miss_corner_circle = Circle{ .center = Vec2.init(-5.0, -5.0), .radius = 5.0 * @sqrt(2.0) - 0.01 };
    try std.testing.expect(!primitives.circleRectangle(miss_corner_circle, rect));

    // Circle exactly touching edge
    const edge_circle = Circle{ .center = Vec2.init(5.0, -3.0), .radius = 3.0 };
    try std.testing.expect(primitives.circleRectangle(edge_circle, rect));

    // Circle just missing edge
    const miss_edge_circle = Circle{ .center = Vec2.init(5.0, -3.01), .radius = 3.0 };
    try std.testing.expect(!primitives.circleRectangle(miss_edge_circle, rect));
}

test "stress test with many overlapping shapes" {
    // Create many shapes in the same location to test numerical stability
    const center = Vec2.init(0.0, 0.0);
    const circle1 = Circle{ .center = center, .radius = 5.0 };
    const circle2 = Circle{ .center = center, .radius = 3.0 };
    const circle3 = Circle{ .center = center, .radius = 1.0 };

    // All should collide with each other
    try std.testing.expect(primitives.circleCircle(circle1, circle2));
    try std.testing.expect(primitives.circleCircle(circle1, circle3));
    try std.testing.expect(primitives.circleCircle(circle2, circle3));

    // Test detailed collision for complete overlap
    const shape1 = Shape{ .circle = circle1 };
    const shape2 = Shape{ .circle = circle3 };

    const result = detailed.checkCollisionDetailed(shape1, shape2);
    try std.testing.expect(result.collided);
    try std.testing.expect(result.penetration_depth == 6.0); // 5 + 1 (complete overlap)
}

test "collision result normal vector validation" {
    // Test that normal vectors are properly normalized
    const circle1 = Circle{ .center = Vec2.init(0.0, 0.0), .radius = 5.0 };
    const circle2 = Circle{ .center = Vec2.init(6.0, 0.0), .radius = 5.0 };

    const shape1 = Shape{ .circle = circle1 };
    const shape2 = Shape{ .circle = circle2 };

    const result = detailed.checkCollisionDetailed(shape1, shape2);

    if (result.collided) {
        // Normal should be approximately unit length
        const normal_length = result.normal.length();
        try std.testing.expect(@abs(normal_length - 1.0) < 0.001);

        // Normal should point from circle1 to circle2 (positive x direction)
        try std.testing.expect(result.normal.x > 0.0);
        try std.testing.expect(@abs(result.normal.y) < 0.001);
    }
}

test "edge case for line thickness tolerance" {
    const line = LineSegment.init(Vec2.init(0.0, 0.0), Vec2.init(10.0, 0.0));
    const tolerance = types.LINE_THICKNESS_TOLERANCE;

    // Point exactly at tolerance distance
    const point_at_tolerance = Vec2.init(5.0, tolerance);
    const point_beyond_tolerance = Vec2.init(5.0, tolerance * 1.1);

    // Should collide within tolerance
    try std.testing.expect(primitives.pointLine(point_at_tolerance, line));

    // Should not collide beyond tolerance
    try std.testing.expect(!primitives.pointLine(point_beyond_tolerance, line));
}
