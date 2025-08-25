// Game systems modules - extracted from game.zig for better organization

pub const CollisionSystem = @import("collision.zig").CollisionSystem;
pub const LifestoneSystem = @import("lifestone.zig").LifestoneSystem;
pub const UpdateSystem = @import("update.zig").UpdateSystem;

// Re-export combat and abilities systems (existing)
pub const combat = @import("../combat/mod.zig");
pub const abilities = @import("../ability_system.zig");
pub const portal = @import("../portals.zig");

// Re-export for convenience
pub const collision = @import("collision.zig");
pub const lifestone = @import("lifestone.zig");
pub const update = @import("update.zig");
