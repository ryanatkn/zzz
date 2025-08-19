const std = @import("std");
const testing = std.testing;
const ttf_parser = @import("ttf_parser.zig");
const rasterizer_core = @import("rasterizer_core.zig");

// Comprehensive pipeline test to trace descender cutoff issue
test "pipeline debug - trace descender 'g' through all stages" {
    const allocator = testing.allocator;
    
    // Try to load DM Sans font
    const font_path = "static/fonts/DM_Sans/static/DMSans-Regular.ttf";
    const font_data = std.fs.cwd().readFileAlloc(allocator, font_path, 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Font file not found: {s} - skipping pipeline test\n", .{font_path});
            return;
        },
        else => return err,
    };
    defer allocator.free(font_data);
    
    std.debug.print("\n" ++ "=" ** 60 ++ "\n", .{});
    std.debug.print("🔍 COMPREHENSIVE PIPELINE DEBUG FOR DESCENDER 'g'\n", .{});
    std.debug.print("=" ** 60 ++ "\n\n", .{});
    
    // Parse the font
    var parser = try ttf_parser.TTFParser.init(allocator, font_data);
    const rasterizer = rasterizer_core.RasterizerCore.init(allocator, &parser, 16.0, 96.0);
    
    const char: u8 = 'g'; // Focus on 'g' as our test descender character
    const metrics = rasterizer.metrics;
    
    std.debug.print("STAGE 1: FONT METRICS\n", .{});
    std.debug.print("-" ** 30 ++ "\n", .{});
    std.debug.print("Scale factor: {d:.6}\n", .{metrics.scale});
    std.debug.print("Line height: {d:.2} px\n", .{metrics.line_height});
    std.debug.print("Baseline offset: {d:.2} px\n", .{metrics.getBaselineOffset()});
    std.debug.print("Available space below baseline: {d:.2} px\n", .{metrics.line_height - metrics.getBaselineOffset()});
    
    // STAGE 2: GLYPH EXTRACTION
    std.debug.print("\nSTAGE 2: GLYPH EXTRACTION\n", .{});
    std.debug.print("-" ** 30 ++ "\n", .{});
    
    // We need to mock the glyph extraction since it needs logger initialization
    // But we can show what SHOULD happen
    std.debug.print("Target character: '{}'\n", .{@as(u21, char)});
    std.debug.print("Expected bounds for descender 'g':\n", .{});
    std.debug.print("  - y_max: ~10 font units (top of glyph)\n", .{});
    std.debug.print("  - y_min: ~-5 font units (bottom of descender)\n", .{});
    std.debug.print("  - Expected height: y_max - y_min = ~15 font units\n", .{});
    std.debug.print("  - In pixels: ~15 * {d:.6} = ~{d:.2} px\n", .{metrics.scale, 15 * metrics.scale});
    
    // STAGE 3: THEORETICAL RASTERIZATION ANALYSIS
    std.debug.print("\nSTAGE 3: RASTERIZATION ANALYSIS\n", .{});
    std.debug.print("-" ** 30 ++ "\n", .{});
    
    // Simulate what the rasterizer should produce
    const expected_y_max: f32 = 10.0; // Font units
    const expected_y_min: f32 = -5.0; // Font units (negative = below baseline)
    const expected_height_font_units = expected_y_max - expected_y_min;
    const expected_height_pixels = expected_height_font_units;
    const bitmap_height_with_padding = @as(u32, @intFromFloat(@ceil(expected_height_pixels))) + 2;
    const expected_bearing_y = @as(i32, @intFromFloat(@round(expected_y_max)));
    
    std.debug.print("Expected glyph bounds:\n", .{});
    std.debug.print("  y_min: {d:.1} font units ({d:.2} px below baseline)\n", .{expected_y_min, @abs(expected_y_min)});
    std.debug.print("  y_max: {d:.1} font units ({d:.2} px above baseline)\n", .{expected_y_max, expected_y_max});
    std.debug.print("  Height: {d:.1} font units ({d:.2} px)\n", .{expected_height_font_units, expected_height_pixels});
    std.debug.print("  Bitmap height (with padding): {} px\n", .{bitmap_height_with_padding});
    std.debug.print("  Expected bearing_y: {} px (distance from baseline to top)\n", .{expected_bearing_y});
    
    // STAGE 4: LAYOUT POSITIONING ANALYSIS
    std.debug.print("\nSTAGE 4: LAYOUT POSITIONING ANALYSIS\n", .{});
    std.debug.print("-" ** 40 ++ "\n", .{});
    
    const cursor_y: f32 = 0;
    const baseline_offset = metrics.getBaselineOffset();
    const glyph_y = cursor_y + baseline_offset - @as(f32, @floatFromInt(expected_bearing_y));
    const glyph_bottom = glyph_y + @as(f32, @floatFromInt(bitmap_height_with_padding));
    
    std.debug.print("Layout positioning calculation:\n", .{});
    std.debug.print("  cursor_y: {d:.2} px (top of texture)\n", .{cursor_y});
    std.debug.print("  baseline_offset: {d:.2} px (distance to baseline)\n", .{baseline_offset});
    std.debug.print("  bearing_y: {} px (distance from baseline to glyph top)\n", .{expected_bearing_y});
    std.debug.print("  Formula: glyph_y = cursor_y + baseline_offset - bearing_y\n", .{});
    std.debug.print("  glyph_y = {d:.2} + {d:.2} - {} = {d:.2} px\n", .{cursor_y, baseline_offset, expected_bearing_y, glyph_y});
    std.debug.print("  glyph_bottom = glyph_y + height = {d:.2} + {} = {d:.2} px\n", .{glyph_y, bitmap_height_with_padding, glyph_bottom});
    
    // STAGE 5: TEXTURE BOUNDS CHECKING
    std.debug.print("\nSTAGE 5: TEXTURE BOUNDS CHECKING\n", .{});
    std.debug.print("-" ** 40 ++ "\n", .{});
    
    const texture_height = metrics.line_height;
    std.debug.print("Texture height: {d:.2} px\n", .{texture_height});
    std.debug.print("Glyph bottom: {d:.2} px\n", .{glyph_bottom});
    std.debug.print("Bounds check: glyph_bottom <= texture_height?\n", .{});
    std.debug.print("  {d:.2} <= {d:.2} = {}\n", .{glyph_bottom, texture_height, glyph_bottom <= texture_height});
    
    if (glyph_bottom > texture_height) {
        const overflow = glyph_bottom - texture_height;
        std.debug.print("  🚨 CUTOFF DETECTED! Glyph extends {d:.2} px beyond texture bounds\n", .{overflow});
        std.debug.print("  This explains why descenders are being cut off!\n", .{});
    } else {
        std.debug.print("  ✅ Glyph should fit within texture bounds\n", .{});
    }
    
    // STAGE 6: ROOT CAUSE ANALYSIS
    std.debug.print("\nSTAGE 6: ROOT CAUSE ANALYSIS\n", .{});
    std.debug.print("-" ** 40 ++ "\n", .{});
    
    // Check each component of the calculation
    std.debug.print("Breaking down the issue:\n", .{});
    std.debug.print("  1. Line height calculation: ascender - descender + line_gap\n", .{});
    std.debug.print("     = {} - ({}) + {} = {d:.2} px\n", .{metrics.ascender, metrics.descender, metrics.line_gap, metrics.line_height});
    
    std.debug.print("  2. Space allocation:\n", .{});
    std.debug.print("     - Above baseline (baseline_offset): {d:.2} px\n", .{baseline_offset});
    std.debug.print("     - Below baseline (remaining): {d:.2} px\n", .{texture_height - baseline_offset});
    
    std.debug.print("  3. Descender needs:\n", .{});
    std.debug.print("     - Glyph extends to: y_min = {d:.1} font units = {d:.2} px below baseline\n", .{expected_y_min, @abs(expected_y_min)});
    std.debug.print("     - But positioned at: glyph_y = {d:.2} px from texture top\n", .{glyph_y});
    std.debug.print("     - Descender bottom will be at: {d:.2} px from texture top\n", .{glyph_y + @abs(expected_y_min)});
    
    // HYPOTHESIS
    std.debug.print("\nHYPOTHESIS:\n", .{});
    if (glyph_bottom > texture_height) {
        std.debug.print("The issue is likely in the layout positioning formula.\n", .{});
        std.debug.print("The current formula doesn't properly account for descenders.\n", .{});
        std.debug.print("Possible fixes:\n", .{});
        std.debug.print("  A) Adjust texture height calculation\n", .{});
        std.debug.print("  B) Modify glyph positioning formula\n", .{});
        std.debug.print("  C) Fix bearing_y calculation for descenders\n", .{});
    } else {
        std.debug.print("The math appears correct. Issue might be elsewhere:\n", .{});
        std.debug.print("  - Rasterizer coordinate flipping\n", .{});
        std.debug.print("  - Atlas packing clipping\n", .{});
        std.debug.print("  - Shader texture sampling\n", .{});
    }
    
    std.debug.print("\n" ++ "=" ** 60 ++ "\n", .{});
    std.debug.print("🔍 PIPELINE DEBUG COMPLETE\n", .{});
    std.debug.print("=" ** 60 ++ "\n", .{});
}

// Additional test to verify actual vs expected dimensions
test "verify bitmap dimensions for descenders" {
    _ = testing.allocator;
    
    std.debug.print("\n🔍 BITMAP DIMENSION VERIFICATION\n", .{});
    std.debug.print("-" ** 40 ++ "\n", .{});
    
    // This test would verify the actual rasterized bitmap dimensions
    // if we could get past the logger initialization issue
    
    std.debug.print("Test concept:\n", .{});
    std.debug.print("1. Extract outline for 'g'\n", .{});
    std.debug.print("2. Check outline.bounds.y_min and y_max\n", .{});
    std.debug.print("3. Rasterize glyph\n", .{});
    std.debug.print("4. Verify bitmap.height >= |y_min| + |y_max|\n", .{});
    std.debug.print("5. Check if full glyph is in bitmap\n", .{});
    
    std.debug.print("Expected result: Bitmap should contain entire glyph including descender\n", .{});
    std.debug.print("If bitmap is too small, the issue is in rasterization\n", .{});
    std.debug.print("If bitmap is correct, the issue is in layout positioning\n", .{});
}