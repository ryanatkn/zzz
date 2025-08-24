const std = @import("std");
const font_metrics = @import("../core/metrics.zig");
const font_types = @import("../core/types.zig");
const bitmap_strategy = @import("../strategies/bitmap/mod.zig");

const FontMetrics = font_metrics.FontMetrics;
const GlyphOutline = font_types.GlyphOutline;
const RasterizedGlyph = bitmap_strategy.RasterizedGlyph;

pub const TestGlyph = struct {
    char: u8,
    y_min: f32,
    y_max: f32,
    bearing_y: i32,
    bearing_x: i32,
    advance: f32,
};

/// Debug utilities for font metrics analysis
pub const MetricsDebugger = struct {
    /// Log complete font metrics information
    pub fn logFontMetrics(metrics: FontMetrics) void {
        std.debug.print("\n=== Font Metrics Analysis ===\n", .{});
        std.debug.print("Units per em: {}\n", .{metrics.units_per_em});
        std.debug.print("Ascender: {} (scaled: {:.2}px)\n", .{ metrics.ascender, @as(f32, @floatFromInt(metrics.ascender)) * metrics.scale });
        std.debug.print("Descender: {} (scaled: {:.2}px)\n", .{ metrics.descender, @as(f32, @floatFromInt(metrics.descender)) * metrics.scale });
        std.debug.print("Line gap: {} (scaled: {:.2}px)\n", .{ metrics.line_gap, @as(f32, @floatFromInt(metrics.line_gap)) * metrics.scale });
        std.debug.print("Calculated line height: {:.2}px\n", .{metrics.line_height});
        std.debug.print("Baseline offset: {:.2}px\n", .{metrics.getBaselineOffset()});
        std.debug.print("Scale factor: {:.6}\n", .{metrics.scale});

        // Additional analysis
        const total_font_height = (@as(f32, @floatFromInt(metrics.ascender - metrics.descender))) * metrics.scale;
        std.debug.print("Total font height (ascender - descender): {:.2}px\n", .{total_font_height});
        std.debug.print("Line height vs font height diff: {:.2}px\n", .{metrics.line_height - total_font_height});
    }

    /// Log detailed glyph information
    pub fn logGlyphData(char: u8, outline: GlyphOutline, rasterized: RasterizedGlyph) void {
        std.debug.print("\n=== Glyph Analysis: '{}' (0x{X:0>2}) ===\n", .{ @as(u21, char), char });

        // Outline bounds in font units and pixels
        std.debug.print("Outline bounds (font units): x[{:.1}, {:.1}] y[{:.1}, {:.1}]\n", .{ outline.bounds.x_min, outline.bounds.x_max, outline.bounds.y_min, outline.bounds.y_max });
        std.debug.print("Outline dimensions: {:.1} x {:.1} font units\n", .{ outline.bounds.width(), outline.bounds.height() });

        // Rasterized data
        std.debug.print("Rasterized bitmap: {}x{} pixels\n", .{ rasterized.width, rasterized.height });
        std.debug.print("Bearings: x={}, y={}\n", .{ rasterized.bearing_x, rasterized.bearing_y });
        std.debug.print("Advance width: {:.2}px\n", .{rasterized.advance});

        // Baseline relationship analysis
        std.debug.print("Y position analysis:\n", .{});
        std.debug.print("  Distance from baseline to glyph top: {} font units ({:.2}px)\n", .{ @as(i32, @intFromFloat(outline.bounds.y_max)), outline.bounds.y_max });
        std.debug.print("  Distance from baseline to glyph bottom: {} font units ({:.2}px)\n", .{ @as(i32, @intFromFloat(outline.bounds.y_min)), outline.bounds.y_min });

        // Descender analysis
        if (outline.bounds.y_min < 0) {
            std.debug.print("  ✓ DESCENDER: extends {:.2}px below baseline\n", .{-outline.bounds.y_min});
        } else {
            std.debug.print("  ○ No descender (y_min >= 0)\n", .{});
        }
    }

    /// Analyze positioning in text layout context
    pub fn logLayoutPositioning(char: u8, glyph_y: f32, cursor_y: f32, baseline_offset: f32, bearing_y: i32, texture_height: f32) void {
        std.debug.print("\n=== Layout Positioning: '{}' ===\n", .{@as(u21, char)});
        std.debug.print("cursor_y: {:.2}px\n", .{cursor_y});
        std.debug.print("baseline_offset: {:.2}px\n", .{baseline_offset});
        std.debug.print("bearing_y: {}px\n", .{bearing_y});
        std.debug.print("Calculated glyph_y: {:.2}px\n", .{glyph_y});
        std.debug.print("Texture height: {:.2}px\n", .{texture_height});

        // Bounds checking
        if (glyph_y < 0) {
            std.debug.print("  ⚠️  WARNING: Glyph positioned above texture bounds!\n", .{});
        }
        if (glyph_y > texture_height) {
            std.debug.print("  ⚠️  WARNING: Glyph positioned below texture bounds!\n", .{});
        }

        const baseline_pos = cursor_y + baseline_offset;
        std.debug.print("Baseline position in texture: {:.2}px\n", .{baseline_pos});
    }

    /// Compare multiple glyphs for descender analysis
    pub fn analyzeDescenders(metrics: FontMetrics, glyphs: []const TestGlyph) void {
        std.debug.print("\n=== Descender Comparison Analysis ===\n", .{});

        var has_descenders = false;
        var max_descent: f32 = 0;

        for (glyphs) |glyph| {
            if (glyph.y_min < 0) {
                has_descenders = true;
                max_descent = @max(max_descent, -glyph.y_min);
                std.debug.print("'{}': descends {:.2}px below baseline (bearing_y: {})\n", .{ @as(u21, glyph.char), -glyph.y_min, glyph.bearing_y });
            } else {
                std.debug.print("'{}': sits on/above baseline (y_min: {:.2}, bearing_y: {})\n", .{ @as(u21, glyph.char), glyph.y_min, glyph.bearing_y });
            }
        }

        if (has_descenders) {
            const font_descender = @abs(@as(f32, @floatFromInt(metrics.descender)) * metrics.scale);
            std.debug.print("\nDescender summary:\n", .{});
            std.debug.print("  Maximum actual descent: {:.2}px\n", .{max_descent});
            std.debug.print("  Font descender metric: {:.2}px\n", .{font_descender});
            if (max_descent > font_descender) {
                std.debug.print("  ⚠️  Actual descent exceeds font metric!\n", .{});
            }
        } else {
            std.debug.print("No descending characters found.\n", .{});
        }
    }

    /// Create a test glyph structure from outline and rasterized data
    pub fn createTestGlyph(char: u8, outline: GlyphOutline, rasterized: RasterizedGlyph) TestGlyph {
        return TestGlyph{
            .char = char,
            .y_min = outline.bounds.y_min,
            .y_max = outline.bounds.y_max,
            .bearing_y = rasterized.bearing_y,
            .bearing_x = rasterized.bearing_x,
            .advance = rasterized.advance,
        };
    }

    /// Log texture bounds analysis
    pub fn analyzeTextureBounds(texture_height: f32, line_height: f32, ascender: f32, descender: f32) void {
        std.debug.print("\n=== Texture Bounds Analysis ===\n", .{});
        std.debug.print("Texture height: {:.2}px\n", .{texture_height});
        std.debug.print("Line height: {:.2}px\n", .{line_height});
        std.debug.print("Ascender space needed: {:.2}px\n", .{ascender});
        std.debug.print("Descender space needed: {:.2}px\n", .{@abs(descender)});
        std.debug.print("Total space needed: {:.2}px\n", .{ascender + @abs(descender)});

        if (texture_height < ascender + @abs(descender)) {
            std.debug.print("  ⚠️  WARNING: Texture too small for font metrics!\n", .{});
        }
    }
};
