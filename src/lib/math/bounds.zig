const std = @import("std");
const Vec2 = @import("vec2.zig").Vec2;
const scalar = @import("scalar.zig");

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

    /// Create bounds from min/max Vec2 points (compatibility with collision system)
    pub fn fromMinMax(min_vec: Vec2, max_vec: Vec2) Bounds {
        return .{
            .x_min = min_vec.x,
            .y_min = min_vec.y,
            .x_max = max_vec.x,
            .y_max = max_vec.y,
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

    /// Get min corner as Vec2 (compatibility with collision system)
    pub fn getMin(self: Bounds) Vec2 {
        return Vec2{ .x = self.x_min, .y = self.y_min };
    }

    /// Get max corner as Vec2 (compatibility with collision system)
    pub fn getMax(self: Bounds) Vec2 {
        return Vec2{ .x = self.x_max, .y = self.y_max };
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

test "Bounds functionality" {
    const bounds = Bounds.init(10.0, 20.0, 50.0, 80.0);

    try std.testing.expect(bounds.width() == 40.0);
    try std.testing.expect(bounds.height() == 60.0);

    const center_pt = bounds.center();
    try std.testing.expect(center_pt.x == 30.0 and center_pt.y == 50.0);

    try std.testing.expect(bounds.contains(Vec2.init(30.0, 40.0)));
    try std.testing.expect(!bounds.contains(Vec2.init(5.0, 40.0)));
}

test "Vec2 compatibility methods" {
    const min_vec = Vec2.init(0.0, 0.0);
    const max_vec = Vec2.init(10.0, 20.0);
    const bounds = Bounds.fromMinMax(min_vec, max_vec);

    try std.testing.expect(bounds.x_min == 0.0);
    try std.testing.expect(bounds.y_max == 20.0);

    const retrieved_min = bounds.getMin();
    const retrieved_max = bounds.getMax();

    try std.testing.expect(retrieved_min.x == 0.0 and retrieved_min.y == 0.0);
    try std.testing.expect(retrieved_max.x == 10.0 and retrieved_max.y == 20.0);
}

test "Bounds intersection and containment" {
    const bounds1 = Bounds.init(0.0, 0.0, 10.0, 10.0);
    const bounds2 = Bounds.init(5.0, 5.0, 15.0, 15.0);
    const bounds3 = Bounds.init(20.0, 20.0, 30.0, 30.0);

    try std.testing.expect(bounds1.intersects(bounds2)); // Overlapping
    try std.testing.expect(!bounds1.intersects(bounds3)); // Non-overlapping

    try std.testing.expect(bounds1.contains(Vec2.init(5.0, 5.0)));
    try std.testing.expect(!bounds1.contains(Vec2.init(15.0, 15.0)));
}
