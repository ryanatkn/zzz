const std = @import("std");
const testing = std.testing;
const ttf_parser = @import("../ttf_parser.zig");
const rasterizer_core = @import("../rasterizer_core.zig");
const test_helpers = @import("../test_helpers.zig");

// Simple test to examine font data for the descender issue
test "simple font metrics examination" {
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
    
    std.debug.print("\n=== FONT DEBUG TEST ===\n", .{});
    std.debug.print("Font file loaded: {s} ({} bytes)\n", .{font_path, font_data.len});
    
    // Parse the font
    var parser = try ttf_parser.TTFParser.init(allocator, font_data);
    defer parser.deinit();
    std.debug.print("Font parsed successfully\n", .{});
    
    // Create rasterizer
    var rasterizer = rasterizer_core.RasterizerCore.init(allocator, &parser, 16.0, 96.0);
    
    // Print basic font metrics
    const metrics = rasterizer.metrics;
    std.debug.print("\nFont Metrics:\n", .{});
    std.debug.print("  Units per em: {}\n", .{metrics.units_per_em});
    std.debug.print("  Ascender: {} font units\n", .{metrics.ascender});
    std.debug.print("  Descender: {} font units\n", .{metrics.descender});
    std.debug.print("  Line gap: {} font units\n", .{metrics.line_gap});
    std.debug.print("  Scale factor: {d:.6}\n", .{metrics.scale});
    std.debug.print("  Calculated line height: {d:.2} px\n", .{metrics.line_height});
    std.debug.print("  Baseline offset: {d:.2} px\n", .{metrics.getBaselineOffset()});
    
    // Test specific characters
    const test_chars = "agy";
    std.debug.print("\nCharacter Analysis:\n", .{});
    
    for (test_chars) |char| {
        std.debug.print("\n--- Character '{}' ---\n", .{@as(u21, char)});
        
        const outline = rasterizer.extractor.extractGlyph(char) catch |err| {
            std.debug.print("Failed to extract '{}': {}\n", .{@as(u21, char), err});
            continue;
        };
        defer outline.deinit(allocator);
        
        const rasterized = rasterizer.rasterizeGlyph(char, 0.0, 0.0) catch |err| {
            std.debug.print("Failed to rasterize '{}': {}\n", .{@as(u21, char), err});
            continue;
        };
        defer allocator.free(rasterized.bitmap);
        
        std.debug.print("  Outline bounds: y_min={d:.1}, y_max={d:.1}\n", 
            .{outline.bounds.y_min, outline.bounds.y_max});
        std.debug.print("  Rasterized: {d:.1}x{d:.1} pixels\n", 
            .{rasterized.width, rasterized.height});
        std.debug.print("  bearing_y: {d:.2} (distance from baseline to top)\n", 
            .{rasterized.bearing_y});
        
        // Calculate layout position using the current formula
        const cursor_y: f32 = 0;
        const baseline_offset = metrics.getBaselineOffset();
        const glyph_y = cursor_y + baseline_offset - rasterized.bearing_y;
        const glyph_bottom = glyph_y + rasterized.height;
        
        std.debug.print("  Layout positioning:\n", .{});
        std.debug.print("    cursor_y: {d:.2}, baseline_offset: {d:.2}\n", .{cursor_y, baseline_offset});
        std.debug.print("    glyph_y: {d:.2}, glyph_bottom: {d:.2}\n", .{glyph_y, glyph_bottom});
        // Calculate both old and new texture height approaches
        const old_texture_height = metrics.line_height;
        const font_ascender_px = @as(f32, @floatFromInt(metrics.ascender)) * metrics.scale;
        const font_descender_px = @as(f32, @floatFromInt(-metrics.descender)) * metrics.scale;
        const rasterizer_padding: f32 = 6.0;
        const new_texture_height = font_ascender_px + font_descender_px + rasterizer_padding;
        
        std.debug.print("    old texture_height (line_height): {d:.2}\n", .{old_texture_height});
        std.debug.print("    new texture_height (ascender+descender+padding): {d:.2}\n", .{new_texture_height});
        
        // Check bounds with both old and new texture heights
        std.debug.print("    Bounds check with old height:\n", .{});
        if (glyph_bottom > old_texture_height) {
            std.debug.print("      ❌ Extends beyond OLD texture bounds by {d:.2} px\n", .{glyph_bottom - old_texture_height});
        } else {
            std.debug.print("      ✓ Fits within OLD texture bounds\n", .{});
        }
        
        std.debug.print("    Bounds check with new height:\n", .{});
        if (glyph_bottom > new_texture_height) {
            std.debug.print("      ❌ Extends beyond NEW texture bounds by {d:.2} px\n", .{glyph_bottom - new_texture_height});
        } else {
            std.debug.print("      ✓ Fits within NEW texture bounds\n", .{});
        }
        
        if (outline.bounds.y_min < 0) {
            std.debug.print("    DESCENDER: extends {d:.2} px below baseline\n", .{-outline.bounds.y_min});
        }
    }
    
    std.debug.print("\n=== END FONT DEBUG TEST ===\n", .{});
}