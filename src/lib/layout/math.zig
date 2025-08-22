/// Barrel import module for layout-specific math utilities
/// Provides convenient access to all math functionality needed by layout algorithms
/// This consolidates imports and provides a clean API for layout implementers

// Re-export core math needed by layout algorithms
const math_mod = @import("../math/mod.zig");

// Core geometric types
pub const Vec2 = math_mod.Vec2;
pub const Rectangle = math_mod.Rectangle;
pub const Circle = math_mod.Circle;
pub const Line = math_mod.Line;
pub const Bounds = math_mod.Bounds;
pub const Spacing = math_mod.Spacing;

// Scalar math utilities (commonly used in layouts)
pub const scalar = math_mod.scalar;
pub const lerp = scalar.lerp;
pub const clamp = scalar.clamp;
pub const mix = scalar.mix;
pub const smoothstep = scalar.smoothstep;
pub const saturate = scalar.saturate;
pub const remap = scalar.remap;

// New layout-specific scalar utilities
pub const distributeProportional = scalar.distributeProportional;
pub const constrainWithAspect = scalar.constrainWithAspect;
pub const smoothLayout = scalar.smoothLayout;
pub const calculateEvenSpacing = scalar.calculateEvenSpacing;
pub const roundToPixel = scalar.roundToPixel;

// Distance calculations (frequently used in layout)
pub const distance = math_mod.distance;
pub const distanceSquared = math_mod.distanceSquared;

// Layout-specific geometry utilities
pub const layout = @import("../math/layout.zig");

// Convenience re-exports for layout algorithms
pub const LayoutGeometry = layout.LayoutGeometry;
pub const PositionUtils = layout.PositionUtils;
pub const SpaceDistributionUtils = layout.SpaceDistributionUtils;
pub const FlexUtils = layout.FlexUtils;

// Layout-specific types
pub const Direction = layout.Direction;
pub const Axis = layout.Axis;
pub const SpaceDistribution = layout.SpaceDistribution;
pub const PositionSpec = layout.PositionSpec;

// Axis calculations - commonly used patterns
pub const getMainAxisSize = LayoutGeometry.getMainAxisSize;
pub const getCrossAxisSize = LayoutGeometry.getCrossAxisSize;
pub const setMainAxisSize = LayoutGeometry.setMainAxisSize;
pub const setCrossAxisSize = LayoutGeometry.setCrossAxisSize;

// Position conflict resolution - commonly used patterns
pub const isOverConstrained = PositionUtils.isOverConstrained;
pub const resolveConflicts = PositionUtils.resolveConflicts;
pub const resolveConflictsWith = PositionUtils.resolveConflictsWith;

// Flex calculations - commonly used patterns
pub const calculateFlexGrow = FlexUtils.calculateFlexGrow;
pub const calculateFlexShrink = FlexUtils.calculateFlexShrink;
pub const shouldReverseOrder = FlexUtils.shouldReverseOrder;

// Spacing calculations - commonly used patterns
pub const getMainAxisSpacing = LayoutGeometry.getMainAxisSpacing;
pub const getCrossAxisSpacing = LayoutGeometry.getCrossAxisSpacing;
pub const getSpacingTotal = LayoutGeometry.getSpacingTotal;

// Space distribution - commonly used patterns
pub const calculateItemPositions = SpaceDistributionUtils.calculateItemPositions;
pub const calculateSpacing = SpaceDistributionUtils.calculateSpacing;

// Convenience constants for common directions
pub const ROW = Direction.row;
pub const COLUMN = Direction.column;
pub const ROW_REVERSE = Direction.row_reverse;
pub const COLUMN_REVERSE = Direction.column_reverse;

// Convenience constants for space distribution
pub const START = SpaceDistribution.start;
pub const END = SpaceDistribution.end;
pub const CENTER = SpaceDistribution.center;
pub const SPACE_BETWEEN = SpaceDistribution.space_between;
pub const SPACE_AROUND = SpaceDistribution.space_around;
pub const SPACE_EVENLY = SpaceDistribution.space_evenly;

// Common layout helper functions
pub const LayoutHelpers = struct {
    /// Create uniform spacing
    pub fn uniformSpacing(value: f32) Spacing {
        return Spacing.uniform(value);
    }

    /// Create horizontal-only spacing
    pub fn horizontalSpacing(value: f32) Spacing {
        return Spacing.horizontal(value);
    }

    /// Create vertical-only spacing
    pub fn verticalSpacing(value: f32) Spacing {
        return Spacing.vertical(value);
    }

    /// Create asymmetric spacing (vertical, horizontal)
    pub fn asymmetricSpacing(vert: f32, horiz: f32) Spacing {
        return Spacing.asymmetric(vert, horiz);
    }

    /// Check if direction is horizontal
    pub fn isHorizontal(direction: Direction) bool {
        return switch (direction) {
            .row, .row_reverse => true,
            .column, .column_reverse => false,
        };
    }

    /// Check if direction is vertical
    pub fn isVertical(direction: Direction) bool {
        return !LayoutHelpers.isHorizontal(direction);
    }

    /// Check if direction should reverse
    pub fn isReversed(direction: Direction) bool {
        return switch (direction) {
            .row_reverse, .column_reverse => true,
            .row, .column => false,
        };
    }

    /// Get opposite direction
    pub fn oppositeDirection(direction: Direction) Direction {
        return switch (direction) {
            .row => .column,
            .column => .row,
            .row_reverse => .column_reverse,
            .column_reverse => .row_reverse,
        };
    }

    /// Constrain size to fit within bounds
    pub fn constrainSize(size: Vec2, min_size: Vec2, max_size: Vec2) Vec2 {
        return Vec2{
            .x = clamp(size.x, min_size.x, max_size.x),
            .y = clamp(size.y, min_size.y, max_size.y),
        };
    }

    /// Calculate aspect ratio from size
    pub fn aspectRatio(size: Vec2) f32 {
        if (size.y == 0) return 1.0;
        return size.x / size.y;
    }

    /// Apply aspect ratio to size (constraining by width)
    pub fn applyAspectRatioByWidth(width: f32, ratio: f32) Vec2 {
        return Vec2{ .x = width, .y = width / ratio };
    }

    /// Apply aspect ratio to size (constraining by height)
    pub fn applyAspectRatioByHeight(height: f32, ratio: f32) Vec2 {
        return Vec2{ .x = height * ratio, .y = height };
    }
};

// Re-export helpers for convenience
pub const uniformSpacing = LayoutHelpers.uniformSpacing;
pub const horizontalSpacing = LayoutHelpers.horizontalSpacing;
pub const verticalSpacing = LayoutHelpers.verticalSpacing;
pub const asymmetricSpacing = LayoutHelpers.asymmetricSpacing;
pub const isHorizontal = LayoutHelpers.isHorizontal;
pub const isVertical = LayoutHelpers.isVertical;
pub const isReversed = LayoutHelpers.isReversed;
pub const oppositeDirection = LayoutHelpers.oppositeDirection;
pub const constrainSize = LayoutHelpers.constrainSize;
pub const aspectRatio = LayoutHelpers.aspectRatio;
pub const applyAspectRatioByWidth = LayoutHelpers.applyAspectRatioByWidth;
pub const applyAspectRatioByHeight = LayoutHelpers.applyAspectRatioByHeight;

// Testing support
const std = @import("std");

test "layout math barrel imports" {
    // Test that we can access core types
    const pos = Vec2{ .x = 10, .y = 20 };
    const size = Vec2{ .x = 100, .y = 80 };
    const rect = Rectangle{ .position = pos, .size = size };

    try std.testing.expect(rect.area() == 8000);

    // Test that we can access layout utilities
    const main_size = getMainAxisSize(size, .row);
    try std.testing.expect(main_size == 100);

    // Test helper functions
    const spacing = uniformSpacing(10);
    try std.testing.expect(spacing.top == 10 and spacing.left == 10);

    try std.testing.expect(isHorizontal(.row));
    try std.testing.expect(isVertical(.column));
    try std.testing.expect(isReversed(.row_reverse));
    try std.testing.expect(oppositeDirection(.row) == .column);

    // Test aspect ratio helpers
    const ratio = aspectRatio(Vec2{ .x = 16, .y = 9 });
    try std.testing.expectApproxEqAbs(@as(f32, 16.0 / 9.0), ratio, 0.001);

    const sized_by_width = applyAspectRatioByWidth(160, ratio);
    try std.testing.expectApproxEqAbs(@as(f32, 90), sized_by_width.y, 0.001);
}
