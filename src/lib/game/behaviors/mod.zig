/// Behavior system module exports
///
/// This module provides reusable AI behavior patterns that can be used
/// across different game implementations without depending on specific
/// entity or component systems.
pub const chase_behavior = @import("chase_behavior.zig");
pub const flee_behavior = @import("flee_behavior.zig");
pub const patrol_behavior = @import("patrol_behavior.zig");
pub const guard_behavior = @import("guard_behavior.zig");
pub const wander_behavior = @import("wander_behavior.zig");
pub const return_home_behavior = @import("return_home_behavior.zig");
pub const unit_behavior = @import("unit_behavior.zig");

// No re-exports - import specific modules directly
