const std = @import("std");
const ttf_parser = @import("ttf_parser.zig");
const glyph_extractor = @import("glyph_extractor.zig");
const font_metrics = @import("font_metrics.zig");
const bitmap_utils = @import("../image/bitmap.zig");
// Deleted modules: edge_builder, scanline_renderer, font_debug, curve_tessellation

const log = std.log.scoped(.rasterizer_core);

/// Simple point-in-polygon test using winding number algorithm
fn isPointInsideGlyph(test_x: f32, test_y: f32, contours: []const glyph_extractor.Contour) bool {
    var winding_number: i32 = 0;

    for (contours) |contour| {
        if (contour.points.len < 3) continue; // Need at least 3 points for a polygon

        for (contour.points, 0..) |_, i| {
            const next_i = (i + 1) % contour.points.len;
            const p1 = contour.points[i];
            const p2 = contour.points[next_i];

            // Ray casting algorithm - check if ray from test point crosses edge
            if ((p1.y <= test_y and test_y < p2.y) or (p2.y <= test_y and test_y < p1.y)) {
                const t = (test_y - p1.y) / (p2.y - p1.y);
                const intersection_x = p1.x + t * (p2.x - p1.x);

                if (intersection_x > test_x) {
                    if (p1.y < p2.y) {
                        winding_number += 1;
                    } else {
                        winding_number -= 1;
                    }
                }
            }
        }
    }

    return winding_number != 0;
}

/// Result of rasterizing a glyph
pub const RasterizedGlyph = struct {
    bitmap: []u8,
    width: f32,
    height: f32,
    bearing_x: f32,
    bearing_y: f32,
    advance: f32,
};

/// Core font rasterizer - simplified to work with bitmap renderer
pub const RasterizerCore = struct {
    allocator: std.mem.Allocator,
    parser: *ttf_parser.TTFParser,
    scale: f32,

    // Sub-components
    extractor: glyph_extractor.GlyphExtractor,

    // Configuration
    metrics: font_metrics.FontMetrics,
    debug_mode: bool = false,

    pub fn init(
        allocator: std.mem.Allocator,
        parser: *ttf_parser.TTFParser,
        point_size: f32,
        dpi: f32,
    ) RasterizerCore {
        // Calculate scale
        const units_per_em = if (parser.head) |head| head.units_per_em else 1000;
        const pixels_per_em = (point_size * dpi) / 72.0;
        const scale = pixels_per_em / @as(f32, @floatFromInt(units_per_em));

        // Get font metrics
        const ascender = if (parser.hhea) |hhea| hhea.ascender else @as(i16, @intFromFloat(@as(f32, @floatFromInt(units_per_em)) * 0.8));
        const descender = if (parser.hhea) |hhea| hhea.descender else @as(i16, @intFromFloat(@as(f32, @floatFromInt(units_per_em)) * -0.2));
        const line_gap = if (parser.hhea) |hhea| hhea.line_gap else 100;

        return RasterizerCore{
            .allocator = allocator,
            .parser = parser,
            .scale = scale,
            .extractor = glyph_extractor.GlyphExtractor.init(allocator, parser, scale),
            .metrics = font_metrics.FontMetrics.init(units_per_em, ascender, descender, line_gap, scale),
            .debug_mode = false,
        };
    }

    /// Rasterize a glyph by codepoint
    pub fn rasterizeGlyph(
        self: *RasterizerCore,
        codepoint: u32,
        subpixel_x: f32,
        subpixel_y: f32,
    ) !RasterizedGlyph {
        // Extract glyph outline
        const outline = try self.extractor.extractGlyph(codepoint);
        defer outline.deinit(self.allocator);

        // Debug: print outline info
        if (self.debug_mode) {
            log.debug("Rasterizing outline with bounds {}", .{outline.bounds});
        }

        // Calculate bitmap dimensions with normalized baseline positioning
        const bounds = outline.bounds;
        const width_f = bounds.width() + 2.0; // Add padding
        
        // For consistent baseline positioning, calculate height based on font metrics
        const font_ascender = @as(f32, @floatFromInt(self.metrics.ascender)) * self.scale;
        const font_descender = @as(f32, @floatFromInt(-self.metrics.descender)) * self.scale; // Make positive
        const total_font_height = font_ascender + font_descender;
        
        // Use the larger of glyph bounds or font metrics to ensure consistent baseline
        const height_f = @max(bounds.height() + 2.0, total_font_height + 2.0);
        const width = @as(u32, @intFromFloat(@ceil(width_f)));
        const height = @as(u32, @intFromFloat(@ceil(height_f)));

        // Handle empty glyphs (like space)
        if (width <= 2 or height <= 2 or outline.contours.len == 0) {
            return RasterizedGlyph{
                .bitmap = &[_]u8{}, // Empty slice
                .width = 0.0,
                .height = 0.0,
                .bearing_x = 0.0,
                .bearing_y = 0.0,
                .advance = outline.metrics.advance_width,
            };
        }

        // Allocate bitmap
        const bitmap = try self.allocator.alloc(u8, width * height);
        errdefer self.allocator.free(bitmap);
        @memset(bitmap, 0);

        // Simple bitmap rasterization using point-in-polygon test
        _ = subpixel_x;
        _ = subpixel_y;

        // Calculate transform from bitmap coordinates to TTF coordinates
        const offset_x = bounds.x_min - 1.0;
        
        // For consistent baseline positioning, place baseline at a fixed position from bottom
        const baseline_from_bottom = font_descender + 1.0; // Padding from bottom
        
        // Rasterize each pixel
        for (0..height) |y| {
            for (0..width) |x| {
                const pixel_x = @as(f32, @floatFromInt(x)) + offset_x;
                
                // Calculate TTF Y coordinate: baseline is at consistent position from bitmap bottom
                const bitmap_y_from_bottom = @as(f32, @floatFromInt(height)) - 1.0 - @as(f32, @floatFromInt(y));
                const pixel_y = bitmap_y_from_bottom - baseline_from_bottom; // TTF coordinate (baseline = 0)

                // Test if point is inside glyph using simple winding number
                const inside = isPointInsideGlyph(pixel_x, pixel_y, outline.contours);

                const bitmap_idx = y * width + x;
                bitmap[bitmap_idx] = if (inside) 255 else 0; // Pure black/white
            }
        }

        // Debug mode
        if (self.debug_mode) {
            log.debug("Rasterized glyph using point-in-polygon: {}x{}", .{ width, height });
        }

        return RasterizedGlyph{
            .bitmap = bitmap,
            .width = width_f,
            .height = height_f,
            .bearing_x = bounds.x_min - 1.0, // X offset from cursor to glyph left edge (already in pixels)
            .bearing_y = baseline_from_bottom + bounds.y_max, // Distance from baseline to top of bitmap
            .advance = outline.metrics.advance_width,
        };
    }

    /// Get font metrics
    pub fn getFontMetrics(self: *const RasterizerCore) font_metrics.FontMetrics {
        return self.metrics;
    }

    /// Enable/disable debug mode
    pub fn setDebugMode(self: *RasterizerCore, enabled: bool) void {
        self.debug_mode = enabled;
    }

    /// Update rendering quality (simplified)
    pub fn setQuality(self: *RasterizerCore, quality: enum { fast, medium, high, ultra }) void {
        _ = self;
        _ = quality;
        // Quality setting is now handled by individual renderer implementations
    }

    /// Set anti-aliasing mode (simplified)
    pub fn setAntialiasing(self: *RasterizerCore, enabled: bool) void {
        _ = self;
        _ = enabled;
        // Anti-aliasing is now handled by individual renderer implementations
    }

    /// Set gamma correction (simplified)
    pub fn setGamma(self: *RasterizerCore, gamma: f32) void {
        _ = self;
        _ = gamma;
        // Gamma correction is now handled by individual renderer implementations
    }
};
