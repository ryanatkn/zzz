const std = @import("std");
const types = @import("../../core/types.zig");
const font_types = @import("../font_types.zig");

const Vec2 = types.Vec2;
const Color = types.Color;

/// Result of rendering a single glyph
pub const RenderResult = struct {
    /// Bitmap data (grayscale coverage values 0-255)
    bitmap: []u8,
    /// Width of the bitmap in pixels
    width: u32,
    /// Height of the bitmap in pixels
    height: u32,
    /// Horizontal bearing (offset from baseline)
    bearing_x: i32,
    /// Vertical bearing (offset from baseline)
    bearing_y: i32,
    /// Horizontal advance to next glyph
    advance_x: f32,
    /// Time taken to render in microseconds
    render_time_us: u64,
    /// Estimated quality score (0-100)
    quality_score: f32,

    /// Free the bitmap memory
    pub fn deinit(self: RenderResult, allocator: std.mem.Allocator) void {
        allocator.free(self.bitmap);
    }
};

/// Performance and quality metrics for a renderer
pub const RendererMetrics = struct {
    /// Total glyphs rendered
    glyphs_rendered: u32 = 0,
    /// Total time spent rendering (microseconds)
    total_render_time_us: u64 = 0,
    /// Average render time per glyph
    avg_render_time_us: u64 = 0,
    /// Cache hit rate (0.0 - 1.0)
    cache_hit_rate: f32 = 0.0,
    /// Average quality score across all glyphs
    avg_quality_score: f32 = 0.0,
    /// Peak memory usage in bytes
    peak_memory_usage: usize = 0,
    /// Success rate (0.0 - 1.0)
    success_rate: f32 = 0.0,
};

/// Configuration for a rendering strategy
pub const RendererConfig = struct {
    /// Enable debug output
    debug_mode: bool = false,
    /// Anti-aliasing level (1 = none, 2 = 2x, 4 = 4x)
    antialias_level: u32 = 1,
    /// Maximum bitmap size per glyph
    max_glyph_size: u32 = 256,
    /// Enable performance profiling
    enable_profiling: bool = true,
    /// Memory budget for caching
    cache_memory_budget: usize = 1024 * 1024, // 1MB default
};

/// Strategy identifier for different rendering approaches
pub const RenderStrategy = enum {
    simple_bitmap,
    scanline_antialiased,
    oversampling_2x,
    oversampling_4x,
    sdf_generator,
    edge_table,
    gpu_path_tessellation,
    debug_ascii,

    /// Get human-readable name for the strategy
    pub fn getName(self: RenderStrategy) []const u8 {
        return switch (self) {
            .simple_bitmap => "Simple Bitmap",
            .scanline_antialiased => "Scanline AA", 
            .oversampling_2x => "Oversample 2x",
            .oversampling_4x => "Oversample 4x",
            .sdf_generator => "SDF Generator",
            .edge_table => "Edge Table",
            .gpu_path_tessellation => "GPU Path",
            .debug_ascii => "Debug ASCII",
        };
    }

    /// Get expected quality tier (1=low, 2=medium, 3=high)
    pub fn getQualityTier(self: RenderStrategy) u32 {
        return switch (self) {
            .debug_ascii => 1,
            .simple_bitmap => 1,
            .edge_table => 2,
            .scanline_antialiased => 2,
            .oversampling_2x => 2,
            .oversampling_4x => 3,
            .sdf_generator => 3,
            .gpu_path_tessellation => 3,
        };
    }

    /// Get expected performance tier (1=fastest, 2=medium, 3=slowest)
    pub fn getPerformanceTier(self: RenderStrategy) u32 {
        return switch (self) {
            .simple_bitmap => 1,
            .debug_ascii => 1,
            .gpu_path_tessellation => 1,
            .edge_table => 2,
            .scanline_antialiased => 2,
            .oversampling_2x => 2,
            .sdf_generator => 3,
            .oversampling_4x => 3,
        };
    }
};

/// Common interface for all text rendering strategies
pub const TextRenderer = struct {
    /// Virtual function table for renderer implementation
    pub const VTable = struct {
        /// Render a single glyph outline to a bitmap
        renderGlyph: *const fn(ctx: *anyopaque, allocator: std.mem.Allocator, outline: font_types.GlyphOutline, font_size: f32) anyerror!RenderResult,
        
        /// Get the name of this rendering strategy
        getName: *const fn(ctx: *const anyopaque) []const u8,
        
        /// Get current performance metrics
        getMetrics: *const fn(ctx: *const anyopaque) RendererMetrics,
        
        /// Update renderer configuration  
        configure: *const fn(ctx: *anyopaque, config: RendererConfig) void,
        
        /// Reset metrics and clear caches
        reset: *const fn(ctx: *anyopaque) void,
        
        /// Check if renderer is currently functional
        isHealthy: *const fn(ctx: *const anyopaque) bool,
        
        /// Get last error message if any
        getLastError: *const fn(ctx: *const anyopaque) ?[]const u8,
        
        /// Clean up resources
        deinit: *const fn(ctx: *anyopaque, allocator: std.mem.Allocator) void,
    };

    /// Pointer to implementation context
    ctx: *anyopaque,
    /// Virtual function table
    vtable: *const VTable,

    /// Render a glyph outline to a bitmap
    pub fn renderGlyph(self: *TextRenderer, allocator: std.mem.Allocator, outline: font_types.GlyphOutline, font_size: f32) !RenderResult {
        return self.vtable.renderGlyph(self.ctx, allocator, outline, font_size);
    }

    /// Get renderer name
    pub fn getName(self: *const TextRenderer) []const u8 {
        return self.vtable.getName(self.ctx);
    }

    /// Get performance metrics
    pub fn getMetrics(self: *const TextRenderer) RendererMetrics {
        return self.vtable.getMetrics(self.ctx);
    }

    /// Update configuration
    pub fn configure(self: *TextRenderer, config: RendererConfig) void {
        self.vtable.configure(self.ctx, config);
    }

    /// Reset state
    pub fn reset(self: *TextRenderer) void {
        self.vtable.reset(self.ctx);
    }

    /// Check if functional
    pub fn isHealthy(self: *const TextRenderer) bool {
        return self.vtable.isHealthy(self.ctx);
    }

    /// Get last error
    pub fn getLastError(self: *const TextRenderer) ?[]const u8 {
        return self.vtable.getLastError(self.ctx);
    }

    /// Clean up
    pub fn deinit(self: *TextRenderer, allocator: std.mem.Allocator) void {
        self.vtable.deinit(self.ctx, allocator);
    }
};

/// Utility to compare two render results for testing
pub fn compareRenderResults(a: RenderResult, b: RenderResult) struct { 
    pixel_diff: f32, // 0.0 = identical, 1.0 = completely different
    size_match: bool,
    bearing_diff: Vec2,
} {
    if (a.width != b.width or a.height != b.height) {
        return .{
            .pixel_diff = 1.0,
            .size_match = false,
            .bearing_diff = Vec2{ 
                .x = @as(f32, @floatFromInt(a.bearing_x - b.bearing_x)), 
                .y = @as(f32, @floatFromInt(a.bearing_y - b.bearing_y)) 
            },
        };
    }

    var total_diff: u64 = 0;
    var total_possible: u64 = 0;
    
    for (a.bitmap, b.bitmap) |pixel_a, pixel_b| {
        const diff = if (pixel_a > pixel_b) pixel_a - pixel_b else pixel_b - pixel_a;
        total_diff += diff;
        total_possible += 255;
    }

    return .{
        .pixel_diff = if (total_possible > 0) @as(f32, @floatFromInt(total_diff)) / @as(f32, @floatFromInt(total_possible)) else 0.0,
        .size_match = true,
        .bearing_diff = Vec2{ 
            .x = @as(f32, @floatFromInt(a.bearing_x - b.bearing_x)), 
            .y = @as(f32, @floatFromInt(a.bearing_y - b.bearing_y)) 
        },
    };
}