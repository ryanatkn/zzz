/// Simple game helpers - no complex ECS
/// Just the useful, battle-tested utilities

// Simple entity ID - just a u32
pub const EntityId = u32;
pub const INVALID_ENTITY: EntityId = @import("std").math.maxInt(u32);

// Simple components from hex game (for backwards compat during transition)
pub const components = @import("components.zig");

// Useful game helpers that are actually used
pub const cooldowns = @import("cooldowns.zig");
pub const behaviors = @import("behaviors/mod.zig");
pub const bullet_pool = @import("projectiles/bullet_pool.zig");
pub const ai_control = @import("control/mod.zig");