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

/// Debug ASCII renderer that creates ASCII art representations of glyphs
/// Very useful for debugging outline parsing and understanding glyph shapes
pub const DebugAsciiRenderer = struct {
    config: RendererConfig,
    metrics: RendererMetrics,
    last_error: ?[]const u8,
    
    // ASCII characters for different coverage levels
    const COVERAGE_CHARS = [_]u8{ ' ', '.', ':', '+', '*', '#', '@' };

    pub fn init() DebugAsciiRenderer {
        return DebugAsciiRenderer{
            .config = RendererConfig{},
            .metrics = RendererMetrics{},
            .last_error = null,
        };
    }

    pub fn asRenderer(self: *DebugAsciiRenderer) TextRenderer {
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
        const self: *DebugAsciiRenderer = @ptrCast(@alignCast(ctx));
        const start_time = std.time.microTimestamp();

        log_throttle.logInfo("debug_ascii_start", "DebugAsciiRenderer: rendering glyph at {}pt", .{font_size});

        // Fixed ASCII grid size for consistency
        const ascii_width: u32 = 16;
        const ascii_height: u32 = 20;
        
        // Calculate scale to fit glyph in ASCII grid
        const bounds_width = @as(f32, @floatFromInt(outline.bounds.width()));
        const bounds_height = @as(f32, @floatFromInt(outline.bounds.height()));
        
        const scale_x = if (bounds_width > 0) @as(f32, @floatFromInt(ascii_width - 2)) / bounds_width else 1.0;
        const scale_y = if (bounds_height > 0) @as(f32, @floatFromInt(ascii_height - 2)) / bounds_height else 1.0;
        const scale = @min(scale_x, scale_y);

        // Allocate bitmap (we'll store ASCII chars as bytes)
        const bitmap = try allocator.alloc(u8, ascii_width * ascii_height);
        @memset(bitmap, COVERAGE_CHARS[0]); // Fill with space

        if (outline.contours.len == 0) {
            // Empty glyph - return spaces
            const end_time = std.time.microTimestamp();
            return RenderResult{
                .bitmap = bitmap,
                .width = ascii_width,
                .height = ascii_height,
                .bearing_x = 0,
                .bearing_y = 0,
                .advance_x = font_size * 0.5, // Reasonable default advance
                .render_time_us = @intCast(end_time - start_time),
                .quality_score = 100.0,
            };
        }

        // Center the glyph in the ASCII grid
        const center_x = @as(f32, @floatFromInt(ascii_width)) / 2.0;
        const center_y = @as(f32, @floatFromInt(ascii_height)) / 2.0;
        
        const bounds_center_x = @as(f32, @floatFromInt(outline.bounds.x_min + outline.bounds.x_max)) / 2.0;
        const bounds_center_y = @as(f32, @floatFromInt(outline.bounds.y_min + outline.bounds.y_max)) / 2.0;

        // Render points and outline
        for (outline.contours) |contour| {
            // Draw outline points
            for (contour.points, 0..) |point, i| {
                // Transform point to ASCII grid space
                const ascii_x = center_x + (point.x - bounds_center_x) * scale;
                const ascii_y = center_y - (point.y - bounds_center_y) * scale; // Flip Y axis
                
                const grid_x = @as(i32, @intFromFloat(@round(ascii_x)));
                const grid_y = @as(i32, @intFromFloat(@round(ascii_y)));
                
                if (grid_x >= 0 and grid_x < ascii_width and grid_y >= 0 and grid_y < ascii_height) {
                    const bitmap_idx = @as(usize, @intCast(grid_y * @as(i32, @intCast(ascii_width)) + grid_x));
                    
                    // Different characters for different point types
                    if (contour.on_curve[i]) {
                        bitmap[bitmap_idx] = COVERAGE_CHARS[5]; // '#' for on-curve points
                    } else {
                        bitmap[bitmap_idx] = COVERAGE_CHARS[4]; // '*' for off-curve points
                    }
                }
            }

            // Draw lines between consecutive points
            for (contour.points, 0..) |_, i| {
                const next_i = (i + 1) % contour.points.len;
                const p1 = contour.points[i];
                const p2 = contour.points[next_i];
                
                self.drawLine(bitmap, ascii_width, ascii_height, p1, p2, bounds_center_x, bounds_center_y, center_x, center_y, scale);
            }
        }

        // Fill interior using simple point-in-polygon test
        if (self.config.debug_mode) {
            self.fillInterior(bitmap, ascii_width, ascii_height, outline.contours, bounds_center_x, bounds_center_y, center_x, center_y, scale);
        }

        // Calculate metrics
        const end_time = std.time.microTimestamp();
        const render_time = @as(u64, @intCast(end_time - start_time));
        
        self.metrics.glyphs_rendered += 1;
        self.metrics.total_render_time_us += render_time;
        self.metrics.avg_render_time_us = self.metrics.total_render_time_us / self.metrics.glyphs_rendered;

        return RenderResult{
            .bitmap = bitmap,
            .width = ascii_width,
            .height = ascii_height,
            .bearing_x = -@as(i32, @intCast(ascii_width)) / 2,
            .bearing_y = @as(i32, @intCast(ascii_height)) / 2,
            .advance_x = font_size * 0.6, // Reasonable default advance
            .render_time_us = render_time,
            .quality_score = 75.0, // Debug rendering gets good score for visualization
        };
    }

    fn drawLine(self: *const DebugAsciiRenderer, bitmap: []u8, width: u32, height: u32, p1: Point, p2: Point, bounds_center_x: f32, bounds_center_y: f32, center_x: f32, center_y: f32, scale: f32) void {
        _ = self;
        
        // Transform points to ASCII grid space
        const x1 = center_x + (p1.x - bounds_center_x) * scale;
        const y1 = center_y - (p1.y - bounds_center_y) * scale;
        const x2 = center_x + (p2.x - bounds_center_x) * scale;
        const y2 = center_y - (p2.y - bounds_center_y) * scale;

        // Simple line drawing (Bresenham-like)
        const dx = @abs(x2 - x1);
        const dy = @abs(y2 - y1);
        const steps = @max(dx, dy);
        
        if (steps < 1) return;
        
        var i: u32 = 0;
        while (i <= @as(u32, @intFromFloat(steps))) : (i += 1) {
            const t = @as(f32, @floatFromInt(i)) / steps;
            const x = x1 + t * (x2 - x1);
            const y = y1 + t * (y2 - y1);
            
            const grid_x = @as(i32, @intFromFloat(@round(x)));
            const grid_y = @as(i32, @intFromFloat(@round(y)));
            
            if (grid_x >= 0 and grid_x < width and grid_y >= 0 and grid_y < height) {
                const bitmap_idx = @as(usize, @intCast(grid_y * @as(i32, @intCast(width)) + grid_x));
                
                // Only draw line if not already a point marker
                if (bitmap[bitmap_idx] == COVERAGE_CHARS[0]) {
                    bitmap[bitmap_idx] = COVERAGE_CHARS[2]; // ':' for lines
                }
            }
        }
    }

    fn fillInterior(self: *const DebugAsciiRenderer, bitmap: []u8, width: u32, height: u32, contours: []const Contour, bounds_center_x: f32, bounds_center_y: f32, center_x: f32, center_y: f32, scale: f32) void {
        _ = self;
        
        var y: u32 = 0;
        while (y < height) : (y += 1) {
            var x: u32 = 0;
            while (x < width) : (x += 1) {
                const bitmap_idx = y * width + x;
                
                // Skip if already drawn
                if (bitmap[bitmap_idx] != COVERAGE_CHARS[0]) continue;
                
                // Transform back to TTF space
                const ttf_x = bounds_center_x + (@as(f32, @floatFromInt(x)) - center_x) / scale;
                const ttf_y = bounds_center_y - (@as(f32, @floatFromInt(y)) - center_y) / scale;
                
                // Test if inside using simple winding number
                if (isPointInside(Point{ .x = ttf_x, .y = ttf_y }, contours)) {
                    bitmap[bitmap_idx] = COVERAGE_CHARS[1]; // '.' for interior
                }
            }
        }
    }

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
        _ = ctx;
        return "Debug ASCII";
    }

    fn getMetrics(ctx: *const anyopaque) RendererMetrics {
        const self: *const DebugAsciiRenderer = @ptrCast(@alignCast(ctx));
        return self.metrics;
    }

    fn configure(ctx: *anyopaque, config: RendererConfig) void {
        const self: *DebugAsciiRenderer = @ptrCast(@alignCast(ctx));
        self.config = config;
    }

    fn reset(ctx: *anyopaque) void {
        const self: *DebugAsciiRenderer = @ptrCast(@alignCast(ctx));
        self.metrics = RendererMetrics{};
        self.last_error = null;
    }

    fn isHealthy(ctx: *const anyopaque) bool {
        const self: *const DebugAsciiRenderer = @ptrCast(@alignCast(ctx));
        return self.last_error == null;
    }

    fn getLastError(ctx: *const anyopaque) ?[]const u8 {
        const self: *const DebugAsciiRenderer = @ptrCast(@alignCast(ctx));
        return self.last_error;
    }

    fn deinit(ctx: *anyopaque, allocator: std.mem.Allocator) void {
        _ = ctx;
        _ = allocator;
    }
};

/// Create a new debug ASCII renderer
pub fn create() DebugAsciiRenderer {
    return DebugAsciiRenderer.init();
}

/// Print ASCII bitmap to console for debugging
pub fn printAsciiGlyph(result: RenderResult) void {
    std.debug.print("ASCII Glyph ({} x {}):\n", .{ result.width, result.height });
    
    var y: u32 = 0;
    while (y < result.height) : (y += 1) {
        var x: u32 = 0;
        while (x < result.width) : (x += 1) {
            const char = result.bitmap[y * result.width + x];
            std.debug.print("{c}", .{char});
        }
        std.debug.print("\n", .{});
    }
    std.debug.print("\n", .{});
}