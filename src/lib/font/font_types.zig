const std = @import("std");

/// Common font-related types shared across modules
/// This provides a single source of truth for font data structures

// ============================================================================
// Core Geometric Types
// ============================================================================

/// A 2D point used in glyph outlines
pub const Point = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) Point {
        return .{ .x = x, .y = y };
    }

    pub fn scale(self: Point, factor: f32) Point {
        return .{ .x = self.x * factor, .y = self.y * factor };
    }

    pub fn translate(self: Point, dx: f32, dy: f32) Point {
        return .{ .x = self.x + dx, .y = self.y + dy };
    }
};

/// Represents a contour (closed path) in a glyph outline
pub const Contour = struct {
    points: []Point,
    on_curve: []bool,

    pub fn deinit(self: *Contour, allocator: std.mem.Allocator) void {
        allocator.free(self.points);
        allocator.free(self.on_curve);
    }
};

/// Complete glyph outline data
pub const GlyphOutline = struct {
    contours: []Contour,
    bounds: GlyphBounds,
    metrics: GlyphMetrics,

    pub fn deinit(self: *GlyphOutline, allocator: std.mem.Allocator) void {
        for (self.contours) |*contour| {
            contour.deinit(allocator);
        }
        allocator.free(self.contours);
    }
};

/// Bounding box for a glyph
pub const GlyphBounds = struct {
    x_min: i16,
    y_min: i16,
    x_max: i16,
    y_max: i16,

    pub fn width(self: GlyphBounds) u16 {
        return @intCast(@as(i32, self.x_max) - @as(i32, self.x_min));
    }

    pub fn height(self: GlyphBounds) u16 {
        return @intCast(@as(i32, self.y_max) - @as(i32, self.y_min));
    }
};

/// Glyph metrics for layout
pub const GlyphMetrics = struct {
    advance_width: u16,
    left_side_bearing: i16,

    pub fn getAdvance(self: GlyphMetrics) f32 {
        return @floatFromInt(self.advance_width);
    }
};

// ============================================================================
// Rasterization Types
// ============================================================================

/// An edge used in scanline rasterization
pub const Edge = struct {
    // Floating point coordinates
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,

    // Winding direction (-1 or +1)
    winding: i32,

    // Fixed-point versions for precision (16.16 format)
    fx0: i32,
    fy0: i32,
    fx1: i32,
    fy1: i32,

    pub fn init(x0: f32, y0: f32, x1: f32, y1: f32, winding: i32) Edge {
        return .{
            .x0 = x0,
            .y0 = y0,
            .x1 = x1,
            .y1 = y1,
            .winding = winding,
            // Convert to fixed-point (16.16 format)
            .fx0 = @intFromFloat(x0 * 65536.0),
            .fy0 = @intFromFloat(y0 * 65536.0),
            .fx1 = @intFromFloat(x1 * 65536.0),
            .fy1 = @intFromFloat(y1 * 65536.0),
        };
    }

    pub fn isHorizontal(self: Edge) bool {
        return self.y0 == self.y1;
    }

    pub fn minY(self: Edge) f32 {
        return @min(self.y0, self.y1);
    }

    pub fn maxY(self: Edge) f32 {
        return @max(self.y0, self.y1);
    }
};

/// Result of rasterizing a glyph
pub const RasterizedGlyph = struct {
    bitmap: []u8,
    width: u32,
    height: u32,
    bearing_x: i32,
    bearing_y: i32,
    advance: i32,

    pub fn deinit(self: *RasterizedGlyph, allocator: std.mem.Allocator) void {
        allocator.free(self.bitmap);
    }
};

// ============================================================================
// Font Configuration Types
// ============================================================================

/// Font weight values (100-900)
pub const FontWeight = enum(u16) {
    thin = 100,
    extra_light = 200,
    light = 300,
    regular = 400,
    medium = 500,
    semi_bold = 600,
    bold = 700,
    extra_bold = 800,
    black = 900,

    pub fn fromInt(value: u16) FontWeight {
        return switch (value) {
            100 => .thin,
            200 => .extra_light,
            300 => .light,
            400 => .regular,
            500 => .medium,
            600 => .semi_bold,
            700 => .bold,
            800 => .extra_bold,
            900 => .black,
            else => .regular,
        };
    }
};

/// Font style options
pub const FontStyle = enum {
    normal,
    italic,
    oblique,
};

/// Font category for selection
pub const FontCategory = enum {
    mono,
    sans,
    serif,
    display,
    handwriting,

    pub fn toString(self: FontCategory) []const u8 {
        return switch (self) {
            .mono => "mono",
            .sans => "sans",
            .serif => "serif",
            .display => "display",
            .handwriting => "handwriting",
        };
    }
};

/// Rendering quality/method selection
pub const RenderingMethod = enum {
    bitmap, // Basic bitmap rendering
    sdf, // Signed Distance Field
    oversampled, // 2x or 4x oversampling
    cached, // Pre-rendered cache

    pub fn toString(self: RenderingMethod) []const u8 {
        return switch (self) {
            .bitmap => "bitmap",
            .sdf => "sdf",
            .oversampled => "oversampled",
            .cached => "cached",
        };
    }
};

// ============================================================================
// Quality and Debug Types
// ============================================================================

/// Fill rule for rasterization
pub const FillRule = enum {
    non_zero,
    even_odd,

    pub fn shouldFill(self: FillRule, winding: i32) bool {
        return switch (self) {
            .non_zero => winding != 0,
            .even_odd => @mod(winding, 2) != 0,
        };
    }
};

/// Antialiasing mode
pub const AntialiasMode = enum {
    none,
    grayscale,
    subpixel_rgb,
    subpixel_bgr,
};

/// Quality metrics for rendered text
pub const QualityMetrics = struct {
    coverage_percent: f32,
    edge_sharpness: f32,
    contrast_ratio: f32,
    kerning_consistency: f32,
    subpixel_accuracy: f32,
    overall_score: f32,
};

// ============================================================================
// Error Types
// ============================================================================

pub const FontError = error{
    InvalidFontData,
    GlyphNotFound,
    OutOfMemory,
    RasterizationFailed,
    UnsupportedFormat,
    InvalidMetrics,
    CacheExhausted,
};

// ============================================================================
// Constants
// ============================================================================

/// Fixed-point scaling factor (16.16 format)
pub const FIXED_POINT_SCALE = 65536;

/// Maximum supported font size
pub const MAX_FONT_SIZE = 256;

/// Default DPI for screen rendering
pub const DEFAULT_DPI = 96;

// ============================================================================
// Utility Functions
// ============================================================================

/// Convert from font units to pixels
pub fn unitsToPixels(units: i32, pixels_per_em: f32) f32 {
    return @as(f32, @floatFromInt(units)) * pixels_per_em;
}

/// Convert from pixels to fixed-point
pub fn pixelsToFixed(pixels: f32) i32 {
    return @intFromFloat(pixels * @as(f32, FIXED_POINT_SCALE));
}

/// Convert from fixed-point to pixels
pub fn fixedToPixels(fixed: i32) f32 {
    return @as(f32, @floatFromInt(fixed)) / @as(f32, FIXED_POINT_SCALE);
}

test "Point operations" {
    const p = Point.init(10, 20);
    const scaled = p.scale(2);
    try std.testing.expectEqual(@as(f32, 20), scaled.x);
    try std.testing.expectEqual(@as(f32, 40), scaled.y);

    const translated = p.translate(5, -5);
    try std.testing.expectEqual(@as(f32, 15), translated.x);
    try std.testing.expectEqual(@as(f32, 15), translated.y);
}

test "Edge initialization" {
    const edge = Edge.init(10.5, 20.5, 30.5, 40.5, 1);
    try std.testing.expectEqual(@as(f32, 10.5), edge.x0);
    try std.testing.expectEqual(@as(f32, 40.5), edge.maxY());
    try std.testing.expectEqual(false, edge.isHorizontal());
}

test "Fill rule logic" {
    try std.testing.expectEqual(true, FillRule.non_zero.shouldFill(1));
    try std.testing.expectEqual(true, FillRule.non_zero.shouldFill(-1));
    try std.testing.expectEqual(false, FillRule.non_zero.shouldFill(0));

    try std.testing.expectEqual(true, FillRule.even_odd.shouldFill(1));
    try std.testing.expectEqual(false, FillRule.even_odd.shouldFill(2));
    try std.testing.expectEqual(true, FillRule.even_odd.shouldFill(3));
}
