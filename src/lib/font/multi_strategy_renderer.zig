const std = @import("std");
const font_types = @import("font_types.zig");
const renderer_interface = @import("renderers/renderer_interface.zig");
const bitmap_simple = @import("renderers/bitmap_simple.zig");
const debug_ascii = @import("renderers/debug_ascii.zig");
const oversampling = @import("renderers/oversampling.zig");
const scanline = @import("renderers/scanline.zig");
const log_throttle = @import("../debug/log_throttle.zig");

const GlyphOutline = font_types.GlyphOutline;
const TextRenderer = renderer_interface.TextRenderer;
const RenderResult = renderer_interface.RenderResult;
const RendererMetrics = renderer_interface.RendererMetrics;
const RendererConfig = renderer_interface.RendererConfig;
const RenderStrategy = renderer_interface.RenderStrategy;

/// Result from rendering with multiple strategies
pub const MultiRenderResult = struct {
    strategy: RenderStrategy,
    result: ?RenderResult, // null if rendering failed
    error_message: ?[]const u8,
};

/// Manager for multiple rendering strategies
pub const MultiStrategyRenderer = struct {
    allocator: std.mem.Allocator,
    
    // Individual renderers
    simple_renderer: bitmap_simple.SimpleBitmapRenderer,
    debug_renderer: debug_ascii.DebugAsciiRenderer,
    oversample_2x_renderer: oversampling.OversamplingRenderer,
    oversample_4x_renderer: oversampling.OversamplingRenderer,
    scanline_renderer: ?scanline.AntialiasedScanlineRenderer, // Optional - may fail to initialize

    // Renderer interfaces
    simple_iface: TextRenderer,
    debug_iface: TextRenderer,
    oversample_2x_iface: TextRenderer,
    oversample_4x_iface: TextRenderer,
    scanline_iface: ?TextRenderer,

    /// Performance comparison data
    comparison_results: std.ArrayList(MultiRenderResult),

    pub fn init(allocator: std.mem.Allocator) !MultiStrategyRenderer {
        // Initialize all renderers
        var simple_renderer = bitmap_simple.create();
        var debug_renderer = debug_ascii.create();
        var oversample_2x_renderer = oversampling.create2x();
        var oversample_4x_renderer = oversampling.create4x();
        
        // Try to initialize scanline renderer (may fail)
        var scanline_renderer: ?scanline.AntialiasedScanlineRenderer = null;
        var scanline_iface: ?TextRenderer = null;
        
        scanline_renderer = scanline.create(allocator);
        scanline_iface = scanline_renderer.?.asRenderer();

        return MultiStrategyRenderer{
            .allocator = allocator,
            .simple_renderer = simple_renderer,
            .debug_renderer = debug_renderer,
            .oversample_2x_renderer = oversample_2x_renderer,
            .oversample_4x_renderer = oversample_4x_renderer,
            .scanline_renderer = scanline_renderer,
            .simple_iface = simple_renderer.asRenderer(),
            .debug_iface = debug_renderer.asRenderer(),
            .oversample_2x_iface = oversample_2x_renderer.asRenderer(),
            .oversample_4x_iface = oversample_4x_renderer.asRenderer(),
            .scanline_iface = scanline_iface,
            .comparison_results = std.ArrayList(MultiRenderResult).init(allocator),
        };
    }

    pub fn deinit(self: *MultiStrategyRenderer) void {
        // Clean up comparison results
        for (self.comparison_results.items) |*result| {
            if (result.result) |render_result| {
                render_result.deinit(self.allocator);
            }
        }
        self.comparison_results.deinit();

        // Clean up renderers
        self.simple_iface.deinit(self.allocator);
        self.debug_iface.deinit(self.allocator);
        self.oversample_2x_iface.deinit(self.allocator);
        self.oversample_4x_iface.deinit(self.allocator);
        
        if (self.scanline_iface) |*iface| {
            iface.deinit(self.allocator);
        }
    }

    /// Render a glyph with all available strategies
    pub fn renderWithAllStrategies(self: *MultiStrategyRenderer, outline: GlyphOutline, font_size: f32) ![]MultiRenderResult {
        // Clear previous results
        for (self.comparison_results.items) |*result| {
            if (result.result) |render_result| {
                render_result.deinit(self.allocator);
            }
        }
        self.comparison_results.clearRetainingCapacity();

        // Define strategies to test
        const strategies = [_]struct {
            strategy: RenderStrategy,
            renderer: *TextRenderer,
        }{
            .{ .strategy = .simple_bitmap, .renderer = &self.simple_iface },
            .{ .strategy = .debug_ascii, .renderer = &self.debug_iface },
            .{ .strategy = .oversampling_2x, .renderer = &self.oversample_2x_iface },
            .{ .strategy = .oversampling_4x, .renderer = &self.oversample_4x_iface },
        };

        // Test each strategy
        for (strategies) |strategy_info| {
            const multi_result = self.renderWithStrategy(strategy_info.renderer, strategy_info.strategy, outline, font_size);
            try self.comparison_results.append(multi_result);
        }

        // TODO: Re-enable scanline renderer once invalid UTF-8 output is fixed
        // Test scanline renderer if available - TEMPORARILY DISABLED due to invalid UTF-8 output
        // if (self.scanline_iface) |*scanline_iface| {
        //     const multi_result = self.renderWithStrategy(scanline_iface, .scanline_antialiased, outline, font_size);
        //     try self.comparison_results.append(multi_result);
        // } else {
        if (true) { // TODO: Remove this once scanline renderer is fixed
            // Add placeholder for failed scanline renderer
            try self.comparison_results.append(MultiRenderResult{
                .strategy = .scanline_antialiased,
                .result = null,
                .error_message = "Scanline renderer initialization failed",
            });
        }

        return self.comparison_results.items;
    }

    /// Render with a specific strategy
    fn renderWithStrategy(self: *MultiStrategyRenderer, renderer: *TextRenderer, strategy: RenderStrategy, outline: GlyphOutline, font_size: f32) MultiRenderResult {
        const result = renderer.renderGlyph(self.allocator, outline, font_size) catch |err| {
            const error_msg = switch (err) {
                error.OutOfMemory => "Out of memory",
                error.InvalidOutline => "Invalid glyph outline", 
                error.RenderingFailed => "Rendering algorithm failed",
                else => "Unknown error",
            };
            
            return MultiRenderResult{
                .strategy = strategy,
                .result = null,
                .error_message = error_msg,
            };
        };

        return MultiRenderResult{
            .strategy = strategy,
            .result = result,
            .error_message = null,
        };
    }

    /// Get summary of all renderer performance
    pub fn getPerformanceSummary(self: *const MultiStrategyRenderer) PerformanceSummary {
        var summary = PerformanceSummary{};

        // Collect metrics from all renderers
        const renderers = [_]struct {
            name: []const u8,
            renderer: *const TextRenderer,
        }{
            .{ .name = "Simple", .renderer = &self.simple_iface },
            .{ .name = "Debug", .renderer = &self.debug_iface },
            .{ .name = "Oversample2x", .renderer = &self.oversample_2x_iface },
            .{ .name = "Oversample4x", .renderer = &self.oversample_4x_iface },
        };

        for (renderers) |renderer_info| {
            const metrics = renderer_info.renderer.getMetrics();
            
            if (metrics.avg_render_time_us > 0) {
                summary.total_glyphs_rendered += metrics.glyphs_rendered;
                summary.total_render_time_us += metrics.total_render_time_us;
                
                if (metrics.avg_render_time_us < summary.fastest_render_time_us) {
                    summary.fastest_render_time_us = metrics.avg_render_time_us;
                    summary.fastest_renderer = renderer_info.name;
                }
                
                if (metrics.avg_quality_score > summary.highest_quality_score) {
                    summary.highest_quality_score = metrics.avg_quality_score;
                    summary.highest_quality_renderer = renderer_info.name;
                }
                
                summary.working_renderers += 1;
            }

            if (!renderer_info.renderer.isHealthy()) {
                summary.failed_renderers += 1;
            }
        }

        // Include scanline renderer if available
        if (self.scanline_iface) |scanline_iface| {
            const metrics = scanline_iface.getMetrics();
            
            if (metrics.avg_render_time_us > 0) {
                summary.total_glyphs_rendered += metrics.glyphs_rendered;
                summary.total_render_time_us += metrics.total_render_time_us;
                
                if (metrics.avg_render_time_us < summary.fastest_render_time_us) {
                    summary.fastest_render_time_us = metrics.avg_render_time_us;
                    summary.fastest_renderer = "Scanline";
                }
                
                if (metrics.avg_quality_score > summary.highest_quality_score) {
                    summary.highest_quality_score = metrics.avg_quality_score;
                    summary.highest_quality_renderer = "Scanline";
                }
                
                summary.working_renderers += 1;
            }

            if (!scanline_iface.isHealthy()) {
                summary.failed_renderers += 1;
            }
        } else {
            summary.failed_renderers += 1; // Count missing scanline renderer
        }

        // Calculate averages
        if (summary.working_renderers > 0) {
            summary.avg_render_time_us = summary.total_render_time_us / summary.total_glyphs_rendered;
        }

        return summary;
    }

    /// Configure all renderers with the same config
    pub fn configureAll(self: *MultiStrategyRenderer, config: RendererConfig) void {
        self.simple_iface.configure(config);
        self.debug_iface.configure(config);
        self.oversample_2x_iface.configure(config);
        self.oversample_4x_iface.configure(config);
        
        if (self.scanline_iface) |*scanline_iface| {
            scanline_iface.configure(config);
        }
    }

    /// Reset all renderer metrics
    pub fn resetAll(self: *MultiStrategyRenderer) void {
        self.simple_iface.reset();
        self.debug_iface.reset();
        self.oversample_2x_iface.reset();
        self.oversample_4x_iface.reset();
        
        if (self.scanline_iface) |*scanline_iface| {
            scanline_iface.reset();
        }
    }

    /// Get best renderer for a given quality/performance preference
    pub fn getBestRenderer(self: *const MultiStrategyRenderer, prefer_quality: bool) ?*const TextRenderer {
        if (prefer_quality) {
            // Prefer quality: oversample 4x > scanline > oversample 2x > simple
            if (self.oversample_4x_iface.isHealthy()) return &self.oversample_4x_iface;
            if (self.scanline_iface) |scanline_iface| {
                if (scanline_iface.isHealthy()) return &scanline_iface;
            }
            if (self.oversample_2x_iface.isHealthy()) return &self.oversample_2x_iface;
            if (self.simple_iface.isHealthy()) return &self.simple_iface;
        } else {
            // Prefer performance: simple > oversample 2x > scanline > oversample 4x
            if (self.simple_iface.isHealthy()) return &self.simple_iface;
            if (self.oversample_2x_iface.isHealthy()) return &self.oversample_2x_iface;
            if (self.scanline_iface) |scanline_iface| {
                if (scanline_iface.isHealthy()) return &scanline_iface;
            }
            if (self.oversample_4x_iface.isHealthy()) return &self.oversample_4x_iface;
        }
        
        // Fallback to debug renderer for visualization
        return &self.debug_iface;
    }
};

/// Summary of performance across all renderers
pub const PerformanceSummary = struct {
    total_glyphs_rendered: u32 = 0,
    total_render_time_us: u64 = 0,
    avg_render_time_us: u64 = 0,
    fastest_render_time_us: u64 = std.math.maxInt(u64),
    fastest_renderer: []const u8 = "",
    highest_quality_score: f32 = 0.0,
    highest_quality_renderer: []const u8 = "",
    working_renderers: u32 = 0,
    failed_renderers: u32 = 0,
};