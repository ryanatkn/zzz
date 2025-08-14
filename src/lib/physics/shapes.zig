const std = @import("std");
const types = @import("../core/types.zig");
const maths = @import("../core/maths.zig");

const Vec2 = types.Vec2;

/// Basic geometric shapes for collision detection and spatial queries
pub const Circle = struct {
    center: Vec2,
    radius: f32,

    /// Create a circle at the given position with radius
    pub fn init(center: Vec2, radius: f32) Circle {
        return Circle{
            .center = center,
            .radius = radius,
        };
    }

    /// Check if a point is inside this circle
    pub fn contains(self: Circle, point: Vec2) bool {
        const dx = point.x - self.center.x;
        const dy = point.y - self.center.y;
        return (dx * dx + dy * dy) <= (self.radius * self.radius);
    }

    /// Get the bounding box of this circle
    pub fn getBounds(self: Circle) Rectangle {
        return Rectangle{
            .position = Vec2{
                .x = self.center.x - self.radius,
                .y = self.center.y - self.radius,
            },
            .size = Vec2{
                .x = self.radius * 2.0,
                .y = self.radius * 2.0,
            },
        };
    }

    /// Get area of the circle
    pub fn getArea(self: Circle) f32 {
        return std.math.pi * self.radius * self.radius;
    }

    /// Get circumference of the circle
    pub fn getCircumference(self: Circle) f32 {
        return 2.0 * std.math.pi * self.radius;
    }

    /// Move the circle by an offset
    pub fn translate(self: *Circle, offset: Vec2) void {
        self.center.x += offset.x;
        self.center.y += offset.y;
    }

    /// Scale the circle's radius
    pub fn scale(self: *Circle, factor: f32) void {
        self.radius *= factor;
    }
};

/// Axis-aligned rectangle shape
pub const Rectangle = struct {
    position: Vec2, // Top-left corner
    size: Vec2,     // Width and height

    /// Create a rectangle at the given position with size
    pub fn init(position: Vec2, size: Vec2) Rectangle {
        return Rectangle{
            .position = position,
            .size = size,
        };
    }

    /// Create a rectangle from center point and size
    pub fn fromCenter(center_point: Vec2, size: Vec2) Rectangle {
        return Rectangle{
            .position = Vec2{
                .x = center_point.x - size.x / 2.0,
                .y = center_point.y - size.y / 2.0,
            },
            .size = size,
        };
    }

    /// Get the center point of the rectangle
    pub fn center(self: Rectangle) Vec2 {
        return Vec2{
            .x = self.position.x + self.size.x / 2.0,
            .y = self.position.y + self.size.y / 2.0,
        };
    }

    /// Check if a point is inside this rectangle
    pub fn contains(self: Rectangle, point: Vec2) bool {
        return maths.vec2_isWithinRect(point, self.position, self.size);
    }

    /// Get the four corners of the rectangle
    pub fn getCorners(self: Rectangle) [4]Vec2 {
        return [4]Vec2{
            self.position, // Top-left
            Vec2{ .x = self.position.x + self.size.x, .y = self.position.y }, // Top-right
            Vec2{ .x = self.position.x + self.size.x, .y = self.position.y + self.size.y }, // Bottom-right
            Vec2{ .x = self.position.x, .y = self.position.y + self.size.y }, // Bottom-left
        };
    }

    /// Get area of the rectangle
    pub fn getArea(self: Rectangle) f32 {
        return self.size.x * self.size.y;
    }

    /// Get perimeter of the rectangle
    pub fn getPerimeter(self: Rectangle) f32 {
        return 2.0 * (self.size.x + self.size.y);
    }

    /// Get the minimum and maximum points
    pub fn getMinMax(self: Rectangle) struct { min: Vec2, max: Vec2 } {
        return .{
            .min = self.position,
            .max = Vec2{
                .x = self.position.x + self.size.x,
                .y = self.position.y + self.size.y,
            },
        };
    }

    /// Move the rectangle by an offset
    pub fn translate(self: *Rectangle, offset: Vec2) void {
        self.position.x += offset.x;
        self.position.y += offset.y;
    }

    /// Scale the rectangle's size
    pub fn scale(self: *Rectangle, factor: Vec2) void {
        self.size.x *= factor.x;
        self.size.y *= factor.y;
    }

    /// Expand or contract the rectangle by a margin
    pub fn expand(self: *Rectangle, margin: f32) void {
        self.position.x -= margin;
        self.position.y -= margin;
        self.size.x += margin * 2.0;
        self.size.y += margin * 2.0;
    }

    /// Check if this rectangle overlaps with another
    pub fn overlaps(self: Rectangle, other: Rectangle) bool {
        return !(self.position.x + self.size.x < other.position.x or
                 other.position.x + other.size.x < self.position.x or
                 self.position.y + self.size.y < other.position.y or
                 other.position.y + other.size.y < self.position.y);
    }

    /// Get the intersection of two rectangles (if any)
    pub fn intersection(self: Rectangle, other: Rectangle) ?Rectangle {
        const min_max_self = self.getMinMax();
        const min_max_other = other.getMinMax();

        const left = @max(min_max_self.min.x, min_max_other.min.x);
        const top = @max(min_max_self.min.y, min_max_other.min.y);
        const right = @min(min_max_self.max.x, min_max_other.max.x);
        const bottom = @min(min_max_self.max.y, min_max_other.max.y);

        if (left < right and top < bottom) {
            return Rectangle{
                .position = Vec2{ .x = left, .y = top },
                .size = Vec2{ .x = right - left, .y = bottom - top },
            };
        }

        return null;
    }
};

/// Point shape (zero-dimensional)
pub const Point = struct {
    position: Vec2,

    /// Create a point at the given position
    pub fn init(position: Vec2) Point {
        return Point{ .position = position };
    }

    /// Get distance to another point
    pub fn distanceTo(self: Point, other: Point) f32 {
        return maths.vec2_distance(self.position, other.position);
    }

    /// Get squared distance to another point (faster)
    pub fn distanceToSquared(self: Point, other: Point) f32 {
        return maths.vec2_distanceSquared(self.position, other.position);
    }

    /// Move the point by an offset
    pub fn translate(self: *Point, offset: Vec2) void {
        self.position.x += offset.x;
        self.position.y += offset.y;
    }
};

/// Line segment shape
pub const LineSegment = struct {
    start: Vec2,
    end: Vec2,

    /// Create a line segment between two points
    pub fn init(start: Vec2, end: Vec2) LineSegment {
        return LineSegment{
            .start = start,
            .end = end,
        };
    }

    /// Get the center point of the line segment
    pub fn center(self: LineSegment) Vec2 {
        return Vec2{
            .x = (self.start.x + self.end.x) / 2.0,
            .y = (self.start.y + self.end.y) / 2.0,
        };
    }

    /// Get the length of the line segment
    pub fn length(self: LineSegment) f32 {
        return maths.vec2_distance(self.start, self.end);
    }

    /// Get the squared length (faster)
    pub fn lengthSquared(self: LineSegment) f32 {
        return maths.vec2_distanceSquared(self.start, self.end);
    }

    /// Get the direction vector (normalized)
    pub fn direction(self: LineSegment) Vec2 {
        const diff = Vec2{
            .x = self.end.x - self.start.x,
            .y = self.end.y - self.start.y,
        };
        return maths.vec2_normalize(diff);
    }

    /// Get a point along the line segment (t = 0.0 to 1.0)
    pub fn pointAt(self: LineSegment, t: f32) Vec2 {
        const clamped_t = @max(0.0, @min(1.0, t));
        return Vec2{
            .x = self.start.x + (self.end.x - self.start.x) * clamped_t,
            .y = self.start.y + (self.end.y - self.start.y) * clamped_t,
        };
    }

    /// Get the closest point on the line segment to a given point
    pub fn closestPointTo(self: LineSegment, point: Vec2) Vec2 {
        const segment_vec = Vec2{
            .x = self.end.x - self.start.x,
            .y = self.end.y - self.start.y,
        };
        
        const point_vec = Vec2{
            .x = point.x - self.start.x,
            .y = point.y - self.start.y,
        };
        
        const segment_length_squared = segment_vec.x * segment_vec.x + segment_vec.y * segment_vec.y;
        
        if (segment_length_squared == 0.0) {
            return self.start; // Degenerate line segment
        }
        
        const t = (point_vec.x * segment_vec.x + point_vec.y * segment_vec.y) / segment_length_squared;
        return self.pointAt(t);
    }
};

/// Generic shape union type for collision detection
pub const Shape = union(enum) {
    circle: Circle,
    rectangle: Rectangle,
    point: Point,
    line_segment: LineSegment,

    /// Get a bounding rectangle that contains the shape
    pub fn getBounds(self: Shape) Rectangle {
        return switch (self) {
            .circle => |c| c.getBounds(),
            .rectangle => |r| r,
            .point => |p| Rectangle{
                .position = p.position,
                .size = Vec2{ .x = 0, .y = 0 },
            },
            .line_segment => |ls| {
                const min_x = @min(ls.start.x, ls.end.x);
                const min_y = @min(ls.start.y, ls.end.y);
                const max_x = @max(ls.start.x, ls.end.x);
                const max_y = @max(ls.start.y, ls.end.y);
                return Rectangle{
                    .position = Vec2{ .x = min_x, .y = min_y },
                    .size = Vec2{ .x = max_x - min_x, .y = max_y - min_y },
                };
            },
        };
    }

    /// Check if the shape contains a point
    pub fn contains(self: Shape, point: Vec2) bool {
        return switch (self) {
            .circle => |c| c.contains(point),
            .rectangle => |r| r.contains(point),
            .point => |p| p.position.x == point.x and p.position.y == point.y,
            .line_segment => |ls| {
                const closest = ls.closestPointTo(point);
                return closest.x == point.x and closest.y == point.y;
            },
        };
    }

    /// Move the shape by an offset
    pub fn translate(self: *Shape, offset: Vec2) void {
        switch (self.*) {
            .circle => |*c| c.translate(offset),
            .rectangle => |*r| r.translate(offset),
            .point => |*p| p.translate(offset),
            .line_segment => |*ls| {
                ls.start.x += offset.x;
                ls.start.y += offset.y;
                ls.end.x += offset.x;
                ls.end.y += offset.y;
            },
        }
    }
};

// Tests
const testing = std.testing;

test "Circle basic operations" {
    var circle = Circle.init(Vec2{ .x = 0, .y = 0 }, 5.0);
    
    try testing.expect(circle.contains(Vec2{ .x = 3, .y = 4 })); // 3-4-5 triangle
    try testing.expect(!circle.contains(Vec2{ .x = 6, .y = 0 }));
    
    circle.translate(Vec2{ .x = 10, .y = 10 });
    try testing.expectEqual(@as(f32, 10), circle.center.x);
    try testing.expectEqual(@as(f32, 10), circle.center.y);
}

test "Rectangle basic operations" {
    var rect = Rectangle.init(Vec2{ .x = 0, .y = 0 }, Vec2{ .x = 10, .y = 5 });
    
    try testing.expect(rect.contains(Vec2{ .x = 5, .y = 2 }));
    try testing.expect(!rect.contains(Vec2{ .x = 15, .y = 2 }));
    
    const center = rect.center();
    try testing.expectEqual(@as(f32, 5), center.x);
    try testing.expectEqual(@as(f32, 2.5), center.y);
    
    const area = rect.getArea();
    try testing.expectEqual(@as(f32, 50), area);
}

test "Shape union operations" {
    var circle_shape = Shape{ .circle = Circle.init(Vec2{ .x = 0, .y = 0 }, 5.0) };
    var rect_shape = Shape{ .rectangle = Rectangle.init(Vec2{ .x = 0, .y = 0 }, Vec2{ .x = 10, .y = 5 }) };
    
    try testing.expect(circle_shape.contains(Vec2{ .x = 3, .y = 4 }));
    try testing.expect(rect_shape.contains(Vec2{ .x = 5, .y = 2 }));
    
    circle_shape.translate(Vec2{ .x = 1, .y = 1 });
    try testing.expectEqual(@as(f32, 1), circle_shape.circle.center.x);
}