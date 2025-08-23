//! Circle collision detection functions
//!
//! All collision detection involving circles, including circle-circle,
//! circle-rectangle, circle-point, and circle-line collisions.

const std = @import("std");
const math = @import("../../../math/mod.zig");
const types = @import("../types.zig");

const Vec2 = math.Vec2;
const Circle = types.Circle;
const Rectangle = types.Rectangle;
const Point = types.Point;
const LineSegment = types.LineSegment;
const CollisionResult = types.CollisionResult;
const FLOATING_POINT_TOLERANCE = types.FLOATING_POINT_TOLERANCE;

/// Circle-circle collision detection (optimized with squared distance)
///
/// Uses squared distance calculation to avoid expensive sqrt operations.
/// Two circles collide when the distance between their centers is less than
/// or equal to the sum of their radii.
///
/// Example:
/// ```zig
/// const circle1 = Circle.init(Vec2.init(0, 0), 5);
/// const circle2 = Circle.init(Vec2.init(8, 0), 4);
/// const colliding = circleCircle(circle1, circle2); // true (distance = 8, radii sum = 9)
/// ```
pub fn circleCircle(c1: Circle, c2: Circle) bool {
    return checkCircleCollision(c1.center, c1.radius, c2.center, c2.radius);
}

/// Simple circle collision check using positions and radii (core implementation)
///
/// Core collision detection function used by other circle collision methods.
/// Validates input (negative radii return false) and uses squared distance
/// for performance optimization.
///
/// Example:
/// ```zig
/// const pos1 = Vec2.init(0, 0);
/// const pos2 = Vec2.init(3, 4);
/// const colliding = checkCircleCollision(pos1, 2.5, pos2, 2.6); // true (distance = 5, radii sum = 5.1)
/// ```
pub fn checkCircleCollision(pos1: Vec2, radius1: f32, pos2: Vec2, radius2: f32) bool {
    // Input validation
    if (radius1 < 0.0 or radius2 < 0.0) return false;

    const distance_sq = math.distanceSquared(pos1, pos2);
    const radius_sum = radius1 + radius2;
    return distance_sq <= radius_sum * radius_sum;
}

/// Circle-rectangle collision detection
pub fn circleRectangle(circle: Circle, rect: Rectangle) bool {
    // Input validation - negative radius or negative rectangle size (zero is valid)
    if (circle.radius < 0.0 or rect.size.x < 0.0 or rect.size.y < 0.0) {
        return false;
    }

    // Find closest point on rectangle to circle center
    const closest_x = math.clamp(circle.center.x, rect.position.x, rect.position.x + rect.size.x);
    const closest_y = math.clamp(circle.center.y, rect.position.y, rect.position.y + rect.size.y);

    const closest_point = Vec2{ .x = closest_x, .y = closest_y };
    const distance_sq = math.distanceSquared(circle.center, closest_point);

    return distance_sq <= circle.radius * circle.radius;
}

/// Circle-point collision detection
pub fn circlePoint(circle: Circle, point: Point) bool {
    // Input validation - negative radius
    if (circle.radius < 0.0) {
        return false;
    }

    return math.distanceSquared(circle.center, point) <= circle.radius * circle.radius;
}

/// Circle-line collision detection
pub fn circleLine(circle: Circle, line: LineSegment) bool {
    const distance_to_line = line.distanceToPoint(circle.center);
    return distance_to_line <= circle.radius;
}

/// Detailed circle-circle collision
pub fn circleCircleDetailed(c1: Circle, c2: Circle) CollisionResult {
    // Input validation - negative radius is invalid
    if (c1.radius < 0.0 or c2.radius < 0.0) {
        return CollisionResult{ .collided = false };
    }

    const distance = math.distance(c1.center, c2.center);
    const radius_sum = c1.radius + c2.radius;

    if (distance > radius_sum) {
        return CollisionResult{ .collided = false };
    }

    const penetration = radius_sum - distance;
    const normal = if (distance > FLOATING_POINT_TOLERANCE)
        math.directionBetween(c1.center, c2.center)
    else
        Vec2{ .x = 1, .y = 0 }; // Default normal if centers overlap

    const contact_point = c1.center.add(normal.scale(c1.radius - penetration / 2.0));

    return CollisionResult{
        .collided = true,
        .penetration_depth = penetration,
        .normal = normal,
        .contact_point = contact_point,
    };
}

/// Detailed circle-rectangle collision
pub fn circleRectangleDetailed(circle: Circle, rect: Rectangle) CollisionResult {
    // Input validation - negative radius or negative rectangle size
    if (circle.radius < 0.0 or rect.size.x < 0.0 or rect.size.y < 0.0) {
        return CollisionResult{ .collided = false };
    }

    const closest_x = math.clamp(circle.center.x, rect.position.x, rect.position.x + rect.size.x);
    const closest_y = math.clamp(circle.center.y, rect.position.y, rect.position.y + rect.size.y);
    const closest_point = Vec2{ .x = closest_x, .y = closest_y };

    const distance = math.distance(circle.center, closest_point);

    if (distance > circle.radius) {
        return CollisionResult{ .collided = false };
    }

    const penetration = circle.radius - distance;
    const normal = if (distance > FLOATING_POINT_TOLERANCE)
        math.directionBetween(closest_point, circle.center)
    else
        Vec2{ .x = 0, .y = -1 }; // Default normal from top of rectangle

    return CollisionResult{
        .collided = true,
        .penetration_depth = penetration,
        .normal = normal,
        .contact_point = closest_point,
    };
}

/// Detailed circle-point collision
pub fn circlePointDetailed(circle: Circle, point: Point) CollisionResult {
    // Input validation - negative radius is invalid
    if (circle.radius < 0.0) {
        return CollisionResult{ .collided = false };
    }

    const distance = math.distance(circle.center, point);

    if (distance > circle.radius) {
        return CollisionResult{ .collided = false };
    }

    const penetration = circle.radius - distance;
    const normal = if (distance > FLOATING_POINT_TOLERANCE)
        math.directionBetween(point, circle.center)
    else
        Vec2{ .x = 1, .y = 0 };

    return CollisionResult{
        .collided = true,
        .penetration_depth = penetration,
        .normal = normal,
        .contact_point = point,
    };
}

/// Detailed circle-line collision
pub fn circleLineDetailed(circle: Circle, line: LineSegment) CollisionResult {
    const distance = line.distanceToPoint(circle.center);

    if (distance > circle.radius) {
        return CollisionResult{ .collided = false };
    }

    const penetration = circle.radius - distance;
    const closest_point = line.closestPointTo(circle.center);
    const normal = if (math.distance(circle.center, closest_point) > FLOATING_POINT_TOLERANCE)
        math.directionBetween(closest_point, circle.center)
    else
        Vec2.init(0.0, 1.0); // Default normal if points coincide

    return CollisionResult{
        .collided = true,
        .penetration_depth = penetration,
        .normal = normal,
        .contact_point = closest_point,
    };
}

// Tests for circle collision functions
test "circle-circle collision detection" {
    const test_utils = @import("../test_utils.zig");
    const TestShapes = test_utils.TestShapes;

    // Overlapping circles
    try std.testing.expect(circleCircle(TestShapes.origin_circle, TestShapes.overlapping_circle));

    // Non-overlapping circles
    try std.testing.expect(!circleCircle(TestShapes.origin_circle, TestShapes.far_circle));

    // Same circle (identity property)
    try test_utils.TestHelpers.testSelfCollision(types.Shape{ .circle = TestShapes.origin_circle });
}

test "checkCircleCollision consistency with circleCircle" {
    const test_utils = @import("../test_utils.zig");
    const TestShapes = test_utils.TestShapes;

    // Test consistency between the two functions
    const c1 = TestShapes.origin_circle;
    const c2 = TestShapes.overlapping_circle;
    const c3 = TestShapes.far_circle;

    // Both functions should give same results
    try std.testing.expect(circleCircle(c1, c2) == checkCircleCollision(c1.center, c1.radius, c2.center, c2.radius));
    try std.testing.expect(circleCircle(c1, c3) == checkCircleCollision(c1.center, c1.radius, c3.center, c3.radius));
}

test "circle-rectangle collision detection" {
    const circle = Circle{ .center = Vec2.init(15.0, 15.0), .radius = 3.0 };
    const rect = Rectangle.fromXYWH(10.0, 10.0, 10.0, 10.0);
    const far_rect = Rectangle.fromXYWH(50.0, 50.0, 10.0, 10.0);

    // Circle overlapping rectangle
    try std.testing.expect(circleRectangle(circle, rect));

    // Circle far from rectangle
    try std.testing.expect(!circleRectangle(circle, far_rect));

    // Circle exactly touching corner
    const corner_circle = Circle{ .center = Vec2.init(20.0, 20.0), .radius = @sqrt(2.0) };
    try std.testing.expect(circleRectangle(corner_circle, rect));
}

test "circle-point collision detection" {
    const circle = Circle{ .center = Vec2.init(0.0, 0.0), .radius = 5.0 };
    const inside_point = Vec2.init(3.0, 0.0);
    const outside_point = Vec2.init(10.0, 0.0);
    const edge_point = Vec2.init(5.0, 0.0);

    try std.testing.expect(circlePoint(circle, inside_point));
    try std.testing.expect(!circlePoint(circle, outside_point));
    try std.testing.expect(circlePoint(circle, edge_point));
}

test "circle-line collision detection" {
    const circle = Circle{ .center = Vec2.init(5.0, 5.0), .radius = 2.0 };
    const line_through = LineSegment.init(Vec2.init(0.0, 5.0), Vec2.init(10.0, 5.0));
    const line_near = LineSegment.init(Vec2.init(0.0, 6.5), Vec2.init(10.0, 6.5));
    const line_far = LineSegment.init(Vec2.init(0.0, 10.0), Vec2.init(10.0, 10.0));

    // Line passing through circle
    try std.testing.expect(circleLine(circle, line_through));

    // Line close to circle (within radius)
    try std.testing.expect(circleLine(circle, line_near));

    // Line far from circle
    try std.testing.expect(!circleLine(circle, line_far));
}

test "detailed circle collision results" {
    const c1 = Circle{ .center = Vec2.init(0.0, 0.0), .radius = 5.0 };
    const c2 = Circle{ .center = Vec2.init(6.0, 0.0), .radius = 5.0 };
    const c3 = Circle{ .center = Vec2.init(15.0, 0.0), .radius = 5.0 };

    // Overlapping circles should have penetration depth
    const result1 = circleCircleDetailed(c1, c2);
    try std.testing.expect(result1.collided);
    try std.testing.expect(result1.penetration_depth > 0.0);
    try std.testing.expect(result1.normal.x > 0.0); // Normal should point away from c1

    // Non-overlapping circles
    const result2 = circleCircleDetailed(c1, c3);
    try std.testing.expect(!result2.collided);
    try std.testing.expect(result2.penetration_depth == 0.0);
}

test "edge cases and boundary conditions for circles" {

    // Zero radius circle - should collide if within other circle's radius
    const zero_circle = Circle{ .center = Vec2.init(0.0, 0.0), .radius = 0.0 };
    const normal_circle = Circle{ .center = Vec2.init(1.0, 0.0), .radius = 2.0 };
    const far_circle = Circle{ .center = Vec2.init(5.0, 0.0), .radius = 2.0 };

    try std.testing.expect(circleCircle(zero_circle, normal_circle)); // Distance 1 < radius 2
    try std.testing.expect(!circleCircle(zero_circle, far_circle)); // Distance 5 > radius 2

    // Very large numbers (stress test)
    const big_circle = Circle{ .center = Vec2.init(1000000.0, 1000000.0), .radius = 100000.0 };
    const small_circle = Circle{ .center = Vec2.init(1000000.0, 1000000.0), .radius = 1.0 };

    try std.testing.expect(circleCircle(big_circle, small_circle));
}
