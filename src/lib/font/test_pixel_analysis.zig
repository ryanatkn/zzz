const std = @import("std");
const testing = std.testing;
const ttf_parser = @import("ttf_parser.zig");
const rasterizer_core = @import("rasterizer_core.zig");
const test_helpers = @import("test_helpers.zig");

// Test to examine actual pixel data in rasterized bitmaps
test "pixel-level bitmap analysis" {
    const allocator = testing.allocator;
    
    // Initialize loggers for font system
    try test_helpers.initTestLoggers(allocator);
    defer test_helpers.deinitTestLoggers();
    
    // Try to load DM Sans font
    const font_path = "static/fonts/DM_Sans/static/DMSans-Regular.ttf";
    const font_data = std.fs.cwd().readFileAlloc(allocator, font_path, 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Font file not found: {s} - skipping test\n", .{font_path});
            return;
        },
        else => return err,
    };
    defer allocator.free(font_data);
    
    std.debug.print("\n🔍 PIXEL-LEVEL BITMAP ANALYSIS\n", .{});
    std.debug.print("=" ** 80 ++ "\n", .{});
    
    // Parse the font
    var parser = try ttf_parser.TTFParser.init(allocator, font_data);
    defer parser.deinit(); // Add proper cleanup
    
    // Create rasterizer
    var rasterizer = rasterizer_core.RasterizerCore.init(allocator, &parser, 16.0, 96.0);
    
    // Test specific characters: 'n' (regular), 'g' (descender)
    const test_chars = "ng";
    
    for (test_chars, 0..) |char, char_idx| {
        std.debug.print("\n" ++ "=" ** 60 ++ "\n", .{});
        std.debug.print("📊 PIXEL ANALYSIS: Character '{}' ('{c}')\n", .{char, char});
        std.debug.print("=" ** 60 ++ "\n", .{});
        
        const outline = rasterizer.extractor.extractGlyph(char) catch |err| {
            std.debug.print("Failed to extract '{}': {}\n", .{char, err});
            continue;
        };
        defer outline.deinit(allocator);
        
        const rasterized = rasterizer.rasterizeGlyph(char, 0.0, 0.0) catch |err| {
            std.debug.print("Failed to rasterize '{}': {}\n", .{char, err});
            continue;
        };
        defer allocator.free(rasterized.bitmap);
        
        std.debug.print("TTF Outline Info:\n", .{});
        std.debug.print("  bounds: y_min={d:.2}, y_max={d:.2} (height={d:.2})\n", 
            .{outline.bounds.y_min, outline.bounds.y_max, outline.bounds.height()});
        std.debug.print("  TTF baseline at Y=0, so glyph extends from {d:.2} to {d:.2}\n", 
            .{outline.bounds.y_min, outline.bounds.y_max});
            
        std.debug.print("\nRasterized Bitmap Info:\n", .{});
        std.debug.print("  size: {d:.1}x{d:.1} pixels\n", .{rasterized.width, rasterized.height});
        std.debug.print("  bearing_x: {d:.2}, bearing_y: {d:.2}\n", .{rasterized.bearing_x, rasterized.bearing_y});
        std.debug.print("  bitmap length: {} bytes\n", .{rasterized.bitmap.len});
        
        // Analyze actual pixel content
        const width_u32 = @as(u32, @intFromFloat(@ceil(rasterized.width)));
        const height_u32 = @as(u32, @intFromFloat(@ceil(rasterized.height)));
        
        std.debug.print("\nPixel Content Analysis:\n", .{});
        if (rasterized.bitmap.len > 0) {
            // Find first and last rows with actual ink
            var first_ink_row: ?u32 = null;
            var last_ink_row: ?u32 = null;
            
            for (0..height_u32) |y| {
                var has_ink = false;
                for (0..width_u32) |x| {
                    const pixel_idx = y * width_u32 + x;
                    if (pixel_idx < rasterized.bitmap.len and rasterized.bitmap[pixel_idx] > 50) {
                        has_ink = true;
                        break;
                    }
                }
                
                if (has_ink) {
                    if (first_ink_row == null) first_ink_row = @intCast(y);
                    last_ink_row = @intCast(y);
                }
            }
            
            std.debug.print("  First row with ink: {?}\n", .{first_ink_row});
            std.debug.print("  Last row with ink: {?}\n", .{last_ink_row});
            
            if (first_ink_row != null and last_ink_row != null) {
                const actual_ink_height = last_ink_row.? - first_ink_row.? + 1;
                std.debug.print("  Actual ink height: {} pixels\n", .{actual_ink_height});
                
                // The key question: where should the baseline be in this bitmap?
                // In TTF coordinates, baseline is at Y=0
                // If glyph goes from y_min to y_max, and we have a bitmap from top to bottom,
                // then baseline should be at: (bitmap_height - 1) - |y_min| pixels from top
                
                const y_min_pixels = @abs(outline.bounds.y_min);
                const expected_baseline_from_top = @as(f32, @floatFromInt(height_u32)) - 1.0 - y_min_pixels;
                std.debug.print("  Expected baseline at row: {d:.1} (from top of bitmap)\n", .{expected_baseline_from_top});
                
                // Check if this matches the bearing_y
                std.debug.print("  Bearing_y check: bearing_y={d:.2} should equal distance from baseline to glyph top\n", .{rasterized.bearing_y});
                std.debug.print("  Glyph top in TTF: {d:.2}, so bearing_y should be ≈ {d:.2}\n", .{outline.bounds.y_max, outline.bounds.y_max});
                
                const bearing_mismatch = @abs(rasterized.bearing_y - outline.bounds.y_max);
                if (bearing_mismatch < 0.1) {
                    std.debug.print("  ✓ bearing_y calculation looks correct\n", .{});
                } else {
                    std.debug.print("  ❌ bearing_y calculation seems wrong! Mismatch: {d:.2}\n", .{bearing_mismatch});
                }
            }
            
            // Show a small visual representation of the bitmap
            std.debug.print("\nBitmap Visualization (first 16x16, '#'=ink, '.'=empty):\n", .{});
            const vis_width = @min(width_u32, 16);
            const vis_height = @min(height_u32, 16);
            
            for (0..vis_height) |y| {
                std.debug.print("  ", .{});
                for (0..vis_width) |x| {
                    const pixel_idx = y * width_u32 + x;
                    if (pixel_idx < rasterized.bitmap.len) {
                        const pixel = rasterized.bitmap[pixel_idx];
                        const char_display: u8 = if (pixel > 128) '#' else if (pixel > 50) '+' else '.';
                        std.debug.print("{c}", .{char_display});
                    } else {
                        std.debug.print("?", .{});
                    }
                }
                std.debug.print(" <- row {}\n", .{y});
            }
        } else {
            std.debug.print("  (Empty bitmap)\n", .{});
        }
        
        // Calculate where this glyph would be positioned using current layout formula
        const cursor_y: f32 = 0.0;
        const baseline_offset = rasterizer.metrics.getBaselineOffset();
        const glyph_y = cursor_y + baseline_offset - rasterized.bearing_y;
        
        std.debug.print("\nLayout Positioning (current formula):\n", .{});
        std.debug.print("  cursor_y: {d:.2}\n", .{cursor_y});
        std.debug.print("  baseline_offset: {d:.2}\n", .{baseline_offset});
        std.debug.print("  glyph_y = cursor_y + baseline_offset - bearing_y\n", .{});
        std.debug.print("  glyph_y = {d:.2} + {d:.2} - {d:.2} = {d:.2}\n", .{cursor_y, baseline_offset, rasterized.bearing_y, glyph_y});
        std.debug.print("  So bitmap top-left corner would be at screen Y={d:.2}\n", .{glyph_y});
        
        const effective_baseline_screen_y = glyph_y + rasterized.bearing_y;
        std.debug.print("  Effective baseline at screen Y={d:.2}\n", .{effective_baseline_screen_y});
        
        if (char_idx == 0) {
            std.debug.print("  (This is the reference character)\n", .{});
        } else {
            std.debug.print("  (Compare with reference character)\n", .{});
        }
    }
    
    std.debug.print("\n" ++ "=" ** 80 ++ "\n", .{});
    std.debug.print("🎯 KEY INSIGHT: Look for differences in bitmap structure and positioning\n", .{});
    std.debug.print("=" ** 80 ++ "\n", .{});
}