const std = @import("std");
const testing = std.testing;
const debug = @import("metrics_debug.zig");
const rasterizer_core = @import("../../../../lib/font/rasterizer_core.zig");
const ttf_parser = @import("../../../../lib/font/ttf_parser.zig");
const glyph_extractor = @import("../../../../lib/font/glyph_extractor.zig");

const MetricsDebugger = debug.MetricsDebugger;
const TestGlyph = debug.TestGlyph;

// Test descender characters using the DM Sans font
test "descender analysis with DM Sans font" {
    const allocator = testing.allocator;
    
    // Load the DM Sans font file
    const font_path = "static/fonts/DM_Sans/static/DMSans-Regular.ttf";
    const font_data = std.fs.cwd().readFileAlloc(allocator, font_path, 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Font file not found: {s}\n", .{font_path});
            std.debug.print("Skipping test - font file required for descender analysis\n", .{});
            return;
        },
        else => return err,
    };
    defer allocator.free(font_data);
    
    // Parse the font
    var parser = try ttf_parser.TTFParser.init(allocator, font_data);
    
    // Create rasterizer with typical web font size
    const rasterizer = rasterizer_core.RasterizerCore.init(allocator, &parser, 16.0, 96.0);
    
    // Log font metrics first
    MetricsDebugger.logFontMetrics(rasterizer.metrics);
    
    // Test specific descender characters
    const test_chars = "gjpqyAhn"; // Mix of descenders and normal chars
    var test_glyphs = std.ArrayList(TestGlyph).init(allocator);
    defer test_glyphs.deinit();
    
    for (test_chars) |char| {
        std.debug.print("\n" ++ "="*50 ++ "\n", .{});
        
        // Extract outline
        const outline = rasterizer.extractor.extractGlyph(char) catch |err| {
            std.debug.print("Failed to extract glyph '{}': {}\n", .{@as(u21, char), err});
            continue;
        };
        defer outline.deinit(allocator);
        
        // Rasterize glyph
        const rasterized = rasterizer.rasterizeGlyph(char, 0.0, 0.0) catch |err| {
            std.debug.print("Failed to rasterize glyph '{}': {}\n", .{@as(u21, char), err});
            continue;
        };
        defer allocator.free(rasterized.bitmap);
        
        // Log detailed analysis
        MetricsDebugger.logGlyphData(char, outline, rasterized);
        
        // Store for comparison
        const test_glyph = MetricsDebugger.createTestGlyph(char, outline, rasterized);
        try test_glyphs.append(test_glyph);
    }
    
    // Compare all glyphs
    if (test_glyphs.items.len > 0) {
        MetricsDebugger.analyzeDescenders(rasterizer.metrics, test_glyphs.items);
    }
}

test "specific descender character 'g'" {
    const allocator = testing.allocator;
    
    const font_path = "static/fonts/DM_Sans/static/DMSans-Regular.ttf";
    const font_data = std.fs.cwd().readFileAlloc(allocator, font_path, 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Skipping 'g' test - font file not found\n", .{});
            return;
        },
        else => return err,
    };
    defer allocator.free(font_data);
    
    var parser = try ttf_parser.TTFParser.init(allocator, font_data);
    
    const rasterizer = rasterizer_core.RasterizerCore.init(allocator, &parser, 20.0, 96.0);
    
    const outline = try rasterizer.extractor.extractGlyph('g');
    defer outline.deinit(allocator);
    
    const rasterized = try rasterizer.rasterizeGlyph('g', 0.0, 0.0);
    defer allocator.free(rasterized.bitmap);
    
    std.debug.print("\n=== Focused Analysis: 'g' ===\n", .{});
    MetricsDebugger.logGlyphData('g', outline, rasterized);
    
    // Verify descender behavior
    try testing.expect(outline.bounds.y_min < 0); // Should extend below baseline
    
    // bearing_y should be distance from baseline to top
    // For 'g', this should be less than the ascender since it's not a tall character
    const font_ascender = @as(f32, @floatFromInt(rasterizer.metrics.ascender)) * rasterizer.metrics.scale;
    try testing.expect(@as(f32, @floatFromInt(rasterized.bearing_y)) <= font_ascender);
    
    std.debug.print("✓ Descender test for 'g' passed\n", .{});
}

test "baseline positioning analysis" {
    const allocator = testing.allocator;
    
    const font_path = "static/fonts/DM_Sans/static/DMSans-Regular.ttf";
    const font_data = std.fs.cwd().readFileAlloc(allocator, font_path, 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Skipping baseline test - font file not found\n", .{});
            return;
        },
        else => return err,
    };
    defer allocator.free(font_data);
    
    var parser = try ttf_parser.TTFParser.init(allocator, font_data);
    
    const rasterizer = rasterizer_core.RasterizerCore.init(allocator, &parser, 16.0, 96.0);
    
    std.debug.print("\n=== Baseline Positioning Analysis ===\n", .{});
    
    // Simulate layout positioning like in layout.zig
    const cursor_y: f32 = 0; // Start at top of texture
    const baseline_offset = rasterizer.metrics.getBaselineOffset();
    const line_height = rasterizer.metrics.getLineHeight();
    
    std.debug.print("Layout simulation:\n", .{});
    std.debug.print("  cursor_y (start): {:.2}px\n", .{cursor_y});
    std.debug.print("  baseline_offset: {:.2}px\n", .{baseline_offset});
    std.debug.print("  line_height: {:.2}px\n", .{line_height});
    
    // Test positioning for both regular and descender characters
    const test_chars = "ag"; // 'a' = regular, 'g' = descender
    
    for (test_chars) |char| {
        const outline = rasterizer.extractor.extractGlyph(char) catch continue;
        defer outline.deinit(allocator);
        
        const rasterized = rasterizer.rasterizeGlyph(char, 0.0, 0.0) catch continue;
        defer allocator.free(rasterized.bitmap);
        
        // Calculate Y position using layout.zig formula
        const glyph_y = cursor_y + baseline_offset - @as(f32, @floatFromInt(rasterized.bearing_y));
        
        MetricsDebugger.logLayoutPositioning(char, glyph_y, cursor_y, baseline_offset, rasterized.bearing_y, line_height);
        
        // For descenders, check if they would extend beyond texture
        if (outline.bounds.y_min < 0) {
            const glyph_bottom = glyph_y + @as(f32, @floatFromInt(rasterized.height));
            std.debug.print("  Descender bottom position: {:.2}px (texture height: {:.2}px)\n", .{glyph_bottom, line_height});
            if (glyph_bottom > line_height) {
                std.debug.print("  ❌ PROBLEM: Descender extends beyond texture bounds!\n", .{});
            }
        }
    }
}

test "texture bounds verification" {
    const allocator = testing.allocator;
    
    const font_path = "static/fonts/DM_Sans/static/DMSans-Regular.ttf";
    const font_data = std.fs.cwd().readFileAlloc(allocator, font_path, 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Skipping bounds test - font file not found\n", .{});
            return;
        },
        else => return err,
    };
    defer allocator.free(font_data);
    
    var parser = ttf_parser.TTFParser.init(font_data) catch |err| {
        std.debug.print("Failed to parse font for bounds test: {}\n", .{err});
        return;
    };
    
    const rasterizer = rasterizer_core.RasterizerCore.init(allocator, &parser, 16.0, 96.0);
    
    const metrics = rasterizer.metrics;
    const line_height = metrics.getLineHeight();
    const ascender = @as(f32, @floatFromInt(metrics.ascender)) * metrics.scale;
    const descender = @as(f32, @floatFromInt(metrics.descender)) * metrics.scale;
    
    MetricsDebugger.analyzeTextureBounds(line_height, line_height, ascender, descender);
    
    // Test the texture height calculation from layout.zig
    std.debug.print("\n=== Layout.zig Texture Height Analysis ===\n", .{});
    
    // Single line case (what layout.zig currently does)
    const single_line_height = line_height;
    std.debug.print("Single line texture height: {:.2}px\n", .{single_line_height});
    
    // What it should be for proper descender support
    const proper_height = ascender + @abs(descender);
    std.debug.print("Proper height for ascender + descender: {:.2}px\n", .{proper_height});
    
    if (single_line_height < proper_height) {
        std.debug.print("❌ Current texture height ({:.2}px) too small for proper descender support!\n", .{single_line_height});
        std.debug.print("   Should be at least {:.2}px\n", .{proper_height});
    } else {
        std.debug.print("✓ Texture height appears adequate\n", .{});
    }
}