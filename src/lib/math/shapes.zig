const std = @import("std");
const Vec2 = @import("vec2.zig").Vec2;
const scalar = @import("scalar.zig");
const bounds_module = @import("bounds.zig");

// Re-export bounds types from dedicated module
pub const Bounds = bounds_module.Bounds;
pub const GlyphBounds = bounds_module.GlyphBounds;

/// Spacing for margins, padding, and borders (CSS-style)
pub const Spacing = struct {
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,

    pub fn uniform(value: f32) Spacing {
        return Spacing{ .top = value, .right = value, .bottom = value, .left = value };
    }

    pub fn horizontal(value: f32) Spacing {
        return Spacing{ .left = value, .right = value };
    }

    pub fn vertical(value: f32) Spacing {
        return Spacing{ .top = value, .bottom = value };
    }

    pub fn asymmetric(vert: f32, horiz: f32) Spacing {
        return Spacing{ .top = vert, .right = horiz, .bottom = vert, .left = horiz };
    }

    pub fn getHorizontal(self: Spacing) f32 {
        return self.left + self.right;
    }

    pub fn getVertical(self: Spacing) f32 {
        return self.top + self.bottom;
    }

    pub fn add(self: Spacing, other: Spacing) Spacing {
        return Spacing{
            .top = self.top + other.top,
            .right = self.right + other.right,
            .bottom = self.bottom + other.bottom,
            .left = self.left + other.left,
        };
    }

    pub fn scale(self: Spacing, factor: f32) Spacing {
        return Spacing{
            .top = self.top * factor,
            .right = self.right * factor,
            .bottom = self.bottom * factor,
            .left = self.left * factor,
        };
    }
};

/// Rectangle shape with position and size fields for compatibility
pub const Rectangle = struct {
    position: Vec2,
    size: Vec2,

    /// Create a new rectangle from position and size
    pub fn init(position: Vec2, size: Vec2) Rectangle {
        return .{ .position = position, .size = size };
    }

    /// Create from x, y, width, height
    pub fn fromXYWH(x: f32, y: f32, width: f32, height: f32) Rectangle {
        return .{ .position = Vec2.init(x, y), .size = Vec2.init(width, height) };
    }

    /// Create from bounds
    pub fn fromBounds(rect_bounds: Bounds) Rectangle {
        return .{
            .position = Vec2.init(rect_bounds.x_min, rect_bounds.y_min),
            .size = Vec2.init(rect_bounds.width(), rect_bounds.height()),
        };
    }

    /// Get bounds
    pub fn bounds(self: Rectangle) Bounds {
        return Bounds.init(self.position.x, self.position.y, self.position.x + self.size.x, self.position.y + self.size.y);
    }

    /// Get center point
    pub fn center(self: Rectangle) Vec2 {
        return Vec2.init(self.position.x + self.size.x * 0.5, self.position.y + self.size.y * 0.5);
    }

    /// Check if point is inside rectangle
    pub fn contains(self: Rectangle, point: Vec2) bool {
        return point.x >= self.position.x and point.x <= self.position.x + self.size.x and
            point.y >= self.position.y and point.y <= self.position.y + self.size.y;
    }

    /// Check if rectangles intersect
    pub fn intersects(self: Rectangle, other: Rectangle) bool {
        return self.position.x <= other.position.x + other.size.x and self.position.x + self.size.x >= other.position.x and
            self.position.y <= other.position.y + other.size.y and self.position.y + self.size.y >= other.position.y;
    }

    /// Get area
    pub fn area(self: Rectangle) f32 {
        return self.size.x * self.size.y;
    }

    /// Get perimeter
    pub fn perimeter(self: Rectangle) f32 {
        return 2.0 * (self.size.x + self.size.y);
    }

    /// Apply spacing insets to rectangle (shrink by spacing)
    pub fn applySpacing(self: Rectangle, spacing: Spacing) Rectangle {
        return Rectangle{
            .position = Vec2{
                .x = self.position.x + spacing.left,
                .y = self.position.y + spacing.top,
            },
            .size = Vec2{
                .x = @max(0, self.size.x - spacing.getHorizontal()),
                .y = @max(0, self.size.y - spacing.getVertical()),
            },
        };
    }

    /// Expand rectangle by spacing (grow by spacing)
    pub fn expandBySpacing(self: Rectangle, spacing: Spacing) Rectangle {
        return Rectangle{
            .position = Vec2{
                .x = self.position.x - spacing.left,
                .y = self.position.y - spacing.top,
            },
            .size = Vec2{
                .x = self.size.x + spacing.getHorizontal(),
                .y = self.size.y + spacing.getVertical(),
            },
        };
    }

    /// Get content area (rectangle minus padding)
    pub fn getContentArea(self: Rectangle, padding: Spacing) Rectangle {
        return self.applySpacing(padding);
    }

    /// Get padding area (content plus padding)
    pub fn getPaddingArea(self: Rectangle, padding: Spacing) Rectangle {
        return self.expandBySpacing(padding);
    }

    /// Apply margin outsets (expand by margin)
    pub fn applyMargin(self: Rectangle, margin: Spacing) Rectangle {
        return self.expandBySpacing(margin);
    }

    /// Layout-specific rectangle operations
    pub fn split(self: Rectangle, axis: enum { horizontal, vertical }, ratio: f32) struct { first: Rectangle, second: Rectangle } {
        const clamped_ratio = scalar.clamp(ratio, 0.0, 1.0);

        return switch (axis) {
            .horizontal => blk: {
                const first_width = self.size.x * clamped_ratio;
                const second_width = self.size.x - first_width;

                break :blk .{
                    .first = Rectangle{
                        .position = self.position,
                        .size = Vec2{ .x = first_width, .y = self.size.y },
                    },
                    .second = Rectangle{
                        .position = Vec2{ .x = self.position.x + first_width, .y = self.position.y },
                        .size = Vec2{ .x = second_width, .y = self.size.y },
                    },
                };
            },
            .vertical => blk: {
                const first_height = self.size.y * clamped_ratio;
                const second_height = self.size.y - first_height;

                break :blk .{
                    .first = Rectangle{
                        .position = self.position,
                        .size = Vec2{ .x = self.size.x, .y = first_height },
                    },
                    .second = Rectangle{
                        .position = Vec2{ .x = self.position.x, .y = self.position.y + first_height },
                        .size = Vec2{ .x = self.size.x, .y = second_height },
                    },
                };
            },
        };
    }

    /// Create a rectangle centered at the given point with the specified size
    pub fn centered(center_point: Vec2, rect_size: Vec2) Rectangle {
        return Rectangle{
            .position = Vec2{
                .x = center_point.x - rect_size.x * 0.5,
                .y = center_point.y - rect_size.y * 0.5,
            },
            .size = rect_size,
        };
    }

    /// Create a rectangle with specified size at origin (0,0)
    pub fn sized(rect_size: Vec2) Rectangle {
        return Rectangle{
            .position = Vec2.ZERO,
            .size = rect_size,
        };
    }

    /// Create a rectangle with specified size at origin using width/height
    pub fn sizedWH(width: f32, height: f32) Rectangle {
        return Rectangle{
            .position = Vec2.ZERO,
            .size = Vec2.size(width, height),
        };
    }

    /// Create a rectangle from bounds (semantic alias for fromBounds)
    pub fn bounds_rect(rect_bounds: Bounds) Rectangle {
        return fromBounds(rect_bounds);
    }

    /// Create a square centered at the given point
    pub fn centeredSquare(center_point: Vec2, side_length: f32) Rectangle {
        const half_side = side_length * 0.5;
        return Rectangle{
            .position = Vec2{
                .x = center_point.x - half_side,
                .y = center_point.y - half_side,
            },
            .size = Vec2{
                .x = side_length,
                .y = side_length,
            },
        };
    }

    /// Create a square with specified side length at origin
    pub fn square(side_length: f32) Rectangle {
        return Rectangle{
            .position = Vec2.ZERO,
            .size = Vec2{
                .x = side_length,
                .y = side_length,
            },
        };
    }
};

/// Circle shape
pub const Circle = struct {
    center: Vec2,
    radius: f32,

    /// Create a new circle
    pub fn init(center: Vec2, radius: f32) Circle {
        return .{ .center = center, .radius = radius };
    }

    /// Check if point is inside circle
    pub fn contains(self: Circle, point: Vec2) bool {
        return self.center.distanceSquared(point) <= self.radius * self.radius;
    }

    /// Get bounding box
    pub fn bounds(self: Circle) Bounds {
        return Bounds.init(
            self.center.x - self.radius,
            self.center.y - self.radius,
            self.center.x + self.radius,
            self.center.y + self.radius,
        );
    }

    /// Get area
    pub fn area(self: Circle) f32 {
        return std.math.pi * self.radius * self.radius;
    }

    /// Get circumference
    pub fn circumference(self: Circle) f32 {
        return 2.0 * std.math.pi * self.radius;
    }

    /// Check if circles intersect
    pub fn intersects(self: Circle, other: Circle) bool {
        const distance_sq = self.center.distanceSquared(other.center);
        const sum_radii = self.radius + other.radius;
        return distance_sq <= sum_radii * sum_radii;
    }
};

/// Line segment
pub const Line = struct {
    start: Vec2,
    end: Vec2,

    /// Create a new line
    pub fn init(start: Vec2, end: Vec2) Line {
        return .{ .start = start, .end = end };
    }

    /// Get length of line
    pub fn length(self: Line) f32 {
        return self.start.distance(self.end);
    }

    /// Get squared length (faster)
    pub fn lengthSquared(self: Line) f32 {
        return self.start.distanceSquared(self.end);
    }

    /// Get direction vector (normalized)
    pub fn direction(self: Line) Vec2 {
        return self.end.sub(self.start).normalize();
    }

    /// Get vector from start to end
    pub fn vector(self: Line) Vec2 {
        return self.end.sub(self.start);
    }

    /// Get point at parameter t (0.0 = start, 1.0 = end)
    pub fn pointAt(self: Line, t: f32) Vec2 {
        return self.start.lerp(self.end, t);
    }

    /// Get midpoint
    pub fn midpoint(self: Line) Vec2 {
        return self.pointAt(0.5);
    }

    /// Get closest point on line to given point
    pub fn closestPointTo(self: Line, point: Vec2) Vec2 {
        const line_vec = self.vector();
        const point_vec = point.sub(self.start);
        const line_len_sq = line_vec.lengthSquared();

        if (line_len_sq == 0) return self.start;

        const t = scalar.clamp(point_vec.dot(line_vec) / line_len_sq, 0.0, 1.0);
        return self.pointAt(t);
    }

    /// Get distance from point to line
    pub fn distanceToPoint(self: Line, point: Vec2) f32 {
        const closest = self.closestPointTo(point);
        return point.distance(closest);
    }

    /// Get bounding box
    pub fn bounds(self: Line) Bounds {
        return Bounds.fromPoints(self.start, self.end);
    }
};

test "Rectangle operations" {
    const rect = Rectangle.fromXYWH(10.0, 20.0, 30.0, 40.0);

    try std.testing.expect(rect.area() == 1200.0);
    try std.testing.expect(rect.contains(Vec2.init(25.0, 35.0)));
    try std.testing.expect(!rect.contains(Vec2.init(5.0, 35.0)));

    const center_pt = rect.center();
    try std.testing.expect(center_pt.x == 25.0 and center_pt.y == 40.0);
}

test "Circle operations" {
    const circle = Circle.init(Vec2.init(0.0, 0.0), 5.0);

    try std.testing.expect(circle.contains(Vec2.init(3.0, 4.0))); // 3-4-5 triangle
    try std.testing.expect(!circle.contains(Vec2.init(5.0, 5.0))); // Outside

    const area = circle.area();
    try std.testing.expect(@abs(area - 78.54) < 0.1); // π * 5²
}


test "Spacing operations" {
    const spacing = Spacing.asymmetric(10.0, 20.0);
    try std.testing.expect(spacing.getVertical() == 20.0); // top + bottom
    try std.testing.expect(spacing.getHorizontal() == 40.0); // left + right

    const uniform = Spacing.uniform(15.0);
    try std.testing.expect(uniform.top == 15.0 and uniform.right == 15.0);
    try std.testing.expect(uniform.bottom == 15.0 and uniform.left == 15.0);

    const added = spacing.add(uniform);
    try std.testing.expect(added.top == 25.0 and added.right == 35.0);

    const scaled = spacing.scale(2.0);
    try std.testing.expect(scaled.top == 20.0 and scaled.left == 40.0);
}

test "Rectangle layout operations" {
    const rect = Rectangle.fromXYWH(10.0, 10.0, 100.0, 80.0);
    const spacing = Spacing.uniform(10.0);

    // Test spacing application (shrink)
    const content = rect.applySpacing(spacing);
    try std.testing.expect(content.position.x == 20.0 and content.position.y == 20.0);
    try std.testing.expect(content.size.x == 80.0 and content.size.y == 60.0);

    // Test spacing expansion (grow)
    const expanded = rect.expandBySpacing(spacing);
    try std.testing.expect(expanded.position.x == 0.0 and expanded.position.y == 0.0);
    try std.testing.expect(expanded.size.x == 120.0 and expanded.size.y == 100.0);

    // Test rectangle split
    const split_result = rect.split(.horizontal, 0.3);
    try std.testing.expectApproxEqAbs(@as(f32, 30.0), split_result.first.size.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 70.0), split_result.second.size.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 40.0), split_result.second.position.x, 0.01);
}
