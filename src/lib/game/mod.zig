/// Game systems barrel export - reusable patterns and interfaces
/// Engine provides interfaces, games provide implementations

// Core simple helpers
pub const ecs = @import("ecs.zig");
pub const components = @import("components.zig");
pub const cooldowns = @import("cooldowns.zig");

// Behaviors
pub const behaviors = @import("behaviors/mod.zig");

// Control systems  
pub const control = @import("control/mod.zig");

// Projectiles
pub const projectiles = @import("projectiles/bullet_pool.zig");

// New generic systems
pub const persistence = @import("persistence/mod.zig");
pub const abilities = @import("abilities/mod.zig");
pub const systems = @import("systems/mod.zig");
pub const input = @import("input/mod.zig");

// Simple ID generation
pub const EntityId = ecs.EntityId;
pub const INVALID_ENTITY = ecs.INVALID_ENTITY;

// Backwards compatibility
pub const bullet_pool = projectiles;