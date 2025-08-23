//! Integration tests for collision detection modules
//!
//! Tests that verify different modules work together correctly,
//! backward compatibility, and cross-module functionality.

const std = @import("std");
const math = @import("../../math/mod.zig");
const collision = @import("mod.zig");
const spatial = @import("spatial.zig");
const batch = @import("batch.zig");
const detection = @import("detection.zig");
const detailed = @import("detailed.zig");

const Vec2 = math.Vec2;
const Shape = collision.Shape;
const Circle = collision.Circle;
const Rectangle = collision.Rectangle;
const Point = collision.Point;
const LineSegment = collision.LineSegment;

test "backward compatibility with original collision.zig interface" {
    // Test that all original functions are still available through mod.zig
    const circle1 = Circle{ .center = Vec2.init(0.0, 0.0), .radius = 5.0 };
    const circle2 = Circle{ .center = Vec2.init(6.0, 0.0), .radius = 5.0 };
    const rect = Rectangle.fromXYWH(3.0, 3.0, 4.0, 4.0);
    const point = Vec2.init(3.0, 3.0);

    const circle_shape = Shape{ .circle = circle1 };
    const rect_shape = Shape{ .rectangle = rect };

    // All original functions should still work
    try std.testing.expect(collision.checkCircleCollision(circle1.center, circle1.radius, circle2.center, circle2.radius));
    try std.testing.expect(collision.circleCircle(circle1, circle2));
    try std.testing.expect(collision.circleRectangle(circle1, rect));
    try std.testing.expect(collision.circlePoint(circle1, point));
    try std.testing.expect(collision.rectangleRectangle(rect, rect));
    try std.testing.expect(collision.rectanglePoint(rect, point));
    try std.testing.expect(collision.pointPoint(point, point));

    // Generic collision detection
    try std.testing.expect(collision.checkCollision(circle_shape, rect_shape));

    // Detailed collision detection
    const result = collision.checkCollisionDetailed(circle_shape, rect_shape);
    try std.testing.expect(result.collided);
    try std.testing.expect(result.penetration_depth > 0.0);

    // Utility functions
    const obstacles = [_]Shape{rect_shape};
    try std.testing.expect(collision.isPositionSafe(Vec2.init(100.0, 100.0), 1.0, &obstacles));
    try std.testing.expect(!collision.isPositionSafe(Vec2.init(5.0, 5.0), 1.0, &obstacles));
}

test "spatial grid integration with batch collision detection" {
    const allocator = std.testing.allocator;

    // Create spatial grid
    const bounds = Rectangle.fromXYWH(0.0, 0.0, 100.0, 100.0);
    var grid = try spatial.SpatialGrid.init(allocator, bounds, 20.0);
    defer grid.deinit();

    // Create collision batch
    var batch_processor = try batch.CollisionBatch.init(allocator, 5);
    defer batch_processor.deinit();

    // Set up test shapes
    const shapes = [_]Shape{
        Shape{ .circle = Circle{ .center = Vec2.init(10.0, 10.0), .radius = 3.0 } },
        Shape{ .circle = Circle{ .center = Vec2.init(15.0, 10.0), .radius = 3.0 } }, // Overlaps with first
        Shape{ .circle = Circle{ .center = Vec2.init(50.0, 50.0), .radius = 3.0 } }, // Isolated
        Shape{ .rectangle = Rectangle.fromXYWH(8.0, 8.0, 6.0, 6.0) }, // Overlaps with first two circles
        Shape{ .point = Vec2.init(12.0, 12.0) }, // Inside rectangle and circles
    };

    // Add shapes to both spatial grid and batch
    for (shapes, 0..) |shape, i| {
        try grid.addShape(i, shape);
        batch_processor.shapes[i] = shape;
    }

    // Test spatial grid neighbor queries
    var neighbors = std.ArrayList(usize).init(allocator);
    defer neighbors.deinit();

    try grid.getNeighbors(shapes[0], &neighbors);
    try std.testing.expect(neighbors.items.len >= 3); // Should find overlapping shapes

    // Test batch collision detection
    var collision_matrix = [_]bool{false} ** 25; // 5x5 matrix
    batch_processor.checkAllCollisions(&collision_matrix);

    // Verify that overlapping shapes are detected
    try std.testing.expect(collision_matrix[1]); // Shape 0 vs shape 1
    try std.testing.expect(collision_matrix[3]); // Shape 0 vs shape 3 (rectangle)
    try std.testing.expect(collision_matrix[4]); // Shape 0 vs shape 4 (point)
    try std.testing.expect(!collision_matrix[2]); // Shape 0 vs shape 2 (isolated)

    // Test batch against single target
    const target = Shape{ .point = Vec2.init(12.0, 12.0) };
    var target_results = [_]bool{false} ** 5;
    batch_processor.checkAgainstShape(target, &target_results);

    // Point should collide with circle, rectangle, and point
    try std.testing.expect(target_results[0]); // Circle contains point
    try std.testing.expect(!target_results[1]); // Circle does not contain point (too far)
    try std.testing.expect(!target_results[2]); // Isolated circle
    try std.testing.expect(target_results[3]); // Rectangle contains point
    try std.testing.expect(target_results[4]); // Point equals point
}

test "detection vs detailed collision consistency" {
    // Test that basic and detailed collision detection give consistent results
    const test_cases = [_]struct { shape1: Shape, shape2: Shape }{
        .{ .shape1 = Shape{ .circle = Circle{ .center = Vec2.init(0.0, 0.0), .radius = 5.0 } }, .shape2 = Shape{ .circle = Circle{ .center = Vec2.init(6.0, 0.0), .radius = 5.0 } } },
        .{ .shape1 = Shape{ .circle = Circle{ .center = Vec2.init(0.0, 0.0), .radius = 3.0 } }, .shape2 = Shape{ .rectangle = Rectangle.fromXYWH(2.0, 2.0, 4.0, 4.0) } },
        .{ .shape1 = Shape{ .rectangle = Rectangle.fromXYWH(0.0, 0.0, 10.0, 10.0) }, .shape2 = Shape{ .point = Vec2.init(5.0, 5.0) } },
        .{ .shape1 = Shape{ .point = Vec2.init(0.0, 0.0) }, .shape2 = Shape{ .point = Vec2.init(0.0, 0.0) } },
    };

    for (test_cases) |test_case| {
        const basic_result = detection.checkCollision(test_case.shape1, test_case.shape2);
        const detailed_result = detailed.checkCollisionDetailed(test_case.shape1, test_case.shape2);

        // Basic and detailed should agree on whether collision occurred
        try std.testing.expect(basic_result == detailed_result.collided);

        // If colliding, detailed should provide meaningful data
        if (detailed_result.collided) {
            try std.testing.expect(detailed_result.penetration_depth >= 0.0);
            try std.testing.expect(detailed_result.normal.lengthSquared() > 0.0);
        } else {
            try std.testing.expect(detailed_result.penetration_depth == 0.0);
        }
    }
}

test "cross-module function equivalence" {
    // Test that functions work the same when called through different paths
    const circle1 = Circle{ .center = Vec2.init(0.0, 0.0), .radius = 5.0 };
    const circle2 = Circle{ .center = Vec2.init(6.0, 0.0), .radius = 5.0 };

    // These should all give the same result
    const result1 = collision.circleCircle(circle1, circle2); // Through mod.zig
    const result2 = @import("primitives/circle.zig").circleCircle(circle1, circle2); // Direct
    const result3 = @import("primitives/mod.zig").circleCircle(circle1, circle2); // Through primitives barrel

    try std.testing.expect(result1 == result2);
    try std.testing.expect(result2 == result3);

    // Same for generic collision
    const shape1 = Shape{ .circle = circle1 };
    const shape2 = Shape{ .circle = circle2 };

    const generic_result1 = collision.checkCollision(shape1, shape2);
    const generic_result2 = detection.checkCollision(shape1, shape2);

    try std.testing.expect(generic_result1 == generic_result2);
}

test "utility functions integration with core collision detection" {
    const obstacles = [_]Shape{
        Shape{ .circle = Circle{ .center = Vec2.init(10.0, 10.0), .radius = 5.0 } },
        Shape{ .rectangle = Rectangle.fromXYWH(20.0, 20.0, 10.0, 10.0) },
        Shape{ .point = Vec2.init(50.0, 50.0) },
    };

    // Test position safety
    try std.testing.expect(collision.isPositionSafe(Vec2.init(0.0, 0.0), 2.0, &obstacles));
    try std.testing.expect(!collision.isPositionSafe(Vec2.init(10.0, 10.0), 2.0, &obstacles));

    // Test nearest obstacle finding
    const nearest = collision.findNearestObstacle(Vec2.init(8.0, 8.0), &obstacles);
    try std.testing.expect(nearest != null);
    try std.testing.expect(nearest.?.index == 0); // Should be the circle

    // Test moving collision detection
    const moving_collision = collision.checkMovingCircleCollision(Vec2.init(0.0, 10.0), Vec2.init(20.0, 10.0), 2.0, &obstacles);
    try std.testing.expect(moving_collision != null); // Should hit the circle

    // Test collision resolution
    const overlapping_pos = Vec2.init(12.0, 10.0); // Inside the circle
    const resolved = collision.resolveCollision(overlapping_pos, 1.0, obstacles[0]);
    try std.testing.expect(resolved != null);

    if (resolved) |pos| {
        // Resolved position should be outside the obstacle
        const distance = math.distance(pos, obstacles[0].circle.center);
        try std.testing.expect(distance > obstacles[0].circle.radius + 1.0);
    }
}

test "all shape combinations integration test" {
    // Comprehensive test of all shape type combinations
    const shapes = [_]Shape{
        Shape{ .circle = Circle{ .center = Vec2.init(5.0, 5.0), .radius = 3.0 } },
        Shape{ .rectangle = Rectangle.fromXYWH(3.0, 3.0, 6.0, 6.0) },
        Shape{ .point = Vec2.init(5.0, 5.0) },
        Shape{ .line = LineSegment.init(Vec2.init(2.0, 2.0), Vec2.init(8.0, 8.0)) },
    };

    // Test all pairwise combinations
    for (shapes, 0..) |shape1, i| {
        for (shapes, 0..) |shape2, j| {
            if (i != j) {
                // Basic collision should not crash
                const basic_collides = detection.checkCollision(shape1, shape2);

                // Detailed collision should not crash and be consistent
                const detailed_result = detailed.checkCollisionDetailed(shape1, shape2);

                try std.testing.expect(basic_collides == detailed_result.collided);

                // Symmetric property should hold for basic collision
                const reverse_collides = detection.checkCollision(shape2, shape1);
                try std.testing.expect(basic_collides == reverse_collides);
            }
        }
    }
}
