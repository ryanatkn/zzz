// Core components module - provides unified access to all components

// Basic components
pub const Transform = @import("transform.zig").Transform;
pub const Health = @import("health.zig").Health;
pub const Movement = @import("movement.zig").Movement;
pub const Visual = @import("visual.zig").Visual;
pub const Unit = @import("unit.zig").Unit; // Generic Unit function
pub const Combat = @import("combat.zig").Combat;
pub const StatusSystem = @import("statuses.zig").StatusSystem; // Generic status system
pub const PlayerInput = @import("player_input.zig").PlayerInput;
pub const Projectile = @import("projectile.zig").Projectile;
pub const Capabilities = @import("capabilities.zig").Capabilities;

// Terrain components (legacy monolithic + new decomposed)
pub const Terrain = @import("terrain.zig").Terrain;
pub const Solid = @import("solid.zig").Solid;
pub const Opaque = @import("opaque.zig").Opaque;
pub const Surface = @import("surface.zig").Surface;

// Game-specific components have been moved to game implementations
// See src/hex/components/ for hex-specific magic and behavior components

// Entity ID type definition
const std = @import("std");
pub const EntityId = u32;
pub const INVALID_ENTITY: EntityId = std.math.maxInt(u32);
