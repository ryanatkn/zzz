const std = @import("std");
const font_types = @import("../font_types.zig");
const renderer_interface = @import("renderer_interface.zig");
const log_throttle = @import("../../debug/log_throttle.zig");

const Point = font_types.Point;
const Contour = font_types.Contour;
const GlyphOutline = font_types.GlyphOutline;
const RenderResult = renderer_interface.RenderResult;
const RendererMetrics = renderer_interface.RendererMetrics;
const RendererConfig = renderer_interface.RendererConfig;
const TextRenderer = renderer_interface.TextRenderer;

/// Simple bitmap renderer using point-in-polygon tests
/// No anti-aliasing, but fast and simple for baseline testing
pub const SimpleBitmapRenderer = struct {
    config: RendererConfig,
    metrics: RendererMetrics,
    last_error: ?[]const u8,

    pub fn init() SimpleBitmapRenderer {
        return SimpleBitmapRenderer{
            .config = RendererConfig{
                .debug_mode = false,
                .antialias_level = 1,
                .max_glyph_size = 256,
                .enable_profiling = true,
                .cache_memory_budget = 1024 * 1024,
            },
            .metrics = RendererMetrics{},
            .last_error = null,
        };
    }

    pub fn asRenderer(self: *SimpleBitmapRenderer) TextRenderer {
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
        const self: *SimpleBitmapRenderer = @ptrCast(@alignCast(ctx));
        const start_time = std.time.microTimestamp();

        log_throttle.logDebug("simple_bitmap_start", "SimpleBitmapRenderer: rendering glyph at {}pt", .{font_size});

        // Calculate render bounds based on outline bounds and font size
        const scale = font_size / 1000.0; // TTF units to pixels (assuming 1000 units per EM)
        
        const bounds_width = @as(f32, @floatFromInt(outline.bounds.width())) * scale;
        const bounds_height = @as(f32, @floatFromInt(outline.bounds.height())) * scale;
        
        log_throttle.logInfo("simple_bitmap_bounds", "Glyph bounds: {}x{} TTF units, {}x{} pixels (scale={d:.3})", .{outline.bounds.width(), outline.bounds.height(), bounds_width, bounds_height, scale});
        
        // Add padding for safety
        const padding = 2.0;
        const render_width = @as(u32, @intFromFloat(@ceil(bounds_width + padding * 2.0)));
        const render_height = @as(u32, @intFromFloat(@ceil(bounds_height + padding * 2.0)));

        // Clamp to reasonable size
        const max_size = self.config.max_glyph_size;
        const width = @min(render_width, max_size);
        const height = @min(render_height, max_size);
        
        log_throttle.logDebug("simple_bitmap_render_size", "Calculated render size: {}x{} -> clamped to {}x{} (max_size={})", .{render_width, render_height, width, height, max_size});

        if (width == 0 or height == 0) {
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
                .quality_score = 100.0, // Empty glyphs are "perfect"
            };
        }

        // Allocate bitmap
        const bitmap = try allocator.alloc(u8, width * height);
        @memset(bitmap, 0);

        // Transform outline to render space
        const transform_offset_x = padding - @as(f32, @floatFromInt(outline.bounds.x_min)) * scale;
        const transform_offset_y = padding - @as(f32, @floatFromInt(outline.bounds.y_min)) * scale;

        // Process each pixel
        var y: u32 = 0;
        while (y < height) : (y += 1) {
            var x: u32 = 0;
            while (x < width) : (x += 1) {
                const pixel_x = @as(f32, @floatFromInt(x)) - transform_offset_x;
                const pixel_y = @as(f32, @floatFromInt(y)) - transform_offset_y;
                
                // Convert to TTF coordinate space
                const ttf_x = pixel_x / scale;
                const ttf_y = pixel_y / scale;

                // Test if point is inside glyph using winding number
                const inside = isPointInside(Point{ .x = ttf_x, .y = ttf_y }, outline.contours);
                
                const bitmap_idx = y * width + x;
                bitmap[bitmap_idx] = if (inside) 255 else 0;
            }
        }

        // Calculate metrics
        const end_time = std.time.microTimestamp();
        const render_time = @as(u64, @intCast(end_time - start_time));
        
        self.metrics.glyphs_rendered += 1;
        self.metrics.total_render_time_us += render_time;
        self.metrics.avg_render_time_us = self.metrics.total_render_time_us / self.metrics.glyphs_rendered;
        
        // Calculate quality score (simple bitmap gets medium score)
        const quality_score = 60.0; // Fixed score for simple bitmap
        
        log_throttle.logDebug("simple_bitmap_result", "SimpleBitmapRenderer: rendered {}x{} bitmap", .{width, height});
        
        return RenderResult{
            .bitmap = bitmap,
            .width = width,
            .height = height,
            .bearing_x = @intFromFloat(@floor(@as(f32, @floatFromInt(outline.bounds.x_min)) * scale)),
            .bearing_y = @intFromFloat(@floor(@as(f32, @floatFromInt(outline.bounds.y_max)) * scale)), // TTF uses top-down, flip for bottom-up
            .advance_x = outline.metrics.getAdvance() * scale,
            .render_time_us = render_time,
            .quality_score = quality_score,
        };
    }

    /// Test if a point is inside the glyph using the winding number algorithm
    fn isPointInside(point: Point, contours: []const Contour) bool {
        var winding_number: i32 = 0;

        for (contours) |contour| {
            if (contour.points.len < 3) continue; // Need at least 3 points for a shape

            // Process each edge in the contour
            var i: usize = 0;
            while (i < contour.points.len) : (i += 1) {
                const next_i = (i + 1) % contour.points.len;
                const p1 = contour.points[i];
                const p2 = contour.points[next_i];

                // Ray casting: count intersections with horizontal ray to the right
                if ((p1.y <= point.y and point.y < p2.y) or (p2.y <= point.y and point.y < p1.y)) {
                    // Compute intersection point
                    const t = (point.y - p1.y) / (p2.y - p1.y);
                    const intersection_x = p1.x + t * (p2.x - p1.x);
                    
                    if (intersection_x > point.x) {
                        // Edge crosses the ray to the right
                        if (p1.y < p2.y) {
                            winding_number += 1; // Upward crossing
                        } else {
                            winding_number -= 1; // Downward crossing
                        }
                    }
                }
            }
        }

        // Point is inside if winding number is non-zero
        return winding_number != 0;
    }

    fn getName(ctx: *const anyopaque) []const u8 {
        _ = ctx;
        return "Simple Bitmap";
    }

    fn getMetrics(ctx: *const anyopaque) RendererMetrics {
        const self: *const SimpleBitmapRenderer = @ptrCast(@alignCast(ctx));
        return self.metrics;
    }

    fn configure(ctx: *anyopaque, config: RendererConfig) void {
        const self: *SimpleBitmapRenderer = @ptrCast(@alignCast(ctx));
        self.config = config;
    }

    fn reset(ctx: *anyopaque) void {
        const self: *SimpleBitmapRenderer = @ptrCast(@alignCast(ctx));
        self.metrics = RendererMetrics{};
        self.last_error = null;
    }

    fn isHealthy(ctx: *const anyopaque) bool {
        const self: *const SimpleBitmapRenderer = @ptrCast(@alignCast(ctx));
        return self.last_error == null;
    }

    fn getLastError(ctx: *const anyopaque) ?[]const u8 {
        const self: *const SimpleBitmapRenderer = @ptrCast(@alignCast(ctx));
        return self.last_error;
    }

    fn deinit(ctx: *anyopaque, allocator: std.mem.Allocator) void {
        _ = ctx;
        _ = allocator;
        // Simple renderer has no resources to clean up
    }
};

/// Create a new simple bitmap renderer
pub fn create() SimpleBitmapRenderer {
    return SimpleBitmapRenderer.init();
}