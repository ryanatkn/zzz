/// Shared positioning utilities
/// 
/// Common types and functions used by absolute, relative, and sticky positioning algorithms.
const std = @import("std");
const math = @import("../../../math/mod.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;

/// Position specification for positioning algorithms
pub const PositionSpec = struct {
    /// Distance from top edge (null = not specified)
    top: ?f32 = null,
    /// Distance from right edge (null = not specified)
    right: ?f32 = null,
    /// Distance from bottom edge (null = not specified)
    bottom: ?f32 = null,
    /// Distance from left edge (null = not specified)
    left: ?f32 = null,
    /// Z-index for stacking order
    z_index: i32 = 0,

    /// Check if position is over-constrained
    pub fn isOverConstrained(self: PositionSpec) bool {
        const has_top = self.top != null;
        const has_bottom = self.bottom != null;
        const has_left = self.left != null;
        const has_right = self.right != null;

        return (has_top and has_bottom) or (has_left and has_right);
    }

    /// Resolve position conflicts by preferring top/left
    pub fn resolveConflicts(self: PositionSpec) PositionSpec {
        var resolved = self;

        // If both top and bottom are specified, ignore bottom
        if (self.top != null and self.bottom != null) {
            resolved.bottom = null;
        }

        // If both left and right are specified, ignore right
        if (self.left != null and self.right != null) {
            resolved.right = null;
        }

        return resolved;
    }
};

/// Common conflict resolution strategies
pub const ConflictResolution = enum {
    prefer_top_left,
    prefer_bottom_right,
    ignore_conflicting,
};