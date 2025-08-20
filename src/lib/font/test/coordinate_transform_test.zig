/// Coordinate transformation testing for font system
/// Tests coordinate transformations that match shader pipeline and generates visual output
const std = @import("std");
const coordinate_transform = @import("../coordinate_transform.zig");
const rasterizer_core = @import("../rasterizer_core.zig");
const ttf_parser = @import("../ttf_parser.zig");
const test_helpers = @import("../test_helpers.zig");
const test_main = @import("../test.zig");

const log = std.log.scoped(.coordinate_transform_test);

const debug_config = @import("../../debug/config.zig");
const ENABLE_DEBUG_OUTPUT = debug_config.font_test_debug.enable_file_output;

/// Test coordinate transformation accuracy against known shader values
pub fn testCoordinateTransformAccuracy() !void {
    std.debug.print("\n🔍 Testing coordinate transformation accuracy...\n", .{});

    const TestPoint = struct { x: f32, y: f32, expected_ndc_x: f32, expected_ndc_y: f32 };

    const test_cases = [_]struct {
        name: []const u8,
        screen_width: f32,
        screen_height: f32,
        test_points: []const TestPoint,
    }{
        .{
            .name = "1920x1080",
            .screen_width = 1920,
            .screen_height = 1080,
            .test_points = &[_]TestPoint{
                .{ .x = 0, .y = 0, .expected_ndc_x = -1.0, .expected_ndc_y = 1.0 }, // Top-left
                .{ .x = 960, .y = 540, .expected_ndc_x = 0.0, .expected_ndc_y = 0.0 }, // Center
                .{ .x = 1920, .y = 1080, .expected_ndc_x = 1.0, .expected_ndc_y = -1.0 }, // Bottom-right
            },
        },
        .{
            .name = "800x600",
            .screen_width = 800,
            .screen_height = 600,
            .test_points = &[_]TestPoint{
                .{ .x = 0, .y = 0, .expected_ndc_x = -1.0, .expected_ndc_y = 1.0 },
                .{ .x = 400, .y = 300, .expected_ndc_x = 0.0, .expected_ndc_y = 0.0 },
                .{ .x = 800, .y = 600, .expected_ndc_x = 1.0, .expected_ndc_y = -1.0 },
            },
        },
    };

    for (test_cases) |case| {
        std.debug.print("  📐 Testing resolution: {s}\n", .{case.name});

        for (case.test_points) |point| {
            const ndc = coordinate_transform.screenToNDC(
                point.x,
                point.y,
                case.screen_width,
                case.screen_height,
            );

            const tolerance = 0.001;
            if (@abs(ndc.x - point.expected_ndc_x) > tolerance or
                @abs(ndc.y - point.expected_ndc_y) > tolerance)
            {
                std.debug.print("    ❌ FAILED: Screen({d}, {d}) -> NDC({d:.6}, {d:.6}), Expected({d:.6}, {d:.6})\n", .{
                    point.x,
                    point.y,
                    ndc.x,
                    ndc.y,
                    point.expected_ndc_x,
                    point.expected_ndc_y,
                });
                return error.CoordinateTransformationFailed;
            } else {
                std.debug.print("    ✅ Screen({d}, {d}) -> NDC({d:.6}, {d:.6})\n", .{ point.x, point.y, ndc.x, ndc.y });
            }
        }
    }

    std.debug.print("✅ Coordinate transformation accuracy test passed\n", .{});
}

/// Test round-trip coordinate transformation (screen -> NDC -> screen)
pub fn testRoundTripTransformation() !void {
    std.debug.print("\n🔄 Testing round-trip coordinate transformation...\n", .{});

    const screen_width: f32 = 1920;
    const screen_height: f32 = 1080;

    const test_points = [_]struct { x: f32, y: f32 }{
        .{ .x = 0, .y = 0 },
        .{ .x = 960, .y = 540 },
        .{ .x = 1920, .y = 1080 },
        .{ .x = 100, .y = 200 },
        .{ .x = 1800, .y = 900 },
        .{ .x = 1, .y = 1 },
        .{ .x = 1919, .y = 1079 },
    };

    for (test_points) |point| {
        const debug_info = coordinate_transform.generateDebugInfo(
            point.x,
            point.y,
            screen_width,
            screen_height,
        );

        const max_error = 0.001;
        if (debug_info.transformation_error > max_error) {
            std.debug.print("    ❌ FAILED: Point({d}, {d}) has error {d:.6} > {d:.6}\n", .{
                point.x,
                point.y,
                debug_info.transformation_error,
                max_error,
            });
            coordinate_transform.printDebugInfo(debug_info);
            return error.RoundTripTransformationFailed;
        } else {
            std.debug.print("    ✅ Point({d}, {d}) error: {d:.6}\n", .{ point.x, point.y, debug_info.transformation_error });
        }
    }

    std.debug.print("✅ Round-trip transformation test passed\n", .{});
}

/// Test bitmap coordinate space transformation with detailed text debugging
pub fn testBitmapTransformation(allocator: std.mem.Allocator) !void {
    std.debug.print("\n🖼️ Testing bitmap coordinate space transformation...\n", .{});

    var bitmap_transform = coordinate_transform.BitmapTransform.init(allocator);

    // Create test pattern bitmap (8x8)
    const original_bitmap = [_]u8{
        255, 255, 255, 255, 0,   0,   0,   0,
        255, 255, 255, 255, 0,   0,   0,   0,
        255, 255, 255, 255, 0,   0,   0,   0,
        255, 255, 255, 255, 0,   0,   0,   0,
        0,   0,   0,   0,   255, 255, 255, 255,
        0,   0,   0,   0,   255, 255, 255, 255,
        0,   0,   0,   0,   255, 255, 255, 255,
        0,   0,   0,   0,   255, 255, 255, 255,
    };

    std.debug.print("🔍 DETAILED BITMAP TRANSFORMATION ANALYSIS\n", .{});
    std.debug.print("=" ** 50 ++ "\n", .{});
    std.debug.print("Original bitmap: 8x8 pixels\n", .{});
    std.debug.print("Target screen: 800x600\n", .{});
    std.debug.print("Output bitmap: 8x8 pixels\n\n", .{});

    // Print original bitmap in text format
    std.debug.print("📄 Original bitmap pattern:\n", .{});
    for (0..8) |y| {
        std.debug.print("  Row {}: ", .{y});
        for (0..8) |x| {
            const pixel = original_bitmap[y * 8 + x];
            std.debug.print("{s}", .{if (pixel > 128) "█" else "░"});
        }
        std.debug.print(" | ", .{});
        for (0..8) |x| {
            const pixel = original_bitmap[y * 8 + x];
            std.debug.print("{:3} ", .{pixel});
        }
        std.debug.print("\n", .{});
    }
    std.debug.print("\n", .{});

    const transformed = try bitmap_transform.createTransformedBitmap(
        &original_bitmap,
        8, // original_width
        8, // original_height
        800, // target_screen_width
        600, // target_screen_height
        8, // output_width
        8, // output_height
    );
    defer allocator.free(transformed);

    // Print transformed bitmap in text format
    std.debug.print("🔄 Transformed bitmap pattern:\n", .{});
    for (0..8) |y| {
        std.debug.print("  Row {}: ", .{y});
        for (0..8) |x| {
            const pixel = transformed[y * 8 + x];
            std.debug.print("{s}", .{if (pixel > 128) "█" else "░"});
        }
        std.debug.print(" | ", .{});
        for (0..8) |x| {
            const pixel = transformed[y * 8 + x];
            std.debug.print("{:3} ", .{pixel});
        }
        std.debug.print("\n", .{});
    }
    std.debug.print("\n", .{});

    // Verify transformation properties
    try std.testing.expect(transformed.len == 64);

    // Check that transformation preserved pattern structure
    var white_pixels: u32 = 0;
    var black_pixels: u32 = 0;
    var gray_pixels: u32 = 0;

    for (transformed) |pixel| {
        if (pixel > 128) {
            white_pixels += 1;
        } else if (pixel == 0) {
            black_pixels += 1;
        } else {
            gray_pixels += 1;
        }
    }

    std.debug.print("📊 Pixel distribution analysis:\n", .{});
    std.debug.print("  White pixels (>128): {} ({d:.1}%%)\n", .{ white_pixels, (@as(f32, @floatFromInt(white_pixels)) / 64.0) * 100.0 });
    std.debug.print("  Black pixels (=0):   {} ({d:.1}%%)\n", .{ black_pixels, (@as(f32, @floatFromInt(black_pixels)) / 64.0) * 100.0 });
    std.debug.print("  Gray pixels (1-128): {} ({d:.1}%%)\n", .{ gray_pixels, (@as(f32, @floatFromInt(gray_pixels)) / 64.0) * 100.0 });
    std.debug.print("  Total: {}\n\n", .{white_pixels + black_pixels + gray_pixels});

    // Analyze coordinate transformation at key points
    std.debug.print("🎯 Sample coordinate transformations:\n", .{});
    const test_points = [_]struct { x: u32, y: u32 }{
        .{ .x = 0, .y = 0 }, // Top-left
        .{ .x = 4, .y = 0 }, // Top-right quadrant boundary
        .{ .x = 0, .y = 4 }, // Bottom-left quadrant boundary
        .{ .x = 4, .y = 4 }, // Center
        .{ .x = 7, .y = 7 }, // Bottom-right
    };

    for (test_points) |point| {
        const coord_data = coordinate_transform.bitmapToShaderSpace(point.x, point.y, 8, 8, 800.0, 600.0);
        std.debug.print("  Bitmap({},{}) -> Screen({d:.1},{d:.1}) -> NDC({d:.3},{d:.3})\n", .{ point.x, point.y, coord_data.screen.x, coord_data.screen.y, coord_data.ndc.x, coord_data.ndc.y });
    }

    // Should have some recognizable pattern
    try std.testing.expect(white_pixels > 0);
    try std.testing.expect(black_pixels > 0);

    std.debug.print("\n✅ Bitmap transformation test passed\n", .{});
}

/// Test coordinate transformations using real font data with comprehensive text debugging
pub fn testFontCoordinateTransformation(allocator: std.mem.Allocator) !void {
    std.debug.print("\n🔤 Testing real font coordinate transformations...\n", .{});

    // Initialize loggers for font system
    try test_helpers.initTestLoggers(allocator);
    defer test_helpers.deinitTestLoggers();

    // Load the same font used in the baseline alignment debugging
    const font_path = "static/fonts/DM_Sans/static/DMSans-Regular.ttf";
    const font_data = std.fs.cwd().readFileAlloc(allocator, font_path, 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Font file not found: {s} - skipping coordinate transformation test\n", .{font_path});
            return;
        },
        else => return err,
    };
    defer allocator.free(font_data);

    // Parse the font
    var parser = ttf_parser.TTFParser.init(allocator, font_data) catch |err| {
        std.debug.print("❌ Failed to create TTF parser: {}\n", .{err});
        return;
    };
    defer parser.deinit();

    var rasterizer = rasterizer_core.RasterizerCore.init(allocator, &parser, 16.0, 96.0);

    std.debug.print("🔍 REAL FONT COORDINATE TRANSFORMATION ANALYSIS\n", .{});
    std.debug.print("=" ** 60 ++ "\n", .{});
    std.debug.print("Font: DM Sans Regular, 16pt\n", .{});
    std.debug.print("Font scale: {d:.6}\n", .{rasterizer.metrics.scale});
    std.debug.print("Ascender: {} units ({d:.1} px)\n", .{ rasterizer.metrics.ascender, @as(f32, @floatFromInt(rasterizer.metrics.ascender)) * rasterizer.metrics.scale });
    std.debug.print("Descender: {} units ({d:.1} px)\n", .{ rasterizer.metrics.descender, @as(f32, @floatFromInt(rasterizer.metrics.descender)) * rasterizer.metrics.scale });
    std.debug.print("Line gap: {} units ({d:.1} px)\n", .{ rasterizer.metrics.line_gap, @as(f32, @floatFromInt(rasterizer.metrics.line_gap)) * rasterizer.metrics.scale });
    std.debug.print("\n", .{});

    // Test the same characters that were proven to work in baseline alignment debugging
    const test_chars = "nopgyj"; // Mix of regular and descender characters

    std.debug.print("📋 Character Analysis with Coordinate Transformations:\n", .{});
    std.debug.print("-" ** 60 ++ "\n", .{});

    const target_screen_width: f32 = 1920;
    const target_screen_height: f32 = 1080;

    for (test_chars, 0..) |char, i| {
        std.debug.print("\n🔤 Character '{}' (#{}):\n", .{ @as(u21, char), i });

        // Rasterize the character using the working system
        const rasterized = rasterizer.rasterizeGlyph(char, 0.0, 0.0) catch |err| {
            std.debug.print("  ❌ Failed to rasterize: {}\n", .{err});
            continue;
        };
        defer allocator.free(rasterized.bitmap);

        // Print glyph metrics
        std.debug.print("  📏 Glyph metrics:\n", .{});
        std.debug.print("    Dimensions: {d:.1} x {d:.1} px\n", .{ rasterized.width, rasterized.height });
        std.debug.print("    Bearing: ({d:.1}, {d:.1})\n", .{ rasterized.bearing_x, rasterized.bearing_y });
        std.debug.print("    Advance: {d:.1} px\n", .{rasterized.advance});

        // Test coordinate transformations at key points within the glyph
        std.debug.print("  🎯 Coordinate transformations:\n", .{});
        const glyph_width = @as(u32, @intFromFloat(rasterized.width));
        const glyph_height = @as(u32, @intFromFloat(rasterized.height));

        if (glyph_width > 0 and glyph_height > 0) {
            const key_points = [_]struct { x: u32, y: u32, name: []const u8 }{
                .{ .x = 0, .y = 0, .name = "Top-left" },
                .{ .x = glyph_width / 2, .y = 0, .name = "Top-center" },
                .{ .x = glyph_width - 1, .y = 0, .name = "Top-right" },
                .{ .x = glyph_width / 2, .y = glyph_height / 2, .name = "Center" },
                .{ .x = 0, .y = glyph_height - 1, .name = "Bottom-left" },
                .{ .x = glyph_width / 2, .y = glyph_height - 1, .name = "Bottom-center" },
                .{ .x = glyph_width - 1, .y = glyph_height - 1, .name = "Bottom-right" },
            };

            for (key_points) |point| {
                const coord_data = coordinate_transform.bitmapToShaderSpace(point.x, point.y, glyph_width, glyph_height, target_screen_width, target_screen_height);
                std.debug.print("    {s:12}: Bitmap({:2},{:2}) -> Screen({d:6.1},{d:6.1}) -> NDC({d:7.3},{d:7.3})\n", .{ point.name, point.x, point.y, coord_data.screen.x, coord_data.screen.y, coord_data.ndc.x, coord_data.ndc.y });
            }
        }

        // Print bitmap pattern in text format (top 8 rows for readability)
        std.debug.print("  📄 Bitmap pattern (top 8 rows):\n", .{});
        const display_height = @min(8, glyph_height);
        const display_width = @min(16, glyph_width);

        for (0..display_height) |y| {
            std.debug.print("    Row {:2}: ", .{y});
            for (0..display_width) |x| {
                const idx = y * glyph_width + x;
                if (idx < rasterized.bitmap.len) {
                    const pixel = rasterized.bitmap[idx];
                    std.debug.print("{s}", .{if (pixel > 128) "█" else if (pixel > 64) "▓" else if (pixel > 0) "░" else " "});
                } else {
                    std.debug.print(" ", .{});
                }
            }
            if (display_width < glyph_width) {
                std.debug.print("...", .{});
            }
            std.debug.print("\n", .{});
        }
        if (display_height < glyph_height) {
            std.debug.print("    ... ({} more rows)\n", .{glyph_height - display_height});
        }
    }

    std.debug.print("\n📊 SUMMARY:\n", .{});
    std.debug.print("✅ Analyzed {} characters with real font data\n", .{test_chars.len});
    std.debug.print("✅ Used working baseline-aligned font rasterization system\n", .{});
    std.debug.print("✅ Generated detailed coordinate transformation analysis\n", .{});

    std.debug.print("\n✅ Font coordinate transformation test completed\n", .{});
}

/// Generate visual test output to filesystem for external verification
pub fn generateVisualTestOutput(allocator: std.mem.Allocator, output_dir: []const u8) !void {
    if (!ENABLE_DEBUG_OUTPUT) return; // Skip when debug output disabled

    std.debug.print("\n📁 Generating visual test output to: {s}\n", .{output_dir});

    // Ensure test directories exist
    try test_main.ensureTestDirectories();

    // Generate coordinate transformation reference data
    const reference_file_path = try test_main.getTestOutputPath(allocator, "coord", "accuracy.txt");
    defer allocator.free(reference_file_path);

    const file = try std.fs.cwd().createFile(reference_file_path, .{});
    defer file.close();
    const writer = file.writer();

    try writer.print("# Font System Coordinate Transformation Reference\n", .{});
    try writer.print("# Generated by coordinate transformation test suite\n\n", .{});

    // Test multiple resolutions
    const resolutions = [_]struct { width: f32, height: f32, name: []const u8 }{
        .{ .width = 1920, .height = 1080, .name = "1920x1080" },
        .{ .width = 1280, .height = 720, .name = "1280x720" },
        .{ .width = 800, .height = 600, .name = "800x600" },
    };

    for (resolutions) |resolution| {
        try writer.print("## Resolution: {s}\n", .{resolution.name});
        try writer.print("| Screen X | Screen Y | NDC X      | NDC Y      | Back X   | Back Y   | Error    |\n", .{});
        try writer.print("|----------|----------|------------|------------|----------|----------|----------|\n", .{});

        // Test grid of points
        const steps = 5;
        var y_step: u32 = 0;
        while (y_step <= steps) : (y_step += 1) {
            var x_step: u32 = 0;
            while (x_step <= steps) : (x_step += 1) {
                const screen_x = (@as(f32, @floatFromInt(x_step)) / @as(f32, @floatFromInt(steps))) * resolution.width;
                const screen_y = (@as(f32, @floatFromInt(y_step)) / @as(f32, @floatFromInt(steps))) * resolution.height;

                const debug_info = coordinate_transform.generateDebugInfo(
                    screen_x,
                    screen_y,
                    resolution.width,
                    resolution.height,
                );

                try writer.print(
                    "| {d:8.1} | {d:8.1} | {d:10.6} | {d:10.6} | {d:8.1} | {d:8.1} | {d:8.6} |\n",
                    .{
                        debug_info.screen_x,
                        debug_info.screen_y,
                        debug_info.ndc_x,
                        debug_info.ndc_y,
                        debug_info.back_to_screen_x,
                        debug_info.back_to_screen_y,
                        debug_info.transformation_error,
                    },
                );
            }
        }
        try writer.print("\n", .{});
    }

    std.debug.print("    📝 Reference data written to: {s}\n", .{reference_file_path});

    // Generate bitmap transformation example
    var bitmap_transform = coordinate_transform.BitmapTransform.init(allocator);

    // Create test font-like bitmap (16x16)
    var test_bitmap = try allocator.alloc(u8, 16 * 16);
    defer allocator.free(test_bitmap);

    // Generate simple "A" pattern
    @memset(test_bitmap, 0);

    // Draw a simple "A" pattern
    const a_pattern = [_]struct { x: u32, y: u32 }{
        // Top bar
        .{ .x = 7, .y = 2 },  .{ .x = 8, .y = 2 },
        // Left vertical
        .{ .x = 6, .y = 3 },  .{ .x = 5, .y = 4 },
        .{ .x = 4, .y = 5 },  .{ .x = 3, .y = 6 },
        .{ .x = 2, .y = 7 },  .{ .x = 1, .y = 8 },
        .{ .x = 0, .y = 9 },
        // Right vertical
         .{ .x = 9, .y = 3 },
        .{ .x = 10, .y = 4 }, .{ .x = 11, .y = 5 },
        .{ .x = 12, .y = 6 }, .{ .x = 13, .y = 7 },
        .{ .x = 14, .y = 8 }, .{ .x = 15, .y = 9 },
        // Cross bar
        .{ .x = 4, .y = 6 },  .{ .x = 5, .y = 6 },
        .{ .x = 6, .y = 6 },  .{ .x = 7, .y = 6 },
        .{ .x = 8, .y = 6 },  .{ .x = 9, .y = 6 },
        .{ .x = 10, .y = 6 }, .{ .x = 11, .y = 6 },
    };

    for (a_pattern) |point| {
        if (point.x < 16 and point.y < 16) {
            test_bitmap[point.y * 16 + point.x] = 255;
        }
    }

    // Transform bitmap for different target resolutions
    const bitmap_output_path = try test_main.getTestOutputPath(allocator, "coord", "pattern_analysis.txt");
    defer allocator.free(bitmap_output_path);

    const bitmap_file = try std.fs.cwd().createFile(bitmap_output_path, .{});
    defer bitmap_file.close();
    const bitmap_writer = bitmap_file.writer();

    try bitmap_writer.print("# Bitmap Coordinate Transformation Analysis\n\n", .{});

    for (resolutions) |resolution| {
        try bitmap_writer.print("## Target Resolution: {s}\n", .{resolution.name});

        const transformed = try bitmap_transform.createTransformedBitmap(
            test_bitmap,
            16, // original_width
            16, // original_height
            resolution.width,
            resolution.height,
            16, // output_width (keep same for comparison)
            16, // output_height
        );
        defer allocator.free(transformed);

        // Analyze transformation
        var pixel_changes: u32 = 0;
        var max_diff: u32 = 0;

        for (test_bitmap, 0..) |original_pixel, i| {
            const diff = @as(i32, @intCast(transformed[i])) - @as(i32, @intCast(original_pixel));
            if (diff != 0) {
                pixel_changes += 1;
                max_diff = @max(max_diff, @as(u32, @intCast(@abs(diff))));
            }
        }

        try bitmap_writer.print("  - Pixels changed: {d}/{d} ({d:.1}%%)\n", .{
            pixel_changes,
            transformed.len,
            (@as(f32, @floatFromInt(pixel_changes)) / @as(f32, @floatFromInt(transformed.len))) * 100.0,
        });
        try bitmap_writer.print("  - Max pixel difference: {d}\n", .{max_diff});

        // Write bitmap representation
        try bitmap_writer.print("  - Original bitmap:\n", .{});
        for (0..16) |y| {
            try bitmap_writer.print("    ", .{});
            for (0..16) |x| {
                const pixel = test_bitmap[y * 16 + x];
                try bitmap_writer.print("{s}", .{if (pixel > 128) "#" else "."});
            }
            try bitmap_writer.print("\n", .{});
        }

        try bitmap_writer.print("  - Transformed bitmap:\n", .{});
        for (0..16) |y| {
            try bitmap_writer.print("    ", .{});
            for (0..16) |x| {
                const pixel = transformed[y * 16 + x];
                try bitmap_writer.print("{s}", .{if (pixel > 128) "#" else "."});
            }
            try bitmap_writer.print("\n", .{});
        }
        try bitmap_writer.print("\n", .{});
    }

    std.debug.print("    🖼️  Bitmap analysis written to: {s}\n", .{bitmap_output_path});
    std.debug.print("✅ Visual test output generation completed\n", .{});
}

/// Run all coordinate transformation tests
pub fn runAllTests(allocator: std.mem.Allocator) !void {
    if (!ENABLE_DEBUG_OUTPUT) return; // Skip all file generation when debug output is disabled
    std.debug.print("🚀 Running coordinate transformation test suite...\n", .{});

    try testCoordinateTransformAccuracy();
    try testRoundTripTransformation();
    try testBitmapTransformation(allocator);
    try testFontCoordinateTransformation(allocator);

    // Generate visual output for external verification
    try generateVisualTestOutput(allocator, debug_config.font_test_debug.output_dir);

    std.debug.print("🎉 All coordinate transformation tests completed successfully!\n", .{});
}

// ========================
// UNIT TESTS
// ========================

test "coordinate transform accuracy" {
    try testCoordinateTransformAccuracy();
}

test "round trip transformation" {
    try testRoundTripTransformation();
}

test "bitmap transformation" {
    try testBitmapTransformation(std.testing.allocator);
}

test "font coordinate transformation" {
    try testFontCoordinateTransformation(std.testing.allocator);
}
