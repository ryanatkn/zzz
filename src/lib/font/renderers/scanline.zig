const std = @import("std");
const font_types = @import("../font_types.zig");
const glyph_extractor = @import("../glyph_extractor.zig");
const renderer_interface = @import("renderer_interface.zig");
// edge_builder and scanline_renderer removed - using simplified bitmap rendering

const Point = font_types.Point;
const Contour = font_types.Contour;
const GlyphOutline = font_types.GlyphOutline;
const ExtractorGlyphOutline = glyph_extractor.GlyphOutline;
const RenderResult = renderer_interface.RenderResult;
const RendererMetrics = renderer_interface.RendererMetrics;
const RendererConfig = renderer_interface.RendererConfig;
const TextRenderer = renderer_interface.TextRenderer;
const EdgeBuilder = edge_builder.EdgeBuilder;
const EdgeBuildConfig = edge_builder.EdgeBuildConfig;
const ScanlineRenderer = scanline_renderer.ScanlineRenderer;
const ScanlineConfig = scanline_renderer.ScanlineConfig;

/// Anti-aliased scanline renderer using the current scanline algorithm
/// This wraps the existing scanline renderer to use the new interface
pub const AntialiasedScanlineRenderer = struct {
    config: RendererConfig,
    metrics: RendererMetrics,
    last_error: ?[]const u8,
    edge_builder: EdgeBuilder,
    scanline_renderer: ScanlineRenderer,

    pub fn init(allocator: std.mem.Allocator) AntialiasedScanlineRenderer {
        // Configure edge builder for high quality
        const edge_config = EdgeBuildConfig{
            .tessellation_config = .{
                .tolerance = 0.5,
                .max_segments = 64,
                .min_segments = 4,
                .angle_tolerance = 0.1,
                .adaptive = true,
            },
            .use_fixed_point = true,
            .min_edge_length = 0.1,
        };

        // Configure scanline renderer for anti-aliasing
        const scanline_config = ScanlineConfig{
            .antialiasing = true,
            .gamma = 2.2,
            .coverage_threshold = 0.01,
            .even_odd_rule = false,
        };

        return AntialiasedScanlineRenderer{
            .config = RendererConfig{},
            .metrics = RendererMetrics{},
            .last_error = null,
            .edge_builder = EdgeBuilder.init(allocator, edge_config),
            .scanline_renderer = ScanlineRenderer.init(allocator, scanline_config),
        };
    }

    pub fn asRenderer(self: *AntialiasedScanlineRenderer) TextRenderer {
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
        const self: *AntialiasedScanlineRenderer = @ptrCast(@alignCast(ctx));
        const start_time = std.time.microTimestamp();

        // Clear any previous error
        self.last_error = null;

        // Calculate render bounds
        const scale = font_size / 1000.0; // TTF units to pixels
        const bounds_width = @as(f32, @floatFromInt(outline.bounds.width())) * scale;
        const bounds_height = @as(f32, @floatFromInt(outline.bounds.height())) * scale;
        
        // Add padding for anti-aliasing
        const padding = 4.0; // More padding for AA
        const width = @as(u32, @intFromFloat(@ceil(bounds_width + padding * 2.0)));
        const height = @as(u32, @intFromFloat(@ceil(bounds_height + padding * 2.0)));

        // Clamp to reasonable size
        const max_size = self.config.max_glyph_size;
        const final_width = @min(width, max_size);
        const final_height = @min(height, max_size);

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

        // Create a transformed outline for rendering and convert to extractor format
        const extractor_outline = try self.convertToExtractorOutline(allocator, outline, scale, padding);
        defer self.freeExtractorOutline(allocator, extractor_outline);

        // Build edges from the transformed outline
        const edges = self.edge_builder.buildEdges(extractor_outline) catch |err| {
            self.last_error = "Failed to build edges from outline";
            return err;
        };
        defer allocator.free(edges);

        // Allocate bitmap
        const bitmap = try allocator.alloc(u8, final_width * final_height);

        // Render using scanline algorithm
        self.scanline_renderer.render(edges, bitmap, final_width, final_height) catch |err| {
            self.last_error = "Scanline rendering failed";
            allocator.free(bitmap);
            return err;
        };

        // Calculate metrics
        const end_time = std.time.microTimestamp();
        const render_time = @as(u64, @intCast(end_time - start_time));
        
        self.metrics.glyphs_rendered += 1;
        self.metrics.total_render_time_us += render_time;
        self.metrics.avg_render_time_us = self.metrics.total_render_time_us / self.metrics.glyphs_rendered;

        // Calculate quality score based on success
        var quality_score: f32 = 85.0; // High quality for successful AA rendering
        
        // Adjust score based on render time (penalty for very slow rendering)
        if (render_time > 50000) { // > 50ms
            quality_score -= 10.0;
        }

        // Check for rendering artifacts (completely black or white bitmap)
        const pixel_sum = blk: {
            var sum: u64 = 0;
            for (bitmap) |pixel| sum += pixel;
            break :blk sum;
        };
        
        if (pixel_sum == 0 or pixel_sum == bitmap.len * 255) {
            quality_score -= 20.0; // Penalty for poor output
        }

        return RenderResult{
            .bitmap = bitmap,
            .width = final_width,
            .height = final_height,
            .bearing_x = @intFromFloat(@floor(@as(f32, @floatFromInt(outline.bounds.x_min)) * scale)),
            .bearing_y = @intFromFloat(@floor(@as(f32, @floatFromInt(outline.bounds.y_max)) * scale)),
            .advance_x = outline.metrics.getAdvance() * scale,
            .render_time_us = render_time,
            .quality_score = @max(0.0, quality_score),
        };
    }

    /// Convert font_types.GlyphOutline to glyph_extractor.GlyphOutline format with transformation
    fn convertToExtractorOutline(self: *AntialiasedScanlineRenderer, allocator: std.mem.Allocator, original: GlyphOutline, scale: f32, padding: f32) !ExtractorGlyphOutline {
        _ = self;
        
        // Calculate transform parameters
        const transform_offset_x = padding - @as(f32, @floatFromInt(original.bounds.x_min)) * scale;
        const transform_offset_y = padding - @as(f32, @floatFromInt(original.bounds.y_min)) * scale;

        // Convert contours to extractor format
        var extractor_contours = try allocator.alloc(glyph_extractor.Contour, original.contours.len);
        
        for (original.contours, 0..) |contour, i| {
            // Convert points to extractor format with transformation and on_curve info
            var extractor_points = try allocator.alloc(glyph_extractor.Point, contour.points.len);

            for (contour.points, 0..) |point, j| {
                extractor_points[j] = glyph_extractor.Point{
                    .x = point.x * scale + transform_offset_x,
                    .y = point.y * scale + transform_offset_y,
                    .on_curve = contour.on_curve[j],
                };
            }

            extractor_contours[i] = glyph_extractor.Contour{
                .points = extractor_points,
                .closed = true, // TTF contours are always closed
            };
        }

        // Create transformed bounds in extractor format
        const extractor_bounds = glyph_extractor.GlyphBounds{
            .x_min = transform_offset_x,
            .y_min = transform_offset_y,
            .x_max = transform_offset_x + @as(f32, @floatFromInt(original.bounds.width())) * scale,
            .y_max = transform_offset_y + @as(f32, @floatFromInt(original.bounds.height())) * scale,
        };

        // Convert metrics
        const extractor_metrics = glyph_extractor.GlyphMetrics{
            .advance_width = original.metrics.getAdvance() * scale,
            .left_side_bearing = @as(f32, @floatFromInt(original.bounds.x_min)) * scale,
        };

        return ExtractorGlyphOutline{
            .contours = extractor_contours,
            .bounds = extractor_bounds,
            .metrics = extractor_metrics,
        };
    }

    /// Free an extractor outline
    fn freeExtractorOutline(self: *AntialiasedScanlineRenderer, allocator: std.mem.Allocator, outline: ExtractorGlyphOutline) void {
        _ = self;
        for (outline.contours) |contour| {
            allocator.free(contour.points);
        }
        allocator.free(outline.contours);
    }

    fn getName(ctx: *const anyopaque) []const u8 {
        _ = ctx;
        return "Scanline AA";
    }

    fn getMetrics(ctx: *const anyopaque) RendererMetrics {
        const self: *const AntialiasedScanlineRenderer = @ptrCast(@alignCast(ctx));
        return self.metrics;
    }

    fn configure(ctx: *anyopaque, config: RendererConfig) void {
        const self: *AntialiasedScanlineRenderer = @ptrCast(@alignCast(ctx));
        self.config = config;
        
        // Update internal configurations based on new config
        if (config.debug_mode) {
            // Enable more detailed edge building in debug mode
            self.edge_builder.config.min_edge_length = 0.01;
        }
        
        // Adjust scanline quality based on antialias level
        self.scanline_renderer.config.antialiasing = config.antialias_level > 1;
        
        if (config.antialias_level >= 4) {
            self.scanline_renderer.config.coverage_threshold = 0.005; // Higher precision
        }
    }

    fn reset(ctx: *anyopaque) void {
        const self: *AntialiasedScanlineRenderer = @ptrCast(@alignCast(ctx));
        self.metrics = RendererMetrics{};
        self.last_error = null;
    }

    fn isHealthy(ctx: *const anyopaque) bool {
        const self: *const AntialiasedScanlineRenderer = @ptrCast(@alignCast(ctx));
        return self.last_error == null;
    }

    fn getLastError(ctx: *const anyopaque) ?[]const u8 {
        const self: *const AntialiasedScanlineRenderer = @ptrCast(@alignCast(ctx));
        return self.last_error;
    }

    fn deinit(ctx: *anyopaque, allocator: std.mem.Allocator) void {
        _ = ctx;
        _ = allocator;
        // The scanline renderer and edge builder don't need explicit cleanup
    }
};

/// Create a new antialiased scanline renderer
pub fn create(allocator: std.mem.Allocator) AntialiasedScanlineRenderer {
    return AntialiasedScanlineRenderer.init(allocator);
}