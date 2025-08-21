/// Block layout algorithm implementation
///
/// This module implements the CSS block layout algorithm, where elements
/// are laid out vertically in a block-formatting context.
const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../types.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;

/// Block layout algorithm
pub const BlockLayout = struct {
    /// Block layout configuration
    pub const Config = struct {
        /// Vertical spacing between blocks
        block_spacing: f32 = 0.0,
        /// Whether to respect margins
        respect_margins: bool = true,
        /// Whether to collapse adjacent margins
        collapse_margins: bool = true,
        /// Maximum width for blocks
        max_block_width: ?f32 = null,
        /// Alignment within container
        block_align: types.Alignment = .start,
    };

    /// Element information for block layout
    pub const BlockElement = struct {
        /// Element size preferences
        size: Vec2,
        /// Element margins
        margin: types.Spacing,
        /// Element constraints
        constraints: types.Constraints,
        /// Whether element is inline-block
        is_inline_block: bool = false,
        /// Custom alignment override
        align_override: ?types.Alignment = null,
        /// Element index for results
        index: usize,
    };

    /// Perform block layout calculation
    pub fn calculateLayout(
        container_bounds: Rectangle,
        elements: []const BlockElement,
        config: Config,
        allocator: std.mem.Allocator,
    ) ![]types.LayoutResult {
        var results = try allocator.alloc(types.LayoutResult, elements.len);

        var current_y = container_bounds.position.y;
        var previous_margin_bottom: f32 = 0.0;

        for (elements, 0..) |element, i| {
            // Calculate margin collapse
            var effective_margin_top = element.margin.top;
            if (config.collapse_margins and i > 0) {
                effective_margin_top = @max(element.margin.top, previous_margin_bottom) -
                    @min(element.margin.top, previous_margin_bottom);
            }

            // Apply top margin and spacing
            current_y += effective_margin_top;
            if (i > 0) {
                current_y += config.block_spacing;
            }

            // Calculate element width
            var element_width = element.size.x;
            if (config.max_block_width) |max_width| {
                element_width = @min(element_width, max_width);
            }

            // Apply constraints
            element_width = element.constraints.constrainWidth(element_width);
            const element_height = element.constraints.constrainHeight(element.size.y);

            // Calculate horizontal position based on alignment
            const alignment = element.align_override orelse config.block_align;
            var element_x = container_bounds.position.x + element.margin.left;

            const available_width = container_bounds.size.x - element.margin.getHorizontal();
            switch (alignment) {
                .start => {}, // Already positioned at start
                .center => {
                    element_x += (available_width - element_width) / 2.0;
                },
                .end => {
                    element_x += available_width - element_width;
                },
                .stretch => {
                    element_width = @max(element_width, available_width);
                },
            }

            // Create layout result
            results[i] = types.LayoutResult{
                .position = Vec2{ .x = element_x, .y = current_y },
                .size = Vec2{ .x = element_width, .y = element_height },
                .element_index = element.index,
            };

            // Advance to next position
            current_y += element_height + element.margin.bottom;
            previous_margin_bottom = element.margin.bottom;
        }

        return results;
    }

    /// Calculate total height required for block layout
    pub fn calculateRequiredHeight(
        elements: []const BlockElement,
        config: Config,
    ) f32 {
        if (elements.len == 0) return 0.0;

        var total_height: f32 = 0.0;
        var previous_margin_bottom: f32 = 0.0;

        for (elements, 0..) |element, i| {
            // Margin collapse calculation
            var effective_margin_top = element.margin.top;
            if (config.collapse_margins and i > 0) {
                effective_margin_top = @max(element.margin.top, previous_margin_bottom) -
                    @min(element.margin.top, previous_margin_bottom);
            }

            total_height += effective_margin_top;
            if (i > 0) {
                total_height += config.block_spacing;
            }

            // Add element height
            const element_height = element.constraints.constrainHeight(element.size.y);
            total_height += element_height;

            previous_margin_bottom = element.margin.bottom;
        }

        // Add final bottom margin
        total_height += previous_margin_bottom;

        return total_height;
    }

    /// Check if elements fit within container height
    pub fn checkFit(
        container_height: f32,
        elements: []const BlockElement,
        config: Config,
    ) bool {
        const required_height = calculateRequiredHeight(elements, config);
        return required_height <= container_height;
    }
};

/// Block layout with overflow handling
pub const OverflowBlockLayout = struct {
    /// Overflow handling strategy
    pub const OverflowStrategy = enum {
        clip, // Clip elements that don't fit
        scroll, // Enable scrolling (virtual)
        wrap, // Wrap to next column (not implemented)
        scale, // Scale down to fit
    };

    pub const Config = struct {
        base_config: BlockLayout.Config = .{},
        overflow_strategy: OverflowStrategy = .clip,
        scale_factor_limit: f32 = 0.5, // Minimum scale when using scale strategy
    };

    /// Calculate block layout with overflow handling
    pub fn calculateLayout(
        container_bounds: Rectangle,
        elements: []const BlockLayout.BlockElement,
        config: Config,
        allocator: std.mem.Allocator,
    ) ![]types.LayoutResult {
        // First, try normal block layout
        const normal_results = try BlockLayout.calculateLayout(
            container_bounds,
            elements,
            config.base_config,
            allocator,
        );
        defer allocator.free(normal_results);

        // Check if we need overflow handling
        const required_height = BlockLayout.calculateRequiredHeight(elements, config.base_config);

        if (required_height <= container_bounds.size.y) {
            // No overflow, return normal results
            const results = try allocator.alloc(types.LayoutResult, normal_results.len);
            @memcpy(results, normal_results);
            return results;
        }

        // Handle overflow based on strategy
        switch (config.overflow_strategy) {
            .clip => {
                return clipOverflowingElements(container_bounds, normal_results, allocator);
            },
            .scroll => {
                // For scroll, we return the normal layout but mark it as overflowing
                // The rendering system should handle the scrolling
                const results = try allocator.alloc(types.LayoutResult, normal_results.len);
                @memcpy(results, normal_results);
                return results;
            },
            .scale => {
                return scaleToFit(container_bounds, elements, config, allocator);
            },
            .wrap => {
                // TODO: Implement column wrapping
                return error.NotImplemented;
            },
        }
    }

    /// Clip elements that overflow the container
    fn clipOverflowingElements(
        container_bounds: Rectangle,
        results: []const types.LayoutResult,
        allocator: std.mem.Allocator,
    ) ![]types.LayoutResult {
        var clipped_results = std.ArrayList(types.LayoutResult).init(allocator);
        defer clipped_results.deinit();

        const container_bottom = container_bounds.position.y + container_bounds.size.y;

        for (results) |result| {
            if (result.position.y < container_bottom) {
                var clipped_result = result;

                // Clip height if element extends beyond container
                const element_bottom = result.position.y + result.size.y;
                if (element_bottom > container_bottom) {
                    clipped_result.size.y = container_bottom - result.position.y;
                }

                // Only include if there's still visible area
                if (clipped_result.size.y > 0) {
                    try clipped_results.append(clipped_result);
                }
            }
        }

        return try clipped_results.toOwnedSlice();
    }

    /// Scale layout to fit within container
    fn scaleToFit(
        container_bounds: Rectangle,
        elements: []const BlockLayout.BlockElement,
        config: Config,
        allocator: std.mem.Allocator,
    ) ![]types.LayoutResult {
        const required_height = BlockLayout.calculateRequiredHeight(elements, config.base_config);
        const scale_factor = @max(
            config.scale_factor_limit,
            container_bounds.size.y / required_height,
        );

        // Create scaled elements
        var scaled_elements = try allocator.alloc(BlockLayout.BlockElement, elements.len);
        defer allocator.free(scaled_elements);

        for (elements, 0..) |element, i| {
            scaled_elements[i] = element;
            scaled_elements[i].size.y *= scale_factor;
            scaled_elements[i].margin.top *= scale_factor;
            scaled_elements[i].margin.bottom *= scale_factor;
        }

        // Calculate layout with scaled elements
        return BlockLayout.calculateLayout(
            container_bounds,
            scaled_elements,
            config.base_config,
            allocator,
        );
    }
};

// Tests
test "block layout basic vertical stacking" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const container = Rectangle{
        .position = Vec2{ .x = 0, .y = 0 },
        .size = Vec2{ .x = 400, .y = 600 },
    };

    const elements = [_]BlockLayout.BlockElement{
        .{
            .size = Vec2{ .x = 200, .y = 100 },
            .margin = types.Spacing.uniform(10),
            .constraints = types.Constraints{},
            .index = 0,
        },
        .{
            .size = Vec2{ .x = 180, .y = 80 },
            .margin = types.Spacing.uniform(5),
            .constraints = types.Constraints{},
            .index = 1,
        },
    };

    const config = BlockLayout.Config{};
    const results = try BlockLayout.calculateLayout(container, &elements, config, allocator);
    defer allocator.free(results);

    try testing.expect(results.len == 2);

    // First element should be at top with margin
    try testing.expect(results[0].position.x == 10); // left margin
    try testing.expect(results[0].position.y == 10); // top margin
    try testing.expect(results[0].size.x == 200);
    try testing.expect(results[0].size.y == 100);

    // Second element should be below first
    try testing.expect(results[1].position.x == 5); // left margin
    try testing.expect(results[1].position.y > results[0].position.y + results[0].size.y);
}

test "block layout with margin collapse" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const container = Rectangle{
        .position = Vec2.ZERO,
        .size = Vec2{ .x = 400, .y = 600 },
    };

    // Elements with overlapping margins
    const elements = [_]BlockLayout.BlockElement{
        .{
            .size = Vec2{ .x = 200, .y = 50 },
            .margin = types.Spacing{ .bottom = 20, .top = 0, .left = 0, .right = 0 },
            .constraints = types.Constraints{},
            .index = 0,
        },
        .{
            .size = Vec2{ .x = 200, .y = 50 },
            .margin = types.Spacing{ .top = 15, .bottom = 0, .left = 0, .right = 0 },
            .constraints = types.Constraints{},
            .index = 1,
        },
    };

    const config = BlockLayout.Config{ .collapse_margins = true };
    const results = try BlockLayout.calculateLayout(container, &elements, config, allocator);
    defer allocator.free(results);

    // With margin collapse, the gap should be max(20, 15) = 20, not 35
    const expected_gap = 20.0;
    const actual_gap = results[1].position.y - (results[0].position.y + results[0].size.y);

    try testing.expect(@abs(actual_gap - expected_gap) < 0.1);
}

test "block layout center alignment" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const container = Rectangle{
        .position = Vec2.ZERO,
        .size = Vec2{ .x = 400, .y = 600 },
    };

    const elements = [_]BlockLayout.BlockElement{
        .{
            .size = Vec2{ .x = 200, .y = 100 },
            .margin = types.Spacing{},
            .constraints = types.Constraints{},
            .index = 0,
        },
    };

    const config = BlockLayout.Config{ .block_align = .center };
    const results = try BlockLayout.calculateLayout(container, &elements, config, allocator);
    defer allocator.free(results);

    // Element should be centered horizontally
    const expected_x = (container.size.x - elements[0].size.x) / 2.0;
    try testing.expect(@abs(results[0].position.x - expected_x) < 0.1);
}

test "overflow block layout clipping" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const container = Rectangle{
        .position = Vec2.ZERO,
        .size = Vec2{ .x = 400, .y = 150 }, // Small height to force overflow
    };

    const elements = [_]BlockLayout.BlockElement{
        .{
            .size = Vec2{ .x = 200, .y = 100 },
            .margin = types.Spacing{},
            .constraints = types.Constraints{},
            .index = 0,
        },
        .{
            .size = Vec2{ .x = 200, .y = 100 },
            .margin = types.Spacing{},
            .constraints = types.Constraints{},
            .index = 1,
        },
    };

    const config = OverflowBlockLayout.Config{
        .overflow_strategy = .clip,
    };

    const results = try OverflowBlockLayout.calculateLayout(container, &elements, config, allocator);
    defer allocator.free(results);

    // Should have fewer elements due to clipping
    try testing.expect(results.len <= elements.len);

    // All elements should fit within container bounds
    for (results) |result| {
        try testing.expect(result.position.y + result.size.y <= container.position.y + container.size.y);
    }
}
