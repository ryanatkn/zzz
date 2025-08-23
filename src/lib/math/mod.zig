/// Math module - Unified mathematical operations and geometric primitives
///
/// This module provides all mathematical functionality used across the engine:
/// - Vec2 operations and 2D vector math
/// - Scalar math utilities (lerp, clamp, etc.)
/// - Easing functions for animations
/// - Interpolation utilities (bezier, hermite, etc.)
/// - Geometric shapes (Rectangle, Circle, Line, Bounds)
/// - Distance calculations and transformations
/// - Coordinate system conversions
pub const Vec2 = @import("vec2.zig").Vec2;
pub const scalar = @import("scalar.zig");
pub const shapes = @import("shapes.zig");
pub const easing = @import("easing.zig");
pub const interpolation = @import("interpolation.zig");
pub const color = @import("color.zig");
pub const waves = @import("waves.zig");
pub const geometry = @import("geometry.zig");
pub const smoothing = @import("smoothing.zig");

// Re-export scalar utilities
pub const lerp = scalar.lerp;
pub const clamp = scalar.clamp;
pub const equals = scalar.equals;
pub const smoothDamp = scalar.smoothDamp;
pub const moveTowards = scalar.moveTowards;
pub const wrapAngle = scalar.wrapAngle;
pub const angleDifference = scalar.angleDifference;
pub const lerpAngle = scalar.lerpAngle;

// Re-export shapes
pub const Rectangle = shapes.Rectangle;
pub const Circle = shapes.Circle;
pub const Line = shapes.Line;
pub const Bounds = shapes.Bounds;
pub const GlyphBounds = shapes.GlyphBounds;
pub const Spacing = shapes.Spacing;

// Re-export color utilities
pub const Color = color.Color;
pub const ColorF32 = color.ColorF32;
pub const ColorPair = color.ColorPair;
pub const ColorMath = color.ColorMath;

// Re-export wave utilities
pub const WaveGenerator = waves.WaveGenerator;
pub const AnimationWaves = waves.AnimationWaves;
pub const WaveUtils = waves.WaveUtils;

// Re-export geometry utilities
pub const GeometryUtils = geometry.GeometryUtils;

// Re-export smoothing utilities
pub const SmoothingUtils = smoothing.SmoothingUtils;

// Commonly used geometry functions for convenience
pub const geometryDistance = geometry.GeometryUtils.distance;
pub const geometryDistanceSquared = geometry.GeometryUtils.distanceSquared;
pub const geometryCentroid = geometry.GeometryUtils.centroid;

// Commonly used smoothing functions for convenience
pub const exponentialSmooth = smoothing.SmoothingUtils.exponentialSmooth;
pub const exponentialSmoothVec2 = smoothing.SmoothingUtils.exponentialSmoothVec2;

// Import vec2 for standalone functions
const vec2 = @import("vec2.zig");

// Distance functions (used frequently)
pub const distance = vec2.distance;
pub const distanceSquared = vec2.distanceSquared;

// Direction functions (used frequently)
pub const directionBetween = vec2.directionBetween;

test "math module integration" {
    const std = @import("std");

    // Test Vec2 operations
    const v1 = Vec2.init(3.0, 4.0);
    const v2 = Vec2.init(1.0, 2.0);

    const sum = v1.add(v2);
    try std.testing.expect(sum.x == 4.0 and sum.y == 6.0);

    // Test shapes
    const rect = Rectangle.fromXYWH(10.0, 20.0, 30.0, 40.0);
    const circle = Circle.init(Vec2.init(0.0, 0.0), 5.0);

    try std.testing.expect(rect.area() == 1200.0);
    try std.testing.expect(circle.contains(Vec2.init(3.0, 4.0)));

    // Test scalar functions
    try std.testing.expect(lerp(0.0, 10.0, 0.5) == 5.0);

    // Test distance functions
    try std.testing.expect(distance(v1, v2) == v1.distance(v2));
}
