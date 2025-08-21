/// Sticky positioning layout algorithm
const std = @import("std");
const math = @import("../../../math/mod.zig");
const types = @import("../../core/types.zig");
const shared = @import("shared.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;
const PositionSpec = shared.PositionSpec;

/// Sticky positioning layout algorithm
pub const StickyLayout = struct {
    /// Sticky positioning configuration
    pub const Config = struct {
        /// Scroll offset of the container
        scroll_offset: Vec2 = Vec2.ZERO,
        /// Container viewport bounds
        viewport_bounds: Rectangle,
    };

    /// Sticky positioned element
    pub const StickyElement = struct {
        /// Base layout result (normal flow position)
        base_result: types.LayoutResult,
        /// Sticky position constraints
        sticky_position: PositionSpec,
        /// Containing block for sticky positioning
        containing_block: Rectangle,
        /// Element index for results
        index: usize,
    };

    /// Calculate sticky layout
    pub fn calculateLayout(
        elements: []const StickyElement,
        config: Config,
        allocator: std.mem.Allocator,
    ) ![]types.LayoutResult {
        var results = try allocator.alloc(types.LayoutResult, elements.len);

        for (elements, 0..) |element, i| {
            results[i] = calculateStickyPosition(element, config);
        }

        return results;
    }

    /// Calculate sticky position for an element
    fn calculateStickyPosition(element: StickyElement, config: Config) types.LayoutResult {
        var result = element.base_result;
        result.element_index = element.index;

        // Calculate if element should be stuck
        const viewport_top = config.viewport_bounds.position.y + config.scroll_offset.y;
        const viewport_bottom = viewport_top + config.viewport_bounds.size.y;
        const viewport_left = config.viewport_bounds.position.x + config.scroll_offset.x;
        const viewport_right = viewport_left + config.viewport_bounds.size.x;

        // Check top constraint
        if (element.sticky_position.top) |top_offset| {
            const stick_position = viewport_top + top_offset;
            if (result.position.y < stick_position) {
                result.position.y = stick_position;
            }
        }

        // Check bottom constraint
        if (element.sticky_position.bottom) |bottom_offset| {
            const stick_position = viewport_bottom - bottom_offset - result.size.y;
            if (result.position.y > stick_position) {
                result.position.y = stick_position;
            }
        }

        // Check left constraint
        if (element.sticky_position.left) |left_offset| {
            const stick_position = viewport_left + left_offset;
            if (result.position.x < stick_position) {
                result.position.x = stick_position;
            }
        }

        // Check right constraint
        if (element.sticky_position.right) |right_offset| {
            const stick_position = viewport_right - right_offset - result.size.x;
            if (result.position.x > stick_position) {
                result.position.x = stick_position;
            }
        }

        // Ensure element stays within containing block
        const cb_right = element.containing_block.position.x + element.containing_block.size.x;
        const cb_bottom = element.containing_block.position.y + element.containing_block.size.y;

        result.position.x = std.math.clamp(
            result.position.x,
            element.containing_block.position.x,
            cb_right - result.size.x,
        );

        result.position.y = std.math.clamp(
            result.position.y,
            element.containing_block.position.y,
            cb_bottom - result.size.y,
        );

        return result;
    }
};
