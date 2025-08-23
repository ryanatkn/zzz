const std = @import("std");
const scalar = @import("scalar.zig");

/// 2D vector with floating-point coordinates
/// This is the canonical type for 2D positions, directions, and sizes
pub const Vec2 = extern struct {
    x: f32,
    y: f32,

    /// Create a new vector
    pub fn init(x: f32, y: f32) Vec2 {
        return .{ .x = x, .y = y };
    }

    /// Create a position vector (semantic alias for init)
    pub fn position(x: f32, y: f32) Vec2 {
        return init(x, y);
    }

    /// Create a size vector (semantic alias for init)
    pub fn size(width: f32, height: f32) Vec2 {
        return init(width, height);
    }

    /// Create screen center position
    pub fn screenCenter(screen_width: f32, screen_height: f32) Vec2 {
        return init(screen_width / 2.0, screen_height / 2.0);
    }

    /// Create an offset from a base position
    pub fn offset(base: Vec2, dx: f32, dy: f32) Vec2 {
        return init(base.x + dx, base.y + dy);
    }

    /// Common constants
    pub const ZERO = Vec2{ .x = 0.0, .y = 0.0 };
    pub const ONE = Vec2{ .x = 1.0, .y = 1.0 };
    pub const UP = Vec2{ .x = 0.0, .y = -1.0 };
    pub const DOWN = Vec2{ .x = 0.0, .y = 1.0 };
    pub const LEFT = Vec2{ .x = -1.0, .y = 0.0 };
    pub const RIGHT = Vec2{ .x = 1.0, .y = 0.0 };

    /// Add two vectors
    pub fn add(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    /// Subtract two vectors
    pub fn sub(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x - other.x, .y = self.y - other.y };
    }

    /// Multiply vector by scalar
    pub fn scale(self: Vec2, factor: f32) Vec2 {
        return .{ .x = self.x * factor, .y = self.y * factor };
    }

    /// Divide vector by scalar
    pub fn divide(self: Vec2, divisor: f32) Vec2 {
        return .{ .x = self.x / divisor, .y = self.y / divisor };
    }

    /// Calculate dot product
    pub fn dot(self: Vec2, other: Vec2) f32 {
        return self.x * other.x + self.y * other.y;
    }

    /// Get length of vector
    pub fn length(self: Vec2) f32 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }

    /// Get squared length (faster than length)
    pub fn lengthSquared(self: Vec2) f32 {
        return self.x * self.x + self.y * self.y;
    }

    /// Normalize vector to unit length
    pub fn normalize(self: Vec2) Vec2 {
        const len = self.length();
        if (len == 0) return ZERO;
        return .{ .x = self.x / len, .y = self.y / len };
    }

    /// Linear interpolation between two vectors
    pub fn lerp(self: Vec2, other: Vec2, t: f32) Vec2 {
        return .{
            .x = self.x + (other.x - self.x) * t,
            .y = self.y + (other.y - self.y) * t,
        };
    }

    /// Check if two vectors are approximately equal
    pub fn equals(self: Vec2, other: Vec2, tolerance: f32) bool {
        return @abs(self.x - other.x) <= tolerance and @abs(self.y - other.y) <= tolerance;
    }

    /// Calculate squared distance between two points
    pub fn distanceSquared(self: Vec2, other: Vec2) f32 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        return dx * dx + dy * dy;
    }

    /// Calculate distance between two points
    pub fn distance(self: Vec2, other: Vec2) f32 {
        return @sqrt(self.distanceSquared(other));
    }

    /// Get direction vector from this point to another
    pub fn directionTo(self: Vec2, other: Vec2) Vec2 {
        return other.sub(self).normalize();
    }

    /// Check if vector is zero
    pub fn isZero(self: Vec2) bool {
        return self.x == 0.0 and self.y == 0.0;
    }

    /// Clamp vector components to range
    pub fn clamp(self: Vec2, min: Vec2, max: Vec2) Vec2 {
        return .{
            .x = scalar.clamp(self.x, min.x, max.x),
            .y = scalar.clamp(self.y, min.y, max.y),
        };
    }

    /// Get angle to another vector
    pub fn angleTo(self: Vec2, other: Vec2) f32 {
        const diff = other.sub(self);
        return std.math.atan2(diff.y, diff.x);
    }

    /// Rotate vector by angle
    pub fn rotate(self: Vec2, angle: f32) Vec2 {
        const cos_a = @cos(angle);
        const sin_a = @sin(angle);
        return .{
            .x = self.x * cos_a - self.y * sin_a,
            .y = self.x * sin_a + self.y * cos_a,
        };
    }

    /// Reflect vector off a normal
    pub fn reflect(self: Vec2, normal: Vec2) Vec2 {
        const n = normal.normalize();
        const d = self.dot(n);
        return self.sub(n.scale(2.0 * d));
    }

    /// Project vector onto another vector
    pub fn project(self: Vec2, onto: Vec2) Vec2 {
        const n = onto.normalize();
        const d = self.dot(n);
        return n.scale(d);
    }

    /// Get perpendicular vector (rotated 90 degrees counter-clockwise)
    pub fn perpendicular(self: Vec2) Vec2 {
        return .{ .x = -self.y, .y = self.x };
    }

    /// Move towards target by max distance
    pub fn moveTowards(self: Vec2, target: Vec2, max_distance: f32) Vec2 {
        const diff = target.sub(self);
        const dist = diff.length();
        if (dist <= max_distance) {
            return target;
        }
        return self.add(diff.normalize().scale(max_distance));
    }

    /// Smooth damp towards target
    pub fn smoothDamp(self: Vec2, target: Vec2, smooth_time: f32, delta_time: f32) Vec2 {
        const omega = 2.0 / smooth_time;
        const x = omega * delta_time;
        const exp = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x);
        const change = self.sub(target);
        return target.add(change.scale(exp));
    }

    /// Check if point is within circle
    pub fn isWithinCircle(self: Vec2, center: Vec2, radius: f32) bool {
        return self.distanceSquared(center) <= radius * radius;
    }

    /// Check if point is within rectangle
    pub fn isWithinRect(self: Vec2, rect_pos: Vec2, rect_size: Vec2) bool {
        return self.x >= rect_pos.x and self.x <= rect_pos.x + rect_size.x and
            self.y >= rect_pos.y and self.y <= rect_pos.y + rect_size.y;
    }

    /// Clamp point to circle boundary
    pub fn clampToCircle(self: Vec2, center: Vec2, radius: f32) Vec2 {
        const dir = self.sub(center);
        const dist = dir.length();
        if (dist <= radius) {
            return self;
        }
        return center.add(dir.normalize().scale(radius));
    }

    /// Clamp point to rectangle boundary
    pub fn clampToRect(self: Vec2, rect_pos: Vec2, rect_size: Vec2) Vec2 {
        return .{
            .x = scalar.clamp(self.x, rect_pos.x, rect_pos.x + rect_size.x),
            .y = scalar.clamp(self.y, rect_pos.y, rect_pos.y + rect_size.y),
        };
    }

    /// Center this size within bounds, returning position
    pub fn centerIn(self: Vec2, bounds_pos: Vec2, bounds_size: Vec2) Vec2 {
        return Vec2{
            .x = bounds_pos.x + (bounds_size.x - self.x) / 2.0,
            .y = bounds_pos.y + (bounds_size.y - self.y) / 2.0,
        };
    }

    /// Align to top-left of bounds
    pub fn alignTopLeft(self: Vec2, bounds_pos: Vec2) Vec2 {
        _ = self; // Size not needed for top-left alignment
        return bounds_pos;
    }

    /// Align to top-right of bounds
    pub fn alignTopRight(self: Vec2, bounds_pos: Vec2, bounds_size: Vec2) Vec2 {
        return Vec2{
            .x = bounds_pos.x + bounds_size.x - self.x,
            .y = bounds_pos.y,
        };
    }

    /// Align to bottom-left of bounds
    pub fn alignBottomLeft(self: Vec2, bounds_pos: Vec2, bounds_size: Vec2) Vec2 {
        return Vec2{
            .x = bounds_pos.x,
            .y = bounds_pos.y + bounds_size.y - self.y,
        };
    }

    /// Align to bottom-right of bounds
    pub fn alignBottomRight(self: Vec2, bounds_pos: Vec2, bounds_size: Vec2) Vec2 {
        return Vec2{
            .x = bounds_pos.x + bounds_size.x - self.x,
            .y = bounds_pos.y + bounds_size.y - self.y,
        };
    }
};

/// Helper function for direction between two points (not a method)
pub fn directionBetween(from: Vec2, to: Vec2) Vec2 {
    return to.sub(from).normalize();
}

/// Distance functions (standalone for convenience)
pub fn distance(a: Vec2, b: Vec2) f32 {
    return a.distance(b);
}

pub fn distanceSquared(a: Vec2, b: Vec2) f32 {
    return a.distanceSquared(b);
}

test "Vec2 operations" {
    const v1 = Vec2.init(3.0, 4.0);
    const v2 = Vec2.init(1.0, 2.0);

    const sum = v1.add(v2);
    try std.testing.expect(sum.x == 4.0 and sum.y == 6.0);

    const diff = v1.sub(v2);
    try std.testing.expect(diff.x == 2.0 and diff.y == 2.0);

    const scaled = v1.scale(2.0);
    try std.testing.expect(scaled.x == 6.0 and scaled.y == 8.0);

    const len = v1.length();
    try std.testing.expect(@abs(len - 5.0) < 0.001);

    const normalized = v1.normalize();
    try std.testing.expect(@abs(normalized.length() - 1.0) < 0.001);

    // Test method API
    const len2 = v1.length();
    try std.testing.expect(@abs(len2 - 5.0) < 0.001);

    const sum2 = v1.add(v2);
    try std.testing.expect(sum2.x == 4.0 and sum2.y == 6.0);
}

test "Vec2 builder methods" {
    // Test semantic aliases
    const pos = Vec2.position(10.0, 20.0);
    const size = Vec2.size(100.0, 50.0);
    try std.testing.expect(pos.x == 10.0 and pos.y == 20.0);
    try std.testing.expect(size.x == 100.0 and size.y == 50.0);

    // Test screen center
    const center = Vec2.screenCenter(800.0, 600.0);
    try std.testing.expect(center.x == 400.0 and center.y == 300.0);

    // Test offset
    const base = Vec2.position(100.0, 100.0);
    const offset_pos = Vec2.offset(base, 10.0, -5.0);
    try std.testing.expect(offset_pos.x == 110.0 and offset_pos.y == 95.0);

    // Test layout helpers
    const item_size = Vec2.size(50.0, 30.0);
    const bounds_pos = Vec2.position(0.0, 0.0);
    const bounds_size = Vec2.size(200.0, 100.0);

    const centered = item_size.centerIn(bounds_pos, bounds_size);
    try std.testing.expect(centered.x == 75.0 and centered.y == 35.0); // (200-50)/2, (100-30)/2

    const top_right = item_size.alignTopRight(bounds_pos, bounds_size);
    try std.testing.expect(top_right.x == 150.0 and top_right.y == 0.0); // 200-50, 0
}
