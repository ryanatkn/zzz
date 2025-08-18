// Core components module - provides unified access to all components
pub const Transform = @import("transform.zig").Transform;
pub const Health = @import("health.zig").Health;
pub const Movement = @import("movement.zig").Movement;
pub const Visual = @import("visual.zig").Visual;
pub const Unit = @import("unit.zig").Unit;
pub const Combat = @import("combat.zig").Combat;
pub const Effects = @import("effects.zig").Effects;
pub const PlayerInput = @import("player_input.zig").PlayerInput;
pub const Projectile = @import("projectile.zig").Projectile;
pub const Terrain = @import("terrain.zig").Terrain;
pub const Awakeable = @import("awakeable.zig").Awakeable;
pub const Interactable = @import("interactable.zig").Interactable;
pub const Hazard = @import("hazard.zig").Hazard;

// Entity ID type definition
pub const EntityId = u32;
pub const INVALID_ENTITY: EntityId = @import("std").math.maxInt(u32);