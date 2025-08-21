/// Alignment algorithms for layout arrangement
///
/// This module provides utilities for aligning elements within containers
/// using various alignment strategies including baseline alignment,
/// content alignment, and distribution algorithms.
const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../core/types.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;
const Alignment = types.Alignment;
const LayoutResult = types.LayoutResult;

/// Content alignment within containers
pub const ContentAlignment = struct {
    /// Align elements horizontally within a container
    pub fn alignHorizontal(
        results: []LayoutResult,
        container_bounds: Rectangle,
        alignment: Alignment,
    ) void {
        if (results.len == 0) return;

        // Calculate total content width
        var min_x: f32 = std.math.inf(f32);
        var max_x: f32 = -std.math.inf(f32);

        for (results) |result| {
            min_x = @min(min_x, result.position.x);
            max_x = @max(max_x, result.position.x + result.size.x);
        }

        const content_width = max_x - min_x;
        const available_width = container_bounds.size.x;
        const container_left = container_bounds.position.x;

        const offset = switch (alignment) {
            .start => container_left - min_x,
            .center => container_left + (available_width - content_width) / 2 - min_x,
            .end => container_left + available_width - max_x,
            .stretch => {
                // Distribute extra space evenly among elements
                if (results.len > 1) {
                    const extra_space = available_width - content_width;
                    const space_per_gap = extra_space / @as(f32, @floatFromInt(results.len - 1));

                    for (results, 0..) |*result, i| {
                        result.position.x += container_left - min_x + @as(f32, @floatFromInt(i)) * space_per_gap;
                    }
                    return;
                }
                return container_left - min_x;
            },
        };

        // Apply offset to all elements
        if (alignment != .stretch) {
            for (results) |*result| {
                result.position.x += offset;
            }
        }
    }

    /// Align elements vertically within a container
    pub fn alignVertical(
        results: []LayoutResult,
        container_bounds: Rectangle,
        alignment: Alignment,
    ) void {
        if (results.len == 0) return;

        // Calculate total content height
        var min_y: f32 = std.math.inf(f32);
        var max_y: f32 = -std.math.inf(f32);

        for (results) |result| {
            min_y = @min(min_y, result.position.y);
            max_y = @max(max_y, result.position.y + result.size.y);
        }

        const content_height = max_y - min_y;
        const available_height = container_bounds.size.y;
        const container_top = container_bounds.position.y;

        const offset = switch (alignment) {
            .start => container_top - min_y,
            .center => container_top + (available_height - content_height) / 2 - min_y,
            .end => container_top + available_height - max_y,
            .stretch => {
                // Stretch elements to fill available height
                if (results.len == 1) {
                    results[0].position.y = container_top;
                    results[0].size.y = available_height;
                    return;
                }

                // For multiple elements, distribute extra space
                const extra_space = available_height - content_height;
                const space_per_gap = if (results.len > 1) extra_space / @as(f32, @floatFromInt(results.len - 1)) else 0;

                for (results, 0..) |*result, i| {
                    result.position.y += container_top - min_y + @as(f32, @floatFromInt(i)) * space_per_gap;
                }
                return;
            },
        };

        // Apply offset to all elements
        if (alignment != .stretch) {
            for (results) |*result| {
                result.position.y += offset;
            }
        }
    }

    /// Align elements both horizontally and vertically
    pub fn alignBoth(
        results: []LayoutResult,
        container_bounds: Rectangle,
        horizontal: Alignment,
        vertical: Alignment,
    ) void {
        alignHorizontal(results, container_bounds, horizontal);
        alignVertical(results, container_bounds, vertical);
    }
};

/// Baseline alignment for text and mixed content
pub const BaselineAlignment = struct {
    /// Baseline information for an element
    pub const BaselineInfo = struct {
        /// Y offset from element top to text baseline
        baseline_offset: f32,
        /// Element bounds
        bounds: Rectangle,
        /// Element index
        element_index: usize,
    };

    /// Align elements to a common baseline
    pub fn alignToBaseline(
        results: []LayoutResult,
        baseline_infos: []const BaselineInfo,
        container_bounds: Rectangle,
    ) void {
        if (results.len != baseline_infos.len or results.len == 0) return;

        // Find the dominant baseline (typically the largest baseline offset)
        var max_baseline_offset: f32 = 0;
        for (baseline_infos) |info| {
            max_baseline_offset = @max(max_baseline_offset, info.baseline_offset);
        }

        // Calculate baseline Y position (use container's vertical center as reference)
        const baseline_y = container_bounds.position.y + container_bounds.size.y / 2;

        // Adjust each element to align to the common baseline
        for (results, baseline_infos) |*result, baseline_info| {
            const target_top = baseline_y - baseline_info.baseline_offset;
            result.position.y = target_top;
        }
    }

    /// Calculate baseline for different content types
    pub fn calculateBaseline(element_size: Vec2, content_type: ContentType, font_size: f32) f32 {
        return switch (content_type) {
            .text => font_size * 0.8, // Approximate text baseline
            .image => element_size.y, // Images align to bottom
            .container => element_size.y, // Containers align to bottom
            .inline_block => font_size * 0.8, // Same as text
            .replaced => element_size.y, // Replaced elements align to bottom
        };
    }

    const ContentType = enum {
        text,
        image,
        container,
        inline_block,
        replaced,
    };
};

/// Grid alignment utilities
pub const GridAlignment = struct {
    /// Grid cell alignment
    pub const CellAlignment = struct {
        horizontal: Alignment = .stretch,
        vertical: Alignment = .stretch,
    };

    /// Align element within a grid cell
    pub fn alignInCell(
        result: *LayoutResult,
        cell_bounds: Rectangle,
        alignment: CellAlignment,
    ) void {
        // Horizontal alignment
        switch (alignment.horizontal) {
            .start => result.position.x = cell_bounds.position.x,
            .center => result.position.x = cell_bounds.position.x + (cell_bounds.size.x - result.size.x) / 2,
            .end => result.position.x = cell_bounds.position.x + cell_bounds.size.x - result.size.x,
            .stretch => {
                result.position.x = cell_bounds.position.x;
                result.size.x = cell_bounds.size.x;
            },
        }

        // Vertical alignment
        switch (alignment.vertical) {
            .start => result.position.y = cell_bounds.position.y,
            .center => result.position.y = cell_bounds.position.y + (cell_bounds.size.y - result.size.y) / 2,
            .end => result.position.y = cell_bounds.position.y + cell_bounds.size.y - result.size.y,
            .stretch => {
                result.position.y = cell_bounds.position.y;
                result.size.y = cell_bounds.size.y;
            },
        }
    }

    /// Align multiple elements within grid cells
    pub fn alignInCells(
        results: []LayoutResult,
        cell_bounds: []const Rectangle,
        alignments: []const CellAlignment,
    ) void {
        const min_len = @min(@min(results.len, cell_bounds.len), alignments.len);

        for (0..min_len) |i| {
            alignInCell(&results[i], cell_bounds[i], alignments[i]);
        }
    }
};

/// Distribution algorithms for spacing elements
pub const Distribution = struct {
    /// Distribution modes
    pub const Mode = enum {
        space_between, // Equal space between elements
        space_around, // Equal space around elements
        space_evenly, // Equal space everywhere
        stretch, // Stretch elements to fill space
    };

    /// Distribute elements horizontally
    pub fn distributeHorizontal(
        results: []LayoutResult,
        container_bounds: Rectangle,
        mode: Mode,
    ) void {
        if (results.len <= 1) return;

        // Calculate total content width
        var content_width: f32 = 0;
        for (results) |result| {
            content_width += result.size.x;
        }

        const available_width = container_bounds.size.x;
        const extra_space = available_width - content_width;

        switch (mode) {
            .space_between => {
                const gap = extra_space / @as(f32, @floatFromInt(results.len - 1));
                var current_x = container_bounds.position.x;

                for (results) |*result| {
                    result.position.x = current_x;
                    current_x += result.size.x + gap;
                }
            },
            .space_around => {
                const space_per_element = extra_space / @as(f32, @floatFromInt(results.len));
                const half_space = space_per_element / 2;
                var current_x = container_bounds.position.x + half_space;

                for (results) |*result| {
                    result.position.x = current_x;
                    current_x += result.size.x + space_per_element;
                }
            },
            .space_evenly => {
                const gap = extra_space / @as(f32, @floatFromInt(results.len + 1));
                var current_x = container_bounds.position.x + gap;

                for (results) |*result| {
                    result.position.x = current_x;
                    current_x += result.size.x + gap;
                }
            },
            .stretch => {
                const additional_width_per_element = extra_space / @as(f32, @floatFromInt(results.len));
                var current_x = container_bounds.position.x;

                for (results) |*result| {
                    result.position.x = current_x;
                    result.size.x += additional_width_per_element;
                    current_x += result.size.x;
                }
            },
        }
    }

    /// Distribute elements vertically
    pub fn distributeVertical(
        results: []LayoutResult,
        container_bounds: Rectangle,
        mode: Mode,
    ) void {
        if (results.len <= 1) return;

        // Calculate total content height
        var content_height: f32 = 0;
        for (results) |result| {
            content_height += result.size.y;
        }

        const available_height = container_bounds.size.y;
        const extra_space = available_height - content_height;

        switch (mode) {
            .space_between => {
                const gap = extra_space / @as(f32, @floatFromInt(results.len - 1));
                var current_y = container_bounds.position.y;

                for (results) |*result| {
                    result.position.y = current_y;
                    current_y += result.size.y + gap;
                }
            },
            .space_around => {
                const space_per_element = extra_space / @as(f32, @floatFromInt(results.len));
                const half_space = space_per_element / 2;
                var current_y = container_bounds.position.y + half_space;

                for (results) |*result| {
                    result.position.y = current_y;
                    current_y += result.size.y + space_per_element;
                }
            },
            .space_evenly => {
                const gap = extra_space / @as(f32, @floatFromInt(results.len + 1));
                var current_y = container_bounds.position.y + gap;

                for (results) |*result| {
                    result.position.y = current_y;
                    current_y += result.size.y + gap;
                }
            },
            .stretch => {
                const additional_height_per_element = extra_space / @as(f32, @floatFromInt(results.len));
                var current_y = container_bounds.position.y;

                for (results) |*result| {
                    result.position.y = current_y;
                    result.size.y += additional_height_per_element;
                    current_y += result.size.y;
                }
            },
        }
    }
};

// Tests
test "content alignment" {
    const testing = std.testing;

    var results = [_]LayoutResult{
        LayoutResult{ .position = Vec2{ .x = 10, .y = 0 }, .size = Vec2{ .x = 50, .y = 20 }, .element_index = 0 },
        LayoutResult{ .position = Vec2{ .x = 70, .y = 0 }, .size = Vec2{ .x = 30, .y = 20 }, .element_index = 1 },
    };

    const container = Rectangle{ .position = Vec2{ .x = 0, .y = 0 }, .size = Vec2{ .x = 200, .y = 100 } };

    // Test center alignment
    ContentAlignment.alignHorizontal(&results, container, .center);

    // Content width is 100-10 = 90, available width is 200
    // Center offset should be (200-90)/2 = 55, so elements should start at 55-10 = 45
    const expected_offset = 45;
    try testing.expect(@abs(results[0].position.x - (10 + expected_offset)) < 0.1);
    try testing.expect(@abs(results[1].position.x - (70 + expected_offset)) < 0.1);
}

test "baseline alignment" {
    const testing = std.testing;

    var results = [_]LayoutResult{
        LayoutResult{ .position = Vec2{ .x = 0, .y = 10 }, .size = Vec2{ .x = 50, .y = 30 }, .element_index = 0 },
        LayoutResult{ .position = Vec2{ .x = 60, .y = 5 }, .size = Vec2{ .x = 40, .y = 20 }, .element_index = 1 },
    };

    const baseline_infos = [_]BaselineAlignment.BaselineInfo{
        BaselineAlignment.BaselineInfo{
            .baseline_offset = 24, // 30 * 0.8
            .bounds = Rectangle{ .position = Vec2{ .x = 0, .y = 10 }, .size = Vec2{ .x = 50, .y = 30 } },
            .element_index = 0,
        },
        BaselineAlignment.BaselineInfo{
            .baseline_offset = 16, // 20 * 0.8
            .bounds = Rectangle{ .position = Vec2{ .x = 60, .y = 5 }, .size = Vec2{ .x = 40, .y = 20 } },
            .element_index = 1,
        },
    };

    const container = Rectangle{ .position = Vec2{ .x = 0, .y = 0 }, .size = Vec2{ .x = 200, .y = 100 } };

    BaselineAlignment.alignToBaseline(&results, &baseline_infos, container);

    // Elements should be positioned so their baselines align
    const baseline_y = 50; // container center
    try testing.expect(@abs(results[0].position.y - (baseline_y - 24)) < 0.1);
    try testing.expect(@abs(results[1].position.y - (baseline_y - 16)) < 0.1);
}

test "distribution algorithms" {
    const testing = std.testing;

    var results = [_]LayoutResult{
        LayoutResult{ .position = Vec2{ .x = 0, .y = 0 }, .size = Vec2{ .x = 50, .y = 20 }, .element_index = 0 },
        LayoutResult{ .position = Vec2{ .x = 0, .y = 0 }, .size = Vec2{ .x = 30, .y = 20 }, .element_index = 1 },
        LayoutResult{ .position = Vec2{ .x = 0, .y = 0 }, .size = Vec2{ .x = 40, .y = 20 }, .element_index = 2 },
    };

    const container = Rectangle{ .position = Vec2{ .x = 0, .y = 0 }, .size = Vec2{ .x = 200, .y = 100 } };

    // Test space-between distribution
    Distribution.distributeHorizontal(&results, container, .space_between);

    // Content width = 50+30+40 = 120, available = 200, extra = 80
    // Gap between elements = 80/2 = 40
    try testing.expect(results[0].position.x == 0);
    try testing.expect(results[1].position.x == 90); // 0 + 50 + 40
    try testing.expect(results[2].position.x == 160); // 90 + 30 + 40
}
