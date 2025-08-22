/// Shared positioning utilities
///
/// Common types and functions used by absolute, relative, and sticky positioning algorithms.
const std = @import("std");
const layout_math = @import("../../math.zig");

const Vec2 = layout_math.Vec2;
const Rectangle = layout_math.Rectangle;

/// Re-export PositionSpec from consolidated math utilities
pub const PositionSpec = layout_math.PositionSpec;

/// Common conflict resolution strategies
pub const ConflictResolution = enum {
    prefer_top_left,
    prefer_bottom_right,
    ignore_conflicting,
};
