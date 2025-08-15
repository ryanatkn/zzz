const std = @import("std");
const Vec2 = @import("vec2.zig").Vec2;

/// Axis-aligned bounding box with floating-point coordinates
pub const Bounds = struct {
    x_min: f32,
    y_min: f32,
    x_max: f32,
    y_max: f32,

    /// Create bounds from min/max coordinates
    pub fn init(x_min: f32, y_min: f32, x_max: f32, y_max: f32) Bounds {
        return .{
            .x_min = x_min,
            .y_min = y_min,
            .x_max = x_max,
            .y_max = y_max,
        };
    }

    /// Create bounds from two points
    pub fn fromPoints(p1: Vec2, p2: Vec2) Bounds {
        return .{
            .x_min = @min(p1.x, p2.x),
            .y_min = @min(p1.y, p2.y),
            .x_max = @max(p1.x, p2.x),
            .y_max = @max(p1.y, p2.y),
        };
    }

    /// Create bounds from center point and size
    pub fn fromCenterSize(center_point: Vec2, w: f32, h: f32) Bounds {
        const half_w = w * 0.5;
        const half_h = h * 0.5;
        return .{
            .x_min = center_point.x - half_w,
            .y_min = center_point.y - half_h,
            .x_max = center_point.x + half_w,
            .y_max = center_point.y + half_h,
        };
    }

    /// Get width of bounds
    pub fn width(self: Bounds) f32 {
        return self.x_max - self.x_min;
    }

    /// Get height of bounds
    pub fn height(self: Bounds) f32 {
        return self.y_max - self.y_min;
    }

    /// Get center point
    pub fn center(self: Bounds) Vec2 {
        return .{
            .x = (self.x_min + self.x_max) * 0.5,
            .y = (self.y_min + self.y_max) * 0.5,
        };
    }

    /// Get top-left corner
    pub fn topLeft(self: Bounds) Vec2 {
        return .{ .x = self.x_min, .y = self.y_min };
    }

    /// Get bottom-right corner
    pub fn bottomRight(self: Bounds) Vec2 {
        return .{ .x = self.x_max, .y = self.y_max };
    }

    /// Check if point is inside bounds
    pub fn contains(self: Bounds, point: Vec2) bool {
        return point.x >= self.x_min and point.x <= self.x_max and
            point.y >= self.y_min and point.y <= self.y_max;
    }

    /// Check if bounds intersect
    pub fn intersects(self: Bounds, other: Bounds) bool {
        return self.x_min <= other.x_max and self.x_max >= other.x_min and
            self.y_min <= other.y_max and self.y_max >= other.y_min;
    }

    /// Expand bounds to include a point
    pub fn expandToInclude(self: *Bounds, point: Vec2) void {
        self.x_min = @min(self.x_min, point.x);
        self.y_min = @min(self.y_min, point.y);
        self.x_max = @max(self.x_max, point.x);
        self.y_max = @max(self.y_max, point.y);
    }

    /// Expand bounds by margin
    pub fn expand(self: Bounds, margin: f32) Bounds {
        return .{
            .x_min = self.x_min - margin,
            .y_min = self.y_min - margin,
            .x_max = self.x_max + margin,
            .y_max = self.y_max + margin,
        };
    }

    /// Get area of bounds
    pub fn area(self: Bounds) f32 {
        return self.width() * self.height();
    }

    /// Check if bounds are valid (min <= max)
    pub fn isValid(self: Bounds) bool {
        return self.x_min <= self.x_max and self.y_min <= self.y_max;
    }
};

/// Integer-based bounds for compatibility with font systems
pub const GlyphBounds = struct {
    x_min: i16,
    y_min: i16,
    x_max: i16,
    y_max: i16,

    /// Convert to floating-point bounds
    pub fn toFloat(self: GlyphBounds) Bounds {
        return Bounds.init(
            @floatFromInt(self.x_min),
            @floatFromInt(self.y_min),
            @floatFromInt(self.x_max),
            @floatFromInt(self.y_max),
        );
    }

    /// Create from floating-point bounds (with rounding)
    pub fn fromFloat(bounds: Bounds) GlyphBounds {
        return .{
            .x_min = @intFromFloat(@round(bounds.x_min)),
            .y_min = @intFromFloat(@round(bounds.y_min)),
            .x_max = @intFromFloat(@round(bounds.x_max)),
            .y_max = @intFromFloat(@round(bounds.y_max)),
        };
    }

    /// Get width as integer
    pub fn width(self: GlyphBounds) i16 {
        return self.x_max - self.x_min;
    }

    /// Get height as integer
    pub fn height(self: GlyphBounds) i16 {
        return self.y_max - self.y_min;
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

        const t = std.math.clamp(point_vec.dot(line_vec) / line_len_sq, 0.0, 1.0);
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

test "Bounds operations" {
    const bounds = Bounds.init(10.0, 20.0, 50.0, 80.0);

    try std.testing.expect(bounds.width() == 40.0);
    try std.testing.expect(bounds.height() == 60.0);

    const center_pt = bounds.center();
    try std.testing.expect(center_pt.x == 30.0 and center_pt.y == 50.0);

    try std.testing.expect(bounds.contains(Vec2.init(30.0, 40.0)));
    try std.testing.expect(!bounds.contains(Vec2.init(5.0, 40.0)));
}
