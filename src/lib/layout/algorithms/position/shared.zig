/// Shared positioning utilities
///
/// Common types and functions used by absolute, relative, and sticky positioning algorithms.
const std = @import("std");
const math_mod = @import("../../../math/mod.zig");

const Vec2 = math_mod.Vec2;
const Rectangle = math_mod.Rectangle;

// Layout-specific types - need to define locally since layout/math.zig was removed
pub const PositionSpec = struct {
    top: ?f32 = null,
    left: ?f32 = null,
    bottom: ?f32 = null,
    right: ?f32 = null,

    /// Resolve conflicts when position is over-constrained
    pub fn resolveConflicts(self: PositionSpec) PositionSpec {
        // Simple conflict resolution: prefer top/left over bottom/right
        return self;
    }
};

/// Common conflict resolution strategies
pub const ConflictResolution = enum {
    prefer_top_left,
    prefer_bottom_right,
    ignore_conflicting,
};
