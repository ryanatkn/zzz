/// Positioning algorithms module
///
/// Provides absolute, relative, and sticky positioning layout algorithms.
pub const shared = @import("shared.zig");
pub const absolute = @import("absolute.zig");
pub const relative = @import("relative.zig");
pub const sticky = @import("sticky.zig");

// Re-export main types
pub const PositionSpec = shared.PositionSpec;
pub const ConflictResolution = shared.ConflictResolution;
pub const AbsoluteLayout = absolute.AbsoluteLayout;
pub const RelativeLayout = relative.RelativeLayout;
pub const StickyLayout = sticky.StickyLayout;
