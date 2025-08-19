const std = @import("std");
const testing = std.testing;
const debug = @import("metrics_debug.zig");
const rasterizer_core = @import("../rasterizer_core.zig");
const ttf_parser = @import("../ttf_parser.zig");

const MetricsDebugger = debug.MetricsDebugger;

test "texture height calculation analysis" {
    const allocator = testing.allocator;
    
    const font_path = "static/fonts/DM_Sans/static/DMSans-Regular.ttf";
    const font_data = std.fs.cwd().readFileAlloc(allocator, font_path, 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Skipping texture bounds test - font file not found\n", .{});
            return;
        },
        else => return err,
    };
    defer allocator.free(font_data);
    
    var parser = try ttf_parser.TTFParser.init(allocator, font_data);
    
    const rasterizer = rasterizer_core.RasterizerCore.init(allocator, &parser, 16.0, 96.0);
    const metrics = rasterizer.metrics;
    
    std.debug.print("\n=== Texture Height Analysis ===\n", .{});
    MetricsDebugger.logFontMetrics(metrics);
    
    // Current layout.zig calculation (after our changes)
    const line_height = metrics.getLineHeight();
    
    // Analyze what this means
    const ascender_px = @as(f32, @floatFromInt(metrics.ascender)) * metrics.scale;
    const descender_px = @as(f32, @floatFromInt(metrics.descender)) * metrics.scale;
    const line_gap_px = @as(f32, @floatFromInt(metrics.line_gap)) * metrics.scale;
    
    std.debug.print("\n=== Component Analysis ===\n", .{});
    std.debug.print("Ascender: {:.2}px\n", .{ascender_px});
    std.debug.print("Descender: {:.2}px (negative: {})\n", .{descender_px, metrics.descender});
    std.debug.print("Line gap: {:.2}px\n", .{line_gap_px});
    std.debug.print("Calculated line_height: {:.2}px\n", .{line_height});
    std.debug.print("Expected (asc - desc + gap): {:.2}px\n", .{ascender_px - descender_px + line_gap_px});
    
    // For single line texture (current layout.zig logic)
    const single_line_texture_height = line_height;
    std.debug.print("\nSingle line texture height: {:.2}px\n", .{single_line_texture_height});
    
    // Calculate what space is actually needed
    const baseline_offset = metrics.getBaselineOffset(); // This is ascender * scale
    std.debug.print("Baseline offset (ascender space): {:.2}px\n", .{baseline_offset});
    std.debug.print("Space needed below baseline: {:.2}px\n", .{@abs(descender_px)});
    std.debug.print("Total space needed: {:.2}px\n", .{baseline_offset + @abs(descender_px)});
    
    MetricsDebugger.analyzeTextureBounds(single_line_texture_height, line_height, ascender_px, descender_px);
}

test "glyph bounds checking within texture" {
    const allocator = testing.allocator;
    
    const font_path = "static/fonts/DM_Sans/static/DMSans-Regular.ttf";
    const font_data = std.fs.cwd().readFileAlloc(allocator, font_path, 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Skipping glyph bounds test - font file not found\n", .{});
            return;
        },
        else => return err,
    };
    defer allocator.free(font_data);
    
    var parser = try ttf_parser.TTFParser.init(allocator, font_data);
    
    const rasterizer = rasterizer_core.RasterizerCore.init(allocator, &parser, 16.0, 96.0);
    
    std.debug.print("\n=== Glyph Bounds Within Texture Test ===\n", .{});
    
    // Simulate current layout.zig logic
    const cursor_y: f32 = 0; // Start at top
    const baseline_offset = rasterizer.metrics.getBaselineOffset();
    const texture_height = rasterizer.metrics.getLineHeight(); // Current single-line calculation
    
    std.debug.print("Texture simulation:\n", .{});
    std.debug.print("  cursor_y: {:.2}px\n", .{cursor_y});
    std.debug.print("  baseline_offset: {:.2}px\n", .{baseline_offset});
    std.debug.print("  texture_height: {:.2}px\n", .{texture_height});
    std.debug.print("  baseline position: {:.2}px\n", .{cursor_y + baseline_offset});
    
    // Test characters that might cause problems
    const problem_chars = "gjpqy"; // All descenders
    const normal_chars = "ahnox"; // Regular characters
    
    var bounds_violations = false;
    
    std.debug.print("\n=== Checking Normal Characters ===\n", .{});
    for (normal_chars) |char| {
        const result = checkGlyphBounds(allocator, &rasterizer, char, cursor_y, baseline_offset, texture_height) catch continue;
        if (!result) bounds_violations = true;
    }
    
    std.debug.print("\n=== Checking Descender Characters ===\n", .{});
    for (problem_chars) |char| {
        const result = checkGlyphBounds(allocator, &rasterizer, char, cursor_y, baseline_offset, texture_height) catch continue;
        if (!result) bounds_violations = true;
    }
    
    if (bounds_violations) {
        std.debug.print("\n❌ BOUNDS VIOLATIONS FOUND!\n", .{});
        std.debug.print("This explains why descenders are being cut off.\n", .{});
    } else {
        std.debug.print("\n✓ All characters fit within texture bounds\n", .{});
    }
}

// Helper function to check if a glyph fits within texture bounds
fn checkGlyphBounds(
    allocator: std.mem.Allocator, 
    rasterizer: *const rasterizer_core.RasterizerCore,
    char: u8, 
    cursor_y: f32, 
    baseline_offset: f32, 
    texture_height: f32
) !bool {
    const outline = rasterizer.extractor.extractGlyph(char) catch |err| {
        std.debug.print("Failed to extract '{}': {}\n", .{@as(u21, char), err});
        return err;
    };
    defer outline.deinit(allocator);
    
    const rasterized = rasterizer.rasterizeGlyph(char, 0.0, 0.0) catch |err| {
        std.debug.print("Failed to rasterize '{}': {}\n", .{@as(u21, char), err});
        return err;
    };
    defer allocator.free(rasterized.bitmap);
    
    // Apply layout.zig positioning formula
    const glyph_y = cursor_y + baseline_offset - @as(f32, @floatFromInt(rasterized.bearing_y));
    const glyph_bottom = glyph_y + @as(f32, @floatFromInt(rasterized.height));
    
    std.debug.print("'{}': y_min={:.1}, glyph_y={:.2}, height={}, bottom={:.2} ", 
        .{@as(u21, char), outline.bounds.y_min, glyph_y, rasterized.height, glyph_bottom});
    
    var fits = true;
    
    if (glyph_y < 0) {
        std.debug.print("❌ TOP VIOLATION (glyph_y < 0) ");
        fits = false;
    }
    
    if (glyph_bottom > texture_height) {
        std.debug.print("❌ BOTTOM VIOLATION (bottom > texture) ");
        fits = false;
    }
    
    if (fits) {
        std.debug.print("✓ FITS");
    }
    
    std.debug.print("\n", .{});
    return fits;
}

test "proposed texture height fix verification" {
    const allocator = testing.allocator;
    
    const font_path = "static/fonts/DM_Sans/static/DMSans-Regular.ttf";
    const font_data = std.fs.cwd().readFileAlloc(allocator, font_path, 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Skipping fix verification test - font file not found\n", .{});
            return;
        },
        else => return err,
    };
    defer allocator.free(font_data);
    
    var parser = try ttf_parser.TTFParser.init(allocator, font_data);
    
    const rasterizer = rasterizer_core.RasterizerCore.init(allocator, &parser, 16.0, 96.0);
    const metrics = rasterizer.metrics;
    
    std.debug.print("\n=== Proposed Fix Verification ===\n", .{});
    
    const cursor_y: f32 = 0;
    const baseline_offset = metrics.getBaselineOffset();
    
    // Current (problematic) height calculation
    const current_height = metrics.getLineHeight();
    
    // Proposed fix: ensure adequate space for descenders
    const ascender_px = @as(f32, @floatFromInt(metrics.ascender)) * metrics.scale;
    const descender_px = @abs(@as(f32, @floatFromInt(metrics.descender)) * metrics.scale);
    const proposed_height = baseline_offset + descender_px;
    
    std.debug.print("Current texture height: {:.2}px\n", .{current_height});
    std.debug.print("Proposed texture height: {:.2}px (baseline_offset + descender)\n", .{proposed_height});
    std.debug.print("Difference: {:.2}px\n", .{proposed_height - current_height});
    
    // Test if proposed fix would work
    std.debug.print("\nTesting with proposed height:\n", .{});
    const test_chars = "gjpqy";
    var all_fit = true;
    
    for (test_chars) |char| {
        const fits = checkGlyphBounds(allocator, &rasterizer, char, cursor_y, baseline_offset, proposed_height) catch continue;
        if (!fits) all_fit = false;
    }
    
    if (all_fit) {
        std.debug.print("\n✅ PROPOSED FIX WORKS! All descenders fit with height {:.2}px\n", .{proposed_height});
    } else {
        std.debug.print("\n❌ Proposed fix insufficient, need larger texture\n", .{});
    }
};