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

// Re-export Vec2 function-style API for compatibility
const vec2 = @import("vec2.zig");
pub const vec2_length = vec2.vec2_length;
pub const vec2_lengthSquared = vec2.vec2_lengthSquared;
pub const vec2_normalize = vec2.vec2_normalize;
pub const vec2_add = vec2.vec2_add;
pub const vec2_subtract = vec2.vec2_subtract;
pub const vec2_multiply = vec2.vec2_multiply;
pub const vec2_divide = vec2.vec2_divide;
pub const vec2_dot = vec2.vec2_dot;
pub const vec2_lerp = vec2.vec2_lerp;
pub const vec2_direction = vec2.vec2_direction;
pub const vec2_isZero = vec2.vec2_isZero;
pub const vec2_isEqual = vec2.vec2_isEqual;
pub const vec2_clamp = vec2.vec2_clamp;
pub const vec2_angleTo = vec2.vec2_angleTo;
pub const vec2_rotate = vec2.vec2_rotate;
pub const vec2_reflect = vec2.vec2_reflect;
pub const vec2_project = vec2.vec2_project;
pub const vec2_perpendicular = vec2.vec2_perpendicular;
pub const vec2_moveTowards = vec2.vec2_moveTowards;
pub const vec2_smoothDamp = vec2.vec2_smoothDamp;
pub const vec2_isWithinCircle = vec2.vec2_isWithinCircle;
pub const vec2_isWithinRect = vec2.vec2_isWithinRect;
pub const vec2_clampToCircle = vec2.vec2_clampToCircle;
pub const vec2_clampToRect = vec2.vec2_clampToRect;
pub const vec2_worldToScreen = vec2.vec2_worldToScreen;
pub const vec2_screenToWorld = vec2.vec2_screenToWorld;

// Distance functions (used frequently)
pub const distance = vec2.distance;
pub const distanceSquared = vec2.distanceSquared;

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

    // Test compatibility functions
    try std.testing.expect(vec2_length(v1) == v1.length());
    try std.testing.expect(distance(v1, v2) == v1.distance(v2));
}
