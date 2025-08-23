const std = @import("std");
const math = @import("../math/mod.zig");

// Re-export shapes from math module
pub const Circle = math.Circle;
pub const Rectangle = math.Rectangle;
pub const Line = math.Line;
pub const Bounds = math.Bounds;

// Use Vec2 from math (not through types.zig)
const Vec2 = math.Vec2;

/// Point is now just an alias for Vec2
pub const Point = Vec2;

/// Line segment is an alias for Line
pub const LineSegment = Line;

/// Unified shape union for collision detection
pub const Shape = union(enum) {
    circle: Circle,
    rectangle: Rectangle,
    line: Line,
    point: Point,

    /// Get bounding box for any shape
    pub fn getBounds(self: Shape) Bounds {
        return switch (self) {
            .circle => |c| c.bounds(),
            .rectangle => |r| r.bounds(),
            .line => |l| l.bounds(),
            .point => |p| Bounds.fromCenterSize(p, 0.01, 0.01), // Tiny bounds for point
        };
    }

    /// Check if point is inside any shape
    pub fn contains(self: Shape, point: Vec2) bool {
        return switch (self) {
            .circle => |c| c.contains(point),
            .rectangle => |r| r.contains(point),
            .line => |l| l.distanceToPoint(point) < 0.5, // Line thickness for collision
            .point => |p| p.equals(point, 0.5), // Small tolerance for point collision
        };
    }

    /// Get center point of any shape
    pub fn center(self: Shape) Vec2 {
        return switch (self) {
            .circle => |c| c.center,
            .rectangle => |r| r.center(),
            .line => |l| l.midpoint(),
            .point => |p| p,
        };
    }
};

/// Physics-specific shape extensions
pub const PhysicsExt = struct {
    /// Calculate moment of inertia for different shapes
    pub fn momentOfInertia(shape: Shape, mass: f32) f32 {
        return switch (shape) {
            .circle => |c| 0.5 * mass * c.radius * c.radius,
            .rectangle => |r| (mass / 12.0) * (r.size.x * r.size.x + r.size.y * r.size.y),
            .line => |l| (mass / 12.0) * l.lengthSquared(),
            .point => 0.0,
        };
    }

    /// Calculate area for mass/density calculations
    pub fn area(shape: Shape) f32 {
        return switch (shape) {
            .circle => |c| c.area(),
            .rectangle => |r| r.area(),
            .line => 0.0, // Lines have no area
            .point => 0.0, // Points have no area
        };
    }

    /// Move shape by offset (mutates shape)
    pub fn translate(shape: *Shape, offset: Vec2) void {
        switch (shape.*) {
            .circle => |*c| c.center = c.center.add(offset),
            .rectangle => |*r| r.position = r.position.add(offset),
            .line => |*l| {
                l.start = l.start.add(offset);
                l.end = l.end.add(offset);
            },
            .point => |*p| p.* = p.add(offset),
        }
    }

    /// Scale shape by factor (mutates shape)
    pub fn scale(shape: *Shape, factor: f32) void {
        switch (shape.*) {
            .circle => |*c| c.radius *= factor,
            .rectangle => |*r| r.size = r.size.scale(factor),
            .line => |*l| {
                const center = l.midpoint();
                const half_vec = l.vector().scale(0.5 * factor);
                l.start = center.sub(half_vec);
                l.end = center.add(half_vec);
            },
            .point => {}, // Points don't scale
        }
    }
};

test "shape union operations" {
    const circle = Shape{ .circle = Circle.init(Vec2.init(0.0, 0.0), 5.0) };
    const rect = Shape{ .rectangle = Rectangle.fromXYWH(10.0, 10.0, 20.0, 30.0) };

    try std.testing.expect(circle.contains(Vec2.init(3.0, 4.0)));
    try std.testing.expect(rect.contains(Vec2.init(15.0, 15.0)));

    const circle_bounds = circle.getBounds();
    const rect_bounds = rect.getBounds();

    try std.testing.expect(circle_bounds.width() == 10.0);
    try std.testing.expect(rect_bounds.width() == 20.0);
}

test "physics extensions" {
    var circle = Shape{ .circle = Circle.init(Vec2.init(0.0, 0.0), 5.0) };

    const area = PhysicsExt.area(circle);
    try std.testing.expect(@abs(area - 78.54) < 0.1);

    PhysicsExt.translate(&circle, Vec2.init(10.0, 0.0));
    try std.testing.expect(circle.center().x == 10.0);

    PhysicsExt.scale(&circle, 2.0);
    try std.testing.expect(circle.circle.radius == 10.0);
}
