/// Game systems barrel export - reusable patterns and interfaces
/// Engine provides interfaces, games provide implementations

// Core simple helpers
pub const components = @import("components/mod.zig");
pub const timer_patterns = @import("timer_patterns.zig");

// Behaviors
pub const behaviors = @import("behaviors/mod.zig");


// Combat systems
pub const combat = @import("combat/mod.zig");

// Control systems
pub const control = @import("control/mod.zig");

// Projectiles
pub const projectiles = @import("projectiles/bullet_pool.zig");

// New generic systems
pub const persistence = @import("persistence/mod.zig");
pub const abilities = @import("abilities/mod.zig");
pub const systems = @import("systems/mod.zig");
pub const input = @import("input/mod.zig");
pub const zones = @import("zones/mod.zig");
pub const storage = @import("storage/mod.zig");
pub const world = @import("world/mod.zig");

// Simple entity ID type - games can define their own if needed
pub const EntityId = u32;
pub const INVALID_ENTITY: EntityId = @import("std").math.maxInt(u32);

// Backwards compatibility
pub const bullet_pool = projectiles;
