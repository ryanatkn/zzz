/// Layout-specific mathematical utilities and geometric calculations
/// Extracted from layout algorithms to reduce duplication and improve maintainability
const std = @import("std");
const Vec2 = @import("vec2.zig").Vec2;

// Import Direction from layout types to avoid duplication
const types = @import("../layout/core/types.zig");
pub const Direction = types.Direction;

pub const Axis = enum { horizontal, vertical };

pub const SpaceDistribution = enum {
    start,
    end,
    center,
    space_between,
    space_around,
    space_evenly,
};

pub const Spacing = struct {
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,

    pub fn getHorizontal(self: Spacing) f32 {
        return self.left + self.right;
    }

    pub fn getVertical(self: Spacing) f32 {
        return self.top + self.bottom;
    }
};

pub const PositionSpec = struct {
    top: ?f32 = null,
    right: ?f32 = null,
    bottom: ?f32 = null,
    left: ?f32 = null,
    z_index: i32 = 0,

    /// Check if position is over-constrained
    pub fn isOverConstrained(self: PositionSpec) bool {
        return PositionUtils.isOverConstrained(self);
    }

    /// Resolve position conflicts by preferring top/left
    pub fn resolveConflicts(self: PositionSpec) PositionSpec {
        return PositionUtils.resolveConflicts(self);
    }

    /// Resolve conflicts with different priority strategy
    pub fn resolveConflictsWith(self: PositionSpec, prefer_bottom_right: bool) PositionSpec {
        return PositionUtils.resolveConflictsWith(self, prefer_bottom_right);
    }
};

/// Layout geometry calculations
pub const LayoutGeometry = struct {
    /// Get size along main axis based on flex direction
    pub fn getMainAxisSize(size: Vec2, direction: Direction) f32 {
        return switch (direction) {
            .row, .row_reverse => size.x,
            .column, .column_reverse => size.y,
        };
    }

    /// Get size along cross axis based on flex direction
    pub fn getCrossAxisSize(size: Vec2, direction: Direction) f32 {
        return switch (direction) {
            .row, .row_reverse => size.y,
            .column, .column_reverse => size.x,
        };
    }

    /// Set size along main axis, returning new Vec2
    pub fn setMainAxisSize(size: Vec2, direction: Direction, main_size: f32) Vec2 {
        return switch (direction) {
            .row, .row_reverse => Vec2{ .x = main_size, .y = size.y },
            .column, .column_reverse => Vec2{ .x = size.x, .y = main_size },
        };
    }

    /// Set size along cross axis, returning new Vec2
    pub fn setCrossAxisSize(size: Vec2, direction: Direction, cross_size: f32) Vec2 {
        return switch (direction) {
            .row, .row_reverse => Vec2{ .x = size.x, .y = cross_size },
            .column, .column_reverse => Vec2{ .x = cross_size, .y = size.y },
        };
    }

    /// Get spacing total along specified axis
    pub fn getSpacingTotal(spacing: Spacing, axis: Axis) f32 {
        return switch (axis) {
            .horizontal => spacing.getHorizontal(),
            .vertical => spacing.getVertical(),
        };
    }

    /// Get spacing total for main axis based on direction
    pub fn getMainAxisSpacing(spacing: Spacing, direction: Direction) f32 {
        return switch (direction) {
            .row, .row_reverse => spacing.getHorizontal(),
            .column, .column_reverse => spacing.getVertical(),
        };
    }

    /// Get spacing total for cross axis based on direction
    pub fn getCrossAxisSpacing(spacing: Spacing, direction: Direction) f32 {
        return switch (direction) {
            .row, .row_reverse => spacing.getVertical(),
            .column, .column_reverse => spacing.getHorizontal(),
        };
    }

    /// Calculate axis enum from direction
    pub fn getMainAxis(direction: Direction) Axis {
        return switch (direction) {
            .row, .row_reverse => .horizontal,
            .column, .column_reverse => .vertical,
        };
    }

    /// Calculate cross axis enum from direction
    pub fn getCrossAxis(direction: Direction) Axis {
        return switch (direction) {
            .row, .row_reverse => .vertical,
            .column, .column_reverse => .horizontal,
        };
    }
};

/// Position conflict resolution utilities
pub const PositionUtils = struct {
    /// Check if position specification is over-constrained
    pub fn isOverConstrained(spec: PositionSpec) bool {
        const has_top = spec.top != null;
        const has_bottom = spec.bottom != null;
        const has_left = spec.left != null;
        const has_right = spec.right != null;

        return (has_top and has_bottom) or (has_left and has_right);
    }

    /// Resolve position conflicts by preferring top/left
    pub fn resolveConflicts(spec: PositionSpec) PositionSpec {
        var resolved = spec;

        // If both top and bottom are specified, ignore bottom
        if (spec.top != null and spec.bottom != null) {
            resolved.bottom = null;
        }

        // If both left and right are specified, ignore right
        if (spec.left != null and spec.right != null) {
            resolved.right = null;
        }

        return resolved;
    }

    /// Resolve conflicts with different priority strategy
    pub fn resolveConflictsWith(spec: PositionSpec, prefer_bottom_right: bool) PositionSpec {
        if (!prefer_bottom_right) {
            return resolveConflicts(spec);
        }

        var resolved = spec;

        // Prefer bottom/right instead
        if (spec.top != null and spec.bottom != null) {
            resolved.top = null;
        }

        if (spec.left != null and spec.right != null) {
            resolved.left = null;
        }

        return resolved;
    }
};

/// Space distribution calculations for layout algorithms
pub const SpaceDistributionUtils = struct {
    /// Calculate item positions based on space distribution mode
    pub fn calculateItemPositions(
        container_size: f32,
        item_sizes: []const f32,
        distribution: SpaceDistribution,
        allocator: std.mem.Allocator,
    ) ![]f32 {
        const item_count = item_sizes.len;
        if (item_count == 0) return &[_]f32{};

        var positions = try allocator.alloc(f32, item_count);

        // Calculate total item size
        var total_item_size: f32 = 0;
        for (item_sizes) |size| {
            total_item_size += size;
        }

        const available_space = @max(0, container_size - total_item_size);

        switch (distribution) {
            .start => {
                var current_pos: f32 = 0;
                for (item_sizes, 0..) |size, i| {
                    positions[i] = current_pos;
                    current_pos += size;
                }
            },
            .end => {
                var current_pos = available_space;
                for (item_sizes, 0..) |size, i| {
                    positions[i] = current_pos;
                    current_pos += size;
                }
            },
            .center => {
                var current_pos = available_space / 2.0;
                for (item_sizes, 0..) |size, i| {
                    positions[i] = current_pos;
                    current_pos += size;
                }
            },
            .space_between => {
                if (item_count == 1) {
                    positions[0] = 0;
                } else {
                    const gap = available_space / @as(f32, @floatFromInt(item_count - 1));
                    var current_pos: f32 = 0;
                    for (item_sizes, 0..) |size, i| {
                        positions[i] = current_pos;
                        current_pos += size + gap;
                    }
                }
            },
            .space_around => {
                const gap = available_space / @as(f32, @floatFromInt(item_count));
                var current_pos = gap / 2.0;
                for (item_sizes, 0..) |size, i| {
                    positions[i] = current_pos;
                    current_pos += size + gap;
                }
            },
            .space_evenly => {
                const gap = available_space / @as(f32, @floatFromInt(item_count + 1));
                var current_pos = gap;
                for (item_sizes, 0..) |size, i| {
                    positions[i] = current_pos;
                    current_pos += size + gap;
                }
            },
        }

        return positions;
    }

    /// Calculate spacing between items for a given distribution mode
    pub fn calculateSpacing(
        available_space: f32,
        item_count: usize,
        distribution: SpaceDistribution,
    ) f32 {
        if (item_count <= 1) return 0;

        return switch (distribution) {
            .start, .end, .center => 0,
            .space_between => available_space / @as(f32, @floatFromInt(item_count - 1)),
            .space_around => available_space / @as(f32, @floatFromInt(item_count)),
            .space_evenly => available_space / @as(f32, @floatFromInt(item_count + 1)),
        };
    }
};

/// Flex-specific calculations
pub const FlexUtils = struct {
    /// Calculate flex grow factor
    pub fn calculateFlexGrow(available_space: f32, flex_basis: f32, flex_grow: f32) f32 {
        if (flex_grow <= 0 or available_space <= 0) return flex_basis;
        return flex_basis + (available_space * flex_grow);
    }

    /// Calculate flex shrink factor
    pub fn calculateFlexShrink(
        overflow_space: f32,
        flex_basis: f32,
        flex_shrink: f32,
        total_shrink_factor: f32,
    ) f32 {
        if (flex_shrink <= 0 or overflow_space <= 0 or total_shrink_factor <= 0) return flex_basis;

        // In CSS flexbox: shrink proportion = (flex_basis * flex_shrink) / sum_of_all(flex_basis * flex_shrink)
        // But here total_shrink_factor represents the sum, so:
        const shrink_proportion = (flex_basis * flex_shrink) / total_shrink_factor;
        const shrink_amount = overflow_space * shrink_proportion;

        return @max(0, flex_basis - shrink_amount);
    }

    /// Check if direction should reverse element order
    pub fn shouldReverseOrder(direction: Direction) bool {
        return switch (direction) {
            .row_reverse, .column_reverse => true,
            .row, .column => false,
        };
    }
};

// Tests
test "LayoutGeometry axis calculations" {
    const size = Vec2{ .x = 100, .y = 200 };

    // Row direction - main axis is horizontal
    try std.testing.expectEqual(@as(f32, 100), LayoutGeometry.getMainAxisSize(size, .row));
    try std.testing.expectEqual(@as(f32, 200), LayoutGeometry.getCrossAxisSize(size, .row));

    // Column direction - main axis is vertical
    try std.testing.expectEqual(@as(f32, 200), LayoutGeometry.getMainAxisSize(size, .column));
    try std.testing.expectEqual(@as(f32, 100), LayoutGeometry.getCrossAxisSize(size, .column));
}

test "PositionUtils conflict resolution" {
    const over_constrained = PositionSpec{
        .top = 10,
        .bottom = 20,
        .left = 5,
        .right = 15,
    };

    try std.testing.expect(PositionUtils.isOverConstrained(over_constrained));

    const resolved = PositionUtils.resolveConflicts(over_constrained);
    try std.testing.expectEqual(@as(?f32, 10), resolved.top);
    try std.testing.expectEqual(@as(?f32, null), resolved.bottom);
    try std.testing.expectEqual(@as(?f32, 5), resolved.left);
    try std.testing.expectEqual(@as(?f32, null), resolved.right);
}

test "SpaceDistributionUtils calculations" {
    const allocator = std.testing.allocator;
    const item_sizes = [_]f32{ 50, 50, 50 }; // 150 total
    const container_size: f32 = 300; // 150 available space

    const positions = try SpaceDistributionUtils.calculateItemPositions(
        container_size,
        &item_sizes,
        .space_between,
        allocator,
    );
    defer allocator.free(positions);

    try std.testing.expectApproxEqAbs(@as(f32, 0), positions[0], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 125), positions[1], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 250), positions[2], 0.01);
}

test "FlexUtils calculations" {
    // Test flex grow
    const grown = FlexUtils.calculateFlexGrow(100, 50, 0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 100), grown, 0.01); // 50 + (100 * 0.5)

    // Test flex shrink: if total_shrink_factor = 100 * 1.0 = 100 (one item)
    // shrink_proportion = (100 * 1.0) / 100 = 1.0
    // shrink_amount = 50 * 1.0 = 50
    // result = max(0, 100 - 50) = 50
    const shrunk = FlexUtils.calculateFlexShrink(50, 100, 1.0, 100);
    try std.testing.expectApproxEqAbs(@as(f32, 50), shrunk, 0.01);

    // Test reverse order
    try std.testing.expect(FlexUtils.shouldReverseOrder(.row_reverse));
    try std.testing.expect(!FlexUtils.shouldReverseOrder(.row));
}

test "scalar utilities integration" {
    const scalar = @import("scalar.zig");

    // Test distributeProportional from scalar module
    const factors = [_]f32{ 1.0, 2.0, 1.0 };
    var results = [_]f32{ 0, 0, 0 };
    scalar.distributeProportional(100.0, &factors, &results);

    try std.testing.expectApproxEqAbs(@as(f32, 25.0), results[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), results[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 25.0), results[2], 0.001);

    // Test calculateEvenSpacing from scalar module
    const spacing = scalar.calculateEvenSpacing(300.0, 50.0, 3);
    try std.testing.expectApproxEqAbs(@as(f32, 75.0), spacing, 0.001);
}
