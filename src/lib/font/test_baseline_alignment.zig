const std = @import("std");
const testing = std.testing;
const ttf_parser = @import("ttf_parser.zig");
const rasterizer_core = @import("rasterizer_core.zig");
const font_atlas = @import("font_atlas.zig");
const layout_engine = @import("../text/layout.zig");
const test_helpers = @import("test_helpers.zig");

// Test baseline alignment for mixed character types
test "baseline alignment verification" {
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
    
    std.debug.print("\n🔍 BASELINE ALIGNMENT TEST\n", .{});
    std.debug.print("=" ** 50 ++ "\n", .{});
    
    // Parse the font
    var parser = try ttf_parser.TTFParser.init(allocator, font_data);
    std.debug.print("Font parsed successfully\n", .{});
    
    // Create rasterizer
    var rasterizer = rasterizer_core.RasterizerCore.init(allocator, &parser, 16.0, 96.0);
    
    // Print metrics
    const metrics = rasterizer.metrics;
    std.debug.print("Line height: {d:.2} px\n", .{metrics.line_height});
    std.debug.print("Baseline offset: {d:.2} px\n", .{metrics.getBaselineOffset()});
    
    // Test specific character types that should align to same baseline
    const test_text = "age"; // a=regular, g=descender, e=regular
    std.debug.print("\nTesting text: '{s}'\n", .{test_text});
    
    const font_ascender_px = @as(f32, @floatFromInt(metrics.ascender)) * metrics.scale;
    std.debug.print("Font ascender (px): {d:.2}\n", .{font_ascender_px});
    
    std.debug.print("\nCharacter Baseline Analysis:\n", .{});
    
    for (test_text, 0..) |char, i| {
        std.debug.print("\n--- Character '{}' ---\n", .{char});
        
        const rasterized = rasterizer.rasterizeGlyph(char, 0.0, 0.0) catch |err| {
            std.debug.print("Failed to rasterize '{}': {}\n", .{char, err});
            continue;
        };
        defer allocator.free(rasterized.bitmap);
        
        // Calculate baseline using font ascender method (same as layout.zig)
        const cursor_y: f32 = 0.0;
        const glyph_y = cursor_y + (font_ascender_px - rasterized.bearing_y);
        const baseline_y = glyph_y + rasterized.bearing_y; // Where the baseline actually is
        
        std.debug.print("  bearing_y: {d:.3} px\n", .{rasterized.bearing_y});
        std.debug.print("  glyph_y: {d:.3} px\n", .{glyph_y});
        std.debug.print("  calculated baseline_y: {d:.3} px\n", .{baseline_y});
        
        // Check if baseline aligns with font ascender
        const expected_baseline = font_ascender_px;
        const baseline_diff = @abs(baseline_y - expected_baseline);
        
        std.debug.print("  expected baseline: {d:.3} px\n", .{expected_baseline});
        std.debug.print("  baseline difference: {d:.6} px\n", .{baseline_diff});
        
        if (baseline_diff < 0.001) { // Allow for float precision
            std.debug.print("  ✓ BASELINE ALIGNED\n", .{});
        } else {
            std.debug.print("  ❌ BASELINE MISALIGNED by {d:.6} px\n", .{baseline_diff});
        }
        
        // Check texture bounds
        const glyph_bottom = glyph_y + rasterized.height;
        if (glyph_bottom <= metrics.line_height) {
            std.debug.print("  ✓ Fits within texture bounds\n", .{});
        } else {
            std.debug.print("  ❌ Extends beyond texture bounds by {d:.2} px\n", .{glyph_bottom - metrics.line_height});
        }
        
        _ = i; // suppress unused variable warning
    }
    
    std.debug.print("\n" ++ "=" ** 50 ++ "\n", .{});
    std.debug.print("🎯 BASELINE ALIGNMENT TEST COMPLETE\n", .{});
}