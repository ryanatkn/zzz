const std = @import("std");
const testing = std.testing;

const rasterizer_core = @import("../src/lib/rasterizer_core.zig");
const ttf_parser = @import("../src/lib/ttf_parser.zig");
const bitmap_utils = @import("../src/lib/image/bitmap.zig");
const font_debug = @import("../src/lib/font_debug.zig");
const font_types = @import("../src/lib/font_types.zig");

test "font rasterizer integration test" {
    // Test basic functionality with a simple mock
    // This tests the module integration without needing actual font files
    
    const mock_ttf_data = [_]u8{0x00, 0x01, 0x00, 0x00} ** 64; // Mock TTF data
    
    const result = ttf_parser.TTFParser.init(&mock_ttf_data);
    if (result) |_| {
        // Parser accepted mock data (unlikely)
        return;
    } else |err| {
        // Expected error with mock data
        try testing.expect(err == error.InvalidTTFHeader or 
                          err == error.InvalidTTFData or
                          err == error.OutOfMemory);
    }
}

test "quality metrics analysis" {
    const allocator = testing.allocator;
    
    // Create a simple test bitmap
    const width = 32;
    const height = 32;
    var bitmap = try allocator.alloc(u8, width * height);
    defer allocator.free(bitmap);
    
    // Fill with a simple pattern
    for (0..height) |y| {
        for (0..width) |x| {
            const idx = y * width + x;
            if (x > 8 and x < 24 and y > 8 and y < 24) {
                bitmap[idx] = 255; // White center
            } else if (x > 6 and x < 26 and y > 6 and y < 26) {
                bitmap[idx] = 128; // Gray border
            } else {
                bitmap[idx] = 0; // Black background
            }
        }
    }
    
    const metrics = font_debug.analyzeBitmap(bitmap, width, height);
    
    // Test basic metrics calculations
    try testing.expect(metrics.coverage_percent > 0);
    try testing.expect(metrics.coverage_percent <= 100);
    try testing.expect(metrics.overall_score >= 0);
    try testing.expect(metrics.overall_score <= 100);
    
    // Test quality assessment
    const recommendations = font_debug.getRecommendations(metrics);
    try testing.expect(recommendations.len > 0);
}

test "font types basic operations" {
    
    // Test Point operations
    const p1 = font_types.Point.init(10, 20);
    const p2 = p1.scale(2);
    try testing.expectEqual(@as(f32, 20), p2.x);
    try testing.expectEqual(@as(f32, 40), p2.y);
    
    const p3 = p1.translate(5, -5);
    try testing.expectEqual(@as(f32, 15), p3.x);
    try testing.expectEqual(@as(f32, 15), p3.y);
    
    // Test Edge creation
    const edge = font_types.Edge.init(0, 0, 10, 10, 1);
    try testing.expectEqual(@as(f32, 0), edge.minY());
    try testing.expectEqual(@as(f32, 10), edge.maxY());
    try testing.expectEqual(false, edge.isHorizontal());
    
    // Test fill rules
    try testing.expectEqual(true, font_types.FillRule.non_zero.shouldFill(1));
    try testing.expectEqual(false, font_types.FillRule.non_zero.shouldFill(0));
    try testing.expectEqual(true, font_types.FillRule.even_odd.shouldFill(1));
    try testing.expectEqual(false, font_types.FillRule.even_odd.shouldFill(2));
}