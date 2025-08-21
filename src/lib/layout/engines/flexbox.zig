const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../types.zig");
const spacing_utils = @import("../primitives/spacing.zig");
const sizing_utils = @import("../primitives/sizing.zig");
const positioning_utils = @import("../primitives/positioning.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;
const Direction = types.Direction;
const JustifyContent = types.JustifyContent;
const AlignItems = types.AlignItems;
const FlexWrap = types.FlexWrap;
const FlexConstraint = types.FlexConstraint;
const LayoutResult = types.LayoutResult;
const SpacingUtils = spacing_utils.SpacingUtils;
const SizingUtils = sizing_utils.SizingUtils;
const PositioningUtils = positioning_utils.PositioningUtils;

/// Flexbox layout engine following CSS Flexbox specification
pub const FlexboxEngine = struct {
    /// Individual flex item properties
    pub const FlexItem = struct {
        /// Content size (before flex calculations)
        content_size: Vec2,
        /// Flex grow factor
        flex_grow: f32 = 0,
        /// Flex shrink factor
        flex_shrink: f32 = 1,
        /// Flex basis (initial size)
        flex_basis: ?f32 = null,
        /// Self alignment override
        align_self: ?AlignItems = null,
        /// Margin around the item
        margin: f32 = 0,
    };

    /// Container properties
    direction: Direction = .row,
    justify_content: JustifyContent = .flex_start,
    align_items: AlignItems = .flex_start,
    flex_wrap: FlexWrap = .nowrap,
    gap: f32 = 0,

    /// Calculate layout for flex items within a container
    pub fn calculateLayout(
        self: FlexboxEngine,
        container_size: Vec2,
        items: []const FlexItem,
        allocator: std.mem.Allocator,
    ) ![]LayoutResult {
        if (items.len == 0) return try allocator.alloc(LayoutResult, 0);

        const is_row = self.direction == .row or self.direction == .row_reverse;
        const is_reverse = self.direction == .row_reverse or self.direction == .column_reverse;

        // Step 1: Calculate available space
        const available_main_size = if (is_row) container_size.x else container_size.y;
        const available_cross_size = if (is_row) container_size.y else container_size.x;

        // Account for gaps
        const total_gap_space = SpacingUtils.calculateGapSpacing(@intCast(items.len), self.gap);
        const content_main_size = available_main_size - total_gap_space;

        // Step 2: Create flex constraints for sizing calculation
        var flex_constraints = try allocator.alloc(FlexConstraint, items.len);
        defer allocator.free(flex_constraints);

        var preferred_sizes = try allocator.alloc(f32, items.len);
        defer allocator.free(preferred_sizes);

        for (items, 0..) |item, i| {
            const main_size = if (is_row) item.content_size.x else item.content_size.y;
            preferred_sizes[i] = main_size;

            flex_constraints[i] = FlexConstraint{
                .min = 0, // Could be configurable
                .max = std.math.inf(f32),
                .flex_grow = item.flex_grow,
                .flex_shrink = item.flex_shrink,
                .flex_basis = item.flex_basis,
            };
        }

        // Step 3: Calculate main axis sizes
        const main_sizes = try allocator.alloc(f32, items.len);
        defer allocator.free(main_sizes);

        SizingUtils.calculateFlexSizes(
            content_main_size,
            flex_constraints,
            preferred_sizes,
            main_sizes,
        );

        // Step 4: Calculate cross axis sizes
        var cross_sizes = try allocator.alloc(f32, items.len);
        defer allocator.free(cross_sizes);

        for (items, 0..) |item, i| {
            cross_sizes[i] = if (is_row) item.content_size.y else item.content_size.x;

            // Handle stretch alignment
            const alignment = item.align_self orelse self.align_items;
            if (alignment == .stretch) {
                cross_sizes[i] = available_cross_size - (item.margin * 2);
            }
        }

        // Step 5: Position items
        var result = try allocator.alloc(LayoutResult, items.len);
        var current_main_pos: f32 = 0;

        // Calculate starting position based on justify_content
        const total_content_size = blk: {
            var total: f32 = 0;
            for (main_sizes) |size| total += size;
            break :blk total;
        };

        switch (self.justify_content) {
            .flex_start => current_main_pos = 0,
            .flex_end => current_main_pos = content_main_size - total_content_size,
            .center => current_main_pos = (content_main_size - total_content_size) / 2,
            .space_between => {
                current_main_pos = 0;
                // Spacing handled in loop below
            },
            .space_around => {
                const spacing_result = SpacingUtils.calculateSpaceAround(content_main_size, total_content_size, @intCast(items.len));
                current_main_pos = spacing_result.offset;
            },
            .space_evenly => {
                const spacing_result = SpacingUtils.calculateSpaceEvenly(content_main_size, total_content_size, @intCast(items.len));
                current_main_pos = spacing_result.offset;
            },
        }

        // Calculate inter-item spacing
        var item_spacing: f32 = self.gap;
        if (self.justify_content == .space_between and items.len > 1) {
            item_spacing = SpacingUtils.calculateSpaceBetween(content_main_size, total_content_size, @intCast(items.len));
        } else if (self.justify_content == .space_around and items.len > 0) {
            const spacing_result = SpacingUtils.calculateSpaceAround(content_main_size, total_content_size, @intCast(items.len));
            item_spacing = spacing_result.spacing;
        } else if (self.justify_content == .space_evenly and items.len > 0) {
            const spacing_result = SpacingUtils.calculateSpaceEvenly(content_main_size, total_content_size, @intCast(items.len));
            item_spacing = spacing_result.spacing;
        }

        // Position each item
        for (items, 0..) |item, i| {
            const display_index = if (is_reverse) items.len - 1 - i else i;

            // Calculate cross axis position
            const alignment = item.align_self orelse self.align_items;
            const cross_pos = switch (alignment) {
                .flex_start => item.margin,
                .flex_end => available_cross_size - cross_sizes[i] - item.margin,
                .center => (available_cross_size - cross_sizes[i]) / 2,
                .stretch, .baseline => item.margin, // baseline simplified to flex_start
            };

            // Create final size
            const final_size = if (is_row)
                Vec2{ .x = main_sizes[i], .y = cross_sizes[i] }
            else
                Vec2{ .x = cross_sizes[i], .y = main_sizes[i] };

            // Create final position
            const final_position = if (is_row)
                Vec2{ .x = current_main_pos + item.margin, .y = cross_pos }
            else
                Vec2{ .x = cross_pos, .y = current_main_pos + item.margin };

            result[display_index] = LayoutResult{
                .position = final_position,
                .size = final_size,
                .element_index = i,
            };

            // Advance main position
            current_main_pos += main_sizes[i] + item.margin * 2 + item_spacing;
        }

        return result;
    }

    /// Helper to create flex item from basic properties
    pub fn createFlexItem(content_size: Vec2, flex_grow: f32, flex_shrink: f32) FlexItem {
        return FlexItem{
            .content_size = content_size,
            .flex_grow = flex_grow,
            .flex_shrink = flex_shrink,
        };
    }

    /// Create flexbox with row direction and common settings
    pub fn createRowLayout(justify: JustifyContent, align_items: AlignItems, gap: f32) FlexboxEngine {
        return FlexboxEngine{
            .direction = .row,
            .justify_content = justify,
            .align_items = align_items,
            .gap = gap,
        };
    }

    /// Create flexbox with column direction and common settings
    pub fn createColumnLayout(justify: JustifyContent, align_items: AlignItems, gap: f32) FlexboxEngine {
        return FlexboxEngine{
            .direction = .column,
            .justify_content = justify,
            .align_items = align_items,
            .gap = gap,
        };
    }
};

// Keep the old name for backward compatibility
pub const Flexbox = FlexboxEngine;

// Tests
test "basic row layout" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const flex = FlexboxEngine.createRowLayout(.flex_start, .flex_start, 10);

    const items = [_]FlexboxEngine.FlexItem{
        FlexboxEngine.createFlexItem(Vec2{ .x = 50, .y = 30 }, 0, 1),
        FlexboxEngine.createFlexItem(Vec2{ .x = 60, .y = 40 }, 0, 1),
        FlexboxEngine.createFlexItem(Vec2{ .x = 40, .y = 20 }, 0, 1),
    };

    const container_size = Vec2{ .x = 200, .y = 100 };
    const layout = try flex.calculateLayout(container_size, &items, allocator);
    defer allocator.free(layout);

    try testing.expect(layout.len == 3);

    // First item should be at origin
    try testing.expect(layout[0].position.x == 0);
    try testing.expect(layout[0].position.y == 0);
    try testing.expect(layout[0].size.x == 50);

    // Second item should be offset by first item width + gap
    try testing.expect(layout[1].position.x == 60); // 50 + 10

    // Third item
    try testing.expect(layout[2].position.x == 130); // 50 + 10 + 60 + 10
}

test "flex grow distribution" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const flex = FlexboxEngine.createRowLayout(.flex_start, .flex_start, 0);

    const items = [_]FlexboxEngine.FlexItem{
        .{ .content_size = Vec2{ .x = 50, .y = 30 }, .flex_grow = 1, .flex_shrink = 1 },
        .{ .content_size = Vec2{ .x = 50, .y = 30 }, .flex_grow = 2, .flex_shrink = 1 },
        .{ .content_size = Vec2{ .x = 50, .y = 30 }, .flex_grow = 1, .flex_shrink = 1 },
    };

    const container_size = Vec2{ .x = 200, .y = 100 };
    const layout = try flex.calculateLayout(container_size, &items, allocator);
    defer allocator.free(layout);

    // Extra space: 200 - 150 = 50px
    // Total grow: 1 + 2 + 1 = 4
    // Item sizes: 50 + 12.5, 50 + 25, 50 + 12.5
    try testing.expect(@abs(layout[0].size.x - 62.5) < 0.1);
    try testing.expect(@abs(layout[1].size.x - 75.0) < 0.1);
    try testing.expect(@abs(layout[2].size.x - 62.5) < 0.1);
}

test "center justification" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const flex = FlexboxEngine.createRowLayout(.center, .flex_start, 10);

    const items = [_]FlexboxEngine.FlexItem{
        FlexboxEngine.createFlexItem(Vec2{ .x = 40, .y = 30 }, 0, 1),
        FlexboxEngine.createFlexItem(Vec2{ .x = 40, .y = 30 }, 0, 1),
    };

    const container_size = Vec2{ .x = 200, .y = 100 };
    const layout = try flex.calculateLayout(container_size, &items, allocator);
    defer allocator.free(layout);

    // Total content: 40 + 10 + 40 = 90px
    // Remaining space: 200 - 90 = 110px
    // Center offset: 110 / 2 = 55px
    try testing.expect(@abs(layout[0].position.x - 55) < 0.1);
    try testing.expect(@abs(layout[1].position.x - 105) < 0.1); // 55 + 40 + 10
}

test "column layout" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const flex = FlexboxEngine.createColumnLayout(.flex_start, .flex_start, 5);

    const items = [_]FlexboxEngine.FlexItem{
        FlexboxEngine.createFlexItem(Vec2{ .x = 50, .y = 30 }, 0, 1),
        FlexboxEngine.createFlexItem(Vec2{ .x = 60, .y = 25 }, 0, 1),
    };

    const container_size = Vec2{ .x = 100, .y = 200 };
    const layout = try flex.calculateLayout(container_size, &items, allocator);
    defer allocator.free(layout);

    try testing.expect(layout.len == 2);

    // First item at top
    try testing.expect(layout[0].position.y == 0);
    try testing.expect(layout[0].size.y == 30);

    // Second item below first + gap
    try testing.expect(layout[1].position.y == 35); // 30 + 5
    try testing.expect(layout[1].size.y == 25);
}
