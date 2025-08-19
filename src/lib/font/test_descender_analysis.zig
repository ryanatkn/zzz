const std = @import("std");
const testing = std.testing;
const ttf_parser = @import("ttf_parser.zig");
const rasterizer_core = @import("rasterizer_core.zig");
const test_helpers = @import("test_helpers.zig");

// Test to specifically analyze descender alignment issue
test "descender character alignment analysis" {
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
    
    std.debug.print("\n🔍 DESCENDER CHARACTER ALIGNMENT ANALYSIS\n", .{});
    std.debug.print("=" ** 80 ++ "\n", .{});
    
    // Parse the font
    var parser = try ttf_parser.TTFParser.init(allocator, font_data);
    defer parser.deinit();
    
    // Create rasterizer
    var rasterizer = rasterizer_core.RasterizerCore.init(allocator, &parser, 16.0, 96.0);
    
    // Test baseline character vs descenders
    const test_chars = "nopgyj";
    
    std.debug.print("\nAnalyzing characters: ", .{});
    for (test_chars) |c| {
        std.debug.print("{c} ", .{c});
    }
    std.debug.print("\n\n", .{});
    
    // Collect data for comparison
    var char_data: [6]struct {
        char: u8,
        y_min: f32,
        y_max: f32,
        bearing_y: f32,
        first_ink_row: ?u32,
        last_ink_row: ?u32,
        expected_baseline_row: f32,
    } = undefined;
    
    for (test_chars, 0..) |char, idx| {
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
        
        // Analyze bitmap content
        const width_u32 = @as(u32, @intFromFloat(@ceil(rasterized.width)));
        const height_u32 = @as(u32, @intFromFloat(@ceil(rasterized.height)));
        
        var first_ink_row: ?u32 = null;
        var last_ink_row: ?u32 = null;
        
        if (rasterized.bitmap.len > 0) {
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
        }
        
        // With the new rasterizer, baseline is at consistent position from bottom for all characters
        const font_descender = @as(f32, @floatFromInt(-rasterizer.metrics.descender)) * rasterizer.scale;
        const baseline_from_bottom = font_descender + 1.0;
        const expected_baseline_from_top = @as(f32, @floatFromInt(height_u32)) - baseline_from_bottom;
        
        char_data[idx] = .{
            .char = char,
            .y_min = outline.bounds.y_min,
            .y_max = outline.bounds.y_max,
            .bearing_y = rasterized.bearing_y,
            .first_ink_row = first_ink_row,
            .last_ink_row = last_ink_row,
            .expected_baseline_row = expected_baseline_from_top,
        };
    }
    
    // Print comparison table
    std.debug.print("Character Analysis Table:\n", .{});
    std.debug.print("-" ** 80 ++ "\n", .{});
    std.debug.print("Char | y_min  | y_max  | bearing_y | first_ink | last_ink | baseline_row\n", .{});
    std.debug.print("-" ** 80 ++ "\n", .{});
    
    for (char_data) |data| {
        std.debug.print(" {c}   | {d:6.2} | {d:6.2} | {d:9.2} | {?:9} | {?:8} | {d:12.1}\n", .{
            data.char,
            data.y_min,
            data.y_max,
            data.bearing_y,
            data.first_ink_row,
            data.last_ink_row,
            data.expected_baseline_row,
        });
    }
    
    std.debug.print("-" ** 80 ++ "\n\n", .{});
    
    // Analyze the issue
    std.debug.print("🎯 KEY OBSERVATIONS:\n", .{});
    std.debug.print("-" ** 40 ++ "\n", .{});
    
    // Check if descenders have more empty space at top
    const n_data = char_data[0];  // 'n' as baseline reference
    const g_data = char_data[3];  // 'g' as descender example
    
    if (n_data.first_ink_row != null and g_data.first_ink_row != null) {
        const n_empty_top = n_data.first_ink_row.?;
        const g_empty_top = g_data.first_ink_row.?;
        
        std.debug.print("1. Empty rows at top of bitmap:\n", .{});
        std.debug.print("   'n': {} rows\n", .{n_empty_top});
        std.debug.print("   'g': {} rows\n", .{g_empty_top});
        std.debug.print("   Difference: {} rows\n\n", .{@as(i32, @intCast(g_empty_top)) - @as(i32, @intCast(n_empty_top))});
        
        if (g_empty_top > n_empty_top) {
            std.debug.print("   ⚠️ PROBLEM: 'g' has {} more empty rows at top!\n", .{g_empty_top - n_empty_top});
            std.debug.print("   This pushes the visible part of 'g' lower in the bitmap.\n\n", .{});
        }
    }
    
    std.debug.print("2. Baseline position in bitmap:\n", .{});
    std.debug.print("   'n': baseline at row {d:.1}\n", .{n_data.expected_baseline_row});
    std.debug.print("   'g': baseline at row {d:.1}\n", .{g_data.expected_baseline_row});
    std.debug.print("   (Both should align when rendered)\n\n", .{});
    
    std.debug.print("3. Y-bounds comparison:\n", .{});
    std.debug.print("   'n': y_min={d:.2}, y_max={d:.2}\n", .{n_data.y_min, n_data.y_max});
    std.debug.print("   'g': y_min={d:.2}, y_max={d:.2}\n", .{g_data.y_min, g_data.y_max});
    std.debug.print("   Note: 'g' extends {d:.2} units below baseline\n\n", .{@abs(g_data.y_min)});
    
    // Calculate where the main body of each character sits
    if (n_data.first_ink_row != null and g_data.first_ink_row != null) {
        const n_baseline_to_first_ink = n_data.expected_baseline_row - @as(f32, @floatFromInt(n_data.first_ink_row.?));
        const g_baseline_to_first_ink = g_data.expected_baseline_row - @as(f32, @floatFromInt(g_data.first_ink_row.?));
        
        std.debug.print("4. Distance from baseline to first ink (in bitmap):\n", .{});
        std.debug.print("   'n': {d:.1} pixels above baseline\n", .{n_baseline_to_first_ink});
        std.debug.print("   'g': {d:.1} pixels above baseline\n", .{g_baseline_to_first_ink});
        
        if (@abs(g_baseline_to_first_ink - n_baseline_to_first_ink) > 1.0) {
            std.debug.print("   ⚠️ MISALIGNMENT: Characters start at different heights relative to baseline!\n", .{});
        }
    }
    
    std.debug.print("\n" ++ "=" ** 80 ++ "\n", .{});
    std.debug.print("🔧 DIAGNOSIS: The rasterizer Y-flipping creates inconsistent padding above glyphs\n", .{});
    std.debug.print("=" ** 80 ++ "\n", .{});
}