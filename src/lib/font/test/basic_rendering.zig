const std = @import("std");
const testing = std.testing;
const font_types = @import("../core/types.zig");
const bitmap_utils = @import("../../image/bitmap.zig");

const BitmapVisualizer = bitmap_utils.Visualizer;
const TestPatterns = bitmap_utils.TestPatterns;
const font_helpers = @import("../../test_utils/font_helpers.zig");

/// Test data generators for font testing (using shared utilities)
const TestData = struct {
    // Delegate to shared implementation
    const createRectangleOutline = font_helpers.createRectangleOutline;

    /// Create a test bitmap with a checkerboard pattern
    fn createCheckerboard(allocator: std.mem.Allocator, width: u32, height: u32, square_size: u32) ![]u8 {
        return TestPatterns.createCheckerboard(allocator, width, height, square_size);
    }
};

// Simplified point-in-polygon test
fn isPointInside(point: font_types.Point, contours: []const font_types.Contour) bool {
    var winding_number: i32 = 0;

    for (contours) |contour| {
        if (contour.points.len < 3) continue;

        for (contour.points, 0..) |_, i| {
            const next_i = (i + 1) % contour.points.len;
            const p1 = contour.points[i];
            const p2 = contour.points[next_i];

            // Ray casting algorithm
            if ((p1.y <= point.y and point.y < p2.y) or (p2.y <= point.y and point.y < p1.y)) {
                const t = (point.y - p1.y) / (p2.y - p1.y);
                const intersection_x = p1.x + t * (p2.x - p1.x);

                if (intersection_x > point.x) {
                    if (p1.y < p2.y) {
                        winding_number += 1;
                    } else {
                        winding_number -= 1;
                    }
                }
            }
        }
    }

    return winding_number != 0;
}

test "point in polygon - rectangle" {
    const allocator = testing.allocator;

    // Create a simple rectangle: (10,10) to (90,90)
    const outline = try TestData.createRectangleOutline(allocator, 10, 10, 80, 80);
    defer @constCast(&outline).deinit(allocator);

    // Test points inside
    try testing.expect(isPointInside(.{ .x = 50, .y = 50, .on_curve = true }, outline.contours)); // Center
    try testing.expect(isPointInside(.{ .x = 20, .y = 20, .on_curve = true }, outline.contours)); // Near corner
    try testing.expect(isPointInside(.{ .x = 80, .y = 80, .on_curve = true }, outline.contours)); // Near opposite corner

    // Test points outside
    try testing.expect(!isPointInside(.{ .x = 5, .y = 5, .on_curve = true }, outline.contours)); // Before rectangle
    try testing.expect(!isPointInside(.{ .x = 100, .y = 100, .on_curve = true }, outline.contours)); // After rectangle
    try testing.expect(!isPointInside(.{ .x = 50, .y = 5, .on_curve = true }, outline.contours)); // Above rectangle

    std.debug.print("\nPoint-in-polygon test passed for rectangle\n", .{});
}

test "simple rasterization - rectangle" {
    const allocator = testing.allocator;

    // Create a small rectangle for testing
    const outline = try TestData.createRectangleOutline(allocator, 20, 20, 60, 40);
    defer @constCast(&outline).deinit(allocator);

    // Simple rasterization at low resolution
    const width: u32 = 100;
    const height: u32 = 80;
    const scale: f32 = 1.0;

    const bitmap = try allocator.alloc(u8, width * height);
    defer allocator.free(bitmap);
    @memset(bitmap, 0);

    // Rasterize by testing each pixel
    var filled_pixels: u32 = 0;
    for (0..height) |y| {
        for (0..width) |x| {
            const point = font_types.Point{
                .x = @as(f32, @floatFromInt(x)) / scale,
                .y = @as(f32, @floatFromInt(y)) / scale,
                .on_curve = true,
            };

            if (isPointInside(point, outline.contours)) {
                bitmap[y * width + x] = 255;
                filled_pixels += 1;
            }
        }
    }

    std.debug.print("\nSimple rasterization test:\n", .{});
    std.debug.print("  Rectangle bounds: ({},{}) to ({},{})\n", .{ 20, 20, 80, 60 });
    std.debug.print("  Bitmap size: {}x{}\n", .{ width, height });
    std.debug.print("  Filled pixels: {} / {}\n", .{ filled_pixels, width * height });

    // Visualize result
    std.debug.print("\nRasterized bitmap:\n", .{});
    BitmapVisualizer.toAsciiArt(bitmap, width, height);

    // Verify we have reasonable coverage
    const coverage = @as(f32, @floatFromInt(filled_pixels)) / @as(f32, @floatFromInt(width * height)) * 100.0;
    std.debug.print("\nCoverage: {d:.1}%\n", .{coverage});

    // Rectangle should cover roughly 60x40 = 2400 pixels out of 100x80 = 8000
    // Expected coverage ~30%
    try testing.expect(coverage > 20.0 and coverage < 40.0);
}

test "winding rule - overlapping rectangles" {
    const allocator = testing.allocator;

    // Create two overlapping rectangles to test winding rule
    const points1 = try allocator.alloc(font_types.Point, 4);
    defer allocator.free(points1);
    points1[0] = .{ .x = 10, .y = 10, .on_curve = true };
    points1[1] = .{ .x = 10, .y = 50, .on_curve = true };
    points1[2] = .{ .x = 50, .y = 50, .on_curve = true };
    points1[3] = .{ .x = 50, .y = 10, .on_curve = true };

    const points2 = try allocator.alloc(font_types.Point, 4);
    defer allocator.free(points2);
    points2[0] = .{ .x = 30, .y = 30, .on_curve = true };
    points2[1] = .{ .x = 30, .y = 70, .on_curve = true };
    points2[2] = .{ .x = 70, .y = 70, .on_curve = true };
    points2[3] = .{ .x = 70, .y = 30, .on_curve = true };

    const contours = try allocator.alloc(font_types.Contour, 2);
    defer allocator.free(contours);
    contours[0] = .{ .points = points1, .closed = true };
    contours[1] = .{ .points = points2, .closed = true };

    // Test points in different regions
    const inside_first_only = isPointInside(.{ .x = 20, .y = 20, .on_curve = true }, contours);
    const inside_overlap = isPointInside(.{ .x = 40, .y = 40, .on_curve = true }, contours);
    const inside_second_only = isPointInside(.{ .x = 60, .y = 60, .on_curve = true }, contours);
    const outside_both = isPointInside(.{ .x = 5, .y = 5, .on_curve = true }, contours);

    std.debug.print("\nWinding rule test with overlapping rectangles:\n", .{});
    std.debug.print("  Point (20,20) inside first only: {}\n", .{inside_first_only});
    std.debug.print("  Point (40,40) inside overlap: {}\n", .{inside_overlap});
    std.debug.print("  Point (60,60) inside second only: {}\n", .{inside_second_only});
    std.debug.print("  Point (5,5) outside both: {}\n", .{outside_both});

    // All regions except outside should be filled
    try testing.expect(inside_first_only);
    try testing.expect(inside_overlap);
    try testing.expect(inside_second_only);
    try testing.expect(!outside_both);
}

test "bitmap visualization" {
    const allocator = testing.allocator;

    // Create a checkerboard pattern
    const bitmap = try TestData.createCheckerboard(allocator, 20, 10, 2);
    defer allocator.free(bitmap);

    std.debug.print("\nCheckerboard pattern (20x10, square size 2):\n", .{});
    BitmapVisualizer.toAsciiArt(bitmap, 20, 10);

    const coverage = BitmapVisualizer.calculateCoverage(bitmap);
    std.debug.print("Coverage: {d:.1}%\n", .{coverage});

    // Checkerboard should be exactly 50% coverage
    try testing.expectApproxEqAbs(coverage, 50.0, 0.1);
}

// TODO save to image formats
test "save to PGM file" {
    const allocator = testing.allocator;

    // Create a simple gradient
    const width: u32 = 64;
    const height: u32 = 64;
    const bitmap = try allocator.alloc(u8, width * height);
    defer allocator.free(bitmap);

    // Create gradient pattern
    for (0..height) |y| {
        for (0..width) |x| {
            const value = @as(u8, @intCast((x + y) * 255 / (width + height)));
            bitmap[y * width + x] = value;
        }
    }

    // Save to file
    // try BitmapVisualizer.saveToPGM(bitmap, width, height, "test_gradient.pgm");
    // std.debug.print("\nSaved gradient to test_gradient.pgm\n", .{});
    // std.debug.print("View with: display test_gradient.pgm\n", .{});
}

// Run with: zig build test -Dtest-filter="basic rendering"
