const std = @import("std");
const testing = std.testing;
const ttf_parser = @import("ttf_parser.zig");
const rasterizer_core = @import("rasterizer_core.zig");
const font_atlas = @import("font_atlas.zig");
const test_helpers = @import("test_helpers.zig");

/// Compare our test rasterizer output with what the font atlas actually uses
pub fn compareRasterizerWithAtlas() !void {
    const allocator = testing.allocator;

    // Initialize test loggers
    try test_helpers.initTestLoggers(allocator);
    defer test_helpers.deinitTestLoggers();

    // Load font
    const font_path = "static/fonts/DM_Sans/static/DMSans-Regular.ttf";
    const font_data = std.fs.cwd().readFileAlloc(allocator, font_path, 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Font file not found: {s} - skipping comparison\n", .{font_path});
            return;
        },
        else => return err,
    };
    defer allocator.free(font_data);

    std.debug.print("\n🔍 RASTERIZER VS ATLAS COMPARISON\n", .{});
    std.debug.print("=" ** 50 ++ "\n", .{});

    // Create rasterizer
    var parser = try ttf_parser.TTFParser.init(allocator, font_data);
    defer parser.deinit();

    var rasterizer = rasterizer_core.RasterizerCore.init(allocator, &parser, 16.0, 96.0);

    const test_char: u8 = 'A'; // Simple character to analyze

    // Test our rasterizer directly
    std.debug.print("\n--- Direct Rasterizer Output ---\n", .{});
    const rasterized = try rasterizer.rasterizeGlyph(test_char, 0.0, 0.0);
    defer allocator.free(rasterized.bitmap);

    std.debug.print("Character '{}' rasterized:\n", .{@as(u21, test_char)});
    std.debug.print("  Dimensions: {:.1}x{:.1} px\n", .{ rasterized.width, rasterized.height });
    std.debug.print("  Bearing: x={:.1}, y={:.1}\n", .{ rasterized.bearing_x, rasterized.bearing_y });
    std.debug.print("  Advance: {:.1}\n", .{rasterized.advance});
    std.debug.print("  Bitmap size: {} bytes\n", .{rasterized.bitmap.len});

    // Analyze bitmap content
    var filled_pixels: u32 = 0;
    var empty_pixels: u32 = 0;
    for (rasterized.bitmap) |pixel| {
        if (pixel > 0) filled_pixels += 1 else empty_pixels += 1;
    }

    std.debug.print("  Bitmap analysis: {} filled, {} empty pixels\n", .{ filled_pixels, empty_pixels });
    std.debug.print("  Fill ratio: {:.1}%\n", .{@as(f32, @floatFromInt(filled_pixels)) * 100.0 / @as(f32, @floatFromInt(rasterized.bitmap.len))});

    // Save both regular and Y-flipped versions for comparison
    try saveBitmapComparison(allocator, &rasterized, test_char);

    std.debug.print("\n✅ Bitmap comparison files saved:\n", .{});
    std.debug.print("  .test_output/atlas_comparison_{}_normal.ppm\n", .{test_char});
    std.debug.print("  .test_output/atlas_comparison_{}_flipped.ppm\n", .{test_char});
}

fn saveBitmapComparison(allocator: std.mem.Allocator, rasterized: *const rasterizer_core.RasterizedGlyph, char: u8) !void {
    _ = allocator;

    const width = @as(u32, @intFromFloat(rasterized.width));
    const height = @as(u32, @intFromFloat(rasterized.height));

    // Create output directory
    std.fs.cwd().makeDir(".test_output") catch {};

    // Save normal orientation
    {
        var filename_buf: [256]u8 = undefined;
        const filename = try std.fmt.bufPrint(filename_buf[0..], ".test_output/atlas_comparison_{}_normal.ppm", .{char});

        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();

        try file.writer().print("P2\n{} {}\n255\n", .{ width, height });

        for (0..height) |y| {
            for (0..width) |x| {
                const idx = y * width + x;
                const pixel = if (idx < rasterized.bitmap.len) rasterized.bitmap[idx] else 0;
                try file.writer().print("{} ", .{pixel});
            }
            try file.writer().print("\n", .{});
        }
    }

    // Save Y-flipped orientation (match GPU texture coordinates)
    {
        var filename_buf: [256]u8 = undefined;
        const filename = try std.fmt.bufPrint(filename_buf[0..], ".test_output/atlas_comparison_{}_flipped.ppm", .{char});

        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();

        try file.writer().print("P2\n{} {}\n255\n", .{ width, height });

        for (0..height) |y| {
            for (0..width) |x| {
                const flipped_y = height - 1 - y;
                const idx = flipped_y * width + x;
                const pixel = if (idx < rasterized.bitmap.len) rasterized.bitmap[idx] else 0;
                try file.writer().print("{} ", .{pixel});
            }
            try file.writer().print("\n", .{});
        }
    }
}

test "atlas comparison test" {
    try compareRasterizerWithAtlas();
}
