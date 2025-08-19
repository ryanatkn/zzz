const std = @import("std");
const testing = std.testing;
const ttf_parser = @import("ttf_parser.zig");
const rasterizer_core = @import("rasterizer_core.zig");
const test_helpers = @import("test_helpers.zig");

// Test to understand proper baseline positioning
test "proper baseline positioning analysis" {
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
    
    std.debug.print("\n🎯 PROPER BASELINE POSITIONING ANALYSIS\n", .{});
    std.debug.print("=" ** 60 ++ "\n", .{});
    
    // Parse the font
    var parser = try ttf_parser.TTFParser.init(allocator, font_data);
    std.debug.print("Font parsed successfully\n", .{});
    
    // Create rasterizer
    var rasterizer = rasterizer_core.RasterizerCore.init(allocator, &parser, 16.0, 96.0);
    
    const metrics = rasterizer.metrics;
    const font_ascender_px = @as(f32, @floatFromInt(metrics.ascender)) * metrics.scale;
    std.debug.print("Font ascender: {d:.2} px\n", .{font_ascender_px});
    
    // Test different characters to understand their bounds
    const test_chars = "apgy"; // a=regular, p=descender, g=descender, y=descender
    std.debug.print("\nCharacter Analysis for proper baseline:\n", .{});
    
    for (test_chars) |char| {
        std.debug.print("\n--- Character '{}' ('{c}') ---\n", .{char, char});
        
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
        
        std.debug.print("  TTF bounds: y_min={d:.1}, y_max={d:.1}\n", 
            .{outline.bounds.y_min, outline.bounds.y_max});
        std.debug.print("  bearing_y: {d:.3} px (distance from baseline to top)\n", 
            .{rasterized.bearing_y});
        
        // For proper baseline alignment, all characters should have their baseline at the same Y position
        // The baseline is at Y=0 in TTF coordinates, so:
        // - glyph_y should be positioned so that (glyph_y + bearing_y) equals the same baseline position for all chars
        
        const cursor_y: f32 = 0.0;
        const desired_baseline_y = font_ascender_px; // This is where we want all baselines
        
        // CORRECT FORMULA: Position glyph so its baseline aligns with desired baseline
        const correct_glyph_y = cursor_y + desired_baseline_y - rasterized.bearing_y;
        const actual_baseline_y = correct_glyph_y + rasterized.bearing_y;
        
        std.debug.print("  CORRECT positioning:\n", .{});
        std.debug.print("    desired_baseline_y: {d:.3} px\n", .{desired_baseline_y});
        std.debug.print("    correct_glyph_y: {d:.3} px\n", .{correct_glyph_y});
        std.debug.print("    actual_baseline_y: {d:.3} px\n", .{actual_baseline_y});
        
        // Check if the character extends below baseline (descender)
        const y_min_px = outline.bounds.y_min * rasterizer.scale;
        if (y_min_px < 0) {
            std.debug.print("    DESCENDER: extends {d:.2} px below baseline\n", .{-y_min_px});
            
            // The glyph bottom in screen coordinates
            const glyph_bottom_y = correct_glyph_y + rasterized.height;
            std.debug.print("    glyph_bottom_y: {d:.2} px\n", .{glyph_bottom_y});
        } else {
            std.debug.print("    REGULAR: no descender\n", .{});
        }
        
        // Show comparison with current wrong formula
        const wrong_glyph_y = cursor_y + (font_ascender_px - rasterized.bearing_y);
        std.debug.print("  COMPARISON with current (wrong) formula:\n", .{});
        std.debug.print("    current_glyph_y: {d:.3} px (WRONG)\n", .{wrong_glyph_y});
        std.debug.print("    difference: {d:.3} px\n", .{correct_glyph_y - wrong_glyph_y});
    }
    
    std.debug.print("\n" ++ "=" ** 60 ++ "\n", .{});
    std.debug.print("💡 INSIGHT: Current formula aligns glyph tops, not baselines!\n", .{});
    std.debug.print("   CORRECT: glyph_y = cursor_y + desired_baseline - bearing_y\n", .{});
    std.debug.print("   CURRENT: glyph_y = cursor_y + (font_ascender - bearing_y) [WRONG]\n", .{});
}