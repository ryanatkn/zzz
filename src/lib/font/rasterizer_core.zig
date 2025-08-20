const std = @import("std");
const ttf_parser = @import("ttf_parser.zig");
const glyph_extractor = @import("glyph_extractor.zig");
const font_metrics = @import("font_metrics.zig");
const bitmap_utils = @import("../image/bitmap.zig");
// Deleted modules: edge_builder, scanline_renderer, font_debug, curve_tessellation

const log = std.log.scoped(.rasterizer_core);

/// Improved point-in-glyph test with curve tessellation support
fn isPointInsideGlyph(test_x: f32, test_y: f32, contours: []const glyph_extractor.Contour, allocator: std.mem.Allocator) !bool {
    var winding_number: i32 = 0;

    for (contours) |contour| {
        if (contour.points.len < 2) continue;

        // Tessellate curves into line segments for more accurate rendering
        const tessellated_points = try tessellateContour(allocator, contour);
        defer allocator.free(tessellated_points);

        if (tessellated_points.len < 3) continue;

        // Use improved winding number algorithm on tessellated contour
        for (tessellated_points, 0..) |_, i| {
            const next_i = (i + 1) % tessellated_points.len;
            const p1 = tessellated_points[i];
            const p2 = tessellated_points[next_i];

            // Ray casting with better precision
            if ((p1.y <= test_y and test_y < p2.y) or (p2.y <= test_y and test_y < p1.y)) {
                const dy = p2.y - p1.y;
                if (@abs(dy) > 0.0001) { // Avoid division by very small numbers
                    const t = (test_y - p1.y) / dy;
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
    }

    return winding_number != 0;
}

/// Fast point-in-glyph test using pre-tessellated contours
fn isPointInsideGlyphFast(test_x: f32, test_y: f32, tessellated_contours: []const []glyph_extractor.Point) bool {
    var winding_number: i32 = 0;

    for (tessellated_contours) |contour_points| {
        if (contour_points.len < 3) continue;

        // Use improved winding number algorithm on tessellated contour
        for (contour_points, 0..) |_, i| {
            const next_i = (i + 1) % contour_points.len;
            const p1 = contour_points[i];
            const p2 = contour_points[next_i];

            // Ray casting with better precision
            if ((p1.y <= test_y and test_y < p2.y) or (p2.y <= test_y and test_y < p1.y)) {
                const dy = p2.y - p1.y;
                if (@abs(dy) > 0.0001) { // Avoid division by very small numbers
                    const t = (test_y - p1.y) / dy;
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
    }

    return winding_number != 0;
}

/// Tessellate a contour by converting curves to line segments
fn tessellateContour(allocator: std.mem.Allocator, contour: glyph_extractor.Contour) ![]glyph_extractor.Point {
    var tessellated = std.ArrayList(glyph_extractor.Point).init(allocator);
    defer tessellated.deinit();

    if (contour.points.len < 2) {
        return tessellated.toOwnedSlice();
    }

    var i: usize = 0;
    while (i < contour.points.len) {
        const current = contour.points[i];
        const next_i = (i + 1) % contour.points.len;
        const next = contour.points[next_i];

        try tessellated.append(current);

        // If current point is on-curve and next is off-curve, we have a curve segment
        if (current.on_curve and !next.on_curve) {
            // Look for the end point of the curve
            const end_i = (i + 2) % contour.points.len;
            var end_point = contour.points[end_i];

            // If end point is also off-curve, create implied on-curve point
            if (!end_point.on_curve and i + 2 < contour.points.len) {
                const next_next = contour.points[end_i];
                end_point = glyph_extractor.Point{
                    .x = (next.x + next_next.x) / 2.0,
                    .y = (next.y + next_next.y) / 2.0,
                    .on_curve = true,
                };
            } else if (!end_point.on_curve) {
                // Wrap around - use first point
                end_point = contour.points[0];
            }

            // Tessellate quadratic bezier curve
            const steps = 8; // Number of line segments to approximate curve
            var step: u32 = 1;
            while (step <= steps) : (step += 1) {
                const t = @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(steps));
                const point = quadraticBezier(current, next, end_point, t);
                try tessellated.append(point);
            }

            // Skip the control point and move to end point
            i = end_i;
        } else {
            i += 1;
        }
    }

    return tessellated.toOwnedSlice();
}

/// Evaluate quadratic bezier curve at parameter t
fn quadraticBezier(p0: glyph_extractor.Point, p1: glyph_extractor.Point, p2: glyph_extractor.Point, t: f32) glyph_extractor.Point {
    const one_minus_t = 1.0 - t;
    const a = one_minus_t * one_minus_t;
    const b = 2.0 * one_minus_t * t;
    const c = t * t;

    return glyph_extractor.Point{
        .x = a * p0.x + b * p1.x + c * p2.x,
        .y = a * p0.y + b * p1.y + c * p2.y,
        .on_curve = true,
    };
}

/// Calculate pixel coverage with basic edge anti-aliasing
fn calculatePixelCoverage(center_x: f32, center_y: f32, contours: []const glyph_extractor.Contour, allocator: std.mem.Allocator) !f32 {
    // First check center point
    const center_inside = isPointInsideGlyph(center_x, center_y, contours, allocator) catch false;

    // For performance, use simple 4-point sampling only near edges
    const edge_samples = [_]struct { x: f32, y: f32 }{
        .{ .x = center_x - 0.25, .y = center_y },
        .{ .x = center_x + 0.25, .y = center_y },
        .{ .x = center_x, .y = center_y - 0.25 },
        .{ .x = center_x, .y = center_y + 0.25 },
    };

    var inside_count: u32 = if (center_inside) 1 else 0;
    var edge_detected = false;

    for (edge_samples) |sample| {
        const inside = isPointInsideGlyph(sample.x, sample.y, contours, allocator) catch false;
        if (inside) inside_count += 1;
        if (inside != center_inside) edge_detected = true;
    }

    // If we're not near an edge, return solid fill or empty
    if (!edge_detected) {
        return if (center_inside) 1.0 else 0.0;
    }

    // Near edge: return proportional coverage
    return @as(f32, @floatFromInt(inside_count)) / 5.0; // 5 samples total
}

/// Result of rasterizing a glyph
pub const RasterizedGlyph = struct {
    bitmap: []u8,
    width: f32, // Logical dimensions for positioning
    height: f32,
    bitmap_width: u32, // Actual bitmap dimensions for indexing
    bitmap_height: u32,
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
                .bitmap_width = 0,
                .bitmap_height = 0,
                .bearing_x = 0.0,
                .bearing_y = 0.0,
                .advance = outline.metrics.advance_width,
            };
        }

        // Allocate bitmap
        const bitmap = try self.allocator.alloc(u8, width * height);
        errdefer self.allocator.free(bitmap);
        @memset(bitmap, 0);

        // Pre-tessellate all contours once to avoid repeated tessellation
        var tessellated_contours = std.ArrayList([]glyph_extractor.Point).init(self.allocator);
        defer {
            for (tessellated_contours.items) |tessellated_points| {
                self.allocator.free(tessellated_points);
            }
            tessellated_contours.deinit();
        }

        // Tessellate all contours once
        for (outline.contours) |contour| {
            const tessellated_points = tessellateContour(self.allocator, contour) catch continue;
            tessellated_contours.append(tessellated_points) catch {
                self.allocator.free(tessellated_points);
                continue;
            };
        }

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

                // Test if point is inside glyph using pre-tessellated contours
                const inside = isPointInsideGlyphFast(pixel_x, pixel_y, tessellated_contours.items);

                const bitmap_idx = y * width + x;
                bitmap[bitmap_idx] = if (inside) 255 else 0;
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
            .bitmap_width = width, // The actual allocated dimensions
            .bitmap_height = height,
            .bearing_x = bounds.x_min - 1.0, // X offset from cursor to glyph left edge (already in pixels)
            .bearing_y = height_f - baseline_from_bottom, // Distance from baseline to top of bitmap
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
