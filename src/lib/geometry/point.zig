const std = @import("std");

/// 2D point with floating-point coordinates
pub const Point = struct {
    x: f32,
    y: f32,

    /// Create a new point
    pub fn init(x: f32, y: f32) Point {
        return .{ .x = x, .y = y };
    }

    /// Zero point (origin)
    pub const ZERO = Point{ .x = 0.0, .y = 0.0 };

    /// Add two points
    pub fn add(self: Point, other: Point) Point {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    /// Subtract two points
    pub fn sub(self: Point, other: Point) Point {
        return .{ .x = self.x - other.x, .y = self.y - other.y };
    }

    /// Scale point by scalar
    pub fn scale(self: Point, factor: f32) Point {
        return .{ .x = self.x * factor, .y = self.y * factor };
    }

    /// Calculate squared distance between two points
    pub fn distanceSquared(self: Point, other: Point) f32 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        return dx * dx + dy * dy;
    }

    /// Calculate distance between two points
    pub fn distance(self: Point, other: Point) f32 {
        return @sqrt(self.distanceSquared(other));
    }

    /// Calculate dot product
    pub fn dot(self: Point, other: Point) f32 {
        return self.x * other.x + self.y * other.y;
    }

    /// Get length of vector from origin
    pub fn length(self: Point) f32 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }

    /// Get squared length (faster than length)
    pub fn lengthSquared(self: Point) f32 {
        return self.x * self.x + self.y * self.y;
    }

    /// Normalize vector to unit length
    pub fn normalize(self: Point) Point {
        const len = self.length();
        if (len == 0) return ZERO;
        return .{ .x = self.x / len, .y = self.y / len };
    }

    /// Linear interpolation between two points
    pub fn lerp(self: Point, other: Point, t: f32) Point {
        return .{
            .x = self.x + (other.x - self.x) * t,
            .y = self.y + (other.y - self.y) * t,
        };
    }

    /// Check if two points are approximately equal
    pub fn equals(self: Point, other: Point, tolerance: f32) bool {
        return @abs(self.x - other.x) <= tolerance and @abs(self.y - other.y) <= tolerance;
    }
};

test "Point operations" {
    const p1 = Point.init(3.0, 4.0);
    const p2 = Point.init(1.0, 2.0);

    const sum = p1.add(p2);
    try std.testing.expect(sum.x == 4.0 and sum.y == 6.0);

    const diff = p1.sub(p2);
    try std.testing.expect(diff.x == 2.0 and diff.y == 2.0);

    const scaled = p1.scale(2.0);
    try std.testing.expect(scaled.x == 6.0 and scaled.y == 8.0);

    const len = p1.length();
    try std.testing.expect(@abs(len - 5.0) < 0.001);

    const normalized = p1.normalize();
    try std.testing.expect(@abs(normalized.length() - 1.0) < 0.001);
}