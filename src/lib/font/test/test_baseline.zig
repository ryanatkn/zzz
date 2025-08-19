const std = @import("std");
const testing = std.testing;
const debug = @import("metrics_debug.zig");
const layout = @import("../../text/layout.zig");
const font_atlas = @import("../font_atlas.zig");
const rasterizer_core = @import("../rasterizer_core.zig");
const ttf_parser = @import("../ttf_parser.zig");

const MetricsDebugger = debug.MetricsDebugger;

test "baseline alignment verification" {
    const allocator = testing.allocator;
    
    // Load font
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
    MetricsDebugger.logFontMetrics(rasterizer.metrics);
    
    std.debug.print("\n=== Baseline Alignment Test ===\n", .{});
    
    // Test text with mixed character types
    const test_text = "Typography"; // Contains 'y' (descender), 'T' (tall), and regular chars
    
    // Simulate the layout calculation
    const cursor_y: f32 = 0;
    const baseline_offset = rasterizer.metrics.getBaselineOffset();
    const baseline_pos = cursor_y + baseline_offset;
    
    std.debug.print("Expected baseline position: {:.2}px\n", .{baseline_pos});
    
    var baseline_positions = std.ArrayList(f32).init(allocator);
    defer baseline_positions.deinit();
    
    for (test_text) |char| {
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
        
        // Calculate where the baseline would be for this glyph
        const glyph_y = cursor_y + baseline_offset - @as(f32, @floatFromInt(rasterized.bearing_y));
        const glyph_baseline = glyph_y + @as(f32, @floatFromInt(rasterized.bearing_y));
        
        std.debug.print("'{}': glyph_y={:.2}, bearing_y={}, calculated baseline={:.2}\n", 
            .{@as(u21, char), glyph_y, rasterized.bearing_y, glyph_baseline});
        
        try baseline_positions.append(glyph_baseline);
        
        // Verify baseline consistency
        const baseline_diff = @abs(glyph_baseline - baseline_pos);
        if (baseline_diff > 0.1) { // Allow small floating point differences
            std.debug.print("  ⚠️  Baseline mismatch! Expected {:.2}, got {:.2} (diff: {:.2})\n", 
                .{baseline_pos, glyph_baseline, baseline_diff});
        }
    }
    
    // Verify all baselines are the same
    if (baseline_positions.items.len > 1) {
        const first_baseline = baseline_positions.items[0];
        var max_diff: f32 = 0;
        
        for (baseline_positions.items[1..]) |pos| {
            const diff = @abs(pos - first_baseline);
            max_diff = @max(max_diff, diff);
        }
        
        std.debug.print("\nBaseline consistency: max difference = {:.3}px\n", .{max_diff});
        if (max_diff < 0.1) {
            std.debug.print("✓ All characters align to same baseline\n", .{});
        } else {
            std.debug.print("❌ Baseline alignment inconsistent\n", .{});
        }
    }
}

test "descender positioning relative to baseline" {
    const allocator = testing.allocator;
    
    const font_path = "static/fonts/DM_Sans/static/DMSans-Regular.ttf";
    const font_data = std.fs.cwd().readFileAlloc(allocator, font_path, 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Skipping descender positioning test - font file not found\n", .{});
            return;
        },
        else => return err,
    };
    defer allocator.free(font_data);
    
    var parser = try ttf_parser.TTFParser.init(allocator, font_data);
    
    const rasterizer = rasterizer_core.RasterizerCore.init(allocator, &parser, 20.0, 96.0);
    
    std.debug.print("\n=== Descender Position Analysis ===\n", .{});
    
    const cursor_y: f32 = 0;
    const baseline_offset = rasterizer.metrics.getBaselineOffset();
    const baseline_pos = cursor_y + baseline_offset;
    
    std.debug.print("Baseline position in texture: {:.2}px\n", .{baseline_pos});
    
    // Test a character with a descender
    const outline = try rasterizer.extractor.extractGlyph('g');
    defer outline.deinit(allocator);
    
    const rasterized = try rasterizer.rasterizeGlyph('g', 0.0, 0.0);
    defer allocator.free(rasterized.bitmap);
    
    // Calculate positioning
    const glyph_y = cursor_y + baseline_offset - @as(f32, @floatFromInt(rasterized.bearing_y));
    const glyph_bottom = glyph_y + @as(f32, @floatFromInt(rasterized.height));
    
    std.debug.print("\nGlyph 'g' positioning:\n", .{});
    std.debug.print("  Outline bounds: y_min={:.2}, y_max={:.2}\n", .{outline.bounds.y_min, outline.bounds.y_max});
    std.debug.print("  bearing_y: {}\n", .{rasterized.bearing_y});
    std.debug.print("  Glyph top (glyph_y): {:.2}px\n", .{glyph_y});
    std.debug.print("  Glyph bottom: {:.2}px\n", .{glyph_bottom});
    std.debug.print("  Descender extends {:.2}px below baseline\n", .{@max(0, glyph_bottom - baseline_pos)});
    
    // Verify descender behavior
    try testing.expect(outline.bounds.y_min < 0); // Should extend below baseline
    
    // In TrueType coordinates, bearing_y should equal bounds.y_max
    const expected_bearing_y = @as(i32, @intFromFloat(@round(outline.bounds.y_max)));
    std.debug.print("  Expected bearing_y from bounds.y_max: {}\n", .{expected_bearing_y});
    
    // Small difference allowed due to rounding
    const bearing_diff = @abs(rasterized.bearing_y - expected_bearing_y);
    try testing.expect(bearing_diff <= 1);
    
    std.debug.print("✓ Descender positioning analysis complete\n", .{});
}

test "compare normal vs descender character positioning" {
    const allocator = testing.allocator;
    
    const font_path = "static/fonts/DM_Sans/static/DMSans-Regular.ttf";
    const font_data = std.fs.cwd().readFileAlloc(allocator, font_path, 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Skipping comparison test - font file not found\n", .{});
            return;
        },
        else => return err,
    };
    defer allocator.free(font_data);
    
    var parser = try ttf_parser.TTFParser.init(allocator, font_data);
    
    const rasterizer = rasterizer_core.RasterizerCore.init(allocator, &parser, 16.0, 96.0);
    
    std.debug.print("\n=== Normal vs Descender Comparison ===\n", .{});
    
    const cursor_y: f32 = 0;
    const baseline_offset = rasterizer.metrics.getBaselineOffset();
    
    // Test pairs: normal char vs descender
    const test_pairs = [_][2]u8{ .{'a', 'g'}, .{'n', 'y'}, .{'o', 'p'} };
    
    for (test_pairs) |pair| {
        const normal_char = pair[0];
        const desc_char = pair[1];
        
        std.debug.print("\nComparing '{}' vs '{}'\n", .{@as(u21, normal_char), @as(u21, desc_char)});
        
        for ([_]u8{normal_char, desc_char}) |char| {
            const outline = rasterizer.extractor.extractGlyph(char) catch continue;
            defer outline.deinit(allocator);
            
            const rasterized = rasterizer.rasterizeGlyph(char, 0.0, 0.0) catch continue;
            defer allocator.free(rasterized.bitmap);
            
            const glyph_y = cursor_y + baseline_offset - @as(f32, @floatFromInt(rasterized.bearing_y));
            const glyph_bottom = glyph_y + @as(f32, @floatFromInt(rasterized.height));
            
            std.debug.print("  '{}': y_min={:.2}, y_max={:.2}, bearing_y={}, glyph_y={:.2}, bottom={:.2}\n", 
                .{@as(u21, char), outline.bounds.y_min, outline.bounds.y_max, rasterized.bearing_y, glyph_y, glyph_bottom});
            
            if (outline.bounds.y_min < 0) {
                std.debug.print("    └─ Descender: extends {:.2}px below baseline\n", .{-outline.bounds.y_min});
            }
        }
    }
};