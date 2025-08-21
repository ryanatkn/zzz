/// Flexbox layout algorithm implementation
///
/// This module implements the CSS Flexbox layout algorithm with support for
/// flex direction, wrapping, alignment, and flex grow/shrink properties.

const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../types.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;

/// Flex layout algorithm
pub const FlexLayout = struct {
    /// Flex container configuration
    pub const Config = struct {
        /// Flex direction (row, column, etc.)
        direction: types.Direction = .row,
        /// Whether to wrap flex items
        wrap: types.FlexWrap = .no_wrap,
        /// How to distribute items along main axis
        justify_content: types.JustifyContent = .flex_start,
        /// How to align items along cross axis
        align_items: types.AlignItems = .stretch,
        /// How to align wrapped lines
        align_content: types.AlignItems = .stretch,
        /// Gap between items
        gap: f32 = 0.0,
        /// Gap between rows/columns when wrapping
        row_gap: ?f32 = null,
        /// Gap between columns/rows when wrapping
        column_gap: ?f32 = null,
    };

    /// Flex item properties
    pub const FlexItem = struct {
        /// Preferred size of the item
        size: Vec2,
        /// Item margins
        margin: types.Spacing,
        /// Size constraints
        constraints: types.Constraints,
        /// Flex grow factor (0 = don't grow)
        flex_grow: f32 = 0.0,
        /// Flex shrink factor (1 = can shrink)
        flex_shrink: f32 = 1.0,
        /// Flex basis (preferred main axis size)
        flex_basis: ?f32 = null,
        /// Self alignment override
        align_self: ?types.AlignItems = null,
        /// Element index for results
        index: usize,
    };

    /// Perform flex layout calculation
    pub fn calculateLayout(
        container_bounds: Rectangle,
        items: []const FlexItem,
        config: Config,
        allocator: std.mem.Allocator,
    ) ![]types.LayoutResult {
        if (items.len == 0) {
            return try allocator.alloc(types.LayoutResult, 0);
        }

        const is_row = config.direction == .row or config.direction == .row_reverse;
        const is_reverse = config.direction == .row_reverse or config.direction == .column_reverse;

        // Calculate available space
        const container_main_size = if (is_row) container_bounds.size.x else container_bounds.size.y;
        const container_cross_size = if (is_row) container_bounds.size.y else container_bounds.size.x;

        // Group items into lines (for wrapping)
        const lines = try createFlexLines(items, container_main_size, config, allocator);
        defer {
            for (lines.items) |line| {
                allocator.free(line.items);
            }
            lines.deinit();
        }

        // Calculate layout for each line
        var results = try allocator.alloc(types.LayoutResult, items.len);
        var current_cross_offset: f32 = 0.0;

        for (lines.items) |line| {
            const line_results = try calculateLineLayout(
                container_bounds,
                line.items,
                config,
                container_main_size,
                container_cross_size,
                current_cross_offset,
                allocator,
            );
            defer allocator.free(line_results);

            // Copy line results to main results array
            for (line_results) |line_result| {
                results[line_result.element_index] = line_result;
            }

            // Calculate cross axis size for this line
            var line_cross_size: f32 = 0;
            for (line_results) |line_result| {
                const cross_size = if (is_row) line_result.size.y else line_result.size.x;
                line_cross_size = @max(line_cross_size, cross_size);
            }

            // Add gap between lines
            current_cross_offset += line_cross_size;
            if (lines.items.len > 1) {
                const cross_gap = if (is_row) 
                    (config.row_gap orelse config.gap) 
                else 
                    (config.column_gap orelse config.gap);
                current_cross_offset += cross_gap;
            }
        }

        // Apply reverse order if needed
        if (is_reverse) {
            reverseResults(results, config.direction);
        }

        return results;
    }

    /// Create flex lines for wrapping
    fn createFlexLines(
        items: []const FlexItem,
        container_main_size: f32,
        config: Config,
        allocator: std.mem.Allocator,
    ) !std.ArrayList(std.ArrayList(FlexItem)) {
        var lines = std.ArrayList(std.ArrayList(FlexItem)).init(allocator);
        
        if (config.wrap == .no_wrap) {
            // Single line - all items
            var line = std.ArrayList(FlexItem).init(allocator);
            try line.appendSlice(items);
            try lines.append(line);
            return lines;
        }

        // Multi-line wrapping
        var current_line = std.ArrayList(FlexItem).init(allocator);
        var current_line_size: f32 = 0;
        
        const main_gap = if (config.direction == .row or config.direction == .row_reverse)
            (config.column_gap orelse config.gap)
        else
            (config.row_gap orelse config.gap);

        for (items) |item| {
            const item_main_size = getItemMainSize(item, config.direction);
            const item_size_with_gap = item_main_size + if (current_line.items.len > 0) main_gap else 0;
            
            // Check if item fits on current line
            if (current_line.items.len > 0 and current_line_size + item_size_with_gap > container_main_size) {
                // Start new line
                try lines.append(current_line);
                current_line = std.ArrayList(FlexItem).init(allocator);
                current_line_size = 0;
            }
            
            try current_line.append(item);
            current_line_size += item_size_with_gap;
        }
        
        // Add final line if not empty
        if (current_line.items.len > 0) {
            try lines.append(current_line);
        }

        return lines;
    }

    /// Calculate layout for a single flex line
    fn calculateLineLayout(
        container_bounds: Rectangle,
        line_items: []const FlexItem,
        config: Config,
        container_main_size: f32,
        container_cross_size: f32,
        cross_offset: f32,
        allocator: std.mem.Allocator,
    ) ![]types.LayoutResult {
        const is_row = config.direction == .row or config.direction == .row_reverse;
        var results = try allocator.alloc(types.LayoutResult, line_items.len);
        
        // Calculate flex item sizes
        const item_sizes = try calculateFlexItemSizes(line_items, container_main_size, config, allocator);
        defer allocator.free(item_sizes);
        
        // Calculate main axis positions using justify-content
        const positions = try calculateMainAxisPositions(
            item_sizes,
            container_main_size,
            config.justify_content,
            config,
            allocator,
        );
        defer allocator.free(positions);
        
        // Create results
        for (line_items, 0..) |item, i| {
            const main_pos = positions[i];
            const main_size = item_sizes[i].main;
            const cross_size = item_sizes[i].cross;
            
            // Calculate cross axis position based on align-items or align-self
            const alignment = item.align_self orelse config.align_items;
            const cross_pos = calculateCrossAxisPosition(cross_size, container_cross_size, alignment) + cross_offset;
            
            results[i] = types.LayoutResult{
                .position = if (is_row) 
                    Vec2{ .x = container_bounds.position.x + main_pos, .y = container_bounds.position.y + cross_pos }
                else 
                    Vec2{ .x = container_bounds.position.x + cross_pos, .y = container_bounds.position.y + main_pos },
                .size = if (is_row) 
                    Vec2{ .x = main_size, .y = cross_size }
                else 
                    Vec2{ .x = cross_size, .y = main_size },
                .element_index = item.index,
            };
        }
        
        return results;
    }

    /// Item size calculation result
    const ItemSize = struct {
        main: f32,
        cross: f32,
    };

    /// Calculate flex item sizes with grow/shrink
    fn calculateFlexItemSizes(
        items: []const FlexItem,
        container_main_size: f32,
        config: Config,
        allocator: std.mem.Allocator,
    ) ![]ItemSize {
        var item_sizes = try allocator.alloc(ItemSize, items.len);
        
        const is_row = config.direction == .row or config.direction == .row_reverse;
        
        // Calculate base sizes and total
        var total_base_size: f32 = 0;
        var total_grow: f32 = 0;
        var total_shrink: f32 = 0;
        
        const main_gap = if (is_row) 
            (config.column_gap orelse config.gap) 
        else 
            (config.row_gap orelse config.gap);
        
        const total_gap = if (items.len > 1) @as(f32, @floatFromInt(items.len - 1)) * main_gap else 0;
        
        for (items, 0..) |item, i| {
            const base_main_size = item.flex_basis orelse getItemMainSize(item, config.direction);
            const base_cross_size = getItemCrossSize(item, config.direction);
            
            item_sizes[i] = ItemSize{
                .main = item.constraints.constrainWidth(base_main_size),
                .cross = item.constraints.constrainHeight(base_cross_size),
            };
            
            total_base_size += item_sizes[i].main;
            total_grow += item.flex_grow;
            total_shrink += item.flex_shrink;
        }
        
        // Calculate available space for growing/shrinking
        const available_space = container_main_size - total_base_size - total_gap;
        
        if (available_space > 0 and total_grow > 0) {
            // Distribute extra space to growing items
            const space_per_grow_unit = available_space / total_grow;
            
            for (items, 0..) |item, i| {
                if (item.flex_grow > 0) {
                    const growth = space_per_grow_unit * item.flex_grow;
                    item_sizes[i].main += growth;
                    item_sizes[i].main = item.constraints.constrainWidth(item_sizes[i].main);
                }
            }
        } else if (available_space < 0 and total_shrink > 0) {
            // Shrink items to fit
            const shrink_factor = @min(1.0, -available_space / total_base_size);
            
            for (items, 0..) |item, i| {
                if (item.flex_shrink > 0) {
                    const shrinkage = item_sizes[i].main * shrink_factor * item.flex_shrink / total_shrink;
                    item_sizes[i].main -= shrinkage;
                    item_sizes[i].main = @max(0, item_sizes[i].main);
                    item_sizes[i].main = item.constraints.constrainWidth(item_sizes[i].main);
                }
            }
        }
        
        return item_sizes;
    }

    /// Calculate main axis positions based on justify-content
    fn calculateMainAxisPositions(
        item_sizes: []const ItemSize,
        container_main_size: f32,
        justify_content: types.JustifyContent,
        config: Config,
        allocator: std.mem.Allocator,
    ) ![]f32 {
        var positions = try allocator.alloc(f32, item_sizes.len);
        
        if (item_sizes.len == 0) return positions;
        
        // Calculate total size of all items
        var total_item_size: f32 = 0;
        for (item_sizes) |size| {
            total_item_size += size.main;
        }
        
        const is_row = config.direction == .row or config.direction == .row_reverse;
        const main_gap = if (is_row) 
            (config.column_gap orelse config.gap) 
        else 
            (config.row_gap orelse config.gap);
        
        const total_gap = if (item_sizes.len > 1) @as(f32, @floatFromInt(item_sizes.len - 1)) * main_gap else 0;
        const remaining_space = container_main_size - total_item_size - total_gap;
        
        switch (justify_content) {
            .flex_start => {
                var current_pos: f32 = 0;
                for (item_sizes, 0..) |size, i| {
                    positions[i] = current_pos;
                    current_pos += size.main + main_gap;
                }
            },
            .flex_end => {
                var current_pos = remaining_space;
                for (item_sizes, 0..) |size, i| {
                    positions[i] = current_pos;
                    current_pos += size.main + main_gap;
                }
            },
            .center => {
                var current_pos = remaining_space / 2.0;
                for (item_sizes, 0..) |size, i| {
                    positions[i] = current_pos;
                    current_pos += size.main + main_gap;
                }
            },
            .space_between => {
                if (item_sizes.len == 1) {
                    positions[0] = 0;
                } else {
                    const space_between = remaining_space / @as(f32, @floatFromInt(item_sizes.len - 1));
                    var current_pos: f32 = 0;
                    for (item_sizes, 0..) |size, i| {
                        positions[i] = current_pos;
                        current_pos += size.main + space_between;
                    }
                }
            },
            .space_around => {
                const space_around = remaining_space / @as(f32, @floatFromInt(item_sizes.len));
                var current_pos = space_around / 2.0;
                for (item_sizes, 0..) |size, i| {
                    positions[i] = current_pos;
                    current_pos += size.main + space_around;
                }
            },
            .space_evenly => {
                const space_evenly = remaining_space / @as(f32, @floatFromInt(item_sizes.len + 1));
                var current_pos = space_evenly;
                for (item_sizes, 0..) |size, i| {
                    positions[i] = current_pos;
                    current_pos += size.main + space_evenly;
                }
            },
        }
        
        return positions;
    }

    /// Calculate cross axis position for an item
    fn calculateCrossAxisPosition(
        item_cross_size: f32,
        container_cross_size: f32,
        alignment: types.AlignItems,
    ) f32 {
        return switch (alignment) {
            .flex_start => 0,
            .flex_end => container_cross_size - item_cross_size,
            .center => (container_cross_size - item_cross_size) / 2.0,
            .stretch => 0, // Item should be stretched to fill
            .baseline => 0, // TODO: Implement baseline alignment
        };
    }

    /// Get item's main axis size
    fn getItemMainSize(item: FlexItem, direction: types.Direction) f32 {
        return switch (direction) {
            .row, .row_reverse => item.size.x,
            .column, .column_reverse => item.size.y,
        };
    }

    /// Get item's cross axis size
    fn getItemCrossSize(item: FlexItem, direction: types.Direction) f32 {
        return switch (direction) {
            .row, .row_reverse => item.size.y,
            .column, .column_reverse => item.size.x,
        };
    }

    /// Reverse results for reverse directions
    fn reverseResults(results: []types.LayoutResult, direction: types.Direction) void {
        switch (direction) {
            .row_reverse, .column_reverse => {
                std.mem.reverse(types.LayoutResult, results);
            },
            else => {},
        }
    }
};

// Tests
test "flex layout basic row layout" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){}; 
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const container = Rectangle{
        .position = Vec2.ZERO,
        .size = Vec2{ .x = 400, .y = 200 },
    };
    
    const items = [_]FlexLayout.FlexItem{
        .{
            .size = Vec2{ .x = 100, .y = 50 },
            .margin = types.Spacing{},
            .constraints = types.Constraints{},
            .index = 0,
        },
        .{
            .size = Vec2{ .x = 80, .y = 40 },
            .margin = types.Spacing{},
            .constraints = types.Constraints{},
            .index = 1,
        },
    };
    
    const config = FlexLayout.Config{ .direction = .row };
    const results = try FlexLayout.calculateLayout(container, &items, config, allocator);
    defer allocator.free(results);
    
    try testing.expect(results.len == 2);
    
    // Items should be laid out horizontally
    try testing.expect(results[0].position.x == 0);
    try testing.expect(results[1].position.x == 100); // After first item
    
    // Both items should start at same Y position
    try testing.expect(results[0].position.y == results[1].position.y);
}

test "flex layout with justify content center" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){}; 
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const container = Rectangle{
        .position = Vec2.ZERO,
        .size = Vec2{ .x = 400, .y = 200 },
    };
    
    const items = [_]FlexLayout.FlexItem{
        .{
            .size = Vec2{ .x = 100, .y = 50 },
            .margin = types.Spacing{},
            .constraints = types.Constraints{},
            .index = 0,
        },
    };
    
    const config = FlexLayout.Config{
        .direction = .row,
        .justify_content = .center,
    };
    const results = try FlexLayout.calculateLayout(container, &items, config, allocator);
    defer allocator.free(results);
    
    // Item should be centered horizontally
    const expected_x = (container.size.x - items[0].size.x) / 2.0;
    try testing.expect(@abs(results[0].position.x - expected_x) < 0.1);
}

test "flex layout with flex grow" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){}; 
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const container = Rectangle{
        .position = Vec2.ZERO,
        .size = Vec2{ .x = 400, .y = 200 },
    };
    
    const items = [_]FlexLayout.FlexItem{
        .{
            .size = Vec2{ .x = 100, .y = 50 },
            .margin = types.Spacing{},
            .constraints = types.Constraints{},
            .flex_grow = 1.0,
            .index = 0,
        },
        .{
            .size = Vec2{ .x = 100, .y = 50 },
            .margin = types.Spacing{},
            .constraints = types.Constraints{},
            .flex_grow = 1.0,
            .index = 1,
        },
    };
    
    const config = FlexLayout.Config{ .direction = .row };
    const results = try FlexLayout.calculateLayout(container, &items, config, allocator);
    defer allocator.free(results);
    
    // Items should grow to fill available space equally
    const expected_width = container.size.x / 2.0;
    try testing.expect(@abs(results[0].size.x - expected_width) < 0.1);
    try testing.expect(@abs(results[1].size.x - expected_width) < 0.1);
}