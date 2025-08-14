const std = @import("std");
const Point = @import("point.zig").Point;
const Bounds = @import("bounds.zig").Bounds;

/// Circle shape
pub const Circle = struct {
    center: Point,
    radius: f32,

    /// Create a new circle
    pub fn init(center: Point, radius: f32) Circle {
        return .{ .center = center, .radius = radius };
    }

    /// Check if point is inside circle
    pub fn contains(self: Circle, point: Point) bool {
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
    start: Point,
    end: Point,

    /// Create a new line
    pub fn init(start: Point, end: Point) Line {
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
    pub fn direction(self: Line) Point {
        return self.end.sub(self.start).normalize();
    }

    /// Get vector from start to end
    pub fn vector(self: Line) Point {
        return self.end.sub(self.start);
    }

    /// Get point at parameter t (0.0 = start, 1.0 = end)
    pub fn pointAt(self: Line, t: f32) Point {
        return self.start.lerp(self.end, t);
    }

    /// Get midpoint
    pub fn midpoint(self: Line) Point {
        return self.pointAt(0.5);
    }

    /// Get closest point on line to given point
    pub fn closestPointTo(self: Line, point: Point) Point {
        const line_vec = self.vector();
        const point_vec = point.sub(self.start);
        const line_len_sq = line_vec.lengthSquared();
        
        if (line_len_sq == 0) return self.start;
        
        const t = std.math.clamp(point_vec.dot(line_vec) / line_len_sq, 0.0, 1.0);
        return self.pointAt(t);
    }

    /// Get distance from point to line
    pub fn distanceToPoint(self: Line, point: Point) f32 {
        const closest = self.closestPointTo(point);
        return point.distance(closest);
    }

    /// Get bounding box
    pub fn bounds(self: Line) Bounds {
        return Bounds.fromPoints(self.start, self.end);
    }
};

/// Rectangle shape
pub const Rectangle = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    /// Create a new rectangle
    pub fn init(x: f32, y: f32, width: f32, height: f32) Rectangle {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }

    /// Create from bounds
    pub fn fromBounds(rect_bounds: Bounds) Rectangle {
        return .{
            .x = rect_bounds.x_min,
            .y = rect_bounds.y_min,
            .width = rect_bounds.width(),
            .height = rect_bounds.height(),
        };
    }

    /// Get bounds
    pub fn bounds(self: Rectangle) Bounds {
        return Bounds.init(self.x, self.y, self.x + self.width, self.y + self.height);
    }

    /// Get center point
    pub fn center(self: Rectangle) Point {
        return Point.init(self.x + self.width * 0.5, self.y + self.height * 0.5);
    }

    /// Check if point is inside rectangle
    pub fn contains(self: Rectangle, point: Point) bool {
        return point.x >= self.x and point.x <= self.x + self.width and
               point.y >= self.y and point.y <= self.y + self.height;
    }

    /// Check if rectangles intersect
    pub fn intersects(self: Rectangle, other: Rectangle) bool {
        return self.x <= other.x + other.width and self.x + self.width >= other.x and
               self.y <= other.y + other.height and self.y + self.height >= other.y;
    }

    /// Get area
    pub fn area(self: Rectangle) f32 {
        return self.width * self.height;
    }

    /// Get perimeter
    pub fn perimeter(self: Rectangle) f32 {
        return 2.0 * (self.width + self.height);
    }
};

test "Circle operations" {
    const circle = Circle.init(Point.init(0.0, 0.0), 5.0);
    
    try std.testing.expect(circle.contains(Point.init(3.0, 4.0))); // 3-4-5 triangle
    try std.testing.expect(!circle.contains(Point.init(5.0, 5.0))); // Outside
    
    const area = circle.area();
    try std.testing.expect(@abs(area - 78.54) < 0.1); // π * 5²
}

test "Line operations" {
    const line = Line.init(Point.init(0.0, 0.0), Point.init(10.0, 0.0));
    
    try std.testing.expect(line.length() == 10.0);
    
    const mid = line.midpoint();
    try std.testing.expect(mid.x == 5.0 and mid.y == 0.0);
    
    const closest = line.closestPointTo(Point.init(7.0, 5.0));
    try std.testing.expect(closest.x == 7.0 and closest.y == 0.0);
}

test "Rectangle operations" {
    const rect = Rectangle.init(10.0, 20.0, 30.0, 40.0);
    
    try std.testing.expect(rect.area() == 1200.0);
    try std.testing.expect(rect.contains(Point.init(25.0, 35.0)));
    try std.testing.expect(!rect.contains(Point.init(5.0, 35.0)));
    
    const center_pt = rect.center();
    try std.testing.expect(center_pt.x == 25.0 and center_pt.y == 40.0);
}