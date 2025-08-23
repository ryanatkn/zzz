const std = @import("std");
const ttf_parser = @import("ttf_parser.zig");
const loggers = @import("../debug/loggers.zig");

const log = std.log.scoped(.glyph_extractor);

// Static empty contours slice for empty glyphs - prevents dangling pointer issues
const EMPTY_CONTOURS: []Contour = @constCast(&[_]Contour{});

/// Extracted glyph outline data
pub const GlyphOutline = struct {
    contours: []Contour,
    bounds: GlyphBounds,
    metrics: GlyphMetrics,

    pub fn deinit(self: GlyphOutline, allocator: std.mem.Allocator) void {
        for (self.contours) |contour| {
            allocator.free(contour.points);
        }
        allocator.free(self.contours);
    }
};

/// Single contour in a glyph
pub const Contour = struct {
    points: []Point,
    closed: bool = true,
};

/// Point in a glyph outline
pub const Point = struct {
    x: f32,
    y: f32,
    on_curve: bool,
};

/// Glyph bounding box
pub const GlyphBounds = struct {
    x_min: f32,
    y_min: f32,
    x_max: f32,
    y_max: f32,

    pub fn width(self: GlyphBounds) f32 {
        return self.x_max - self.x_min;
    }

    pub fn height(self: GlyphBounds) f32 {
        return self.y_max - self.y_min;
    }
};

/// Glyph metrics
pub const GlyphMetrics = struct {
    advance_width: f32,
    left_side_bearing: f32,
};

/// Extracts glyph outlines from TTF data
pub const GlyphExtractor = struct {
    allocator: std.mem.Allocator,
    parser: *ttf_parser.TTFParser,
    scale: f32,

    pub fn init(allocator: std.mem.Allocator, parser: *ttf_parser.TTFParser, scale: f32) GlyphExtractor {
        return .{
            .allocator = allocator,
            .parser = parser,
            .scale = scale,
        };
    }

    /// Extract outline for a specific codepoint
    pub fn extractGlyph(self: *GlyphExtractor, codepoint: u32) !GlyphOutline {
        const glyph_id = try self.parser.getGlyphIndex(codepoint);
        loggers.getFontLog().debug("glyph_extract", "Extracting codepoint {} ('{c}'): glyph_id={}", .{ codepoint, if (codepoint < 127) @as(u8, @intCast(codepoint)) else '?', glyph_id });
        if (glyph_id == 0 and codepoint != 0) {
            log.info("Using missing glyph outline for codepoint {}", .{codepoint});
            return self.createMissingGlyphOutline();
        }

        return self.extractGlyphById(glyph_id);
    }

    /// Extract outline for a glyph ID
    pub fn extractGlyphById(self: *GlyphExtractor, glyph_id: u16) !GlyphOutline {
        const glyph_offset = self.parser.getGlyphOffset(glyph_id) catch |err| switch (err) {
            error.EmptyGlyph => {
                loggers.getFontLog().info("empty_glyph", "Empty glyph for glyph_id={}, creating empty outline", .{glyph_id});
                return self.createEmptyGlyphOutline(glyph_id);
            },
            else => {
                log.info("Failed to get glyph offset for glyph_id={} ({}), using missing glyph", .{ glyph_id, err });
                return self.createMissingGlyphOutline();
            },
        };

        loggers.getFontLog().debug("glyph_offset", "Got glyph_offset={} for glyph_id={}", .{ glyph_offset, glyph_id });

        const glyf_offset = self.parser.glyf_offset orelse return error.NoGlyfTable;
        const glyph_data_offset = glyf_offset + glyph_offset;

        if (glyph_data_offset + 10 > self.parser.data.len) {
            return self.createMissingGlyphOutline();
        }

        const num_contours = std.mem.readInt(i16, self.parser.data[glyph_data_offset..][0..2], .big);

        if (num_contours < 0) {
            return self.extractCompositeGlyph(glyph_data_offset);
        }

        return self.extractSimpleGlyph(glyph_data_offset, num_contours, glyph_id);
    }

    /// Extract a simple (non-composite) glyph
    fn extractSimpleGlyph(self: *GlyphExtractor, glyph_offset: usize, num_contours: i16, glyph_id: u16) !GlyphOutline {
        loggers.getFontLog().debug("simple_glyph", "Extracting simple glyph_id={}, num_contours={}", .{ glyph_id, num_contours });

        // Handle empty glyphs (like space)
        if (num_contours == 0) {
            log.info("Creating empty glyph outline for glyph_id={}", .{glyph_id});
            return self.createEmptyGlyphOutline(glyph_id);
        }

        // Read bounding box
        const x_min = std.mem.readInt(i16, self.parser.data[glyph_offset + 2 ..][0..2], .big);
        const y_min = std.mem.readInt(i16, self.parser.data[glyph_offset + 4 ..][0..2], .big);
        const x_max = std.mem.readInt(i16, self.parser.data[glyph_offset + 6 ..][0..2], .big);
        const y_max = std.mem.readInt(i16, self.parser.data[glyph_offset + 8 ..][0..2], .big);

        var data_offset = glyph_offset + 10;

        // Read contour endpoints
        var contour_ends = try self.allocator.alloc(u16, @intCast(num_contours));
        defer self.allocator.free(contour_ends);

        var total_points: u16 = 0;
        for (0..@intCast(num_contours)) |i| {
            if (data_offset + 2 > self.parser.data.len) return error.InvalidGlyph;
            contour_ends[i] = std.mem.readInt(u16, self.parser.data[data_offset..][0..2], .big);
            data_offset += 2;
            total_points = contour_ends[i] + 1;
        }

        // Skip instructions
        const instruction_length = std.mem.readInt(u16, self.parser.data[data_offset..][0..2], .big);
        data_offset += 2 + instruction_length;

        // Read flags
        var flags = try self.allocator.alloc(u8, total_points);
        defer self.allocator.free(flags);

        var i: u16 = 0;
        while (i < total_points) {
            if (data_offset >= self.parser.data.len) return error.InvalidGlyph;
            const flag = self.parser.data[data_offset];
            data_offset += 1;
            flags[i] = flag;

            if (flag & 0x08 != 0) { // Repeat flag
                if (data_offset >= self.parser.data.len) return error.InvalidGlyph;
                const repeat_count = self.parser.data[data_offset];
                data_offset += 1;
                var j: u8 = 0;
                while (j < repeat_count and i + 1 < total_points) : (j += 1) {
                    i += 1;
                    flags[i] = flag;
                }
            }
            i += 1;
        }

        // Read X coordinates
        var x_coords = try self.allocator.alloc(i16, total_points);
        defer self.allocator.free(x_coords);

        var current_x: i16 = 0;
        for (0..total_points) |j| {
            const flag = flags[j];
            if (flag & 0x02 != 0) { // X_SHORT_VECTOR
                if (data_offset >= self.parser.data.len) return error.InvalidGlyph;
                const delta = self.parser.data[data_offset];
                data_offset += 1;
                if (flag & 0x10 != 0) {
                    current_x += @intCast(delta);
                } else {
                    current_x -= @intCast(delta);
                }
            } else if (flag & 0x10 == 0) { // X coordinate is not same
                if (data_offset + 2 > self.parser.data.len) return error.InvalidGlyph;
                const delta = std.mem.readInt(i16, self.parser.data[data_offset..][0..2], .big);
                data_offset += 2;
                current_x += delta;
            }
            x_coords[j] = current_x;
        }

        // Read Y coordinates
        var y_coords = try self.allocator.alloc(i16, total_points);
        defer self.allocator.free(y_coords);

        var current_y: i16 = 0;
        for (0..total_points) |j| {
            const flag = flags[j];
            if (flag & 0x04 != 0) { // Y_SHORT_VECTOR
                if (data_offset >= self.parser.data.len) return error.InvalidGlyph;
                const delta = self.parser.data[data_offset];
                data_offset += 1;
                if (flag & 0x20 != 0) {
                    current_y += @intCast(delta);
                } else {
                    current_y -= @intCast(delta);
                }
            } else if (flag & 0x20 == 0) { // Y coordinate is not same
                if (data_offset + 2 > self.parser.data.len) return error.InvalidGlyph;
                const delta = std.mem.readInt(i16, self.parser.data[data_offset..][0..2], .big);
                data_offset += 2;
                current_y += delta;
            }
            y_coords[j] = current_y;
        }

        // Build contours
        var contours = try self.allocator.alloc(Contour, @intCast(num_contours));
        for (0..@intCast(num_contours)) |contour_idx| {
            const end_index = contour_ends[contour_idx];
            const start_index = if (contour_idx == 0) 0 else contour_ends[contour_idx - 1] + 1;
            const num_points = end_index - start_index + 1;

            var points = try self.allocator.alloc(Point, num_points);
            for (0..num_points) |p| {
                const idx = start_index + p;
                points[p] = .{
                    .x = @as(f32, @floatFromInt(x_coords[idx])) * self.scale,
                    .y = @as(f32, @floatFromInt(y_coords[idx])) * self.scale,
                    .on_curve = (flags[idx] & 0x01) != 0,
                };
            }

            contours[contour_idx] = .{
                .points = points,
                .closed = true,
            };
        }

        // Get metrics
        const metrics = try self.parser.getGlyphMetrics(glyph_id);

        return GlyphOutline{
            .contours = contours,
            .bounds = .{
                .x_min = @as(f32, @floatFromInt(x_min)) * self.scale,
                .y_min = @as(f32, @floatFromInt(y_min)) * self.scale,
                .x_max = @as(f32, @floatFromInt(x_max)) * self.scale,
                .y_max = @as(f32, @floatFromInt(y_max)) * self.scale,
            },
            .metrics = .{
                .advance_width = @as(f32, @floatFromInt(metrics.advance_width)) * self.scale,
                .left_side_bearing = @as(f32, @floatFromInt(metrics.left_side_bearing)) * self.scale,
            },
        };
    }

    /// Extract a composite glyph
    fn extractCompositeGlyph(self: *GlyphExtractor, glyph_offset: usize) !GlyphOutline {
        _ = glyph_offset;
        // TODO: Implement composite glyph extraction
        return self.createMissingGlyphOutline();
    }

    /// Create outline for empty glyph (like space)
    fn createEmptyGlyphOutline(self: *GlyphExtractor, glyph_id: u16) !GlyphOutline {
        // Get metrics for the empty glyph
        const metrics = try self.parser.getGlyphMetrics(glyph_id);

        return GlyphOutline{
            .contours = EMPTY_CONTOURS, // Safe static empty slice - no dangling pointer
            .bounds = .{
                .x_min = 0,
                .y_min = 0,
                .x_max = 0,
                .y_max = 0,
            },
            .metrics = .{
                .advance_width = @as(f32, @floatFromInt(metrics.advance_width)) * self.scale,
                .left_side_bearing = @as(f32, @floatFromInt(metrics.left_side_bearing)) * self.scale,
            },
        };
    }

    /// Create outline for missing glyph (usually a box)
    fn createMissingGlyphOutline(self: *GlyphExtractor) !GlyphOutline {
        const size = 0.5 * self.scale * 1000; // Assume 1000 units per em

        var points = try self.allocator.alloc(Point, 4);
        points[0] = .{ .x = 0.1 * size, .y = 0.1 * size, .on_curve = true };
        points[1] = .{ .x = 0.9 * size, .y = 0.1 * size, .on_curve = true };
        points[2] = .{ .x = 0.9 * size, .y = 0.9 * size, .on_curve = true };
        points[3] = .{ .x = 0.1 * size, .y = 0.9 * size, .on_curve = true };

        var contours = try self.allocator.alloc(Contour, 1);
        contours[0] = .{
            .points = points,
            .closed = true,
        };

        return GlyphOutline{
            .contours = contours,
            .bounds = .{
                .x_min = 0.1 * size,
                .y_min = 0.1 * size,
                .x_max = 0.9 * size,
                .y_max = 0.9 * size,
            },
            .metrics = .{
                .advance_width = size,
                .left_side_bearing = 0.1 * size,
            },
        };
    }
};
