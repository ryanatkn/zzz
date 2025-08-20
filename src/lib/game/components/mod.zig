// Core components module - provides unified access to all components

// Basic components
pub const Transform = @import("transform.zig").Transform;
pub const Health = @import("health.zig").Health;
pub const Movement = @import("movement.zig").Movement;
pub const Visual = @import("visual.zig").Visual;
pub const Unit = @import("unit.zig").Unit;
pub const Combat = @import("combat.zig").Combat;
pub const Statuses = @import("statuses.zig").Statuses;
pub const PlayerInput = @import("player_input.zig").PlayerInput;
pub const Projectile = @import("projectile.zig").Projectile;
pub const Capabilities = @import("capabilities.zig").Capabilities;

// Terrain components (legacy monolithic + new decomposed)
pub const Terrain = @import("terrain.zig").Terrain;
pub const Solid = @import("solid.zig").Solid;
pub const Opaque = @import("opaque.zig").Opaque;
pub const Surface = @import("surface.zig").Surface;

// Behavior components
pub const Awakeable = @import("awakeable.zig").Awakeable;
pub const Interactable = @import("interactable.zig").Interactable;
pub const Hazard = @import("hazard.zig").Hazard;

// Magic components
pub const Phaseable = @import("phaseable.zig").Phaseable;
pub const Charmable = @import("charmable.zig").Charmable;
pub const Teleportable = @import("teleportable.zig").Teleportable;
pub const MagicTarget = @import("magic_target.zig").MagicTarget;

// Entity ID type definition
const std = @import("std");
pub const EntityId = u32;
pub const INVALID_ENTITY: EntityId = std.math.maxInt(u32);
