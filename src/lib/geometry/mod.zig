/// Geometry module - Unified geometric primitives and utilities
/// 
/// This module provides shared geometric types and operations used across
/// the font, rendering, physics, and UI systems.
///
/// Key features:
/// - Point operations (add, subtract, distance, etc.)
/// - Bounds/rectangle types with intersection testing
/// - Shape primitives (Circle, Line, Rectangle)
/// - Geometric utilities (point-in-polygon, line intersection, transformations)
/// - Optimized for font rasterization and collision detection

pub const Point = @import("point.zig").Point;
pub const Bounds = @import("bounds.zig").Bounds;
pub const GlyphBounds = @import("bounds.zig").GlyphBounds;
pub const Circle = @import("shapes.zig").Circle;
pub const Line = @import("shapes.zig").Line;
pub const Rectangle = @import("shapes.zig").Rectangle;
pub const Utils = @import("utils.zig").Utils;

// Re-export commonly used functions for convenience
pub const pointInPolygon = Utils.pointInPolygon;
pub const windingNumber = Utils.windingNumber;
pub const lineSegmentsIntersect = Utils.lineSegmentsIntersect;
pub const translatePoint = Utils.translatePoint;
pub const scalePoint = Utils.scalePoint;
pub const rotatePoint = Utils.rotatePoint;

test "geometry module integration" {
    const std = @import("std");
    
    // Test that all types work together
    const center = Point.init(50.0, 50.0);
    const circle = Circle.init(center, 25.0);
    const rect = Rectangle.fromBounds(circle.bounds());
    
    try std.testing.expect(rect.contains(center));
    try std.testing.expect(circle.contains(center));
    
    // Test polygon operations
    const triangle = [_]Point{
        Point.init(0.0, 0.0),
        Point.init(100.0, 0.0),
        Point.init(50.0, 100.0),
    };
    
    const inside_point = Point.init(50.0, 30.0);
    try std.testing.expect(pointInPolygon(inside_point, &triangle));
    
    const outside_point = Point.init(10.0, 90.0);
    try std.testing.expect(!pointInPolygon(outside_point, &triangle));
}