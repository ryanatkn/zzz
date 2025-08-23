//! Property-based tests for collision detection mathematical invariants
//!
//! Tests fundamental mathematical properties that should always hold true
//! regardless of input values, such as symmetry, consistency, and geometric laws.

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

const test_utils = @import("test_utils.zig");
const RandomGen = test_utils.RandomGen;

test "collision detection symmetry property" {
    var prng = std.Random.DefaultPrng.init(12345);
    var rng = prng.random();

    // Test many random shape pairs
    for (0..100) |_| {
        const circle1 = RandomGen.randomCircle(&rng);
        const circle2 = RandomGen.randomCircle(&rng);
        const rect1 = RandomGen.randomRectangle(&rng);
        const rect2 = RandomGen.randomRectangle(&rng);

        const shape_pairs = [_]struct { a: Shape, b: Shape }{
            .{ .a = Shape{ .circle = circle1 }, .b = Shape{ .circle = circle2 } },
            .{ .a = Shape{ .circle = circle1 }, .b = Shape{ .rectangle = rect1 } },
            .{ .a = Shape{ .rectangle = rect1 }, .b = Shape{ .rectangle = rect2 } },
        };

        for (shape_pairs) |pair| {
            // Collision detection should be symmetric: A vs B == B vs A
            const result_ab = detection.checkCollision(pair.a, pair.b);
            const result_ba = detection.checkCollision(pair.b, pair.a);
            try std.testing.expect(result_ab == result_ba);
        }
    }
}

test "detailed collision normal vector properties" {
    var prng = std.Random.DefaultPrng.init(54321);
    var rng = prng.random();

    for (0..50) |_| {
        const circle1 = RandomGen.randomCircle(&rng);
        const circle2 = RandomGen.randomCircle(&rng);

        const shape1 = Shape{ .circle = circle1 };
        const shape2 = Shape{ .circle = circle2 };

        const result = detailed.checkCollisionDetailed(shape1, shape2);

        if (result.collided) {
            // Normal vector should be unit length (or close to it)
            const normal_length = result.normal.length();
            try std.testing.expect(@abs(normal_length - 1.0) < 0.1);

            // Penetration depth should be positive
            try std.testing.expect(result.penetration_depth > 0.0);

            // Penetration depth should be reasonable (not larger than sum of radii)
            const max_penetration = circle1.radius + circle2.radius;
            try std.testing.expect(result.penetration_depth <= max_penetration);
        } else {
            // If not colliding, penetration depth should be zero
            try std.testing.expect(result.penetration_depth == 0.0);
        }
    }
}

test "circle collision transitivity property" {
    var prng = std.Random.DefaultPrng.init(98765);
    var rng = prng.random();

    // Test that if A contains B and B contains C, then A should contain C
    for (0..20) |_| {
        const center = RandomGen.randomVec2(&rng, -50.0, 50.0);

        // Create three concentric circles with different radii
        const large_radius = RandomGen.randomFloat(&rng, 10.0, 20.0);
        const medium_radius = RandomGen.randomFloat(&rng, 5.0, large_radius - 1.0);
        const small_radius = RandomGen.randomFloat(&rng, 1.0, medium_radius - 1.0);

        const large_circle = Circle{ .center = center, .radius = large_radius };
        const medium_circle = Circle{ .center = center, .radius = medium_radius };
        const small_circle = Circle{ .center = center, .radius = small_radius };

        // All should collide with each other (containment)
        try std.testing.expect(primitives.circleCircle(large_circle, medium_circle));
        try std.testing.expect(primitives.circleCircle(medium_circle, small_circle));
        try std.testing.expect(primitives.circleCircle(large_circle, small_circle));
    }
}

test "collision consistency under translation" {
    var prng = std.Random.DefaultPrng.init(11111);
    var rng = prng.random();

    for (0..30) |_| {
        const circle1 = RandomGen.randomCircle(&rng);
        const circle2 = RandomGen.randomCircle(&rng);
        const translation = RandomGen.randomVec2(&rng, -1000.0, 1000.0);

        // Original collision result
        const original_result = primitives.circleCircle(circle1, circle2);

        // Translate both circles by the same amount
        const translated_circle1 = Circle{
            .center = circle1.center.add(translation),
            .radius = circle1.radius,
        };
        const translated_circle2 = Circle{
            .center = circle2.center.add(translation),
            .radius = circle2.radius,
        };

        // Collision result should be the same after translation
        const translated_result = primitives.circleCircle(translated_circle1, translated_circle2);
        try std.testing.expect(original_result == translated_result);
    }
}

test "distance-based collision invariant" {
    var prng = std.Random.DefaultPrng.init(22222);
    var rng = prng.random();

    // Test that circle collision is consistent with distance calculations
    for (0..50) |_| {
        const center1 = RandomGen.randomVec2(&rng, -50.0, 50.0);
        const center2 = RandomGen.randomVec2(&rng, -50.0, 50.0);
        const radius1 = RandomGen.randomFloat(&rng, 1.0, 10.0);
        const radius2 = RandomGen.randomFloat(&rng, 1.0, 10.0);

        const circle1 = Circle{ .center = center1, .radius = radius1 };
        const circle2 = Circle{ .center = center2, .radius = radius2 };

        const distance = math.distance(center1, center2);
        const radius_sum = radius1 + radius2;

        const collision_result = primitives.circleCircle(circle1, circle2);
        const expected_collision = distance <= radius_sum;

        // Handle floating-point precision issues
        if (@abs(distance - radius_sum) < 0.001) {
            // Too close to call - either result is acceptable
            continue;
        }

        try std.testing.expect(collision_result == expected_collision);
    }
}

test "rectangle containment property" {
    var prng = std.Random.DefaultPrng.init(33333);
    var rng = prng.random();

    for (0..30) |_| {
        const rect = RandomGen.randomRectangle(&rng);

        // Test points that should definitely be inside
        const inside_points = [_]Vec2{
            rect.center(),
            rect.position.add(rect.size.scale(0.25)),
            rect.position.add(rect.size.scale(0.75)),
        };

        for (inside_points) |point| {
            try std.testing.expect(primitives.rectanglePoint(rect, point));
        }

        // Test points that should definitely be outside
        const outside_points = [_]Vec2{
            Vec2.init(rect.position.x - 10.0, rect.position.y - 10.0),
            Vec2.init(rect.position.x + rect.size.x + 10.0, rect.position.y + rect.size.y + 10.0),
            Vec2.init(rect.position.x - 5.0, rect.center().y),
            Vec2.init(rect.center().x, rect.position.y - 5.0),
        };

        for (outside_points) |point| {
            try std.testing.expect(!primitives.rectanglePoint(rect, point));
        }
    }
}

test "collision result magnitude bounds" {
    var prng = std.Random.DefaultPrng.init(44444);
    var rng = prng.random();

    // Test that collision results are within reasonable bounds
    for (0..50) |_| {
        const circle1 = RandomGen.randomCircle(&rng);
        const circle2 = RandomGen.randomCircle(&rng);

        const shape1 = Shape{ .circle = circle1 };
        const shape2 = Shape{ .circle = circle2 };

        const result = detailed.checkCollisionDetailed(shape1, shape2);

        if (result.collided) {
            // Contact point should be within reasonable distance of both shapes
            const dist_to_c1 = math.distance(result.contact_point, circle1.center);
            const dist_to_c2 = math.distance(result.contact_point, circle2.center);

            // Contact point should be roughly within the circles' radii
            // (allowing some tolerance for edge cases)
            try std.testing.expect(dist_to_c1 <= circle1.radius + 1.0);
            try std.testing.expect(dist_to_c2 <= circle2.radius + 1.0);

            // Normal vector components should be within [-1, 1]
            try std.testing.expect(@abs(result.normal.x) <= 1.1); // Small tolerance
            try std.testing.expect(@abs(result.normal.y) <= 1.1);
        }
    }
}

test "identity collision property" {
    var prng = std.Random.DefaultPrng.init(55555);
    var rng = prng.random();

    // Test that shapes always collide with themselves
    for (0..20) |_| {
        const circle = RandomGen.randomCircle(&rng);
        const rect = RandomGen.randomRectangle(&rng);
        const point = RandomGen.randomVec2(&rng, -100.0, 100.0);

        // Shapes should always collide with themselves
        try std.testing.expect(primitives.circleCircle(circle, circle));
        try std.testing.expect(primitives.rectangleRectangle(rect, rect));
        try std.testing.expect(primitives.pointPoint(point, point));

        const circle_shape = Shape{ .circle = circle };
        const rect_shape = Shape{ .rectangle = rect };
        const point_shape = Shape{ .point = point };

        try std.testing.expect(detection.checkCollision(circle_shape, circle_shape));
        try std.testing.expect(detection.checkCollision(rect_shape, rect_shape));
        try std.testing.expect(detection.checkCollision(point_shape, point_shape));
    }
}

test "scaling invariant property" {
    var prng = std.Random.DefaultPrng.init(66666);
    var rng = prng.random();

    // Test that collision relationships are preserved under uniform scaling
    for (0..20) |_| {
        const circle1 = RandomGen.randomCircle(&rng);
        const circle2 = RandomGen.randomCircle(&rng);
        const scale_factor = RandomGen.randomFloat(&rng, 0.1, 10.0);

        const original_collision = primitives.circleCircle(circle1, circle2);

        // Scale both circles uniformly
        const scaled_circle1 = Circle{
            .center = circle1.center.scale(scale_factor),
            .radius = circle1.radius * scale_factor,
        };
        const scaled_circle2 = Circle{
            .center = circle2.center.scale(scale_factor),
            .radius = circle2.radius * scale_factor,
        };

        const scaled_collision = primitives.circleCircle(scaled_circle1, scaled_circle2);

        // Collision relationship should be preserved under uniform scaling
        try std.testing.expect(original_collision == scaled_collision);
    }
}

test "line intersection mathematical consistency" {
    var prng = std.Random.DefaultPrng.init(77777);
    var rng = prng.random();

    for (0..30) |_| {
        // Create two clearly intersecting lines
        const center = RandomGen.randomVec2(&rng, -50.0, 50.0);
        const offset = RandomGen.randomFloat(&rng, 5.0, 20.0);

        // One line goes from left to right
        const line1 = LineSegment.init(Vec2.init(center.x - offset, center.y), Vec2.init(center.x + offset, center.y));

        // Other line goes from bottom to top, crossing the first
        const line2 = LineSegment.init(Vec2.init(center.x, center.y - offset), Vec2.init(center.x, center.y + offset));

        // These should always intersect
        try std.testing.expect(primitives.lineLineIntersect(line1, line2));

        // Test with lines that clearly don't intersect
        const far_line = LineSegment.init(Vec2.init(center.x + offset * 3.0, center.y + offset * 3.0), Vec2.init(center.x + offset * 4.0, center.y + offset * 4.0));

        try std.testing.expect(!primitives.lineLineIntersect(line1, far_line));
        try std.testing.expect(!primitives.lineLineIntersect(line2, far_line));
    }
}
