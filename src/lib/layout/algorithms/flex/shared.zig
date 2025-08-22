/// Shared utilities and types for flex layout algorithms
const std = @import("std");
const layout_math = @import("../../math.zig");
const types = @import("../../core/types.zig");

pub const Vec2 = layout_math.Vec2;
pub const Rectangle = layout_math.Rectangle;

/// Flex container configuration
pub const Config = struct {
    /// Flex direction (row, column, etc.)
    direction: types.Direction = .row,
    /// Whether to wrap flex items
    wrap: types.FlexWrap = .no_wrap,
    /// How to distribute items along main axis
    justify_content: types.JustifyContent = .start,
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

/// Get item size along main axis
pub fn getItemMainSize(item: FlexItem, direction: types.Direction) f32 {
    return layout_math.getMainAxisSize(item.size, direction);
}

/// Get item size along cross axis
pub fn getItemCrossSize(item: FlexItem, direction: types.Direction) f32 {
    return layout_math.getCrossAxisSize(item.size, direction);
}

/// Reverse layout results based on direction
pub fn reverseResults(results: []types.LayoutResult, direction: types.Direction) void {
    if (layout_math.shouldReverseOrder(direction)) {
        // Reverse the order of results
        var i: usize = 0;
        var j: usize = results.len - 1;
        while (i < j) {
            const temp = results[i];
            results[i] = results[j];
            results[j] = temp;
            i += 1;
            j -= 1;
        }
    }
}
