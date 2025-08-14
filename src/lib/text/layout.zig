const std = @import("std");
const types = @import("../types.zig");
const font_atlas = @import("../font/font_atlas.zig");
const rasterizer_core = @import("../font/rasterizer_core.zig");

const Vec2 = types.Vec2;

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
        var cursor_y: f32 = 0;
        const line_height: f32 = @floatFromInt(font_size);
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
                const tex_u0 = @as(f32, @floatFromInt(glyph_info.texture_x)) / @as(f32, @floatFromInt(atlas_texture.width));
                const tex_v0 = @as(f32, @floatFromInt(glyph_info.texture_y)) / @as(f32, @floatFromInt(atlas_texture.height));
                const tex_u1 = @as(f32, @floatFromInt(glyph_info.texture_x + glyph_info.width)) / @as(f32, @floatFromInt(atlas_texture.width));
                const tex_v1 = @as(f32, @floatFromInt(glyph_info.texture_y + glyph_info.height)) / @as(f32, @floatFromInt(atlas_texture.height));

                const layouted_glyph = LayoutedGlyph{
                    .codepoint = codepoint,
                    .position = Vec2{
                        .x = cursor_x + @as(f32, @floatFromInt(glyph_info.bearing_x)),
                        .y = cursor_y + line_height - @as(f32, @floatFromInt(glyph_info.bearing_y)),
                    },
                    .size = Vec2{
                        .x = @floatFromInt(glyph_info.width),
                        .y = @floatFromInt(glyph_info.height),
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

        const total_height = cursor_y + line_height;

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

        try lines.append(LayoutedLine{
            .glyphs = owned_glyphs,
            .width = line_width,
            .height = line_height,
            .baseline = y_offset + line_height * 0.8,
        });

        glyphs.clearRetainingCapacity();
    }

    pub fn freeLayout(self: *TextLayoutEngine, layout: LayoutedText) void {
        for (layout.lines) |line| {
            self.allocator.free(line.glyphs);
        }
        self.allocator.free(layout.lines);
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
