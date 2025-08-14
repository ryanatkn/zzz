const std = @import("std");
const ttf_parser = @import("ttf_parser.zig");
const glyph_extractor = @import("glyph_extractor.zig");
const edge_builder = @import("edge_builder.zig");
const scanline_renderer = @import("scanline_renderer.zig");
const font_debug = @import("font_debug.zig");
const font_metrics = @import("font_metrics.zig");
const curve_tessellation = @import("curve_tessellation.zig");

const log = std.log.scoped(.rasterizer_core);

/// Result of rasterizing a glyph
pub const RasterizedGlyph = struct {
    bitmap: []u8,
    width: u32,
    height: u32,
    bearing_x: i32,
    bearing_y: i32,
    advance: f32,
};

/// Core font rasterizer - coordinates between modules
pub const RasterizerCore = struct {
    allocator: std.mem.Allocator,
    parser: *ttf_parser.TTFParser,
    scale: f32,
    
    // Sub-components
    extractor: glyph_extractor.GlyphExtractor,
    edge_builder: edge_builder.EdgeBuilder,
    scanline: scanline_renderer.ScanlineRenderer,
    
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
        
        // Configure edge building based on scale
        const edge_config = edge_builder.EdgeBuildConfig{
            .offset_x = 1.0,  // Small offset for padding
            .offset_y = 1.0,
            .tessellation_config = curve_tessellation.recommendConfigForScale(scale),
            .min_edge_length = 0.001,
            .use_fixed_point = true,
        };
        
        // Configure scanline rendering
        const scanline_config = scanline_renderer.ScanlineConfig{
            .antialiasing = true,
            .gamma = 2.2,
            .coverage_threshold = 0.01,
            .even_odd_rule = false,  // Use non-zero winding
        };
        
        return RasterizerCore{
            .allocator = allocator,
            .parser = parser,
            .scale = scale,
            .extractor = glyph_extractor.GlyphExtractor.init(allocator, parser, scale),
            .edge_builder = edge_builder.EdgeBuilder.init(allocator, edge_config),
            .scanline = scanline_renderer.ScanlineRenderer.init(allocator, scanline_config),
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
            font_debug.printOutline(outline);
        }
        
        // Calculate bitmap dimensions
        const bounds = outline.bounds;
        const width = @as(u32, @intFromFloat(@ceil(bounds.width()))) + 2;
        const height = @as(u32, @intFromFloat(@ceil(bounds.height()))) + 2;
        
        // Handle empty glyphs (like space)
        if (width <= 2 or height <= 2 or outline.contours.len == 0) {
            return RasterizedGlyph{
                .bitmap = &[_]u8{},  // Empty slice
                .width = 0,
                .height = 0,
                .bearing_x = 0,
                .bearing_y = 0,
                .advance = outline.metrics.advance_width,
            };
        }
        
        // Allocate bitmap
        const bitmap = try self.allocator.alloc(u8, width * height);
        errdefer self.allocator.free(bitmap);
        @memset(bitmap, 0);
        
        // Update edge builder offset for subpixel positioning
        self.edge_builder.config.offset_x = -bounds.x_min + 1.0 + subpixel_x;
        self.edge_builder.config.offset_y = -bounds.y_min + 1.0 + subpixel_y;
        
        // Build edges from outline
        const edges = try self.edge_builder.buildEdges(outline);
        defer self.allocator.free(edges);
        
        // Debug: print edges
        if (self.debug_mode) {
            font_debug.printEdges(edges, 10);
        }
        
        // Render edges to bitmap
        try self.scanline.render(edges, bitmap, width, height);
        
        // Debug: print coverage map and stats
        if (self.debug_mode) {
            font_debug.printCoverageMap(bitmap, width, height, codepoint);
            font_debug.printBitmapStats(bitmap, width, height, codepoint);
        }
        
        return RasterizedGlyph{
            .bitmap = bitmap,
            .width = width,
            .height = height,
            .bearing_x = @intFromFloat(@round(bounds.x_min - 1.0)),
            .bearing_y = @intFromFloat(@round(bounds.y_max + 1.0)),
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
    
    /// Update rendering quality
    pub fn setQuality(self: *RasterizerCore, quality: enum { fast, medium, high, ultra }) void {
        self.edge_builder.config.tessellation_config = switch (quality) {
            .fast => curve_tessellation.QualityPresets.fast,
            .medium => curve_tessellation.QualityPresets.medium,
            .high => curve_tessellation.QualityPresets.high,
            .ultra => curve_tessellation.QualityPresets.ultra,
        };
    }
    
    /// Set anti-aliasing mode
    pub fn setAntialiasing(self: *RasterizerCore, enabled: bool) void {
        self.scanline.config.antialiasing = enabled;
    }
    
    /// Set gamma correction
    pub fn setGamma(self: *RasterizerCore, gamma: f32) void {
        self.scanline.config.gamma = gamma;
    }
};