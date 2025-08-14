const std = @import("std");
const ttf_parser = @import("ttf_parser.zig");
const vector_path = @import("vector_path.zig");
const curve_tessellation = @import("curve_tessellation.zig");
const font_metrics = @import("font_metrics.zig");
const types = @import("types.zig");

const log = std.log.scoped(.font_rasterizer);
const Vec2 = types.Vec2;

pub const RasterizedGlyph = struct {
    bitmap: []u8,
    width: u32,
    height: u32,
    bearing_x: i32,
    bearing_y: i32,
    advance: f32,
};

// Re-export edge types from curve_tessellation for compatibility
pub const Edge = curve_tessellation.Edge;

pub const ActiveEdge = struct {
    x: f32,
    dx: f32,
    y_max: f32,
    winding: i32,
};

// Helper functions for cleaner type conversions
fn floorToU32(value: f32) u32 {
    return @as(u32, @intFromFloat(@floor(value)));
}

fn roundToI32(value: f32) i32 {
    return @as(i32, @intFromFloat(@round(value)));
}

pub const FontRasterizer = struct {
    allocator: std.mem.Allocator,
    parser: *ttf_parser.TTFParser,
    scale: f32,
    
    tessellation_config: curve_tessellation.TessellationConfig,
    font_metrics: font_metrics.FontMetrics,
    
    pub fn init(allocator: std.mem.Allocator, parser: *ttf_parser.TTFParser, point_size: f32, dpi: f32) FontRasterizer {
        // Calculate scale with fallback defaults
        const units_per_em = if (parser.head) |head| head.units_per_em else 1000;
        const pixels_per_em = (point_size * dpi) / 72.0;
        const scale = pixels_per_em / @as(f32, @floatFromInt(units_per_em));
        
        // Get metrics with fallbacks
        const ascender = if (parser.hhea) |hhea| hhea.ascender else @as(i16, @intFromFloat(@as(f32, @floatFromInt(units_per_em)) * 0.8));
        const descender = if (parser.hhea) |hhea| hhea.descender else @as(i16, @intFromFloat(@as(f32, @floatFromInt(units_per_em)) * -0.2));
        const line_gap = if (parser.hhea) |hhea| hhea.line_gap else 100;
        
        return FontRasterizer{
            .allocator = allocator,
            .parser = parser,
            .scale = scale,
            .tessellation_config = curve_tessellation.recommendConfigForScale(scale),
            .font_metrics = font_metrics.FontMetrics.init(units_per_em, ascender, descender, line_gap, scale),
        };
    }
    
    /// Get font metrics for this rasterizer
    pub fn getFontMetrics(self: *const FontRasterizer) font_metrics.FontMetrics {
        return self.font_metrics;
    }
    
    /// Update tessellation quality based on scale
    pub fn updateTessellationQuality(self: *FontRasterizer, quality: enum { fast, medium, high, ultra }) void {
        self.tessellation_config = switch (quality) {
            .fast => curve_tessellation.QualityPresets.fast,
            .medium => curve_tessellation.QualityPresets.medium,
            .high => curve_tessellation.QualityPresets.high,
            .ultra => curve_tessellation.QualityPresets.ultra,
        };
    }
    
    /// Enhanced scanline rendering with better anti-aliasing
    fn scanlineRenderOptimized(self: *FontRasterizer, edges: []Edge, bitmap: []u8, width: u32, height: u32) void {
        // Pre-allocate active edges array once, reuse for all scanlines
        var active_edges = std.ArrayList(ActiveEdge).init(self.allocator);
        defer active_edges.deinit();
        
        var y: u32 = 0;
        while (y < height) : (y += 1) {
            // Clear the array for reuse instead of creating new
            active_edges.clearRetainingCapacity();
            
            const y_float = @as(f32, @floatFromInt(y)) + 0.5;
            
            for (edges) |edge| {
                const min_y = @min(edge.y0, edge.y1);
                const max_y = @max(edge.y0, edge.y1);
                
                if (y_float >= min_y and y_float < max_y) {
                    const dx = (edge.x1 - edge.x0) / (edge.y1 - edge.y0);
                    const x = edge.x0 + (y_float - edge.y0) * dx;
                    
                    active_edges.append(ActiveEdge{
                        .x = x,
                        .dx = dx,
                        .y_max = max_y,
                        .winding = edge.winding,
                    }) catch continue;
                }
            }
            
            // Sort active edges by x coordinate
            std.sort.heap(ActiveEdge, active_edges.items, {}, compareActiveEdges);
            
            // Fill spans between edge pairs
            var winding: i32 = 0;
            var x_start: ?f32 = null;
            
            for (active_edges.items) |active_edge| {
                if (winding == 0 and active_edge.winding != 0) {
                    x_start = active_edge.x;
                }
                
                winding += active_edge.winding;
                
                if (winding == 0 and x_start != null) {
                    // Fill span from x_start to current x with sub-pixel precision
                    const x_left = @max(0, @min(@as(f32, @floatFromInt(width - 1)), x_start.?));
                    const x_right = @max(0, @min(@as(f32, @floatFromInt(width - 1)), active_edge.x));
                    
                    const start_pixel = floorToU32(x_left);
                    const end_pixel = floorToU32(x_right);
                    
                    if (start_pixel == end_pixel) {
                        // Single pixel span - use coverage based on span width
                        const coverage = @min(1.0, x_right - x_left);
                        const pixel_index = y * width + start_pixel;
                        if (pixel_index < bitmap.len) {
                            const current_coverage = @as(f32, @floatFromInt(bitmap[pixel_index])) / 255.0;
                            const new_coverage = @min(1.0, current_coverage + coverage);
                            bitmap[pixel_index] = @as(u8, @intFromFloat(new_coverage * 255.0));
                        }
                    } else {
                        // Multi-pixel span with sub-pixel coverage at edges
                        var fill_x = start_pixel;
                        while (fill_x <= end_pixel and fill_x < width) : (fill_x += 1) {
                            var coverage: f32 = 1.0;
                            
                            if (fill_x == start_pixel) {
                                // Left edge - partial coverage
                                coverage = 1.0 - (x_left - @floor(x_left));
                            } else if (fill_x == end_pixel) {
                                // Right edge - partial coverage  
                                coverage = x_right - @floor(x_right);
                            }
                            // Middle pixels get full coverage (1.0)
                            
                            const pixel_index = y * width + fill_x;
                            if (pixel_index < bitmap.len) {
                                const current_coverage = @as(f32, @floatFromInt(bitmap[pixel_index])) / 255.0;
                                const new_coverage = @min(1.0, current_coverage + coverage);
                                bitmap[pixel_index] = @as(u8, @intFromFloat(new_coverage * 255.0));
                            }
                        }
                    }
                    x_start = null;
                }
            }
        }
    }
    
    fn compareActiveEdges(_: void, a: ActiveEdge, b: ActiveEdge) bool {
        return a.x < b.x;
    }
    
    pub fn rasterizeGlyph(self: *FontRasterizer, codepoint: u32, subpixel_x: f32, subpixel_y: f32) !RasterizedGlyph {
        const glyph_id = try self.parser.getGlyphIndex(codepoint);
        if (glyph_id == 0 and codepoint != 0) {
            return self.rasterizeMissingGlyph();
        }
        
        const glyph_offset = self.parser.getGlyphOffset(glyph_id) catch {
            return self.rasterizeMissingGlyph();
        };
        
        const glyf_offset = self.parser.glyf_offset orelse return error.NoGlyfTable;
        const glyph_data_offset = glyf_offset + glyph_offset;
        
        if (glyph_data_offset + 10 > self.parser.data.len) {
            return self.rasterizeMissingGlyph();
        }
        
        const num_contours = std.mem.readInt(i16, self.parser.data[glyph_data_offset..][0..2], .big);
        
        if (num_contours < 0) {
            return self.rasterizeCompositeGlyph(glyph_data_offset);
        }
        
        const x_min = std.mem.readInt(i16, self.parser.data[glyph_data_offset + 2..][0..2], .big);
        const y_min = std.mem.readInt(i16, self.parser.data[glyph_data_offset + 4..][0..2], .big);
        const x_max = std.mem.readInt(i16, self.parser.data[glyph_data_offset + 6..][0..2], .big);
        const y_max = std.mem.readInt(i16, self.parser.data[glyph_data_offset + 8..][0..2], .big);
        
        const metrics = try self.parser.getGlyphMetrics(glyph_id);
        
        const scaled_x_min = @as(f32, @floatFromInt(x_min)) * self.scale + subpixel_x;
        const scaled_y_min = @as(f32, @floatFromInt(y_min)) * self.scale + subpixel_y;
        const scaled_x_max = @as(f32, @floatFromInt(x_max)) * self.scale + subpixel_x;
        const scaled_y_max = @as(f32, @floatFromInt(y_max)) * self.scale + subpixel_y;
        
        // Use better precision for bitmap dimensions to avoid truncation  
        const width = floorToU32(@ceil(scaled_x_max - scaled_x_min)) + 2;
        const height = floorToU32(@ceil(scaled_y_max - scaled_y_min)) + 2;
        
        if (width <= 2 or height <= 2) {
            // Don't allocate for empty glyphs - use a static empty slice
            return RasterizedGlyph{
                .bitmap = &[_]u8{}, // Empty slice, no allocation
                .width = 0,
                .height = 0,
                .bearing_x = 0,
                .bearing_y = 0,
                .advance = @as(f32, @floatFromInt(metrics.advance_width)) * self.scale,
            };
        }
        
        const bitmap = try self.allocator.alloc(u8, width * height);
        @memset(bitmap, 0);
        
        if (num_contours > 0) {
            try self.rasterizeSimpleGlyph(glyph_data_offset, num_contours, bitmap, width, height, -scaled_x_min + 1, -scaled_y_min + 1);
        }
        
        // Debug output for specific glyphs
        if (codepoint == 'A' or codepoint == '0' or codepoint == 'F') {
            var non_zero: u32 = 0;
            var total_value: u32 = 0;
            for (bitmap) |pixel| {
                if (pixel != 0) non_zero += 1;
                total_value += pixel;
            }
            
            // Check if we're filling entire rows
            var filled_rows: u32 = 0;
            var y_check: u32 = 0;
            while (y_check < height) : (y_check += 1) {
                var row_filled = true;
                var x_check: u32 = 0;
                while (x_check < width) : (x_check += 1) {
                    if (bitmap[y_check * width + x_check] == 0) {
                        row_filled = false;
                        break;
                    }
                }
                if (row_filled) filled_rows += 1;
            }
            
            log.warn("Glyph '{}': {}/{} pixels filled, {} fully filled rows out of {} rows", 
                     .{@as(u8, @intCast(codepoint)), non_zero, bitmap.len, filled_rows, height});
            
            // Show a sample row from the middle
            if (height > 2) {
                const mid_y = height / 2;
                const row_start = mid_y * width;
                const row_end = @min(row_start + width, bitmap.len);
                log.warn("  Middle row (y={}): {any}", .{mid_y, bitmap[row_start..@min(row_start + 10, row_end)]});
            }
        }
        
        return RasterizedGlyph{
            .bitmap = bitmap,
            .width = width,
            .height = height,
            .bearing_x = roundToI32(scaled_x_min - 1),
            .bearing_y = roundToI32(scaled_y_max + 1),
            .advance = @as(f32, @floatFromInt(metrics.advance_width)) * self.scale,
        };
    }
    
    fn rasterizeSimpleGlyph(
        self: *FontRasterizer,
        glyph_offset: usize,
        num_contours: i16,
        bitmap: []u8,
        width: u32,
        height: u32,
        offset_x: f32,
        offset_y: f32
    ) !void {
        var data_offset = glyph_offset + 10;
        
        var contour_ends = try self.allocator.alloc(u16, @intCast(num_contours));
        defer self.allocator.free(contour_ends);
        
        var total_points: u16 = 0;
        for (0..@intCast(num_contours)) |i| {
            if (data_offset + 2 > self.parser.data.len) return error.InvalidGlyph;
            contour_ends[i] = std.mem.readInt(u16, self.parser.data[data_offset..][0..2], .big);
            data_offset += 2;
            total_points = contour_ends[i] + 1;
        }
        
        const instruction_length = std.mem.readInt(u16, self.parser.data[data_offset..][0..2], .big);
        data_offset += 2 + instruction_length;
        
        var flags = try self.allocator.alloc(u8, total_points);
        defer self.allocator.free(flags);
        
        var i: u16 = 0;
        while (i < total_points) {
            if (data_offset >= self.parser.data.len) return error.InvalidGlyph;
            
            const flag = self.parser.data[data_offset];
            data_offset += 1;
            flags[i] = flag;
            
            if (flag & 0x08 != 0) {
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
        
        var x_coords = try self.allocator.alloc(f32, total_points);
        defer self.allocator.free(x_coords);
        var y_coords = try self.allocator.alloc(f32, total_points);
        defer self.allocator.free(y_coords);
        
        var current_x: i32 = 0;
        for (0..total_points) |j| {
            const flag = flags[j];
            var delta_x: i32 = 0;
            
            if (flag & 0x02 != 0) {
                if (data_offset >= self.parser.data.len) return error.InvalidGlyph;
                delta_x = self.parser.data[data_offset];
                data_offset += 1;
                if (flag & 0x10 == 0) {
                    delta_x = -delta_x;
                }
            } else if (flag & 0x10 == 0) {
                if (data_offset + 2 > self.parser.data.len) return error.InvalidGlyph;
                delta_x = std.mem.readInt(i16, self.parser.data[data_offset..][0..2], .big);
                data_offset += 2;
            }
            
            current_x += delta_x;
            x_coords[j] = @as(f32, @floatFromInt(current_x)) * self.scale + offset_x;
        }
        
        var current_y: i32 = 0;
        for (0..total_points) |j| {
            const flag = flags[j];
            var delta_y: i32 = 0;
            
            if (flag & 0x04 != 0) {
                if (data_offset >= self.parser.data.len) return error.InvalidGlyph;
                delta_y = self.parser.data[data_offset];
                data_offset += 1;
                if (flag & 0x20 == 0) {
                    delta_y = -delta_y;
                }
            } else if (flag & 0x20 == 0) {
                if (data_offset + 2 > self.parser.data.len) return error.InvalidGlyph;
                delta_y = std.mem.readInt(i16, self.parser.data[data_offset..][0..2], .big);
                data_offset += 2;
            }
            
            current_y += delta_y;
            y_coords[j] = @as(f32, @floatFromInt(height)) - (@as(f32, @floatFromInt(current_y)) * self.scale + offset_y);
        }
        
        var edges = std.ArrayList(Edge).init(self.allocator);
        defer edges.deinit();
        
        var point_index: u16 = 0;
        for (0..@intCast(num_contours)) |contour| {
            const start_index = if (contour == 0) 0 else contour_ends[contour - 1] + 1;
            const end_index = contour_ends[contour];
            
            var prev_on_curve = (flags[end_index] & 0x01) != 0;
            var prev_x = x_coords[end_index];
            var prev_y = y_coords[end_index];
            
            point_index = start_index;
            while (point_index <= end_index) : (point_index += 1) {
                const on_curve = (flags[point_index] & 0x01) != 0;
                const x = x_coords[point_index];
                const y = y_coords[point_index];
                
                if (prev_on_curve and on_curve) {
                    // Skip horizontal edges (they don't affect scanline fill)
                    if (@abs(prev_y - y) > 0.001) {
                        try edges.append(Edge{
                            .x0 = prev_x,
                            .y0 = prev_y,
                            .x1 = x,
                            .y1 = y,
                            .winding = if (prev_y < y) 1 else -1,
                        });
                    }
                } else if (prev_on_curve and !on_curve) {
                } else if (!prev_on_curve and on_curve) {
                    const control_x = prev_x;
                    const control_y = prev_y;
                    
                    // Adaptive tessellation based on curve length
                    const dx = @abs(control_x - x) + @abs(control_x - prev_x);
                    const dy = @abs(control_y - y) + @abs(control_y - prev_y);
                    const curve_length = @sqrt(dx * dx + dy * dy);
                    const steps = @max(3, @min(20, @as(u32, @intFromFloat(curve_length * 0.5))));
                    
                    var t: f32 = 0;
                    var last_qx = x_coords[if (point_index == start_index) end_index else point_index - 1];
                    var last_qy = y_coords[if (point_index == start_index) end_index else point_index - 1];
                    
                    while (t <= 1.0) : (t += 1.0 / @as(f32, @floatFromInt(steps))) {
                        const one_minus_t = 1.0 - t;
                        const qx = one_minus_t * one_minus_t * last_qx + 2.0 * one_minus_t * t * control_x + t * t * x;
                        const qy = one_minus_t * one_minus_t * last_qy + 2.0 * one_minus_t * t * control_y + t * t * y;
                        
                        if (t > 0 and @abs(last_qy - qy) > 0.001) {
                            try edges.append(Edge{
                                .x0 = last_qx,
                                .y0 = last_qy,
                                .x1 = qx,
                                .y1 = qy,
                                .winding = if (last_qy < qy) 1 else -1,
                            });
                        }
                        last_qx = qx;
                        last_qy = qy;
                    }
                } else {
                    const mid_x = (prev_x + x) * 0.5;
                    const mid_y = (prev_y + y) * 0.5;
                    
                    const control_x = prev_x;
                    const control_y = prev_y;
                    
                    // Adaptive tessellation based on curve length
                    const dx = @abs(control_x - mid_x) + @abs(control_x - prev_x);
                    const dy = @abs(control_y - mid_y) + @abs(control_y - prev_y);
                    const curve_length = @sqrt(dx * dx + dy * dy);
                    const steps = @max(3, @min(15, @as(u32, @intFromFloat(curve_length * 0.5))));
                    
                    var t: f32 = 0;
                    // Handle wraparound: if we're at start_index or start_index+1, we need to look at the end
                    const prev_prev_index = if (point_index == start_index) 
                        end_index 
                    else if (point_index == start_index + 1) 
                        end_index 
                    else 
                        point_index - 2;
                    var last_qx = x_coords[prev_prev_index];
                    var last_qy = y_coords[prev_prev_index];
                    
                    while (t <= 1.0) : (t += 1.0 / @as(f32, @floatFromInt(steps))) {
                        const one_minus_t = 1.0 - t;
                        const qx = one_minus_t * one_minus_t * last_qx + 2.0 * one_minus_t * t * control_x + t * t * mid_x;
                        const qy = one_minus_t * one_minus_t * last_qy + 2.0 * one_minus_t * t * control_y + t * t * mid_y;
                        
                        if (t > 0 and @abs(last_qy - qy) > 0.001) {
                            try edges.append(Edge{
                                .x0 = last_qx,
                                .y0 = last_qy,
                                .x1 = qx,
                                .y1 = qy,
                                .winding = if (last_qy < qy) 1 else -1,
                            });
                        }
                        last_qx = qx;
                        last_qy = qy;
                    }
                    
                    prev_x = mid_x;
                    prev_y = mid_y;
                    prev_on_curve = true;
                    continue;
                }
                
                prev_x = x;
                prev_y = y;
                prev_on_curve = on_curve;
            }
        }
        
        self.scanlineRender(edges.items, bitmap, width, height);
    }
    
    fn scanlineRender(self: *FontRasterizer, edges: []Edge, bitmap: []u8, width: u32, height: u32) void {
        // Pre-allocate active edges array once, reuse for all scanlines
        var active_edges = std.ArrayList(ActiveEdge).init(self.allocator);
        defer active_edges.deinit();
        
        // Debug: count edges
        if (width * height < 2000) { // Only for small glyphs
            log.warn("Scanline render: {} edges for {}x{} bitmap", .{edges.len, width, height});
        }
        
        var y: u32 = 0;
        while (y < height) : (y += 1) {
            // Clear the array for reuse instead of creating new
            active_edges.clearRetainingCapacity();
            
            const y_float = @as(f32, @floatFromInt(y)) + 0.5;
            
            for (edges) |edge| {
                const min_y = @min(edge.y0, edge.y1);
                const max_y = @max(edge.y0, edge.y1);
                
                if (y_float >= min_y and y_float < max_y) {
                    const dx = (edge.x1 - edge.x0) / (edge.y1 - edge.y0);
                    const x = edge.x0 + (y_float - edge.y0) * dx;
                    
                    active_edges.append(ActiveEdge{
                        .x = x,
                        .dx = dx,
                        .y_max = max_y,
                        .winding = edge.winding,
                    }) catch continue;
                }
            }
            
            const lessThan = struct {
                fn lessThan(_: void, a: ActiveEdge, b: ActiveEdge) bool {
                    return a.x < b.x;
                }
            }.lessThan;
            std.sort.insertion(ActiveEdge, active_edges.items, {}, lessThan);
            
            var winding_number: i32 = 0;
            var x: u32 = 0;
            var edge_index: usize = 0;
            
            // Debug for small glyphs - check middle scanline
            if (width * height < 500 and y == height / 2) {
                log.warn("  Scanline {}/{}: {} active edges", .{y, height, active_edges.items.len});
                for (active_edges.items, 0..) |edge, i| {
                    log.warn("    Edge {}: x={d:.1}, winding={}", .{i, edge.x, edge.winding});
                }
            }
            
            while (x < width) : (x += 1) {
                const x_float = @as(f32, @floatFromInt(x)) + 0.5;
                
                // Process all edges at or before this x position
                while (edge_index < active_edges.items.len and active_edges.items[edge_index].x <= x_float) {
                    winding_number += active_edges.items[edge_index].winding;
                    edge_index += 1;
                }
                
                // Fill pixel if winding number is non-zero (inside shape)
                if (winding_number != 0) {
                    bitmap[y * width + x] = 255;
                }
            }
        }
    }
    
    fn rasterizeMissingGlyph(self: *FontRasterizer) !RasterizedGlyph {
        const size = @as(u32, @intFromFloat(self.scale * 1000));
        const width = size;
        const height = size;
        
        var bitmap = try self.allocator.alloc(u8, width * height);
        @memset(bitmap, 0);
        
        const border = @max(1, size / 10);
        var y: u32 = border;
        while (y < height - border) : (y += 1) {
            var x: u32 = border;
            while (x < width - border) : (x += 1) {
                if (y == border or y == height - border - 1 or x == border or x == width - border - 1) {
                    bitmap[y * width + x] = 255;
                }
            }
        }
        
        return RasterizedGlyph{
            .bitmap = bitmap,
            .width = width,
            .height = height,
            .bearing_x = 0,
            .bearing_y = @intCast(height),
            .advance = @as(f32, @floatFromInt(width)),
        };
    }
    
    fn rasterizeCompositeGlyph(self: *FontRasterizer, glyph_offset: usize) !RasterizedGlyph {
        _ = glyph_offset;
        return self.rasterizeMissingGlyph();
    }
};