const std = @import("std");
const font_types = @import("../font_types.zig");
const renderer_interface = @import("renderer_interface.zig");

const Point = font_types.Point;
const Contour = font_types.Contour;
const GlyphOutline = font_types.GlyphOutline;
const RenderResult = renderer_interface.RenderResult;
const RendererMetrics = renderer_interface.RendererMetrics;
const RendererConfig = renderer_interface.RendererConfig;
const TextRenderer = renderer_interface.TextRenderer;

/// Oversampling renderer that renders at higher resolution then downsamples
/// Provides anti-aliasing through simple oversampling with box filter
pub const OversamplingRenderer = struct {
    config: RendererConfig,
    metrics: RendererMetrics,
    last_error: ?[]const u8,
    oversample_factor: u32, // 2x or 4x

    pub fn init(oversample_factor: u32) OversamplingRenderer {
        return OversamplingRenderer{
            .config = RendererConfig{
                .debug_mode = false,
                .antialias_level = oversample_factor,
                .max_glyph_size = 256,
                .enable_profiling = true,
                .cache_memory_budget = 1024 * 1024,
            },
            .metrics = RendererMetrics{},
            .last_error = null,
            .oversample_factor = oversample_factor,
        };
    }

    pub fn asRenderer(self: *OversamplingRenderer) TextRenderer {
        return TextRenderer{
            .ctx = self,
            .vtable = &.{
                .renderGlyph = renderGlyph,
                .getName = getName,
                .getMetrics = getMetrics,
                .configure = configure,
                .reset = reset,
                .isHealthy = isHealthy,
                .getLastError = getLastError,
                .deinit = deinit,
            },
        };
    }

    fn renderGlyph(ctx: *anyopaque, allocator: std.mem.Allocator, outline: GlyphOutline, font_size: f32) anyerror!RenderResult {
        const self: *OversamplingRenderer = @ptrCast(@alignCast(ctx));
        const start_time = std.time.microTimestamp();

        // Calculate render bounds
        const scale = font_size / 1000.0; // TTF units to pixels
        const bounds_width = @as(f32, @floatFromInt(outline.bounds.width())) * scale;
        const bounds_height = @as(f32, @floatFromInt(outline.bounds.height())) * scale;

        // Add padding
        const padding = 2.0;
        const target_width = @as(u32, @intFromFloat(@ceil(bounds_width + padding * 2.0)));
        const target_height = @as(u32, @intFromFloat(@ceil(bounds_height + padding * 2.0)));

        // Clamp target size
        const max_size = self.config.max_glyph_size;
        const final_width = @min(target_width, max_size);
        const final_height = @min(target_height, max_size);

        if (final_width == 0 or final_height == 0) {
            // Empty glyph
            const empty_bitmap = try allocator.alloc(u8, 1);
            empty_bitmap[0] = 0;

            const end_time = std.time.microTimestamp();
            return RenderResult{
                .bitmap = empty_bitmap,
                .width = 0,
                .height = 0,
                .bearing_x = 0,
                .bearing_y = 0,
                .advance_x = outline.metrics.getAdvance() * scale,
                .render_time_us = @intCast(end_time - start_time),
                .quality_score = 100.0,
            };
        }

        // Calculate oversampled dimensions with overflow checking
        const oversample_width = @as(u64, final_width) * @as(u64, self.oversample_factor);
        const oversample_height = @as(u64, final_height) * @as(u64, self.oversample_factor);

        // Check for reasonable limits to prevent excessive memory usage
        if (oversample_width > std.math.maxInt(u32) or oversample_height > std.math.maxInt(u32)) {
            // Fall back to simple rendering if oversampling would be too large
            return try self.renderSimple(allocator, outline, font_size, final_width, final_height, scale, padding);
        }

        const oversample_width_u32 = @as(u32, @intCast(oversample_width));
        const oversample_height_u32 = @as(u32, @intCast(oversample_height));

        // Prevent excessive memory usage
        const max_oversample_size = max_size * 2; // Allow up to 2x max size for oversampling
        if (oversample_width_u32 > max_oversample_size or oversample_height_u32 > max_oversample_size) {
            // Fall back to simple rendering at target size
            return try self.renderSimple(allocator, outline, font_size, final_width, final_height, scale, padding);
        }

        // Allocate oversampled bitmap (check for overflow in total size)
        const total_oversample_size = oversample_width * oversample_height;
        if (total_oversample_size > std.math.maxInt(usize)) {
            return try self.renderSimple(allocator, outline, font_size, final_width, final_height, scale, padding);
        }
        const oversample_bitmap = try allocator.alloc(u8, @intCast(total_oversample_size));
        defer allocator.free(oversample_bitmap);
        @memset(oversample_bitmap, 0);

        // Transform parameters for oversampled rendering
        const oversample_scale = scale * @as(f32, @floatFromInt(self.oversample_factor));
        const transform_offset_x = padding * @as(f32, @floatFromInt(self.oversample_factor)) - @as(f32, @floatFromInt(outline.bounds.x_min)) * oversample_scale;
        const transform_offset_y = padding * @as(f32, @floatFromInt(self.oversample_factor)) - @as(f32, @floatFromInt(outline.bounds.y_min)) * oversample_scale;

        // Render at oversampled resolution
        var y: u32 = 0;
        while (y < oversample_height_u32) : (y += 1) {
            var x: u32 = 0;
            while (x < oversample_width_u32) : (x += 1) {
                const pixel_x = @as(f32, @floatFromInt(x)) - transform_offset_x;
                const pixel_y = @as(f32, @floatFromInt(y)) - transform_offset_y;

                // Convert to TTF coordinate space
                const ttf_x = pixel_x / oversample_scale;
                const ttf_y = pixel_y / oversample_scale;

                const inside = isPointInside(Point{ .x = ttf_x, .y = ttf_y }, outline.contours);

                const bitmap_idx = y * oversample_width_u32 + x;
                oversample_bitmap[bitmap_idx] = if (inside) 255 else 0;
            }
        }

        // Downsample to target resolution
        const final_bitmap = try allocator.alloc(u8, final_width * final_height);

        y = 0;
        while (y < final_height) : (y += 1) {
            var x: u32 = 0;
            while (x < final_width) : (x += 1) {
                // Sample box from oversampled bitmap
                var sum: u32 = 0;
                const box_size = self.oversample_factor;

                var by: u32 = 0;
                while (by < box_size) : (by += 1) {
                    var bx: u32 = 0;
                    while (bx < box_size) : (bx += 1) {
                        const sample_x = x * box_size + bx;
                        const sample_y = y * box_size + by;

                        if (sample_x < oversample_width_u32 and sample_y < oversample_height_u32) {
                            const sample_idx = sample_y * oversample_width_u32 + sample_x;
                            sum += oversample_bitmap[sample_idx];
                        }
                    }
                }

                // Average the samples
                const pixel_value = sum / (box_size * box_size);
                const final_idx = y * final_width + x;
                final_bitmap[final_idx] = @intCast(pixel_value);
            }
        }

        // Calculate metrics
        const end_time = std.time.microTimestamp();
        const render_time = @as(u64, @intCast(end_time - start_time));

        self.metrics.glyphs_rendered += 1;
        self.metrics.total_render_time_us += render_time;
        self.metrics.avg_render_time_us = self.metrics.total_render_time_us / self.metrics.glyphs_rendered;

        // Quality score based on oversampling level
        const quality_score: f32 = switch (self.oversample_factor) {
            2 => 75.0,
            4 => 85.0,
            else => 70.0,
        };

        return RenderResult{
            .bitmap = final_bitmap,
            .width = final_width,
            .height = final_height,
            .bearing_x = @intFromFloat(@floor(@as(f32, @floatFromInt(outline.bounds.x_min)) * scale)),
            .bearing_y = @intFromFloat(@floor(@as(f32, @floatFromInt(outline.bounds.y_max)) * scale)),
            .advance_x = outline.metrics.getAdvance() * scale,
            .render_time_us = render_time,
            .quality_score = quality_score,
        };
    }

    /// Fallback simple rendering when oversampling would use too much memory
    fn renderSimple(self: *OversamplingRenderer, allocator: std.mem.Allocator, outline: GlyphOutline, _: f32, width: u32, height: u32, scale: f32, padding: f32) !RenderResult {
        const start_time = std.time.microTimestamp();

        const bitmap = try allocator.alloc(u8, width * height);
        @memset(bitmap, 0);

        const transform_offset_x = padding - @as(f32, @floatFromInt(outline.bounds.x_min)) * scale;
        const transform_offset_y = padding - @as(f32, @floatFromInt(outline.bounds.y_min)) * scale;

        var y: u32 = 0;
        while (y < height) : (y += 1) {
            var x: u32 = 0;
            while (x < width) : (x += 1) {
                const pixel_x = @as(f32, @floatFromInt(x)) - transform_offset_x;
                const pixel_y = @as(f32, @floatFromInt(y)) - transform_offset_y;

                const ttf_x = pixel_x / scale;
                const ttf_y = pixel_y / scale;

                const inside = isPointInside(Point{ .x = ttf_x, .y = ttf_y }, outline.contours);

                const bitmap_idx = y * width + x;
                bitmap[bitmap_idx] = if (inside) 255 else 0;
            }
        }

        const end_time = std.time.microTimestamp();
        const render_time = @as(u64, @intCast(end_time - start_time));

        self.metrics.glyphs_rendered += 1;
        self.metrics.total_render_time_us += render_time;
        self.metrics.avg_render_time_us = self.metrics.total_render_time_us / self.metrics.glyphs_rendered;

        return RenderResult{
            .bitmap = bitmap,
            .width = width,
            .height = height,
            .bearing_x = @intFromFloat(@floor(@as(f32, @floatFromInt(outline.bounds.x_min)) * scale)),
            .bearing_y = @intFromFloat(@floor(@as(f32, @floatFromInt(outline.bounds.y_max)) * scale)),
            .advance_x = outline.metrics.getAdvance() * scale,
            .render_time_us = render_time,
            .quality_score = 60.0, // Lower score for fallback
        };
    }

    /// Point-in-polygon test using winding number algorithm
    fn isPointInside(point: Point, contours: []const Contour) bool {
        var winding_number: i32 = 0;

        for (contours) |contour| {
            if (contour.points.len < 3) continue;

            var i: usize = 0;
            while (i < contour.points.len) : (i += 1) {
                const next_i = (i + 1) % contour.points.len;
                const p1 = contour.points[i];
                const p2 = contour.points[next_i];

                if ((p1.y <= point.y and point.y < p2.y) or (p2.y <= point.y and point.y < p1.y)) {
                    const t = (point.y - p1.y) / (p2.y - p1.y);
                    const intersection_x = p1.x + t * (p2.x - p1.x);

                    if (intersection_x > point.x) {
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

    fn getName(ctx: *const anyopaque) []const u8 {
        const self: *const OversamplingRenderer = @ptrCast(@alignCast(ctx));
        return switch (self.oversample_factor) {
            2 => "Oversample 2x",
            4 => "Oversample 4x",
            else => "Oversample Nx",
        };
    }

    fn getMetrics(ctx: *const anyopaque) RendererMetrics {
        const self: *const OversamplingRenderer = @ptrCast(@alignCast(ctx));
        return self.metrics;
    }

    fn configure(ctx: *anyopaque, config: RendererConfig) void {
        const self: *OversamplingRenderer = @ptrCast(@alignCast(ctx));
        self.config = config;
    }

    fn reset(ctx: *anyopaque) void {
        const self: *OversamplingRenderer = @ptrCast(@alignCast(ctx));
        self.metrics = RendererMetrics{};
        self.last_error = null;
    }

    fn isHealthy(ctx: *const anyopaque) bool {
        const self: *const OversamplingRenderer = @ptrCast(@alignCast(ctx));
        return self.last_error == null;
    }

    fn getLastError(ctx: *const anyopaque) ?[]const u8 {
        const self: *const OversamplingRenderer = @ptrCast(@alignCast(ctx));
        return self.last_error;
    }

    fn deinit(ctx: *anyopaque, allocator: std.mem.Allocator) void {
        _ = ctx;
        _ = allocator;
    }
};

/// Create a new 2x oversampling renderer
pub fn create2x() OversamplingRenderer {
    return OversamplingRenderer.init(2);
}

/// Create a new 4x oversampling renderer
pub fn create4x() OversamplingRenderer {
    return OversamplingRenderer.init(4);
}
