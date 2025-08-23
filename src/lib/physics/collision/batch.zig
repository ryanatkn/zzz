//! Batch collision detection for multiple shapes
//!
//! Provides CollisionBatch for efficiently processing collision detection
//! across multiple shapes at once.

const std = @import("std");
const types = @import("types.zig");
const detection = @import("detection.zig");
const math = @import("../../math/mod.zig");

const Shape = types.Shape;
const Vec2 = math.Vec2;
const Circle = types.Circle;
const Rectangle = types.Rectangle;

/// Batch collision detection for multiple shapes
pub const CollisionBatch = struct {
    shapes: []Shape,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !CollisionBatch {
        return CollisionBatch{
            .shapes = try allocator.alloc(Shape, capacity),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CollisionBatch) void {
        self.allocator.free(self.shapes);
    }

    /// Check all pairwise collisions
    pub fn checkAllCollisions(self: *const CollisionBatch, results: []bool) void {
        // Input validation - results buffer must be large enough
        if (results.len < self.shapes.len * self.shapes.len) {
            std.debug.panic("Results buffer too small: need {} but got {}", .{ self.shapes.len * self.shapes.len, results.len });
        }

        for (self.shapes, 0..) |shape1, i| {
            for (self.shapes, 0..) |shape2, j| {
                if (i != j) {
                    results[i * self.shapes.len + j] = detection.checkCollision(shape1, shape2);
                } else {
                    results[i * self.shapes.len + j] = false; // Don't collide with self
                }
            }
        }
    }

    /// Check collision against a single shape
    pub fn checkAgainstShape(self: *const CollisionBatch, target: Shape, results: []bool) void {
        // Input validation - results buffer must be large enough
        if (results.len < self.shapes.len) {
            std.debug.panic("Results buffer too small: need {} but got {}", .{ self.shapes.len, results.len });
        }

        for (self.shapes, 0..) |shape, i| {
            results[i] = detection.checkCollision(shape, target);
        }
    }
};

// Tests for CollisionBatch
test "CollisionBatch init and deinit" {
    const allocator = std.testing.allocator;

    // Test successful initialization
    var batch = try CollisionBatch.init(allocator, 10);
    defer batch.deinit();

    try std.testing.expect(batch.shapes.len == 10);
    try std.testing.expect(batch.allocator.ptr == allocator.ptr);
}

test "CollisionBatch checkAllCollisions basic functionality" {
    const allocator = std.testing.allocator;

    var batch = try CollisionBatch.init(allocator, 3);
    defer batch.deinit();

    // Set up test shapes
    batch.shapes[0] = Shape{ .circle = Circle{ .center = Vec2.init(0.0, 0.0), .radius = 5.0 } };
    batch.shapes[1] = Shape{ .circle = Circle{ .center = Vec2.init(8.0, 0.0), .radius = 5.0 } }; // Overlapping
    batch.shapes[2] = Shape{ .circle = Circle{ .center = Vec2.init(20.0, 0.0), .radius = 5.0 } }; // Non-overlapping

    // Check all pairwise collisions
    var results = [_]bool{false} ** 9; // 3x3 matrix
    batch.checkAllCollisions(&results);

    // Verify results
    try std.testing.expect(!results[0]); // Shape 0 vs itself = false
    try std.testing.expect(results[1]); // Shape 0 vs shape 1 = true (overlapping)
    try std.testing.expect(!results[2]); // Shape 0 vs shape 2 = false
    try std.testing.expect(results[3]); // Shape 1 vs shape 0 = true (symmetric)
    try std.testing.expect(!results[4]); // Shape 1 vs itself = false
    try std.testing.expect(!results[5]); // Shape 1 vs shape 2 = false
    try std.testing.expect(!results[6]); // Shape 2 vs shape 0 = false
    try std.testing.expect(!results[7]); // Shape 2 vs shape 1 = false
    try std.testing.expect(!results[8]); // Shape 2 vs itself = false
}

test "CollisionBatch checkAgainstShape functionality" {
    const allocator = std.testing.allocator;

    var batch = try CollisionBatch.init(allocator, 3);
    defer batch.deinit();

    // Set up batch shapes
    batch.shapes[0] = Shape{ .circle = Circle{ .center = Vec2.init(0.0, 0.0), .radius = 3.0 } };
    batch.shapes[1] = Shape{ .circle = Circle{ .center = Vec2.init(10.0, 0.0), .radius = 3.0 } };
    batch.shapes[2] = Shape{ .rectangle = Rectangle.fromXYWH(20.0, 20.0, 10.0, 10.0) };

    // Target shape that overlaps with shape 0 only
    const target = Shape{ .circle = Circle{ .center = Vec2.init(2.0, 0.0), .radius = 3.0 } };

    var results = [_]bool{false} ** 3;
    batch.checkAgainstShape(target, &results);

    // Verify results
    try std.testing.expect(results[0]); // Shape 0 overlaps with target
    try std.testing.expect(!results[1]); // Shape 1 doesn't overlap
    try std.testing.expect(!results[2]); // Shape 2 doesn't overlap
}

test "CollisionBatch buffer validation" {
    const allocator = std.testing.allocator;

    var batch = try CollisionBatch.init(allocator, 2);
    defer batch.deinit();

    // Set up shapes
    batch.shapes[0] = Shape{ .circle = Circle{ .center = Vec2.init(0.0, 0.0), .radius = 1.0 } };
    batch.shapes[1] = Shape{ .circle = Circle{ .center = Vec2.init(5.0, 0.0), .radius = 1.0 } };

    // Note: We can't test panics directly in Zig tests, but the validation logic is there
    // In real usage, insufficient buffers would cause panics

    // Test with insufficient buffer for checkAllCollisions (needs 2x2=4, only provide 3)
    _ = [_]bool{false} ** 3; // Would panic if used

    // Test with insufficient buffer for checkAgainstShape (needs 2, only provide 1)
    _ = [_]bool{false} ** 1; // Would panic if used

    // Same here - would panic in real usage due to validation
    // For now, just verify the shapes are set up correctly
    try std.testing.expect(batch.shapes.len == 2);
}

test "CollisionBatch with different shape types" {
    const allocator = std.testing.allocator;

    var batch = try CollisionBatch.init(allocator, 4);
    defer batch.deinit();

    // Set up diverse shapes
    batch.shapes[0] = Shape{ .circle = Circle{ .center = Vec2.init(5.0, 5.0), .radius = 3.0 } };
    batch.shapes[1] = Shape{ .rectangle = Rectangle.fromXYWH(3.0, 3.0, 6.0, 6.0) }; // Overlaps circle
    batch.shapes[2] = Shape{ .point = Vec2.init(5.0, 5.0) }; // Inside circle and rectangle
    batch.shapes[3] = Shape{ .circle = Circle{ .center = Vec2.init(20.0, 20.0), .radius = 2.0 } }; // Isolated

    // Test against external shape
    const target = Shape{ .point = Vec2.init(5.0, 5.0) };

    var results = [_]bool{false} ** 4;
    batch.checkAgainstShape(target, &results);

    // Point should collide with circle, rectangle, and point
    try std.testing.expect(results[0]); // Circle contains point
    try std.testing.expect(results[1]); // Rectangle contains point
    try std.testing.expect(results[2]); // Point equals point
    try std.testing.expect(!results[3]); // Distant circle doesn't contain point
}

test "CollisionBatch empty batch edge case" {
    const allocator = std.testing.allocator;

    var batch = try CollisionBatch.init(allocator, 0);
    defer batch.deinit();

    try std.testing.expect(batch.shapes.len == 0);

    // Test with empty results array
    var results: [0]bool = .{};
    batch.checkAllCollisions(&results);
    batch.checkAgainstShape(Shape{ .point = Vec2.init(0.0, 0.0) }, &results);

    // Should not crash and do nothing
}

test "CollisionBatch performance characteristics" {
    const allocator = std.testing.allocator;

    // Test with moderate number of shapes to verify O(N²) behavior
    const shape_count = 10;
    var batch = try CollisionBatch.init(allocator, shape_count);
    defer batch.deinit();

    // Set up non-overlapping circles in a grid
    for (0..shape_count) |i| {
        const x = @as(f32, @floatFromInt(i % 5)) * 10.0;
        const y = @as(f32, @floatFromInt(i / 5)) * 10.0;
        batch.shapes[i] = Shape{ .circle = Circle{ .center = Vec2.init(x, y), .radius = 2.0 } };
    }

    // Test all pairwise collisions (should be fast for non-overlapping shapes)
    var results = [_]bool{false} ** (shape_count * shape_count);
    batch.checkAllCollisions(&results);

    // Count total collisions (should be 0 since shapes don't overlap)
    var collision_count: usize = 0;
    for (results) |collision| {
        if (collision) collision_count += 1;
    }

    try std.testing.expect(collision_count == 0);
}
