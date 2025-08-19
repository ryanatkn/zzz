const std = @import("std");
const testing = std.testing;
const ttf_parser = @import("ttf_parser.zig");
const rasterizer_core = @import("rasterizer_core.zig");
const glyph_extractor = @import("glyph_extractor.zig");

// Simple debug test to understand our font data
test "debug font metrics and descenders" {
    const allocator = testing.allocator;
    
    std.debug.print("\n\n🔍 FONT DEBUG SESSION STARTING\n", .{});
    std.debug.print("=" ** 50 ++ "\n", .{});
    
    // Try to load DM Sans font
    const font_path = "static/fonts/DM_Sans/static/DMSans-Regular.ttf";
    const font_data = std.fs.cwd().readFileAlloc(allocator, font_path, 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("❌ Font file not found: {s}\n", .{font_path});
            std.debug.print("This test requires the DM Sans font to be present.\n", .{});
            return;
        },
        else => return err,
    };
    defer allocator.free(font_data);
    
    std.debug.print("✅ Loaded font file: {s} ({} bytes)\n", .{font_path, font_data.len});
    
    // Parse the font
    var parser = try ttf_parser.TTFParser.init(allocator, font_data);
    
    std.debug.print("✅ Font parsed successfully\n", .{});
    
    // Create rasterizer with common web font size
    var rasterizer = rasterizer_core.RasterizerCore.init(allocator, &parser, 16.0, 96.0);
    
    // Log font-level metrics
    const metrics = rasterizer.metrics;
    std.debug.print("\n📊 FONT METRICS ANALYSIS\n", .{});
    std.debug.print("Units per em: {}\n", .{metrics.units_per_em});
    std.debug.print("Ascender: {} font units ({:.2} px)\n", .{metrics.ascender, @as(f32, @floatFromInt(metrics.ascender)) * metrics.scale});
    std.debug.print("Descender: {} font units ({:.2} px)\n", .{metrics.descender, @as(f32, @floatFromInt(metrics.descender)) * metrics.scale});
    std.debug.print("Line gap: {} font units ({:.2} px)\n", .{metrics.line_gap, @as(f32, @floatFromInt(metrics.line_gap)) * metrics.scale});
    std.debug.print("Calculated line height: {:.2} px\n", .{metrics.line_height});
    std.debug.print("Baseline offset: {:.2} px\n", .{metrics.getBaselineOffset()});
    std.debug.print("Scale factor: {:.6}\n", .{metrics.scale});
    
    // Analyze specific characters
    const test_chars = "agpyT"; // Mix: regular, descenders, tall
    
    std.debug.print("\n🔤 INDIVIDUAL CHARACTER ANALYSIS\n", .{});
    
    for (test_chars) |char| {
        std.debug.print("\n--- Analyzing '{}' ---\n", .{@as(u21, char)});
        
        const outline = rasterizer.extractor.extractGlyph(char) catch |err| {
            std.debug.print("❌ Failed to extract '{}': {}\n", .{@as(u21, char), err});
            continue;
        };
        defer outline.deinit(allocator);
        
        const rasterized = rasterizer.rasterizeGlyph(char, 0.0, 0.0) catch |err| {
            std.debug.print("❌ Failed to rasterize '{}': {}\n", .{@as(u21, char), err});
            continue;
        };
        defer allocator.free(rasterized.bitmap);
        
        // Print raw data
        std.debug.print("Outline bounds: x[{:.1}, {:.1}] y[{:.1}, {:.1}]\n", 
            .{outline.bounds.x_min, outline.bounds.x_max, outline.bounds.y_min, outline.bounds.y_max});
        std.debug.print("Rasterized: {}x{} pixels, bearing_x:{}, bearing_y:{}, advance:{:.1}\n",
            .{rasterized.width, rasterized.height, rasterized.bearing_x, rasterized.bearing_y, rasterized.advance});
        
        // Analyze relationship to baseline
        std.debug.print("Relationship to baseline (y=0):\n");
        std.debug.print("  Top: {:.1} font units ({:.2} px above baseline)\n", 
            .{outline.bounds.y_max, outline.bounds.y_max});
        std.debug.print("  Bottom: {:.1} font units ({:.2} px {} baseline)\n", 
            .{outline.bounds.y_min, @abs(outline.bounds.y_min), if (outline.bounds.y_min < 0) "below" else "above"});
        
        if (outline.bounds.y_min < 0) {
            std.debug.print("  🔽 DESCENDER: extends {:.2} px below baseline\n", .{-outline.bounds.y_min});
        }
        
        // Simulate layout positioning
        const cursor_y: f32 = 0;
        const baseline_offset = metrics.getBaselineOffset();
        const glyph_y = cursor_y + baseline_offset - @as(f32, @floatFromInt(rasterized.bearing_y));
        const glyph_bottom = glyph_y + @as(f32, @floatFromInt(rasterized.height));
        
        std.debug.print("Layout positioning simulation:\n");
        std.debug.print("  cursor_y: {:.2}, baseline_offset: {:.2}, bearing_y: {}\n", 
            .{cursor_y, baseline_offset, rasterized.bearing_y});
        std.debug.print("  Final glyph_y: {:.2}, glyph_bottom: {:.2}\n", .{glyph_y, glyph_bottom});
    }
    
    // Texture height analysis
    std.debug.print("\n📐 TEXTURE HEIGHT ANALYSIS\n", .{});
    const line_height = metrics.getLineHeight();
    const ascender_px = @as(f32, @floatFromInt(metrics.ascender)) * metrics.scale;
    const descender_px = @as(f32, @floatFromInt(metrics.descender)) * metrics.scale;
    
    std.debug.print("Current line_height: {:.2} px\n", .{line_height});
    std.debug.print("Space needed above baseline: {:.2} px\n", .{ascender_px});
    std.debug.print("Space needed below baseline: {:.2} px\n", .{@abs(descender_px)});
    std.debug.print("Total space needed: {:.2} px\n", .{ascender_px + @abs(descender_px)});
    
    if (line_height < ascender_px + @abs(descender_px)) {
        std.debug.print("⚠️  POTENTIAL ISSUE: line_height ({:.2}) < required space ({:.2})\n", 
            .{line_height, ascender_px + @abs(descender_px)});
    } else {
        std.debug.print("✅ line_height appears adequate\n", .{});
    }
    
    std.debug.print("\n🔍 FONT DEBUG SESSION COMPLETE\n", .{});
    std.debug.print("=" ** 50 ++ "\n", .{});
}