const std = @import("std");
const Point = @import("point.zig").Point;

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
    pub fn fromPoints(p1: Point, p2: Point) Bounds {
        return .{
            .x_min = @min(p1.x, p2.x),
            .y_min = @min(p1.y, p2.y),
            .x_max = @max(p1.x, p2.x),
            .y_max = @max(p1.y, p2.y),
        };
    }

    /// Create bounds from center point and size
    pub fn fromCenterSize(center_point: Point, w: f32, h: f32) Bounds {
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
    pub fn center(self: Bounds) Point {
        return .{
            .x = (self.x_min + self.x_max) * 0.5,
            .y = (self.y_min + self.y_max) * 0.5,
        };
    }

    /// Get top-left corner
    pub fn topLeft(self: Bounds) Point {
        return .{ .x = self.x_min, .y = self.y_min };
    }

    /// Get bottom-right corner
    pub fn bottomRight(self: Bounds) Point {
        return .{ .x = self.x_max, .y = self.y_max };
    }

    /// Check if point is inside bounds
    pub fn contains(self: Bounds, point: Point) bool {
        return point.x >= self.x_min and point.x <= self.x_max and
               point.y >= self.y_min and point.y <= self.y_max;
    }

    /// Check if bounds intersect
    pub fn intersects(self: Bounds, other: Bounds) bool {
        return self.x_min <= other.x_max and self.x_max >= other.x_min and
               self.y_min <= other.y_max and self.y_max >= other.y_min;
    }

    /// Expand bounds to include a point
    pub fn expandToInclude(self: *Bounds, point: Point) void {
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

test "Bounds operations" {
    const bounds = Bounds.init(10.0, 20.0, 50.0, 80.0);
    
    try std.testing.expect(bounds.width() == 40.0);
    try std.testing.expect(bounds.height() == 60.0);
    
    const center_pt = bounds.center();
    try std.testing.expect(center_pt.x == 30.0 and center_pt.y == 50.0);
    
    try std.testing.expect(bounds.contains(Point.init(30.0, 40.0)));
    try std.testing.expect(!bounds.contains(Point.init(5.0, 40.0)));
    
    const other = Bounds.init(40.0, 70.0, 60.0, 90.0);
    try std.testing.expect(bounds.intersects(other));
}

test "GlyphBounds conversion" {
    const float_bounds = Bounds.init(10.5, 20.3, 50.7, 80.9);
    const glyph_bounds = GlyphBounds.fromFloat(float_bounds);
    
    try std.testing.expect(glyph_bounds.x_min == 11);
    try std.testing.expect(glyph_bounds.y_min == 20);
    try std.testing.expect(glyph_bounds.x_max == 51);
    try std.testing.expect(glyph_bounds.y_max == 81);
    
    const back_to_float = glyph_bounds.toFloat();
    try std.testing.expect(back_to_float.x_min == 11.0);
}