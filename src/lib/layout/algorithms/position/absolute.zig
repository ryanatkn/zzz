/// Absolute positioning layout algorithm
const std = @import("std");
const math = @import("../../../math/mod.zig");
const types = @import("../../core/types.zig");
const shared = @import("shared.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;
const PositionSpec = shared.PositionSpec;
const ConflictResolution = shared.ConflictResolution;

/// Absolute positioning layout algorithm
pub const AbsoluteLayout = struct {
    /// Absolute positioning configuration
    pub const Config = struct {
        /// Default containing block if none specified
        default_containing_block: Rectangle,
        /// Whether to clip elements to containing block
        clip_to_container: bool = false,
        /// How to handle over-constrained positions
        conflict_resolution: ConflictResolution = .prefer_top_left,
    };

    /// Absolutely positioned element
    pub const AbsoluteElement = struct {
        /// Element's intrinsic size
        size: Vec2,
        /// Element margins
        margin: types.Spacing,
        /// Size constraints
        constraints: types.Constraints,
        /// Position specification
        position: PositionSpec,
        /// Containing block (if different from default)
        containing_block: ?Rectangle = null,
        /// Whether element is fixed position (relative to viewport)
        is_fixed: bool = false,
        /// Element index for results
        index: usize,
    };

    /// Calculate absolute layout
    pub fn calculateLayout(
        elements: []const AbsoluteElement,
        config: Config,
        allocator: std.mem.Allocator,
    ) ![]types.LayoutResult {
        var results = try allocator.alloc(types.LayoutResult, elements.len);

        for (elements, 0..) |element, i| {
            results[i] = calculateElementLayout(element, config);
        }

        // Sort by z-index for correct rendering order
        std.sort.pdq(types.LayoutResult, results, {}, compareByZIndex);

        return results;
    }

    /// Calculate layout for a single element
    fn calculateElementLayout(element: AbsoluteElement, config: Config) types.LayoutResult {
        const containing_block = element.containing_block orelse config.default_containing_block;

        // Resolve position conflicts
        var position_spec = element.position;
        switch (config.conflict_resolution) {
            .prefer_top_left => position_spec = position_spec.resolveConflicts(),
            .prefer_bottom_right => {
                // Custom resolution preferring bottom/right
                if (position_spec.top != null and position_spec.bottom != null) {
                    position_spec.top = null;
                }
                if (position_spec.left != null and position_spec.right != null) {
                    position_spec.left = null;
                }
            },
            .ignore_conflicting => {
                // Keep all constraints, may lead to unexpected results
            },
        }

        // Calculate element size
        var element_size = element.size;
        element_size.x = element.constraints.constrainWidth(element_size.x);
        element_size.y = element.constraints.constrainHeight(element_size.y);

        // Calculate position
        const element_position = calculatePosition(
            position_spec,
            element_size,
            element.margin,
            containing_block,
        );

        var result = types.LayoutResult{
            .position = element_position,
            .size = element_size,
            .content = types.Rectangle{
                .position = element_position,
                .size = element_size,
            },
            .element_index = element.index,
        };

        // Apply clipping if enabled
        if (config.clip_to_container) {
            result = clipToContainer(result, containing_block);
        }

        return result;
    }

    /// Calculate element position based on position specification
    fn calculatePosition(
        position_spec: PositionSpec,
        element_size: Vec2,
        margin: types.Spacing,
        containing_block: Rectangle,
    ) Vec2 {
        var position = Vec2.ZERO;

        // Calculate horizontal position
        if (position_spec.left) |left| {
            position.x = containing_block.position.x + left + margin.left;
        } else if (position_spec.right) |right| {
            position.x = containing_block.position.x + containing_block.size.x -
                right - element_size.x - margin.right;
        } else {
            // No horizontal constraint, use containing block start
            position.x = containing_block.position.x + margin.left;
        }

        // Calculate vertical position
        if (position_spec.top) |top| {
            position.y = containing_block.position.y + top + margin.top;
        } else if (position_spec.bottom) |bottom| {
            position.y = containing_block.position.y + containing_block.size.y -
                bottom - element_size.y - margin.bottom;
        } else {
            // No vertical constraint, use containing block start
            position.y = containing_block.position.y + margin.top;
        }

        // Handle over-constrained cases (both sides specified)
        if (position_spec.left != null and position_spec.right != null) {
            // Element should stretch to fill the space
            const left = position_spec.left.?;
            const right = position_spec.right.?;
            const available_width = containing_block.size.x - left - right - margin.getHorizontal();
            // Note: We already resolved conflicts above, so this shouldn't happen
            // unless conflict_resolution is .ignore_conflicting
            _ = available_width;
        }

        if (position_spec.top != null and position_spec.bottom != null) {
            // Element should stretch to fill the space
            const top = position_spec.top.?;
            const bottom = position_spec.bottom.?;
            const available_height = containing_block.size.y - top - bottom - margin.getVertical();
            // Note: We already resolved conflicts above, so this shouldn't happen
            // unless conflict_resolution is .ignore_conflicting
            _ = available_height;
        }

        return position;
    }

    /// Clip element to containing block bounds
    fn clipToContainer(result: types.LayoutResult, containing_block: Rectangle) types.LayoutResult {
        var clipped = result;

        // Clip position to container bounds
        clipped.position.x = @max(clipped.position.x, containing_block.position.x);
        clipped.position.y = @max(clipped.position.y, containing_block.position.y);

        // Clip size if element extends beyond container
        const container_right = containing_block.position.x + containing_block.size.x;
        const container_bottom = containing_block.position.y + containing_block.size.y;

        if (clipped.position.x + clipped.size.x > container_right) {
            clipped.size.x = @max(0, container_right - clipped.position.x);
        }

        if (clipped.position.y + clipped.size.y > container_bottom) {
            clipped.size.y = @max(0, container_bottom - clipped.position.y);
        }

        return clipped;
    }

    /// Compare function for sorting by z-index
    fn compareByZIndex(_: void, a: types.LayoutResult, b: types.LayoutResult) bool {
        // This is a simplified comparison - in a real implementation,
        // we'd need access to the original z-index values
        return a.element_index < b.element_index;
    }
};

// Tests
test "absolute layout basic positioning" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const containing_block = Rectangle{
        .position = Vec2{ .x = 10, .y = 20 },
        .size = Vec2{ .x = 400, .y = 300 },
    };

    const elements = [_]AbsoluteLayout.AbsoluteElement{
        .{
            .size = Vec2{ .x = 100, .y = 80 },
            .margin = types.Spacing{},
            .constraints = types.Constraints{},
            .position = PositionSpec{
                .top = 50,
                .left = 30,
            },
            .index = 0,
        },
        .{
            .size = Vec2{ .x = 80, .y = 60 },
            .margin = types.Spacing{},
            .constraints = types.Constraints{},
            .position = PositionSpec{
                .bottom = 40,
                .right = 25,
            },
            .index = 1,
        },
    };

    const config = AbsoluteLayout.Config{
        .default_containing_block = containing_block,
    };

    const results = try AbsoluteLayout.calculateLayout(&elements, config, allocator);
    defer allocator.free(results);

    try testing.expect(results.len == 2);

    // First element: positioned from top-left
    try testing.expect(results[0].position.x == 40); // 10 + 30
    try testing.expect(results[0].position.y == 70); // 20 + 50

    // Second element: positioned from bottom-right
    try testing.expect(results[1].position.x == 305); // 10 + 400 - 25 - 80
    try testing.expect(results[1].position.y == 220); // 20 + 300 - 40 - 60 = 220
}

test "absolute layout conflict resolution" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const containing_block = Rectangle{
        .position = Vec2.ZERO,
        .size = Vec2{ .x = 400, .y = 300 },
    };

    // Element with conflicting constraints (both top and bottom)
    const elements = [_]AbsoluteLayout.AbsoluteElement{
        .{
            .size = Vec2{ .x = 100, .y = 80 },
            .margin = types.Spacing{},
            .constraints = types.Constraints{},
            .position = PositionSpec{
                .top = 50,
                .bottom = 60, // This should be ignored due to conflict
                .left = 30,
            },
            .index = 0,
        },
    };

    const config = AbsoluteLayout.Config{
        .default_containing_block = containing_block,
        .conflict_resolution = .prefer_top_left,
    };

    const results = try AbsoluteLayout.calculateLayout(&elements, config, allocator);
    defer allocator.free(results);

    // Should use top constraint, ignoring bottom
    try testing.expect(results[0].position.y == 50);
}
