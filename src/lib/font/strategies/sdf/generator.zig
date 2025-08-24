// SDF Generator - creates Signed Distance Field textures from font glyphs
// This is the font domain part of SDF generation (CPU-only operations)

const std = @import("std");
const math = @import("../../../math/mod.zig");
const distance_fields = @import("../../../math/distance_fields.zig");
const glyph_extractor = @import("../../core/glyph_extractor.zig");
const curve_utils = @import("../../core/curve_utils.zig");
const loggers = @import("../../../debug/loggers.zig");

const Vec2 = math.Vec2;
const GlyphOutline = glyph_extractor.GlyphOutline;
const Contour = glyph_extractor.Contour;
const Point = glyph_extractor.Point;

/// Configuration for SDF generation
pub const SDFConfig = struct {
    /// Resolution of the SDF texture (typically 64x64 or 128x128)
    texture_size: u32 = 64,

    /// Range of the distance field in texture units
    range: f32 = 4.0,

    /// Whether to use high-precision calculation
    high_precision: bool = true,

    /// Number of samples for anti-aliasing (0 = no AA, 4+ recommended)
    sample_count: u32 = 8,

    /// Whether to generate multi-channel SDF (MSDF)
    multi_channel: bool = false,

    /// Scale factor for oversampling
    oversample: u32 = 1,
};

/// A signed distance field texture data
pub const SDFGlyphData = struct {
    /// SDF data (single channel for SDF, RGB for MSDF)
    data: []u8,

    /// Texture dimensions
    width: u32,
    height: u32,

    /// Number of channels (1 for SDF, 3 for MSDF)
    channels: u32,

    /// Distance field range in texture space
    range: f32,

    /// Glyph metrics for positioning
    metrics: glyph_extractor.GlyphMetrics,
    bounds: glyph_extractor.GlyphBounds,

    /// Memory allocator used for the data
    allocator: std.mem.Allocator,

    pub fn deinit(self: *SDFGlyphData) void {
        self.allocator.free(self.data);
    }
};

/// SDF Generator - converts glyph outlines to signed distance field data
pub const SDFGenerator = struct {
    allocator: std.mem.Allocator,
    config: SDFConfig,

    pub fn init(allocator: std.mem.Allocator, config: SDFConfig) SDFGenerator {
        return SDFGenerator{
            .allocator = allocator,
            .config = config,
        };
    }

    /// Generate SDF data for a glyph outline
    pub fn generateSDF(self: *SDFGenerator, outline: GlyphOutline) !SDFGlyphData {
        const channels = if (self.config.multi_channel) @as(u32, 3) else @as(u32, 1);
        const data_size = self.config.texture_size * self.config.texture_size * channels;
        const data = try self.allocator.alloc(u8, data_size);

        // Generate actual SDF data
        try self.generateSDFData(data, outline);

        return SDFGlyphData{
            .data = data,
            .width = self.config.texture_size,
            .height = self.config.texture_size,
            .channels = channels,
            .range = self.config.range,
            .metrics = outline.metrics,
            .bounds = outline.bounds,
            .allocator = self.allocator,
        };
    }

    /// Generate the actual SDF texture data
    fn generateSDFData(self: *SDFGenerator, data: []u8, outline: GlyphOutline) !void {
        const texture_size = self.config.texture_size;
        const range = self.config.range;
        const channels = if (self.config.multi_channel) @as(u32, 3) else @as(u32, 1);

        // Calculate glyph bounds in texture space
        const bounds = outline.bounds;
        const glyph_width = bounds.x_max - bounds.x_min;
        const glyph_height = bounds.y_max - bounds.y_min;

        // Add padding around glyph
        const padding = range;
        const scale = @as(f32, @floatFromInt(texture_size)) / @max(glyph_width + 2.0 * padding, glyph_height + 2.0 * padding);

        // Calculate offset to center glyph in texture
        const offset_x = (@as(f32, @floatFromInt(texture_size)) - glyph_width * scale) / 2.0 - bounds.x_min * scale;
        const offset_y = (@as(f32, @floatFromInt(texture_size)) - glyph_height * scale) / 2.0 - bounds.y_min * scale;

        // Generate SDF for each pixel
        for (0..texture_size) |y| {
            for (0..texture_size) |x| {
                // Convert pixel coordinates to glyph space
                const glyph_x = (@as(f32, @floatFromInt(x)) - offset_x) / scale;
                const glyph_y = (@as(f32, @floatFromInt(y)) - offset_y) / scale;
                const sample_point = Vec2{ .x = glyph_x, .y = glyph_y };

                // Calculate signed distance
                const distance = self.calculateSignedDistance(sample_point, outline.contours);

                // Convert to texture value using extracted utility
                const texture_value = distance_fields.distanceToTextureByte(distance, range);

                // Set pixel value(s)
                const pixel_index = (y * texture_size + x) * channels;
                for (0..channels) |c| {
                    data[pixel_index + c] = texture_value;
                }
            }
        }
    }

    /// Calculate signed distance from point to glyph contours
    fn calculateSignedDistance(self: *SDFGenerator, point: Vec2, contours: []const Contour) f32 {
        _ = self;
        if (contours.len == 0) return 1.0; // Outside if no contours

        var min_distance: f32 = std.math.floatMax(f32);
        var inside = false;

        // For each contour, calculate distance and determine if point is inside
        for (contours) |contour| {
            var contour_inside = false;
            var contour_min_dist: f32 = std.math.floatMax(f32);

            // Simple ray casting for inside/outside test
            var intersections: u32 = 0;
            for (0..contour.points.len) |i| {
                const p1 = contour.points[i];
                const p2 = contour.points[(i + 1) % contour.points.len];

                // Ray casting test (horizontal ray to the right)
                if ((p1.y > point.y) != (p2.y > point.y)) {
                    const x_intersect = (p2.x - p1.x) * (point.y - p1.y) / (p2.y - p1.y) + p1.x;
                    if (point.x < x_intersect) {
                        intersections += 1;
                    }
                }

                // Calculate distance to line segment using extracted utility
                const segment_start = distance_fields.Point2D.init(p1.x, p1.y);
                const segment_end = distance_fields.Point2D.init(p2.x, p2.y);
                const test_point = distance_fields.Point2D.init(point.x, point.y);
                const segment_dist = distance_fields.distanceToSegment(test_point, segment_start, segment_end);
                contour_min_dist = @min(contour_min_dist, segment_dist);
            }

            // Odd number of intersections means inside this contour
            contour_inside = (intersections % 2) == 1;

            // Update global minimum distance
            min_distance = @min(min_distance, contour_min_dist);

            // For text, typically outer contours are clockwise (outside) and inner are counter-clockwise (holes)
            // Simple heuristic: if inside any contour, we're inside the glyph
            if (contour_inside) {
                inside = true;
            }
        }

        // Return signed distance (negative inside, positive outside)
        return if (inside) -min_distance else min_distance;
    }
};

// Strategy metadata
pub const STRATEGY_NAME = "sdf";
pub const OPTIMAL_FONT_SIZE_RANGE = struct {
    min: f32 = 16.0,
    max: f32 = 128.0,
};
pub const TYPICAL_VERTICES_PER_GLYPH = 6; // Same as bitmap, but scalable
pub const RENDERING_APPROACH = "SDF texture → GPU shader with effects";
