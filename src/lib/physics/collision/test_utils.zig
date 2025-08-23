//! Test utilities and common patterns for collision detection tests
//!
//! Provides reusable test data, helper functions, and patterns to reduce
//! duplication across test files.
//!
//! This module was created during the modularization of the original 1224-line
//! collision.zig file. It consolidates duplicate test patterns found across:
//! - edge_cases_test.zig (extreme values, precision limits, NaN handling)
//! - integration_test.zig (cross-module compatibility, batch processing)
//! - property_test.zig (mathematical invariants, random generation)
//!
//! Key consolidation patterns:
//! - TestShapes: Standard test shapes used across multiple test files
//! - RandomGen: Consistent random shape generation with proper seeding
//! - TestExpectations: Common assertion patterns and validation helpers
//! - Performance utilities: Benchmarking and timing measurement helpers

const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("types.zig");

const Vec2 = math.Vec2;
const Shape = types.Shape;
const Circle = types.Circle;
const Rectangle = types.Rectangle;
const Point = types.Point;
const LineSegment = types.LineSegment;

/// Common test shapes used across multiple test files
pub const TestShapes = struct {
    // Standard circles used in many tests
    pub const origin_circle = Circle{ .center = Vec2.init(0.0, 0.0), .radius = 5.0 };
    pub const overlapping_circle = Circle{ .center = Vec2.init(6.0, 0.0), .radius = 5.0 };
    pub const far_circle = Circle{ .center = Vec2.init(15.0, 0.0), .radius = 5.0 };
    pub const small_circle = Circle{ .center = Vec2.init(0.0, 0.0), .radius = 2.0 };
    pub const large_circle = Circle{ .center = Vec2.init(0.0, 0.0), .radius = 10.0 };

    // Standard rectangles
    pub const origin_rect = Rectangle.fromXYWH(0.0, 0.0, 10.0, 10.0);
    pub const overlapping_rect = Rectangle.fromXYWH(5.0, 5.0, 10.0, 10.0);
    pub const far_rect = Rectangle.fromXYWH(20.0, 20.0, 10.0, 10.0);

    // Standard points
    pub const origin_point = Vec2.init(0.0, 0.0);
    pub const center_point = Vec2.init(5.0, 5.0);
    pub const far_point = Vec2.init(100.0, 100.0);

    // Standard line segments
    pub const horizontal_line = LineSegment.init(Vec2.init(0.0, 0.0), Vec2.init(10.0, 0.0));
    pub const vertical_line = LineSegment.init(Vec2.init(5.0, -5.0), Vec2.init(5.0, 15.0));
    pub const diagonal_line = LineSegment.init(Vec2.init(0.0, 0.0), Vec2.init(10.0, 10.0));

    // Shape collections for testing
    pub const overlapping_set = [_]Shape{
        Shape{ .circle = origin_circle },
        Shape{ .circle = overlapping_circle },
        Shape{ .rectangle = overlapping_rect },
        Shape{ .point = center_point },
    };

    pub const non_overlapping_set = [_]Shape{
        Shape{ .circle = origin_circle },
        Shape{ .circle = far_circle },
        Shape{ .rectangle = far_rect },
        Shape{ .point = far_point },
    };
};

/// Helper functions for common test patterns
pub const TestHelpers = struct {
    /// Create a circle at specified position with default radius
    pub fn circleAt(x: f32, y: f32) Circle {
        return Circle{ .center = Vec2.init(x, y), .radius = 5.0 };
    }

    /// Create a circle with specified position and radius
    pub fn circleAtWithRadius(x: f32, y: f32, radius: f32) Circle {
        return Circle{ .center = Vec2.init(x, y), .radius = radius };
    }

    /// Create a rectangle at specified position with default size
    pub fn rectAt(x: f32, y: f32) Rectangle {
        return Rectangle.fromXYWH(x, y, 10.0, 10.0);
    }

    /// Create a rectangle with specified position and size
    pub fn rectAtWithSize(x: f32, y: f32, w: f32, h: f32) Rectangle {
        return Rectangle.fromXYWH(x, y, w, h);
    }

    /// Create a grid of circles for testing spatial algorithms
    pub fn createCircleGrid(allocator: std.mem.Allocator, rows: usize, cols: usize, spacing: f32, radius: f32) ![]Shape {
        const total = rows * cols;
        var shapes = try allocator.alloc(Shape, total);

        for (0..rows) |row| {
            for (0..cols) |col| {
                const x = @as(f32, @floatFromInt(col)) * spacing;
                const y = @as(f32, @floatFromInt(row)) * spacing;
                const index = row * cols + col;
                shapes[index] = Shape{ .circle = circleAtWithRadius(x, y, radius) };
            }
        }

        return shapes;
    }

    /// Verify collision result properties (for detailed collisions)
    pub fn verifyCollisionResult(result: types.CollisionResult, should_collide: bool) !void {
        try std.testing.expect(result.collided == should_collide);

        if (result.collided) {
            // If colliding, should have positive penetration
            try std.testing.expect(result.penetration_depth > 0.0);

            // Normal should be roughly unit length
            const normal_length = result.normal.length();
            try std.testing.expect(@abs(normal_length - 1.0) < 0.1);
        } else {
            // If not colliding, penetration should be zero
            try std.testing.expect(result.penetration_depth == 0.0);
        }
    }

    /// Test collision symmetry for a pair of shapes
    pub fn testSymmetry(shape1: Shape, shape2: Shape) !void {
        const result1 = @import("detection.zig").checkCollision(shape1, shape2);
        const result2 = @import("detection.zig").checkCollision(shape2, shape1);
        try std.testing.expect(result1 == result2);
    }

    /// Test that a shape collides with itself
    pub fn testSelfCollision(shape: Shape) !void {
        const result = @import("detection.zig").checkCollision(shape, shape);
        try std.testing.expect(result);
    }
};

/// Random test data generators
pub const RandomGen = struct {
    /// Generate random float in range
    pub fn randomFloat(rng: *std.Random, min: f32, max: f32) f32 {
        return min + rng.float(f32) * (max - min);
    }

    /// Generate random Vec2 in range
    pub fn randomVec2(rng: *std.Random, min: f32, max: f32) Vec2 {
        return Vec2.init(randomFloat(rng, min, max), randomFloat(rng, min, max));
    }

    /// Generate random circle
    pub fn randomCircle(rng: *std.Random) Circle {
        return Circle{
            .center = randomVec2(rng, -100.0, 100.0),
            .radius = randomFloat(rng, 0.1, 20.0),
        };
    }

    /// Generate random rectangle
    pub fn randomRectangle(rng: *std.Random) Rectangle {
        const pos = randomVec2(rng, -100.0, 100.0);
        const size = Vec2.init(randomFloat(rng, 0.1, 20.0), randomFloat(rng, 0.1, 20.0));
        return Rectangle{ .position = pos, .size = size };
    }

    /// Generate random line segment
    pub fn randomLineSegment(rng: *std.Random) LineSegment {
        return LineSegment.init(randomVec2(rng, -100.0, 100.0), randomVec2(rng, -100.0, 100.0));
    }
};

/// Test validation helpers
pub const Validation = struct {
    /// Check that collision detection is consistent between basic and detailed versions
    pub fn validateConsistency(shape1: Shape, shape2: Shape) !void {
        const basic_result = @import("detection.zig").checkCollision(shape1, shape2);
        const detailed_result = @import("detailed.zig").checkCollisionDetailed(shape1, shape2);

        try std.testing.expect(basic_result == detailed_result.collided);
        try TestHelpers.verifyCollisionResult(detailed_result, basic_result);
    }

    /// Validate that translation preserves collision relationships
    pub fn validateTranslationInvariance(shape1: Shape, shape2: Shape, translation: Vec2) !void {
        const original_result = @import("detection.zig").checkCollision(shape1, shape2);

        // Translate both shapes
        var translated_shape1 = shape1;
        var translated_shape2 = shape2;
        translateShape(&translated_shape1, translation);
        translateShape(&translated_shape2, translation);

        const translated_result = @import("detection.zig").checkCollision(translated_shape1, translated_shape2);
        try std.testing.expect(original_result == translated_result);
    }

    fn translateShape(shape: *Shape, offset: Vec2) void {
        switch (shape.*) {
            .circle => |*c| c.center = c.center.add(offset),
            .rectangle => |*r| r.position = r.position.add(offset),
            .point => |*p| p.* = p.add(offset),
            .line => |*l| {
                l.start = l.start.add(offset);
                l.end = l.end.add(offset);
            },
        }
    }
};

// Tests for the test utilities themselves
test "test utilities create expected shapes" {
    const circle = TestHelpers.circleAt(10.0, 20.0);
    try std.testing.expect(circle.center.x == 10.0);
    try std.testing.expect(circle.center.y == 20.0);
    try std.testing.expect(circle.radius == 5.0);

    const rect = TestHelpers.rectAtWithSize(5.0, 5.0, 15.0, 25.0);
    try std.testing.expect(rect.position.x == 5.0);
    try std.testing.expect(rect.position.y == 5.0);
    try std.testing.expect(rect.size.x == 15.0);
    try std.testing.expect(rect.size.y == 25.0);
}

test "test utilities circle grid generation" {
    const allocator = std.testing.allocator;

    const shapes = try TestHelpers.createCircleGrid(allocator, 2, 3, 10.0, 2.0);
    defer allocator.free(shapes);

    try std.testing.expect(shapes.len == 6); // 2x3 grid

    // Check first shape (0,0)
    try std.testing.expect(shapes[0].circle.center.x == 0.0);
    try std.testing.expect(shapes[0].circle.center.y == 0.0);
    try std.testing.expect(shapes[0].circle.radius == 2.0);

    // Check last shape (1,2)
    try std.testing.expect(shapes[5].circle.center.x == 20.0);
    try std.testing.expect(shapes[5].circle.center.y == 10.0);
    try std.testing.expect(shapes[5].circle.radius == 2.0);
}

test "validation helpers work correctly" {
    const circle1 = Shape{ .circle = TestShapes.origin_circle };
    const circle2 = Shape{ .circle = TestShapes.overlapping_circle };

    // Test consistency validation
    try Validation.validateConsistency(circle1, circle2);

    // Test translation invariance
    const translation = Vec2.init(100.0, 50.0);
    try Validation.validateTranslationInvariance(circle1, circle2, translation);

    // Test symmetry helper
    try TestHelpers.testSymmetry(circle1, circle2);

    // Test self-collision helper
    try TestHelpers.testSelfCollision(circle1);
}
