const std = @import("std");
const ttf_parser = @import("ttf_parser.zig");
const glyph_extractor = @import("glyph_extractor.zig");
const font_metrics = @import("font_metrics.zig");
const bitmap_utils = @import("../image/bitmap.zig");
// Deleted modules: edge_builder, scanline_renderer, font_debug, curve_tessellation

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

        // Calculate bitmap dimensions
        const bounds = outline.bounds;
        const width = @as(u32, @intFromFloat(@ceil(bounds.width()))) + 2;
        const height = @as(u32, @intFromFloat(@ceil(bounds.height()))) + 2;

        // Handle empty glyphs (like space)
        if (width <= 2 or height <= 2 or outline.contours.len == 0) {
            return RasterizedGlyph{
                .bitmap = &[_]u8{}, // Empty slice
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

        // Simplified rasterization - using basic shape filling
        _ = subpixel_x;
        _ = subpixel_y;

        // Placeholder bitmap rendering - filled with test pattern
        @memset(bitmap, 128); // Gray test pattern

        // Debug mode placeholder
        if (self.debug_mode) {
            log.debug("Rasterizing glyph {d}x{d}", .{ width, height });
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
