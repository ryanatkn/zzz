/// Game helpers barrel export - simplified
/// Only the actually useful utilities, no complex ECS

// Core simple helpers
pub const ecs = @import("ecs.zig");
pub const components = @import("components.zig");
pub const cooldowns = @import("cooldowns.zig");

// Behaviors
pub const behaviors = @import("behaviors/mod.zig");

// Control systems  
pub const control = @import("control/mod.zig");

// Projectiles
pub const bullet_pool = @import("projectiles/bullet_pool.zig");

// State management removed - depends on deleted persistence system
// Hex game should implement its own simpler save/load

// Simple ID generation
pub const EntityId = ecs.EntityId;
pub const INVALID_ENTITY = ecs.INVALID_ENTITY;