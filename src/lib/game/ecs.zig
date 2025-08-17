/// Simple game helpers - no complex ECS
/// Just the useful, battle-tested utilities

// Simple entity ID - just a u32
pub const EntityId = u32;
pub const INVALID_ENTITY: EntityId = @import("std").math.maxInt(u32);

// Generic game components
pub const components = @import("components.zig");

// Useful game helpers that are actually used
pub const timer_patterns = @import("timer_patterns.zig");
pub const behaviors = @import("behaviors/mod.zig");
pub const bullet_pool = @import("projectiles/bullet_pool.zig");
pub const ai_control = @import("control/mod.zig");
