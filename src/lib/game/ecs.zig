/// ECS (Entity Component System) barrel export
/// Provides core abstractions for game entity management
pub const entity = @import("entity.zig");
pub const storage = @import("storage.zig");
pub const components = @import("components.zig");
pub const world = @import("world.zig");

// Core types
pub const EntityId = entity.EntityId;
pub const EntityAllocator = entity.EntityAllocator;
pub const World = world.World;

// Storage types
pub const DenseStorage = storage.DenseStorage;
pub const SparseStorage = storage.SparseStorage;

// Component types
pub const Transform = components.Transform;
pub const Health = components.Health;
pub const Movement = components.Movement;
pub const Visual = components.Visual;
pub const Unit = components.Unit;
pub const Combat = components.Combat;
pub const Effects = components.Effects;
