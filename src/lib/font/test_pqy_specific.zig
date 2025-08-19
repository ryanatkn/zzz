const std = @import("std");
const testing = std.testing;
const ttf_parser = @import("ttf_parser.zig");
const rasterizer_core = @import("rasterizer_core.zig");
const test_helpers = @import("test_helpers.zig");

// Test specifically for p, q, y characters as reported by user
test "p q y character specific analysis" {
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
    
    std.debug.print("\n🔍 SPECIFIC ANALYSIS: p, q, y vs regular characters\n", .{});
    std.debug.print("=" ** 70 ++ "\n", .{});
    
    // Parse the font
    var parser = try ttf_parser.TTFParser.init(allocator, font_data);
    
    // Create rasterizer
    var rasterizer = rasterizer_core.RasterizerCore.init(allocator, &parser, 16.0, 96.0);
    
    const metrics = rasterizer.metrics;
    const baseline_offset = metrics.getBaselineOffset();
    
    std.debug.print("Font metrics:\n", .{});
    std.debug.print("  baseline_offset: {d:.3} px\n", .{baseline_offset});
    std.debug.print("  line_height: {d:.3} px\n", .{metrics.line_height});
    
    // Test the specific characters user mentioned: p, q, y
    // Plus some reference characters: a, n, o
    const problem_chars = "pqy";
    const reference_chars = "ano";
    
    std.debug.print("\n🚨 PROBLEM CHARACTERS (reported as positioned too low):\n", .{});
    for (problem_chars) |char| {
        try analyzeCharacter(&rasterizer, allocator, char, baseline_offset);
    }
    
    std.debug.print("\n✅ REFERENCE CHARACTERS (should be positioned correctly):\n", .{});
    for (reference_chars) |char| {
        try analyzeCharacter(&rasterizer, allocator, char, baseline_offset);
    }
    
    std.debug.print("\n" ++ "=" ** 70 ++ "\n", .{});
    std.debug.print("🔍 ANALYSIS COMPLETE - Look for patterns in the differences!\n", .{});
}

fn analyzeCharacter(rasterizer: *rasterizer_core.RasterizerCore, allocator: std.mem.Allocator, char: u8, baseline_offset: f32) !void {
    std.debug.print("\n--- Character '{}' ('{c}') ---\n", .{char, char});
    
    const outline = rasterizer.extractor.extractGlyph(char) catch |err| {
        std.debug.print("Failed to extract '{}': {}\n", .{char, err});
        return;
    };
    defer outline.deinit(allocator);
    
    const rasterized = rasterizer.rasterizeGlyph(char, 0.0, 0.0) catch |err| {
        std.debug.print("Failed to rasterize '{}': {}\n", .{char, err});
        return;
    };
    defer allocator.free(rasterized.bitmap);
    
    std.debug.print("  TTF bounds: y_min={d:.1}, y_max={d:.1} (height={d:.1})\n", 
        .{outline.bounds.y_min, outline.bounds.y_max, outline.bounds.height()});
    std.debug.print("  Rasterized: {d:.1}x{d:.1} pixels\n", 
        .{rasterized.width, rasterized.height});
    std.debug.print("  bearing_x: {d:.3}, bearing_y: {d:.3}\n", 
        .{rasterized.bearing_x, rasterized.bearing_y});
    
    // Calculate position using current formula
    const cursor_y: f32 = 0.0;
    const glyph_y = cursor_y + baseline_offset - rasterized.bearing_y;
    const glyph_bottom = glyph_y + rasterized.height;
    
    std.debug.print("  Layout positioning:\n", .{});
    std.debug.print("    glyph_y: {d:.3} px\n", .{glyph_y});
    std.debug.print("    glyph_bottom: {d:.3} px\n", .{glyph_bottom});
    std.debug.print("    baseline_y: {d:.3} px (glyph_y + bearing_y)\n", .{glyph_y + rasterized.bearing_y});
    
    // Check descender info
    const y_min_px = outline.bounds.y_min * rasterizer.scale;
    if (y_min_px < -0.01) { // Small epsilon for floating point
        std.debug.print("    🠗 DESCENDER: extends {d:.2} px below baseline\n", .{-y_min_px});
        
        // Calculate where the descender part ends up in screen coordinates
        const descender_bottom_y = (glyph_y + rasterized.bearing_y) - y_min_px;
        std.debug.print("    🠗 Descender bottom at: {d:.2} px from texture top\n", .{descender_bottom_y});
    } else {
        std.debug.print("    ⬜ NO descender\n", .{});
    }
    
    // Show how much space this character needs
    std.debug.print("    Space needed: {d:.2} px (from glyph_y to glyph_bottom)\n", .{glyph_bottom - glyph_y});
}