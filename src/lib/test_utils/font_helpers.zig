const std = @import("std");
const font_types = @import("../font/core/types.zig");

/// Shared test data generators for font testing
/// Extracted from duplicated code in test files
/// Create a simple rectangular glyph outline for testing
pub fn createRectangleOutline(allocator: std.mem.Allocator, x: i32, y: i32, width: i32, height: i32) !font_types.GlyphOutline {
    const points = try allocator.alloc(font_types.Point, 4);

    // Counter-clockwise winding
    points[0] = .{ .x = @floatFromInt(x), .y = @floatFromInt(y), .on_curve = true };
    points[1] = .{ .x = @floatFromInt(x), .y = @floatFromInt(y + height), .on_curve = true };
    points[2] = .{ .x = @floatFromInt(x + width), .y = @floatFromInt(y + height), .on_curve = true };
    points[3] = .{ .x = @floatFromInt(x + width), .y = @floatFromInt(y), .on_curve = true };

    const contours = try allocator.alloc(font_types.Contour, 1);
    contours[0] = .{
        .points = points,
        .closed = true,
    };

    return font_types.GlyphOutline{
        .contours = contours,
        .bounds = .{
            .x_min = @floatFromInt(x),
            .y_min = @floatFromInt(y),
            .x_max = @floatFromInt(x + width),
            .y_max = @floatFromInt(y + height),
        },
        .metrics = .{
            .advance_width = @floatFromInt(width + 10),
            .left_side_bearing = @floatFromInt(x),
        },
    };
}

/// Create a triangle outline for testing
pub fn createTriangleOutline(allocator: std.mem.Allocator) !font_types.GlyphOutline {
    const points = try allocator.alloc(font_types.Point, 3);

    // Simple triangle
    points[0] = .{ .x = 50, .y = 100 };
    points[1] = .{ .x = 100, .y = 200 };
    points[2] = .{ .x = 150, .y = 100 };

    const on_curve = try allocator.alloc(bool, 3);
    @memset(on_curve, true);

    const contours = try allocator.alloc(font_types.Contour, 1);
    contours[0] = .{
        .points = points,
        .on_curve = on_curve,
    };

    return font_types.GlyphOutline{
        .contours = contours,
        .bounds = .{
            .x_min = 50,
            .y_min = 100,
            .x_max = 150,
            .y_max = 200,
        },
        .metrics = .{
            .advance_width = 160,
            .left_side_bearing = 50,
        },
    };
}

/// Free a glyph outline's memory
pub fn freeOutline(allocator: std.mem.Allocator, outline: font_types.GlyphOutline) void {
    for (outline.contours) |contour| {
        allocator.free(contour.points);
        allocator.free(contour.on_curve);
    }
    allocator.free(outline.contours);
}
