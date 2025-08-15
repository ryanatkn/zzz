const std = @import("std");
const types = @import("../core/types.zig");
const math = @import("../math/mod.zig");

const Vec2 = types.Vec2;

/// Font metrics from the font's 'head' table
pub const FontMetrics = struct {
    /// Units per em (typically 1000 or 2048)
    units_per_em: u16,

    /// Ascender height (above baseline)
    ascender: i16,

    /// Descender depth (below baseline, typically negative)
    descender: i16,

    /// Line gap (additional spacing between lines)
    line_gap: i16,

    /// Calculated line height (ascender - descender + line_gap)
    line_height: f32,

    /// X-height (height of lowercase 'x')
    x_height: f32,

    /// Cap height (height of uppercase letters)
    cap_height: f32,

    /// Scale factor to convert font units to pixels
    scale: f32,

    pub fn init(units_per_em: u16, ascender: i16, descender: i16, line_gap: i16, scale: f32) FontMetrics {
        const line_height = (@as(f32, @floatFromInt(ascender - descender + line_gap))) * scale;

        return FontMetrics{
            .units_per_em = units_per_em,
            .ascender = ascender,
            .descender = descender,
            .line_gap = line_gap,
            .line_height = line_height,
            .x_height = 0.5 * scale * @as(f32, @floatFromInt(units_per_em)), // Estimate
            .cap_height = 0.7 * scale * @as(f32, @floatFromInt(units_per_em)), // Estimate
            .scale = scale,
        };
    }

    /// Get the baseline offset from the top of the line
    pub fn getBaselineOffset(self: FontMetrics) f32 {
        return @as(f32, @floatFromInt(self.ascender)) * self.scale;
    }

    /// Get the total line height in pixels
    pub fn getLineHeight(self: FontMetrics) f32 {
        return self.line_height;
    }

    /// Convert font units to pixels
    pub fn unitsToPixels(self: FontMetrics, units: i32) f32 {
        return @as(f32, @floatFromInt(units)) * self.scale;
    }
};

/// Metrics for a specific glyph
pub const GlyphMetrics = struct {
    /// Glyph width in pixels
    width: f32,

    /// Glyph height in pixels
    height: f32,

    /// Horizontal bearing (offset from origin to left edge)
    bearing_x: f32,

    /// Vertical bearing (offset from baseline to top edge)
    bearing_y: f32,

    /// Horizontal advance to next glyph
    advance_x: f32,

    /// Vertical advance (usually 0 for horizontal text)
    advance_y: f32,

    /// Bounding box of the glyph
    bounding_box: struct {
        min_x: f32,
        min_y: f32,
        max_x: f32,
        max_y: f32,
    },

    pub fn init(width: f32, height: f32, bearing_x: f32, bearing_y: f32, advance_x: f32) GlyphMetrics {
        return GlyphMetrics{
            .width = width,
            .height = height,
            .bearing_x = bearing_x,
            .bearing_y = bearing_y,
            .advance_x = advance_x,
            .advance_y = 0.0,
            .bounding_box = .{
                .min_x = bearing_x,
                .min_y = bearing_y - height,
                .max_x = bearing_x + width,
                .max_y = bearing_y,
            },
        };
    }

    /// Get the total width including bearing
    pub fn getTotalWidth(self: GlyphMetrics) f32 {
        return @max(self.advance_x, self.bearing_x + self.width);
    }

    /// Get the total height
    pub fn getTotalHeight(self: GlyphMetrics) f32 {
        return self.height;
    }

    /// Check if this glyph overlaps with another at given relative position
    pub fn overlaps(self: GlyphMetrics, other: GlyphMetrics, relative_pos: Vec2) bool {
        const other_min_x = other.bounding_box.min_x + relative_pos.x;
        const other_max_x = other.bounding_box.max_x + relative_pos.x;
        const other_min_y = other.bounding_box.min_y + relative_pos.y;
        const other_max_y = other.bounding_box.max_y + relative_pos.y;

        return !(self.bounding_box.max_x < other_min_x or
            self.bounding_box.min_x > other_max_x or
            self.bounding_box.max_y < other_min_y or
            self.bounding_box.min_y > other_max_y);
    }
};

/// Text layout metrics for a line of text
pub const LineMetrics = struct {
    /// Width of the line in pixels
    width: f32,

    /// Height of the line in pixels
    height: f32,

    /// Baseline position from the top of the line
    baseline: f32,

    /// Number of glyphs in the line
    glyph_count: u32,

    /// Number of actual characters (may differ from glyph_count due to ligatures)
    character_count: u32,

    /// Ascender height for this line
    ascender: f32,

    /// Descender depth for this line
    descender: f32,

    pub fn init(width: f32, height: f32, baseline: f32, ascender: f32, descender: f32) LineMetrics {
        return LineMetrics{
            .width = width,
            .height = height,
            .baseline = baseline,
            .glyph_count = 0,
            .character_count = 0,
            .ascender = ascender,
            .descender = descender,
        };
    }
};

/// Complete text block metrics
pub const TextMetrics = struct {
    /// Total width of the text block
    width: f32,

    /// Total height of the text block
    height: f32,

    /// Metrics for each line
    lines: std.ArrayList(LineMetrics),

    /// Baseline of the first line from the top
    first_baseline: f32,

    /// Overall bounding box
    bounding_box: struct {
        min_x: f32,
        min_y: f32,
        max_x: f32,
        max_y: f32,
    },

    pub fn init(allocator: std.mem.Allocator) TextMetrics {
        return TextMetrics{
            .width = 0,
            .height = 0,
            .lines = std.ArrayList(LineMetrics).init(allocator),
            .first_baseline = 0,
            .bounding_box = .{ .min_x = 0, .min_y = 0, .max_x = 0, .max_y = 0 },
        };
    }

    pub fn deinit(self: *TextMetrics) void {
        self.lines.deinit();
    }

    /// Add a line to the text metrics
    pub fn addLine(self: *TextMetrics, line: LineMetrics) !void {
        try self.lines.append(line);

        // Update overall metrics
        self.width = @max(self.width, line.width);

        if (self.lines.items.len == 1) {
            self.first_baseline = line.baseline;
            self.height = line.height;
            self.bounding_box.min_x = 0;
            self.bounding_box.min_y = 0;
            self.bounding_box.max_x = line.width;
            self.bounding_box.max_y = line.height;
        } else {
            self.height += line.height;
            self.bounding_box.max_x = @max(self.bounding_box.max_x, line.width);
            self.bounding_box.max_y = self.height;
        }
    }

    /// Get the number of lines
    pub fn getLineCount(self: *const TextMetrics) u32 {
        return @intCast(self.lines.items.len);
    }

    /// Get metrics for a specific line
    pub fn getLine(self: *const TextMetrics, index: u32) ?LineMetrics {
        if (index >= self.lines.items.len) return null;
        return self.lines.items[index];
    }
};

/// Kerning pair for adjusting spacing between specific glyph combinations
pub const KerningPair = struct {
    left_glyph: u32,
    right_glyph: u32,
    adjustment: f32,
};

/// Kerning table for a font
pub const KerningTable = struct {
    pairs: std.AutoHashMap(u64, f32),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .pairs = std.AutoHashMap(u64, f32).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.pairs.deinit();
    }

    /// Add a kerning pair
    pub fn addPair(self: *Self, left_glyph: u32, right_glyph: u32, adjustment: f32) !void {
        const key = (@as(u64, left_glyph) << 32) | @as(u64, right_glyph);
        try self.pairs.put(key, adjustment);
    }

    /// Get kerning adjustment for a pair of glyphs
    pub fn getKerning(self: *const Self, left_glyph: u32, right_glyph: u32) f32 {
        const key = (@as(u64, left_glyph) << 32) | @as(u64, right_glyph);
        return self.pairs.get(key) orelse 0.0;
    }

    /// Check if a kerning pair exists
    pub fn hasPair(self: *const Self, left_glyph: u32, right_glyph: u32) bool {
        const key = (@as(u64, left_glyph) << 32) | @as(u64, right_glyph);
        return self.pairs.contains(key);
    }
};

/// Text alignment options
pub const TextAlignment = enum {
    left,
    center,
    right,
    justify,
};

/// Text measurement configuration
pub const MeasurementConfig = struct {
    /// Maximum width before wrapping (0 = no wrapping)
    max_width: f32 = 0,

    /// Line spacing multiplier (1.0 = normal)
    line_spacing: f32 = 1.0,

    /// Text alignment
    alignment: TextAlignment = .left,

    /// Whether to include kerning
    use_kerning: bool = true,

    /// Whether to include ligatures
    use_ligatures: bool = false,

    /// Tab size in spaces
    tab_size: u32 = 4,
};

/// Utility functions for font metrics calculations
pub const MetricsUtils = struct {
    /// Calculate scale factor for a given point size and DPI
    pub fn calculateScale(point_size: f32, dpi: f32, units_per_em: u16) f32 {
        const pixels_per_em = (point_size * dpi) / 72.0;
        return pixels_per_em / @as(f32, @floatFromInt(units_per_em));
    }

    /// Calculate optimal line height for readability
    pub fn calculateOptimalLineHeight(font_metrics: FontMetrics, text_size: f32) f32 {
        // Use 120% of the font size as a starting point for good readability
        const base_line_height = text_size * 1.2;

        // Adjust based on the font's actual metrics
        const font_line_height = font_metrics.getLineHeight();

        // Use the larger of the two to ensure proper spacing
        return @max(base_line_height, font_line_height);
    }

    /// Measure the width of a string without creating a full layout
    pub fn measureStringWidth(
        text: []const u8,
        glyph_metrics: []const GlyphMetrics,
        kerning: ?*const KerningTable,
        config: MeasurementConfig,
    ) f32 {
        var width: f32 = 0;
        var prev_glyph_id: ?u32 = null;

        for (text, 0..) |char, i| {
            if (i >= glyph_metrics.len) break;

            const glyph_id = @as(u32, char); // Simplified mapping
            const metrics = glyph_metrics[i];

            // Add kerning if available
            if (config.use_kerning and kerning != null and prev_glyph_id != null) {
                width += kerning.?.getKerning(prev_glyph_id.?, glyph_id);
            }

            width += metrics.advance_x;
            prev_glyph_id = glyph_id;
        }

        return width;
    }

    /// Calculate character spacing for justified text
    pub fn calculateJustificationSpacing(
        line_width: f32,
        desired_width: f32,
        space_count: u32,
    ) f32 {
        if (space_count == 0) return 0;
        return (desired_width - line_width) / @as(f32, @floatFromInt(space_count));
    }

    /// Convert text coordinates to glyph index
    pub fn coordsToGlyphIndex(
        x: f32,
        y: f32,
        metrics: *const TextMetrics,
        glyph_advances: []const f32,
    ) ?struct { line: u32, glyph: u32 } {
        // Find the line
        var current_y: f32 = 0;
        for (metrics.lines.items, 0..) |line, line_index| {
            if (y >= current_y and y < current_y + line.height) {
                // Found the line, now find the glyph
                var current_x: f32 = 0;
                var glyph_start: u32 = 0;

                // Calculate starting glyph index for this line
                for (0..line_index) |prev_line_index| {
                    glyph_start += metrics.lines.items[prev_line_index].glyph_count;
                }

                for (0..line.glyph_count) |glyph_offset| {
                    const glyph_index = glyph_start + @as(u32, @intCast(glyph_offset));
                    if (glyph_index >= glyph_advances.len) break;

                    const advance = glyph_advances[glyph_index];
                    if (x >= current_x and x < current_x + advance) {
                        return .{ .line = @intCast(line_index), .glyph = @intCast(glyph_offset) };
                    }
                    current_x += advance;
                }

                // If we're past the end of the line, return the last glyph
                return .{ .line = @intCast(line_index), .glyph = line.glyph_count };
            }
            current_y += line.height;
        }

        return null;
    }

    /// Calculate text cursor position from glyph coordinates
    pub fn glyphCoordsToPosition(
        line: u32,
        glyph: u32,
        metrics: *const TextMetrics,
        glyph_advances: []const f32,
    ) Vec2 {
        var position = Vec2{ .x = 0, .y = 0 };

        // Calculate Y position
        for (0..line) |line_index| {
            if (line_index >= metrics.lines.items.len) break;
            position.y += metrics.lines.items[line_index].height;
        }

        // Calculate X position
        if (line < metrics.lines.items.len) {
            var glyph_start: u32 = 0;

            // Calculate starting glyph index for this line
            for (0..line) |prev_line_index| {
                glyph_start += metrics.lines.items[prev_line_index].glyph_count;
            }

            // Sum advances up to the specified glyph
            const end_glyph = @min(glyph, metrics.lines.items[line].glyph_count);
            for (0..end_glyph) |glyph_offset| {
                const glyph_index = glyph_start + @as(u32, @intCast(glyph_offset));
                if (glyph_index >= glyph_advances.len) break;
                position.x += glyph_advances[glyph_index];
            }
        }

        return position;
    }
};

/// Font quality metrics for choosing between different font rendering approaches
pub const QualityMetrics = struct {
    /// Recommended minimum size for bitmap rendering (below this, use SDF)
    bitmap_min_size: f32 = 8.0,

    /// Recommended maximum size for bitmap rendering (above this, use vector)
    bitmap_max_size: f32 = 48.0,

    /// Size at which subpixel rendering becomes beneficial
    subpixel_threshold: f32 = 12.0,

    /// Size at which hinting becomes important
    hinting_threshold: f32 = 16.0,

    /// Get recommended rendering approach for a given size
    pub fn getRecommendedRendering(self: QualityMetrics, size: f32) enum { bitmap, sdf, vector } {
        if (size < self.bitmap_min_size) return .sdf;
        if (size > self.bitmap_max_size) return .vector;
        return .bitmap;
    }

    /// Check if subpixel rendering is recommended
    pub fn shouldUseSubpixel(self: QualityMetrics, size: f32) bool {
        return size >= self.subpixel_threshold and size <= self.bitmap_max_size;
    }

    /// Check if hinting is recommended
    pub fn shouldUseHinting(self: QualityMetrics, size: f32) bool {
        return size >= self.hinting_threshold and size <= self.bitmap_max_size;
    }
};

test "font metrics calculation" {
    const testing = std.testing;

    const metrics = FontMetrics.init(1000, 800, -200, 100, 0.048);

    try testing.expect(metrics.units_per_em == 1000);
    try testing.expect(metrics.ascender == 800);
    try testing.expect(metrics.descender == -200);

    const baseline_offset = metrics.getBaselineOffset();
    try testing.expect(@abs(baseline_offset - 38.4) < 0.01);

    const pixel_value = metrics.unitsToPixels(500);
    try testing.expect(@abs(pixel_value - 24.0) < 0.01);
}

test "glyph metrics bounding box" {
    const testing = std.testing;

    const glyph = GlyphMetrics.init(10, 12, 1, 9, 8);

    try testing.expect(glyph.bounding_box.min_x == 1);
    try testing.expect(glyph.bounding_box.max_x == 11);
    try testing.expect(glyph.bounding_box.min_y == -3);
    try testing.expect(glyph.bounding_box.max_y == 9);
}

test "kerning table operations" {
    const testing = std.testing;

    var kerning = KerningTable.init(testing.allocator);
    defer kerning.deinit();

    try kerning.addPair(65, 86, -2.0); // A-V pair

    try testing.expect(kerning.getKerning(65, 86) == -2.0);
    try testing.expect(kerning.getKerning(86, 65) == 0.0);
    try testing.expect(kerning.hasPair(65, 86));
    try testing.expect(!kerning.hasPair(86, 65));
}
