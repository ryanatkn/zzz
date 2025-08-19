const std = @import("std");
const testing = std.testing;
const ttf_parser = @import("../ttf_parser.zig");
const rasterizer_core = @import("../rasterizer_core.zig");
const test_helpers = @import("../test_helpers.zig");

// Consolidated character analysis test that combines baseline, descender, capital letter,
// and specific character (pqy) analysis into a single comprehensive test

const CharacterData = struct {
    char: u8,
    type: CharacterType,
    y_min: f32,
    y_max: f32,
    bearing_y: f32,
    first_ink_row: ?u32,
    last_ink_row: ?u32,
    baseline_row: f32,
};

const CharacterType = enum {
    regular, // a, e, n, o
    descender, // g, j, p, q, y
    capital, // A, B, C, etc.
    tall, // b, d, f, h, k, l, t
};

test "comprehensive character analysis - baseline and alignment" {
    const allocator = testing.allocator;

    // Initialize loggers for font system
    try test_helpers.initTestLoggers(allocator);
    defer test_helpers.deinitTestLoggers();

    // Try to load DM Sans font
    const font_path = "static/fonts/DM_Sans/static/DMSans-Regular.ttf";
    const font_data = std.fs.cwd().readFileAlloc(allocator, font_path, 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Font file not found: {s} - skipping comprehensive character analysis\n", .{font_path});
            return;
        },
        else => return err,
    };
    defer allocator.free(font_data);

    std.debug.print("\n📊 COMPREHENSIVE CHARACTER ANALYSIS\n", .{});
    std.debug.print("=" ** 80 ++ "\n", .{});

    // Parse the font
    var parser = try ttf_parser.TTFParser.init(allocator, font_data);
    defer parser.deinit();

    // Create rasterizer
    var rasterizer = rasterizer_core.RasterizerCore.init(allocator, &parser, 16.0, 96.0);

    // Test character sets by type
    const test_chars = [_]struct { char: u8, char_type: CharacterType }{
        // Regular characters (sit on baseline, extend to x-height)
        .{ .char = 'n', .char_type = .regular },
        .{ .char = 'o', .char_type = .regular },
        .{ .char = 'a', .char_type = .regular },
        .{ .char = 'e', .char_type = .regular },

        // Descender characters (extend below baseline)
        .{ .char = 'g', .char_type = .descender },
        .{ .char = 'j', .char_type = .descender },
        .{ .char = 'p', .char_type = .descender },
        .{ .char = 'q', .char_type = .descender },
        .{ .char = 'y', .char_type = .descender },

        // Capital letters
        .{ .char = 'A', .char_type = .capital },
        .{ .char = 'N', .char_type = .capital },
        .{ .char = 'Z', .char_type = .capital },

        // Tall characters (extend to ascender)
        .{ .char = 'b', .char_type = .tall },
        .{ .char = 'd', .char_type = .tall },
        .{ .char = 'h', .char_type = .tall },
    };

    var character_data = std.ArrayList(CharacterData).init(allocator);
    defer character_data.deinit();

    std.debug.print("Analyzing {} character types...\n\n", .{test_chars.len});

    // Analyze each character
    for (test_chars) |test_char| {
        const char = test_char.char;
        const char_type = test_char.char_type;

        const outline = rasterizer.extractor.extractGlyph(char) catch |err| {
            std.debug.print("❌ Failed to extract '{}': {}\n", .{ @as(u21, char), err });
            continue;
        };
        defer outline.deinit(allocator);

        const rasterized = rasterizer.rasterizeGlyph(char, 0.0, 0.0) catch |err| {
            std.debug.print("❌ Failed to rasterize '{}': {}\n", .{ @as(u21, char), err });
            continue;
        };
        defer allocator.free(rasterized.bitmap);

        // Analyze bitmap for first/last ink
        var first_ink_row: ?u32 = null;
        var last_ink_row: ?u32 = null;

        const height = @as(u32, @intFromFloat(rasterized.height));
        const width = @as(u32, @intFromFloat(rasterized.width));

        for (0..height) |y| {
            var has_ink = false;
            for (0..width) |x| {
                const idx = y * width + x;
                if (idx < rasterized.bitmap.len and rasterized.bitmap[idx] > 0) {
                    has_ink = true;
                    break;
                }
            }
            if (has_ink) {
                if (first_ink_row == null) first_ink_row = @as(u32, @intCast(y));
                last_ink_row = @as(u32, @intCast(y));
            }
        }

        // Calculate baseline position
        const font_descender = @as(f32, @floatFromInt(-rasterizer.metrics.descender)) * rasterizer.metrics.scale;
        const baseline_from_bottom = font_descender + 1.0;
        const baseline_row = @as(f32, @floatFromInt(height)) - 1.0 - baseline_from_bottom;

        try character_data.append(CharacterData{
            .char = char,
            .type = char_type,
            .y_min = outline.bounds.y_min,
            .y_max = outline.bounds.y_max,
            .bearing_y = rasterized.bearing_y,
            .first_ink_row = first_ink_row,
            .last_ink_row = last_ink_row,
            .baseline_row = baseline_row,
        });

        std.debug.print("'{c}' ({s}): y_min={:.2}, y_max={:.2}, bearing_y={:.1}, ink rows {?}-{?}, baseline={:.1}\n", .{ char, @tagName(char_type), outline.bounds.y_min, outline.bounds.y_max, rasterized.bearing_y, first_ink_row, last_ink_row, baseline_row });
    }

    // Analysis by character type
    std.debug.print("\n--- CHARACTER TYPE ANALYSIS ---\n", .{});

    const types_to_analyze = [_]CharacterType{ .regular, .descender, .capital, .tall };
    for (types_to_analyze) |char_type| {
        std.debug.print("\n{s} Characters:\n", .{@tagName(char_type)});

        var type_chars = std.ArrayList(*const CharacterData).init(allocator);
        defer type_chars.deinit();

        for (character_data.items) |*data| {
            if (data.type == char_type) {
                try type_chars.append(data);
            }
        }

        if (type_chars.items.len == 0) continue;

        // Calculate averages for this type
        var avg_y_min: f32 = 0;
        var avg_y_max: f32 = 0;
        var avg_bearing_y: f32 = 0;
        var avg_baseline: f32 = 0;

        for (type_chars.items) |data| {
            avg_y_min += data.y_min;
            avg_y_max += data.y_max;
            avg_bearing_y += data.bearing_y;
            avg_baseline += data.baseline_row;
        }

        const count = @as(f32, @floatFromInt(type_chars.items.len));
        avg_y_min /= count;
        avg_y_max /= count;
        avg_bearing_y /= count;
        avg_baseline /= count;

        std.debug.print("  Average y_min: {:.2}, y_max: {:.2}\n", .{ avg_y_min, avg_y_max });
        std.debug.print("  Average bearing_y: {:.1}, baseline: {:.1}\n", .{ avg_bearing_y, avg_baseline });

        // Check consistency
        var min_baseline = avg_baseline;
        var max_baseline = avg_baseline;
        for (type_chars.items) |data| {
            min_baseline = @min(min_baseline, data.baseline_row);
            max_baseline = @max(max_baseline, data.baseline_row);
        }

        const baseline_range = max_baseline - min_baseline;
        std.debug.print("  Baseline consistency: {:.3} pixel range", .{baseline_range});
        if (baseline_range < 1.0) {
            std.debug.print(" ✅ Good\n", .{});
        } else {
            std.debug.print(" ⚠️  Inconsistent\n", .{});
        }
    }

    // Cross-type baseline consistency check
    std.debug.print("\n--- BASELINE CONSISTENCY CHECK ---\n", .{});

    if (character_data.items.len > 0) {
        var min_baseline: f32 = character_data.items[0].baseline_row;
        var max_baseline: f32 = character_data.items[0].baseline_row;

        for (character_data.items) |data| {
            min_baseline = @min(min_baseline, data.baseline_row);
            max_baseline = @max(max_baseline, data.baseline_row);
        }

        const overall_range = max_baseline - min_baseline;
        std.debug.print("Overall baseline range: {:.3} pixels\n", .{overall_range});

        if (overall_range < 2.0) {
            std.debug.print("✅ EXCELLENT: All character types align to same baseline\n", .{});
        } else if (overall_range < 5.0) {
            std.debug.print("⚠️  ACCEPTABLE: Minor baseline variations detected\n", .{});
        } else {
            std.debug.print("❌ PROBLEM: Significant baseline misalignment detected\n", .{});
        }

        // Detailed analysis for problem cases
        if (overall_range >= 2.0) {
            std.debug.print("\nDetailed baseline positions:\n", .{});
            for (character_data.items) |data| {
                std.debug.print("  '{c}': {:.3} px\n", .{ data.char, data.baseline_row });
            }
        }
    }

    // Descender-specific analysis
    std.debug.print("\n--- DESCENDER ANALYSIS ---\n", .{});

    var has_descenders = false;
    var max_descent: f32 = 0;

    for (character_data.items) |data| {
        if (data.type == .descender and data.y_min < 0) {
            has_descenders = true;
            max_descent = @max(max_descent, -data.y_min);
            std.debug.print("'{c}': descends {:.2}px below baseline\n", .{ data.char, -data.y_min });
        }
    }

    if (has_descenders) {
        std.debug.print("Maximum descent: {:.2}px\n", .{max_descent});
        std.debug.print("✅ Descender characters properly extend below baseline\n", .{});
    } else {
        std.debug.print("⚠️  No descender extension detected - potential issue\n", .{});
    }

    std.debug.print("\n📊 ANALYSIS COMPLETE\n", .{});
    std.debug.print("Analyzed {} characters across {} character types\n", .{ character_data.items.len, types_to_analyze.len });

    // Ensure we analyzed a reasonable number of characters
    try testing.expect(character_data.items.len >= 10);
}
