/// Document flow algorithms for layout arrangement
///
/// This module implements various flow algorithms for arranging elements
/// within containers, including block flow, inline flow, and floating.
const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../core/types.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;
const LayoutResult = types.LayoutResult;
const PositionMode = types.PositionMode;

/// Block flow layout engine (elements stack vertically)
pub const BlockFlow = struct {
    /// Block flow configuration
    pub const Config = struct {
        margin_collapse: bool = true, // Collapse adjacent margins
        baseline_alignment: bool = false, // Align to text baseline
        spacing: f32 = 0, // Additional spacing between blocks
    };

    /// Calculate block flow layout
    pub fn calculateLayout(
        container_bounds: Rectangle,
        element_sizes: []const Vec2,
        element_margins: []const types.Spacing,
        config: Config,
        allocator: std.mem.Allocator,
    ) ![]LayoutResult {
        if (element_sizes.len != element_margins.len) {
            return error.MismatchedArrayLengths;
        }

        var results = try allocator.alloc(LayoutResult, element_sizes.len);
        var current_y = container_bounds.position.y;

        for (element_sizes, element_margins, 0..) |size, margin, i| {
            // Calculate margin collapse
            var effective_top_margin = margin.top;
            if (config.margin_collapse and i > 0) {
                const prev_margin = element_margins[i - 1];
                effective_top_margin = @max(margin.top, prev_margin.bottom) - prev_margin.bottom;
            }

            // Position element
            const x = container_bounds.position.x + margin.left;
            const y = current_y + effective_top_margin;

            results[i] = LayoutResult{
                .position = Vec2{ .x = x, .y = y },
                .size = size,
                .element_index = i,
            };

            // Update current_y for next element
            current_y = y + size.y + margin.bottom + config.spacing;
        }

        return results;
    }

    /// Calculate minimum height needed for block flow
    pub fn calculateMinHeight(
        element_sizes: []const Vec2,
        element_margins: []const types.Spacing,
        config: Config,
    ) f32 {
        if (element_sizes.len == 0) return 0;

        var total_height: f32 = 0;

        for (element_sizes, element_margins, 0..) |size, margin, i| {
            // Add top margin (with collapse consideration)
            if (i == 0) {
                total_height += margin.top;
            } else {
                const prev_margin = element_margins[i - 1];
                if (config.margin_collapse) {
                    total_height += @max(margin.top, prev_margin.bottom) - prev_margin.bottom;
                } else {
                    total_height += margin.top;
                }
            }

            // Add element height
            total_height += size.y;

            // Add bottom margin
            total_height += margin.bottom;

            // Add spacing (except for last element)
            if (i < element_sizes.len - 1) {
                total_height += config.spacing;
            }
        }

        return total_height;
    }
};

/// Inline flow layout engine (elements flow horizontally with wrapping)
pub const InlineFlow = struct {
    /// Inline flow configuration
    pub const Config = struct {
        line_height: f32 = 1.2, // Multiplier for line height
        word_spacing: f32 = 0, // Additional space between words
        letter_spacing: f32 = 0, // Additional space between letters
        text_align: types.Alignment = .start, // Text alignment within lines
        wrap_mode: WrapMode = .word, // How to handle wrapping
    };

    /// Text wrapping modes
    pub const WrapMode = enum {
        none, // No wrapping
        word, // Wrap at word boundaries
        character, // Wrap at any character
        break_word, // Break words if necessary
    };

    /// Information about a line of inline content
    pub const LineInfo = struct {
        start_index: usize, // First element on this line
        end_index: usize, // Last element on this line (exclusive)
        width: f32, // Total width of content on this line
        height: f32, // Height of this line
        baseline_y: f32, // Y position of text baseline
    };

    /// Calculate inline flow layout with line wrapping
    pub fn calculateLayout(
        container_bounds: Rectangle,
        element_sizes: []const Vec2,
        element_margins: []const types.Spacing,
        config: Config,
        allocator: std.mem.Allocator,
    ) !struct {
        results: []LayoutResult,
        lines: []LineInfo,
    } {
        if (element_sizes.len != element_margins.len) {
            return error.MismatchedArrayLengths;
        }

        var results = try allocator.alloc(LayoutResult, element_sizes.len);
        var lines = std.ArrayList(LineInfo).init(allocator);
        defer lines.deinit();

        var current_x = container_bounds.position.x;
        var current_y = container_bounds.position.y;
        var line_start: usize = 0;
        var line_width: f32 = 0;
        var line_height: f32 = 0;

        for (element_sizes, element_margins, 0..) |size, margin, i| {
            const element_width = margin.left + size.x + margin.right;
            const element_height = margin.top + size.y + margin.bottom;

            // Check if element fits on current line
            if (config.wrap_mode != .none and line_start < i and current_x + element_width > container_bounds.position.x + container_bounds.size.x) {
                // Start new line
                try finalizeLine(&lines, line_start, i, line_width, line_height, current_y, config);

                current_x = container_bounds.position.x;
                current_y += line_height;
                line_start = i;
                line_width = 0;
                line_height = 0;
            }

            // Position element on current line
            results[i] = LayoutResult{
                .position = Vec2{ .x = current_x + margin.left, .y = current_y + margin.top },
                .size = size,
                .element_index = i,
            };

            // Update line state
            current_x += element_width + config.word_spacing;
            line_width += element_width + config.word_spacing;
            line_height = @max(line_height, element_height);
        }

        // Finalize last line
        if (line_start < element_sizes.len) {
            try finalizeLine(&lines, line_start, element_sizes.len, line_width, line_height, current_y, config);
        }

        // Apply text alignment to each line
        for (lines.items) |line_info| {
            alignLineElements(results[line_info.start_index..line_info.end_index], container_bounds, line_info, config.text_align);
        }

        return .{
            .results = results,
            .lines = try lines.toOwnedSlice(),
        };
    }

    fn finalizeLine(
        lines: *std.ArrayList(LineInfo),
        start_index: usize,
        end_index: usize,
        width: f32,
        height: f32,
        y: f32,
        config: Config,
    ) !void {
        _ = config;
        try lines.append(LineInfo{
            .start_index = start_index,
            .end_index = end_index,
            .width = width,
            .height = height,
            .baseline_y = y + height * 0.8, // Estimate baseline position
        });
    }

    fn alignLineElements(
        line_results: []LayoutResult,
        container_bounds: Rectangle,
        line_info: LineInfo,
        alignment: types.Alignment,
    ) void {
        const available_width = container_bounds.size.x;
        const content_width = line_info.width;

        const offset = switch (alignment) {
            .start => 0,
            .center => (available_width - content_width) / 2,
            .end => available_width - content_width,
            .stretch => 0, // TODO: Implement text justification
        };

        for (line_results) |*result| {
            result.position.x += offset;
        }
    }
};

/// Float layout engine for floating elements
pub const FloatLayout = struct {
    /// Float direction
    pub const FloatDirection = enum {
        left,
        right,
        none,
    };

    /// Floating element info
    pub const FloatInfo = struct {
        direction: FloatDirection,
        clear: FloatDirection = .none, // Clear floating elements
        margin: types.Spacing = types.Spacing{},
    };

    /// Area occupied by floating elements
    pub const FloatArea = struct {
        left_floats: std.ArrayList(Rectangle),
        right_floats: std.ArrayList(Rectangle),

        pub fn init(allocator: std.mem.Allocator) FloatArea {
            return FloatArea{
                .left_floats = std.ArrayList(Rectangle).init(allocator),
                .right_floats = std.ArrayList(Rectangle).init(allocator),
            };
        }

        pub fn deinit(self: *FloatArea) void {
            self.left_floats.deinit();
            self.right_floats.deinit();
        }

        /// Find available space for non-floating content
        pub fn getAvailableSpace(self: *const FloatArea, container_bounds: Rectangle, y: f32, height: f32) Rectangle {
            var available = container_bounds;
            available.position.y = y;
            available.size.y = height;

            // Reduce available space based on left floats
            for (self.left_floats.items) |float_rect| {
                if (rectanglesOverlap(available, float_rect)) {
                    const overlap_right = float_rect.position.x + float_rect.size.x;
                    if (overlap_right > available.position.x) {
                        const reduction = overlap_right - available.position.x;
                        available.position.x = overlap_right;
                        available.size.x -= reduction;
                    }
                }
            }

            // Reduce available space based on right floats
            for (self.right_floats.items) |float_rect| {
                if (rectanglesOverlap(available, float_rect)) {
                    const overlap_left = float_rect.position.x;
                    const available_right = available.position.x + available.size.x;
                    if (overlap_left < available_right) {
                        available.size.x = overlap_left - available.position.x;
                    }
                }
            }

            return available;
        }

        fn rectanglesOverlap(rect1: Rectangle, rect2: Rectangle) bool {
            return !(rect1.position.x + rect1.size.x <= rect2.position.x or
                rect2.position.x + rect2.size.x <= rect1.position.x or
                rect1.position.y + rect1.size.y <= rect2.position.y or
                rect2.position.y + rect2.size.y <= rect1.position.y);
        }
    };

    /// Calculate float layout
    pub fn calculateFloatLayout(
        container_bounds: Rectangle,
        element_sizes: []const Vec2,
        float_infos: []const FloatInfo,
        allocator: std.mem.Allocator,
    ) ![]LayoutResult {
        if (element_sizes.len != float_infos.len) {
            return error.MismatchedArrayLengths;
        }

        var results = try allocator.alloc(LayoutResult, element_sizes.len);
        var float_area = FloatArea.init(allocator);
        defer float_area.deinit();

        for (element_sizes, float_infos, 0..) |size, float_info, i| {
            const element_rect = Rectangle{
                .position = Vec2.ZERO, // Will be calculated
                .size = Vec2{
                    .x = size.x + float_info.margin.getHorizontal(),
                    .y = size.y + float_info.margin.getVertical(),
                },
            };

            const position = switch (float_info.direction) {
                .left => try positionLeftFloat(&float_area, container_bounds, element_rect, float_info),
                .right => try positionRightFloat(&float_area, container_bounds, element_rect, float_info),
                .none => positionNormalFlow(&float_area, container_bounds, element_rect, float_info),
            };

            results[i] = LayoutResult{
                .position = Vec2{
                    .x = position.x + float_info.margin.left,
                    .y = position.y + float_info.margin.top,
                },
                .size = size,
                .element_index = i,
            };

            // Add to float area if floating
            if (float_info.direction != .none) {
                const float_rect = Rectangle{
                    .position = position,
                    .size = element_rect.size,
                };

                switch (float_info.direction) {
                    .left => try float_area.left_floats.append(float_rect),
                    .right => try float_area.right_floats.append(float_rect),
                    .none => unreachable,
                }
            }
        }

        return results;
    }

    fn positionLeftFloat(
        float_area: *FloatArea,
        container_bounds: Rectangle,
        element_rect: Rectangle,
        float_info: FloatInfo,
    ) !Vec2 {
        _ = float_info;
        var y = container_bounds.position.y;

        // Find first available position
        while (true) {
            const available = float_area.getAvailableSpace(container_bounds, y, element_rect.size.y);

            if (available.size.x >= element_rect.size.x) {
                return Vec2{ .x = available.position.x, .y = y };
            }

            y += 1; // Move down incrementally
            if (y + element_rect.size.y > container_bounds.position.y + container_bounds.size.y) {
                break; // Can't fit in container
            }
        }

        // Fallback to container position
        return container_bounds.position;
    }

    fn positionRightFloat(
        float_area: *FloatArea,
        container_bounds: Rectangle,
        element_rect: Rectangle,
        float_info: FloatInfo,
    ) !Vec2 {
        _ = float_info;
        var y = container_bounds.position.y;

        // Find first available position
        while (true) {
            const available = float_area.getAvailableSpace(container_bounds, y, element_rect.size.y);

            if (available.size.x >= element_rect.size.x) {
                const x = available.position.x + available.size.x - element_rect.size.x;
                return Vec2{ .x = x, .y = y };
            }

            y += 1; // Move down incrementally
            if (y + element_rect.size.y > container_bounds.position.y + container_bounds.size.y) {
                break; // Can't fit in container
            }
        }

        // Fallback to container position
        const x = container_bounds.position.x + container_bounds.size.x - element_rect.size.x;
        return Vec2{ .x = x, .y = container_bounds.position.y };
    }

    fn positionNormalFlow(
        float_area: *FloatArea,
        container_bounds: Rectangle,
        element_rect: Rectangle,
        float_info: FloatInfo,
    ) Vec2 {
        _ = float_info;
        const available = float_area.getAvailableSpace(container_bounds, container_bounds.position.y, element_rect.size.y);
        return available.position;
    }
};

// Tests
test "block flow layout" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const container = Rectangle{
        .position = Vec2{ .x = 10, .y = 20 },
        .size = Vec2{ .x = 200, .y = 300 },
    };

    const sizes = [_]Vec2{
        Vec2{ .x = 180, .y = 50 },
        Vec2{ .x = 160, .y = 30 },
        Vec2{ .x = 190, .y = 40 },
    };

    const margins = [_]types.Spacing{
        types.Spacing{ .top = 10, .bottom = 5 },
        types.Spacing{ .top = 8, .bottom = 12 },
        types.Spacing{ .top = 6, .bottom = 10 },
    };

    const config = BlockFlow.Config{ .margin_collapse = true };
    const results = try BlockFlow.calculateLayout(container, &sizes, &margins, config, allocator);
    defer allocator.free(results);

    try testing.expect(results.len == 3);

    // First element
    try testing.expect(results[0].position.x == 10); // container.x + margin.left (0)
    try testing.expect(results[0].position.y == 30); // container.y (20) + margin.top (10)

    // Second element (margin collapse: max(8, 5) = 8, but since prev bottom was 5, add 8-5=3)
    try testing.expect(results[1].position.y == 85); // 30 + 50 + 5 = 85, no collapse in this implementation

    // Calculate minimum height
    const min_height = BlockFlow.calculateMinHeight(&sizes, &margins, config);
    try testing.expect(min_height > 0);
}

test "inline flow layout" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const container = Rectangle{
        .position = Vec2{ .x = 0, .y = 0 },
        .size = Vec2{ .x = 100, .y = 200 },
    };

    const sizes = [_]Vec2{
        Vec2{ .x = 30, .y = 20 },
        Vec2{ .x = 40, .y = 15 },
        Vec2{ .x = 50, .y = 25 }, // This should wrap to next line
    };

    const margins = [_]types.Spacing{
        types.Spacing{},
        types.Spacing{},
        types.Spacing{},
    };

    const config = InlineFlow.Config{ .wrap_mode = .word };
    const layout = try InlineFlow.calculateLayout(container, &sizes, &margins, config, allocator);
    defer allocator.free(layout.results);
    defer allocator.free(layout.lines);

    try testing.expect(layout.results.len == 3);
    try testing.expect(layout.lines.len == 2); // Should have 2 lines

    // First two elements on first line
    try testing.expect(layout.results[0].position.y == layout.results[1].position.y);

    // Third element on second line
    try testing.expect(layout.results[2].position.y > layout.results[1].position.y);
}
