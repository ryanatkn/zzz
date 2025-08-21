const std = @import("std");
const math = @import("../../math/mod.zig");

const Vec2 = math.Vec2;

/// Spacing calculation utilities for layout primitives
pub const SpacingUtils = struct {
    /// Calculate distributed spacing for justify-content: space-between
    pub fn calculateSpaceBetween(total_width: f32, content_width: f32, item_count: u32) f32 {
        if (item_count <= 1) return 0;
        return (total_width - content_width) / @as(f32, @floatFromInt(item_count - 1));
    }

    /// Calculate distributed spacing for justify-content: space-around
    pub fn calculateSpaceAround(total_width: f32, content_width: f32, item_count: u32) struct { spacing: f32, offset: f32 } {
        if (item_count == 0) return .{ .spacing = 0, .offset = 0 };
        const total_spacing = total_width - content_width;
        const spacing_per_item = total_spacing / @as(f32, @floatFromInt(item_count));
        return .{
            .spacing = spacing_per_item,
            .offset = spacing_per_item / 2.0,
        };
    }

    /// Calculate distributed spacing for justify-content: space-evenly
    pub fn calculateSpaceEvenly(total_width: f32, content_width: f32, item_count: u32) struct { spacing: f32, offset: f32 } {
        if (item_count == 0) return .{ .spacing = 0, .offset = 0 };
        const spacing = (total_width - content_width) / @as(f32, @floatFromInt(item_count + 1));
        return .{
            .spacing = spacing,
            .offset = spacing,
        };
    }

    /// Calculate gap spacing between items
    pub fn calculateGapSpacing(item_count: u32, gap: f32) f32 {
        if (item_count <= 1) return 0;
        return @as(f32, @floatFromInt(item_count - 1)) * gap;
    }

    /// Apply spacing constraints to ensure minimum spacing
    pub fn constrainSpacing(spacing: f32, min_spacing: f32, max_spacing: f32) f32 {
        return std.math.clamp(spacing, min_spacing, max_spacing);
    }
};

// Tests
test "space-between calculation" {
    const testing = std.testing;

    // 300px total width, 200px content, 3 items = 50px spacing between each
    const spacing = SpacingUtils.calculateSpaceBetween(300, 200, 3);
    try testing.expect(@abs(spacing - 50.0) < 0.01);

    // Single item should have 0 spacing
    const single_spacing = SpacingUtils.calculateSpaceBetween(300, 200, 1);
    try testing.expect(single_spacing == 0);
}

test "space-around calculation" {
    const testing = std.testing;

    const result = SpacingUtils.calculateSpaceAround(300, 200, 4);
    // 100px extra space / 4 items = 25px per item
    try testing.expect(@abs(result.spacing - 25.0) < 0.01);
    // Half spacing as offset
    try testing.expect(@abs(result.offset - 12.5) < 0.01);
}

test "space-evenly calculation" {
    const testing = std.testing;

    const result = SpacingUtils.calculateSpaceEvenly(300, 200, 4);
    // 100px extra space / 5 gaps = 20px per gap
    try testing.expect(@abs(result.spacing - 20.0) < 0.01);
    try testing.expect(@abs(result.offset - 20.0) < 0.01);
}

test "gap spacing" {
    const testing = std.testing;

    // 4 items with 10px gap = 3 gaps = 30px total
    const total_gap = SpacingUtils.calculateGapSpacing(4, 10);
    try testing.expect(total_gap == 30);

    // Single item should have no gap spacing
    const no_gap = SpacingUtils.calculateGapSpacing(1, 10);
    try testing.expect(no_gap == 0);
}
