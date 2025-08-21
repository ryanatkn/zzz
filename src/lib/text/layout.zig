const std = @import("std");
const math = @import("../math/mod.zig");
const font_atlas = @import("../font/font_atlas.zig");
const rasterizer_core = @import("../font/rasterizer_core.zig");

const Vec2 = math.Vec2;

pub const TextAlign = enum {
    left,
    center,
    right,
    justify,
};

pub const TextBaseline = enum {
    top,
    middle,
    bottom,
    alphabetic,
};

pub const LayoutedGlyph = struct {
    codepoint: u32,
    position: Vec2,
    size: Vec2,
    tex_coords: struct {
        u0: f32,
        v0: f32,
        u1: f32,
        v1: f32,
    },
    atlas_index: u32,
};

pub const LayoutedLine = struct {
    glyphs: []LayoutedGlyph,
    width: f32,
    height: f32,
    baseline: f32,
};

pub const LayoutedText = struct {
    lines: []LayoutedLine,
    total_width: f32,
    total_height: f32,
};

pub const LayoutOptions = struct {
    alignment: TextAlign = .left,
    baseline: TextBaseline = .alphabetic,
    wrap_width: ?f32 = null,
    line_spacing: f32 = 1.2,
    letter_spacing: f32 = 0,
    word_spacing: f32 = 0,
};

pub const TextLayoutEngine = struct {
    allocator: std.mem.Allocator,
    atlas: *font_atlas.FontAtlas,
    rasterizer: *rasterizer_core.RasterizerCore,

    pub fn init(allocator: std.mem.Allocator, atlas: *font_atlas.FontAtlas, rasterizer: *rasterizer_core.RasterizerCore) TextLayoutEngine {
        return TextLayoutEngine{
            .allocator = allocator,
            .atlas = atlas,
            .rasterizer = rasterizer,
        };
    }

    pub fn layoutText(self: *TextLayoutEngine, text: []const u8, font_id: u32, font_size: u32, options: LayoutOptions) !LayoutedText {
        var lines = std.ArrayList(LayoutedLine).init(self.allocator);
        defer lines.deinit();

        var current_line_glyphs = std.ArrayList(LayoutedGlyph).init(self.allocator);
        defer current_line_glyphs.deinit();

        var cursor_x: f32 = 0;
        const line_height = self.rasterizer.metrics.getLineHeight();
        var cursor_y: f32 = 0; // Start at top of texture
        var max_width: f32 = 0;

        const space_glyph = try self.atlas.getOrRasterizeGlyph(self.rasterizer, ' ', font_id, font_size);
        const space_advance = space_glyph.advance + options.word_spacing;

        var i: usize = 0;
        while (i < text.len) {
            const codepoint = try getNextCodepoint(text, &i);

            if (codepoint == '\n') {
                try self.finalizeLine(&lines, &current_line_glyphs, cursor_x, cursor_y, line_height, options.alignment);
                cursor_x = 0;
                cursor_y += line_height * options.line_spacing;
                continue;
            }

            if (codepoint == ' ') {
                if (options.wrap_width) |wrap| {
                    if (cursor_x + space_advance > wrap) {
                        try self.finalizeLine(&lines, &current_line_glyphs, cursor_x, cursor_y, line_height, options.alignment);
                        cursor_x = 0;
                        cursor_y += line_height * options.line_spacing;
                        continue;
                    }
                }
                cursor_x += space_advance;
                continue;
            }

            const glyph_info = try self.atlas.getOrRasterizeGlyph(self.rasterizer, codepoint, font_id, font_size);

            if (options.wrap_width) |wrap| {
                if (cursor_x + glyph_info.advance > wrap and cursor_x > 0) {
                    try self.finalizeLine(&lines, &current_line_glyphs, cursor_x, cursor_y, line_height, options.alignment);
                    cursor_x = 0;
                    cursor_y += line_height * options.line_spacing;
                }
            }

            if (glyph_info.width > 0 and glyph_info.height > 0) {
                const atlas_texture = self.atlas.atlases.items[glyph_info.atlas_index];
                const tex_u0 = glyph_info.texture_x / @as(f32, @floatFromInt(atlas_texture.width));
                const tex_v0 = glyph_info.texture_y / @as(f32, @floatFromInt(atlas_texture.height));
                const tex_u1 = (glyph_info.texture_x + glyph_info.width) / @as(f32, @floatFromInt(atlas_texture.width));
                const tex_v1 = (glyph_info.texture_y + glyph_info.height) / @as(f32, @floatFromInt(atlas_texture.height));

                // Position glyph using standard baseline approach
                // All glyphs should have their baseline at the same Y position
                const baseline_offset = self.rasterizer.metrics.getBaselineOffset();
                const glyph_y = cursor_y + baseline_offset - glyph_info.bearing_y;

                const layouted_glyph = LayoutedGlyph{
                    .codepoint = codepoint,
                    .position = Vec2{
                        .x = cursor_x + glyph_info.bearing_x,
                        .y = glyph_y, // Baseline alignment: baseline_pos - distance_from_baseline_to_top
                    },
                    .size = Vec2{
                        .x = glyph_info.width,
                        .y = glyph_info.height,
                    },
                    .tex_coords = .{
                        .u0 = tex_u0,
                        .v0 = tex_v0,
                        .u1 = tex_u1,
                        .v1 = tex_v1,
                    },
                    .atlas_index = glyph_info.atlas_index,
                };

                try current_line_glyphs.append(layouted_glyph);
            }

            cursor_x += glyph_info.advance + options.letter_spacing;
            max_width = @max(max_width, cursor_x);
        }

        if (current_line_glyphs.items.len > 0) {
            try self.finalizeLine(&lines, &current_line_glyphs, cursor_x, cursor_y, line_height, options.alignment);
        }

        // Calculate total height for the layouted text
        const total_height = self.calculateTotalTextHeight(lines.items.len, cursor_y);

        const owned_lines = try self.allocator.alloc(LayoutedLine, lines.items.len);
        for (lines.items, 0..) |line, idx| {
            owned_lines[idx] = line;
        }

        return LayoutedText{
            .lines = owned_lines,
            .total_width = max_width,
            .total_height = total_height,
        };
    }

    fn finalizeLine(self: *TextLayoutEngine, lines: *std.ArrayList(LayoutedLine), glyphs: *std.ArrayList(LayoutedGlyph), line_width: f32, y_offset: f32, line_height: f32, alignment: TextAlign) !void {
        if (glyphs.items.len == 0) return;

        const owned_glyphs = try self.allocator.alloc(LayoutedGlyph, glyphs.items.len);
        for (glyphs.items, 0..) |glyph, i| {
            owned_glyphs[i] = glyph;
        }

        var offset_x: f32 = 0;
        switch (alignment) {
            .center => offset_x = -line_width / 2,
            .right => offset_x = -line_width,
            else => {},
        }

        if (offset_x != 0) {
            for (owned_glyphs) |*glyph| {
                glyph.position.x += offset_x;
            }
        }

        // Calculate proper baseline position (distance from top of line to baseline)
        const baseline_from_top = self.rasterizer.metrics.getBaselineOffset();
        
        try lines.append(LayoutedLine{
            .glyphs = owned_glyphs,
            .width = line_width,
            .height = line_height,
            .baseline = y_offset + baseline_from_top,
        });

        glyphs.clearRetainingCapacity();
    }

    pub fn freeLayout(self: *TextLayoutEngine, layout: LayoutedText) void {
        for (layout.lines) |line| {
            self.allocator.free(line.glyphs);
        }
        self.allocator.free(layout.lines);
    }

    /// Calculate total height needed for text layout
    /// Accounts for font metrics and safety margins
    fn calculateTotalTextHeight(self: *TextLayoutEngine, line_count: usize, cursor_y: f32) f32 {
        const font_ascender_px = @as(f32, @floatFromInt(self.rasterizer.metrics.ascender)) * self.rasterizer.metrics.scale;
        const font_descender_px = @as(f32, @floatFromInt(-self.rasterizer.metrics.descender)) * self.rasterizer.metrics.scale; // Make positive
        
        // Constants for text layout calculations
        const bitmap_padding: f32 = 2.0; // Padding in rasterized bitmaps
        const positioning_margin: f32 = 4.0; // Safety margin for positioning
        const rasterizer_padding = bitmap_padding + positioning_margin;

        // Total height calculation based on positioning scheme:
        // We position glyphs using: glyph_y = cursor_y + (font_ascender_px - bearing_y)
        return if (line_count <= 1)
            font_ascender_px + font_descender_px + rasterizer_padding // Single line: full font metrics + padding
        else
            cursor_y + font_ascender_px + font_descender_px + rasterizer_padding; // Multiple lines: cursor_y + full font metrics + padding
    }
};

fn getNextCodepoint(text: []const u8, index: *usize) !u32 {
    if (index.* >= text.len) return error.EndOfText;

    const byte = text[index.*];
    index.* += 1;

    if (byte < 0x80) {
        return byte;
    } else if (byte < 0xC0) {
        return error.InvalidUtf8;
    } else if (byte < 0xE0) {
        if (index.* >= text.len) return error.InvalidUtf8;
        const byte2 = text[index.*];
        index.* += 1;
        return (@as(u32, byte & 0x1F) << 6) | (byte2 & 0x3F);
    } else if (byte < 0xF0) {
        if (index.* + 1 >= text.len) return error.InvalidUtf8;
        const byte2 = text[index.*];
        const byte3 = text[index.* + 1];
        index.* += 2;
        return (@as(u32, byte & 0x0F) << 12) | (@as(u32, byte2 & 0x3F) << 6) | (byte3 & 0x3F);
    } else if (byte < 0xF8) {
        if (index.* + 2 >= text.len) return error.InvalidUtf8;
        const byte2 = text[index.*];
        const byte3 = text[index.* + 1];
        const byte4 = text[index.* + 2];
        index.* += 3;
        return (@as(u32, byte & 0x07) << 18) | (@as(u32, byte2 & 0x3F) << 12) | (@as(u32, byte3 & 0x3F) << 6) | (byte4 & 0x3F);
    }

    return error.InvalidUtf8;
}
