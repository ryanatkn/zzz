//! Generic collision detection dispatcher
//!
//! Provides the main checkCollision function that dispatches to appropriate
//! primitive collision functions based on shape types.

const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("types.zig");
const primitives = @import("primitives/mod.zig");

const Vec2 = math.Vec2;
const Shape = types.Shape;

/// Generic collision detection between any two shapes
///
/// Performs collision detection between any combination of supported shapes.
/// Returns true if the shapes are colliding, false otherwise.
///
/// Example:
/// ```zig
/// const circle = Circle.init(Vec2.init(0, 0), 5);
/// const rect = Rectangle.fromXYWH(10, 10, 20, 15);
/// const colliding = checkCollision(.{ .circle = circle }, .{ .rectangle = rect });
/// ```
///
/// Supported shape combinations:
/// - Circle vs Circle, Rectangle, Point, LineSegment
/// - Rectangle vs Rectangle, Point, LineSegment
/// - Point vs Point, LineSegment
/// - LineSegment vs LineSegment
pub fn checkCollision(shape1: Shape, shape2: Shape) bool {
    return switch (shape1) {
        .circle => |c1| switch (shape2) {
            .circle => |c2| primitives.circleCircle(c1, c2),
            .rectangle => |r2| primitives.circleRectangle(c1, r2),
            .point => |p2| primitives.circlePoint(c1, p2),
            .line => |l2| primitives.circleLine(c1, l2),
        },
        .rectangle => |r1| switch (shape2) {
            .circle => |c2| primitives.circleRectangle(c2, r1), // Symmetric
            .rectangle => |r2| primitives.rectangleRectangle(r1, r2),
            .point => |p2| primitives.rectanglePoint(r1, p2),
            .line => |l2| primitives.rectangleLine(r1, l2),
        },
        .point => |p1| switch (shape2) {
            .circle => |c2| primitives.circlePoint(c2, p1), // Symmetric
            .rectangle => |r2| primitives.rectanglePoint(r2, p1), // Symmetric
            .point => |p2| primitives.pointPoint(p1, p2),
            .line => |l2| primitives.pointLine(p1, l2),
        },
        .line => |l1| switch (shape2) {
            .circle => |c2| primitives.circleLine(c2, l1), // Symmetric
            .rectangle => |r2| primitives.rectangleLine(r2, l1), // Symmetric
            .point => |p2| primitives.pointLine(p2, l1), // Symmetric
            .line => |l2| primitives.lineLineIntersect(l1, l2),
        },
    };
}

// Tests for generic collision detection
test "generic shape collision detection" {
    const circle_shape = Shape{ .circle = types.Circle{ .center = Vec2.init(0.0, 0.0), .radius = 5.0 } };
    const rect_shape = Shape{ .rectangle = types.Rectangle.fromXYWH(3.0, 3.0, 10.0, 10.0) };
    const point_shape = Shape{ .point = Vec2.init(2.0, 2.0) };

    // Circle-rectangle collision
    try std.testing.expect(checkCollision(circle_shape, rect_shape));

    // Circle-point collision
    try std.testing.expect(checkCollision(circle_shape, point_shape));

    // Symmetric collision (rectangle-circle should equal circle-rectangle)
    try std.testing.expect(checkCollision(rect_shape, circle_shape) == checkCollision(circle_shape, rect_shape));
}

test "complete shape collision matrix" {
    const circle_shape = Shape{ .circle = types.Circle{ .center = Vec2.init(5.0, 5.0), .radius = 3.0 } };
    const line_shape = Shape{ .line = types.LineSegment.init(Vec2.init(0.0, 5.0), Vec2.init(10.0, 5.0)) };
    const rect_shape = Shape{ .rectangle = types.Rectangle.fromXYWH(4.0, 4.0, 6.0, 6.0) };
    const point_shape = Shape{ .point = Vec2.init(5.0, 5.0) };

    // Circle-line collision
    try std.testing.expect(checkCollision(circle_shape, line_shape));
    try std.testing.expect(checkCollision(line_shape, circle_shape)); // Symmetric

    // Rectangle-line collision
    try std.testing.expect(checkCollision(rect_shape, line_shape));
    try std.testing.expect(checkCollision(line_shape, rect_shape)); // Symmetric

    // Point-line collision
    try std.testing.expect(checkCollision(point_shape, line_shape));
    try std.testing.expect(checkCollision(line_shape, point_shape)); // Symmetric
}
