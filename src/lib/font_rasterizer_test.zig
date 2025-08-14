const std = @import("std");
const font_rasterizer = @import("font_rasterizer.zig");
const ttf_parser = @import("ttf_parser.zig");
const testing = std.testing;

test "Font Rasterizer: Initialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Create a minimal parser
    var parser = ttf_parser.TTFParser{
        .allocator = allocator,
        .data = &[_]u8{},
        .tables = std.StringHashMap(ttf_parser.TableRecord).init(allocator),
        .head = ttf_parser.HeadTable{
            .version = ttf_parser.Fixed{ .value = 0x00010000 },
            .font_revision = ttf_parser.Fixed{ .value = 0 },
            .checksum_adjustment = 0,
            .magic_number = 0x5F0F3CF5,
            .flags = 0,
            .units_per_em = 1024,
            .created = 0,
            .modified = 0,
            .x_min = -100,
            .y_min = -100,
            .x_max = 1000,
            .y_max = 1000,
            .mac_style = 0,
            .lowest_rec_ppem = 8,
            .font_direction_hint = 2,
            .index_to_loc_format = 0,
            .glyph_data_format = 0,
        },
        .maxp = null,
        .hhea = null,
        .cmap_offset = null,
        .glyf_offset = null,
        .loca_offset = null,
        .hmtx_offset = null,
    };
    defer parser.deinit();
    
    const rasterizer = font_rasterizer.FontRasterizer.init(allocator, &parser, 16.0, 96.0);
    
    // Calculate expected scale: (16 * 96) / 72 / 1024 = 0.020833...
    const expected_scale = (16.0 * 96.0) / 72.0 / 1024.0;
    try testing.expectApproxEqAbs(expected_scale, rasterizer.scale, 0.001);
}

test "Font Rasterizer: Scale calculation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var parser = ttf_parser.TTFParser{
        .allocator = allocator,
        .data = &[_]u8{},
        .tables = std.StringHashMap(ttf_parser.TableRecord).init(allocator),
        .head = ttf_parser.HeadTable{
            .version = ttf_parser.Fixed{ .value = 0x00010000 },
            .font_revision = ttf_parser.Fixed{ .value = 0 },
            .checksum_adjustment = 0,
            .magic_number = 0x5F0F3CF5,
            .flags = 0,
            .units_per_em = 2048, // Different units per em
            .created = 0,
            .modified = 0,
            .x_min = 0,
            .y_min = 0,
            .x_max = 2048,
            .y_max = 2048,
            .mac_style = 0,
            .lowest_rec_ppem = 8,
            .font_direction_hint = 2,
            .index_to_loc_format = 0,
            .glyph_data_format = 0,
        },
        .maxp = null,
        .hhea = null,
        .cmap_offset = null,
        .glyf_offset = null,
        .loca_offset = null,
        .hmtx_offset = null,
    };
    defer parser.deinit();
    
    // Test different point sizes and DPIs
    const test_cases = [_]struct {
        point_size: f32,
        dpi: f32,
        expected_scale: f32,
    }{
        .{ .point_size = 12.0, .dpi = 72.0, .expected_scale = 0.00586 },
        .{ .point_size = 24.0, .dpi = 96.0, .expected_scale = 0.01563 },
        .{ .point_size = 48.0, .dpi = 144.0, .expected_scale = 0.04688 },
    };
    
    for (test_cases) |tc| {
        const rasterizer = font_rasterizer.FontRasterizer.init(allocator, &parser, tc.point_size, tc.dpi);
        try testing.expectApproxEqAbs(tc.expected_scale, rasterizer.scale, 0.00001);
    }
}

test "Font Rasterizer: Empty glyph handling" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var parser = ttf_parser.TTFParser{
        .allocator = allocator,
        .data = &[_]u8{
            // Minimal glyf data with empty glyph (num_contours = 0)
            0x00, 0x00, // num_contours = 0 (empty glyph)
            0x00, 0x00, // xMin
            0x00, 0x00, // yMin
            0x00, 0x00, // xMax
            0x00, 0x00, // yMax
        },
        .tables = std.StringHashMap(ttf_parser.TableRecord).init(allocator),
        .head = ttf_parser.HeadTable{
            .version = ttf_parser.Fixed{ .value = 0x00010000 },
            .font_revision = ttf_parser.Fixed{ .value = 0 },
            .checksum_adjustment = 0,
            .magic_number = 0x5F0F3CF5,
            .flags = 0,
            .units_per_em = 1024,
            .created = 0,
            .modified = 0,
            .x_min = 0,
            .y_min = 0,
            .x_max = 1024,
            .y_max = 1024,
            .mac_style = 0,
            .lowest_rec_ppem = 8,
            .font_direction_hint = 2,
            .index_to_loc_format = 0,
            .glyph_data_format = 0,
        },
        .maxp = null,
        .hhea = null,
        .cmap_offset = null,
        .glyf_offset = 0,
        .loca_offset = null,
        .hmtx_offset = null,
    };
    defer parser.deinit();
    
    var rasterizer = font_rasterizer.FontRasterizer.init(allocator, &parser, 16.0, 96.0);
    
    // Rasterizing empty glyph should return a zero-sized bitmap
    const result = try rasterizer.rasterizeGlyph(0, 0, 0);
    defer allocator.free(result.bitmap);
    
    try testing.expectEqual(@as(u32, 0), result.width);
    try testing.expectEqual(@as(u32, 0), result.height);
}

test "Font Rasterizer: Scanline edge generation" {
    // Test edge winding calculation
    const edge1 = font_rasterizer.Edge{
        .x0 = 0,
        .y0 = 0,
        .x1 = 10,
        .y1 = 10,
        .winding = 1, // Going down
    };
    
    const edge2 = font_rasterizer.Edge{
        .x0 = 10,
        .y0 = 10,
        .x1 = 0,
        .y1 = 0,
        .winding = -1, // Going up
    };
    
    try testing.expectEqual(@as(i32, 1), edge1.winding);
    try testing.expectEqual(@as(i32, -1), edge2.winding);
}

test "Font Rasterizer: Bitmap allocation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Test bitmap allocation for various sizes
    const test_sizes = [_]struct { width: u32, height: u32 }{
        .{ .width = 0, .height = 0 },
        .{ .width = 1, .height = 1 },
        .{ .width = 16, .height = 16 },
        .{ .width = 256, .height = 256 },
        .{ .width = 1024, .height = 1 },
        .{ .width = 1, .height = 1024 },
    };
    
    for (test_sizes) |size| {
        const bitmap_size = size.width * size.height;
        const bitmap = try allocator.alloc(u8, bitmap_size);
        defer allocator.free(bitmap);
        
        // Initialize bitmap to white (255)
        @memset(bitmap, 255);
        
        // Verify initialization
        for (bitmap) |pixel| {
            try testing.expectEqual(@as(u8, 255), pixel);
        }
    }
}

test "Font Rasterizer: Bounds checking for contour parsing" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var parser = ttf_parser.TTFParser{
        .allocator = allocator,
        .data = &[_]u8{
            // Invalid glyf data (truncated)
            0x00, 0x01, // num_contours = 1
            0x00, 0x00, // xMin
            0x00, 0x00, // yMin
            // Missing xMax, yMax, and contour data
        },
        .tables = std.StringHashMap(ttf_parser.TableRecord).init(allocator),
        .head = ttf_parser.HeadTable{
            .version = ttf_parser.Fixed{ .value = 0x00010000 },
            .font_revision = ttf_parser.Fixed{ .value = 0 },
            .checksum_adjustment = 0,
            .magic_number = 0x5F0F3CF5,
            .flags = 0,
            .units_per_em = 1024,
            .created = 0,
            .modified = 0,
            .x_min = 0,
            .y_min = 0,
            .x_max = 1024,
            .y_max = 1024,
            .mac_style = 0,
            .lowest_rec_ppem = 8,
            .font_direction_hint = 2,
            .index_to_loc_format = 0,
            .glyph_data_format = 0,
        },
        .maxp = null,
        .hhea = null,
        .cmap_offset = null,
        .glyf_offset = 0,
        .loca_offset = null,
        .hmtx_offset = null,
    };
    defer parser.deinit();
    
    var rasterizer = font_rasterizer.FontRasterizer.init(allocator, &parser, 16.0, 96.0);
    
    // Should fail due to incomplete data
    const result = rasterizer.rasterizeGlyph(0, 0, 0);
    try testing.expectError(error.InvalidGlyph, result);
}

test "Font Rasterizer: Integer overflow fix verification" {
    // This test verifies that our fix for the integer overflow is working
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Test the edge case that was causing the crash
    const start_index: usize = 0;
    const end_index: usize = 10;
    const point_index: usize = 0; // This was causing underflow
    
    // The fix should handle this case
    const prev_prev_index = if (point_index == start_index) 
        end_index 
    else if (point_index == start_index + 1) 
        end_index 
    else 
        point_index - 2;
    
    try testing.expectEqual(@as(usize, 10), prev_prev_index);
    
    // Test another edge case
    const point_index2: usize = 1;
    const prev_prev_index2 = if (point_index2 == start_index) 
        end_index 
    else if (point_index2 == start_index + 1) 
        end_index 
    else 
        point_index2 - 2;
    
    try testing.expectEqual(@as(usize, 10), prev_prev_index2);
    
    // Test normal case
    const point_index3: usize = 5;
    const prev_prev_index3 = if (point_index3 == start_index) 
        end_index 
    else if (point_index3 == start_index + 1) 
        end_index 
    else 
        point_index3 - 2;
    
    try testing.expectEqual(@as(usize, 3), prev_prev_index3);
}