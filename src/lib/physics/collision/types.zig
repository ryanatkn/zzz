//! Core types and constants for collision detection system
//!
//! Contains shared types, constants, and result structures used throughout
//! the collision detection modules.

const std = @import("std");
const math = @import("../../math/mod.zig");
const shapes = @import("../shapes.zig");

const Vec2 = math.Vec2;

// Re-export shape types for convenience
pub const Shape = shapes.Shape;
pub const Circle = shapes.Circle;
pub const Rectangle = shapes.Rectangle;
pub const Point = shapes.Point;
pub const LineSegment = shapes.LineSegment;

// Constants for collision detection accuracy and behavior
pub const LINE_THICKNESS_TOLERANCE: f32 = 0.5;
pub const PARALLEL_LINE_TOLERANCE: f32 = 0.001;
pub const MOVING_COLLISION_STEPS: u32 = 20;
pub const COLLISION_RESOLUTION_BUFFER: f32 = 0.1;
pub const FLOATING_POINT_TOLERANCE: f32 = 0.001;

/// Axis-aligned bounding box for spatial calculations
///
/// Represents a rectangular bounds with minimum and maximum corners.
/// Used for broad-phase collision detection, spatial partitioning,
/// and shape bounding calculations.
///
/// Example:
/// ```zig
/// const bounds = Bounds{ .min = Vec2.init(0, 0), .max = Vec2.init(10, 10) };
/// const width = bounds.width();
/// const height = bounds.height();
/// const center = bounds.center();
/// ```
pub const Bounds = struct {
    min: Vec2,
    max: Vec2,

    /// Calculate width of the bounding box
    pub fn width(self: Bounds) f32 {
        return self.max.x - self.min.x;
    }

    /// Calculate height of the bounding box
    pub fn height(self: Bounds) f32 {
        return self.max.y - self.min.y;
    }

    /// Calculate center point of the bounding box
    pub fn center(self: Bounds) Vec2 {
        return Vec2{
            .x = (self.min.x + self.max.x) * 0.5,
            .y = (self.min.y + self.max.y) * 0.5,
        };
    }

    /// Check if a point is inside the bounding box
    pub fn contains(self: Bounds, point: Vec2) bool {
        return point.x >= self.min.x and point.x <= self.max.x and
            point.y >= self.min.y and point.y <= self.max.y;
    }

    /// Check if this bounding box intersects with another
    pub fn intersects(self: Bounds, other: Bounds) bool {
        return self.min.x <= other.max.x and self.max.x >= other.min.x and
            self.min.y <= other.max.y and self.max.y >= other.min.y;
    }
};

/// Collision result with additional information
///
/// Contains all data needed for collision response and physics simulation:
/// - `collided`: Whether shapes are actually colliding
/// - `penetration_depth`: How far shapes have penetrated (0 if not colliding)
/// - `normal`: Unit vector pointing from shape1 to shape2 for separation
/// - `contact_point`: World position where collision occurs
///
/// The normal vector points in the direction shape1 should move to separate.
/// For symmetric cases (e.g., circle-rectangle vs rectangle-circle),
/// the normal is automatically flipped to maintain consistent direction.
pub const CollisionResult = struct {
    collided: bool,
    penetration_depth: f32 = 0.0,
    normal: Vec2 = Vec2.ZERO, // Direction to separate shapes
    contact_point: Vec2 = Vec2.ZERO,
};

/// 2D cross product (returns scalar)
/// Optimized for frequent use in line intersection calculations
pub inline fn vec2Cross(a: Vec2, b: Vec2) f32 {
    return a.x * b.y - a.y * b.x;
}

// Tests for collision types and utilities
test "vec2Cross calculation" {
    const v1 = Vec2.init(1.0, 0.0);
    const v2 = Vec2.init(0.0, 1.0);
    const v3 = Vec2.init(1.0, 1.0);

    // Basic cross product tests
    try std.testing.expect(vec2Cross(v1, v2) == 1.0);
    try std.testing.expect(vec2Cross(v2, v1) == -1.0);
    try std.testing.expect(vec2Cross(v1, v3) == 1.0);
    try std.testing.expect(vec2Cross(v3, v1) == -1.0);

    // Parallel vectors should have zero cross product
    try std.testing.expect(vec2Cross(v1, v1) == 0.0);
    try std.testing.expect(vec2Cross(v2, v2) == 0.0);
}

test "Bounds functionality" {
    const bounds = Bounds{ .min = Vec2.init(0.0, 0.0), .max = Vec2.init(10.0, 20.0) };

    // Test dimensions
    try std.testing.expect(bounds.width() == 10.0);
    try std.testing.expect(bounds.height() == 20.0);

    // Test center calculation
    const center = bounds.center();
    try std.testing.expect(center.x == 5.0);
    try std.testing.expect(center.y == 10.0);

    // Test containment
    try std.testing.expect(bounds.contains(Vec2.init(5.0, 10.0))); // Center point
    try std.testing.expect(bounds.contains(Vec2.init(0.0, 0.0))); // Min corner
    try std.testing.expect(bounds.contains(Vec2.init(10.0, 20.0))); // Max corner
    try std.testing.expect(!bounds.contains(Vec2.init(-1.0, 5.0))); // Outside left
    try std.testing.expect(!bounds.contains(Vec2.init(15.0, 5.0))); // Outside right

    // Test intersection
    const other1 = Bounds{ .min = Vec2.init(5.0, 5.0), .max = Vec2.init(15.0, 15.0) };
    const other2 = Bounds{ .min = Vec2.init(20.0, 20.0), .max = Vec2.init(30.0, 30.0) };

    try std.testing.expect(bounds.intersects(other1)); // Overlapping
    try std.testing.expect(!bounds.intersects(other2)); // Non-overlapping
}
