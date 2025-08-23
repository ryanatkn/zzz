//! Detailed collision detection with physics information
//!
//! Provides checkCollisionDetailed function that returns comprehensive collision
//! data including penetration depth, separation normal, and contact points.

const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("types.zig");
const primitives = @import("primitives/mod.zig");

const Vec2 = math.Vec2;
const Shape = types.Shape;
const CollisionResult = types.CollisionResult;

/// Advanced collision detection with detailed result information
///
/// Provides comprehensive collision data including:
/// - Penetration depth (how much shapes overlap)
/// - Separation normal (direction to resolve collision)
/// - Contact point (where collision occurs)
///
/// Used for physics simulation, collision response, and debugging.
/// More expensive than basic collision detection but provides
/// information needed for realistic collision resolution.
///
/// Example:
/// ```zig
/// const circle = Circle.init(Vec2.init(5, 5), 3);
/// const rect = Rectangle.fromXYWH(0, 0, 10, 10);
/// const result = checkCollisionDetailed(.{ .circle = circle }, .{ .rectangle = rect });
/// if (result.collided) {
///     // Move circle out by penetration depth along normal
///     const separation = result.normal.scale(result.penetration_depth);
/// }
/// ```
pub fn checkCollisionDetailed(shape1: Shape, shape2: Shape) CollisionResult {
    return switch (shape1) {
        .circle => |c1| switch (shape2) {
            .circle => |c2| primitives.circleCircleDetailed(c1, c2),
            .rectangle => |r2| primitives.circleRectangleDetailed(c1, r2),
            .point => |p2| primitives.circlePointDetailed(c1, p2),
            .line => |l2| primitives.circleLineDetailed(c1, l2),
        },
        .rectangle => |r1| switch (shape2) {
            .circle => |c2| {
                var result = primitives.circleRectangleDetailed(c2, r1);
                // Flip normal for symmetric case
                result.normal = result.normal.scale(-1.0);
                return result;
            },
            .rectangle => |r2| primitives.rectangleRectangleDetailed(r1, r2),
            .point => |p2| primitives.rectanglePointDetailed(r1, p2),
            .line => |l2| primitives.rectangleLineDetailed(r1, l2),
        },
        .point => |p1| switch (shape2) {
            .circle => |c2| {
                var result = primitives.circlePointDetailed(c2, p1);
                result.normal = result.normal.scale(-1.0);
                return result;
            },
            .rectangle => |r2| {
                var result = primitives.rectanglePointDetailed(r2, p1);
                result.normal = result.normal.scale(-1.0);
                return result;
            },
            .point => |p2| primitives.pointPointDetailed(p1, p2),
            .line => |l2| primitives.pointLineDetailed(p1, l2),
        },
        .line => |l1| switch (shape2) {
            .circle => |c2| {
                var result = primitives.circleLineDetailed(c2, l1);
                result.normal = result.normal.scale(-1.0);
                return result;
            },
            .rectangle => |r2| {
                var result = primitives.rectangleLineDetailed(r2, l1);
                result.normal = result.normal.scale(-1.0);
                return result;
            },
            .point => |p2| {
                var result = primitives.pointLineDetailed(p2, l1);
                result.normal = result.normal.scale(-1.0);
                return result;
            },
            .line => |l2| primitives.lineLineDetailed(l1, l2),
        },
    };
}

// Tests for detailed collision detection
test "detailed collision results" {
    const c1 = types.Circle{ .center = Vec2.init(0.0, 0.0), .radius = 5.0 };
    const c2 = types.Circle{ .center = Vec2.init(6.0, 0.0), .radius = 5.0 };
    const c3 = types.Circle{ .center = Vec2.init(15.0, 0.0), .radius = 5.0 };

    const shape1 = Shape{ .circle = c1 };
    const shape2 = Shape{ .circle = c2 };
    const shape3 = Shape{ .circle = c3 };

    // Overlapping circles should have penetration depth
    const result1 = checkCollisionDetailed(shape1, shape2);
    try std.testing.expect(result1.collided);
    try std.testing.expect(result1.penetration_depth > 0.0);
    try std.testing.expect(result1.normal.x > 0.0); // Normal should point away from c1

    // Non-overlapping circles
    const result2 = checkCollisionDetailed(shape1, shape3);
    try std.testing.expect(!result2.collided);
    try std.testing.expect(result2.penetration_depth == 0.0);
}

test "detailed collision symmetry" {
    const circle_shape = Shape{ .circle = types.Circle{ .center = Vec2.init(5.0, 5.0), .radius = 3.0 } };
    const rect_shape = Shape{ .rectangle = types.Rectangle.fromXYWH(3.0, 3.0, 6.0, 6.0) };

    // Test that symmetric cases properly flip normals
    const result1 = checkCollisionDetailed(circle_shape, rect_shape);
    const result2 = checkCollisionDetailed(rect_shape, circle_shape);

    try std.testing.expect(result1.collided == result2.collided);
    if (result1.collided and result2.collided) {
        // Normals should be opposite
        const dot_product = result1.normal.dot(result2.normal);
        try std.testing.expect(dot_product < 0.0); // Should be pointing in opposite directions
    }
}
