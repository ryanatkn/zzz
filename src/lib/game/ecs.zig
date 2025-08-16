/// ECS (Entity Component System) barrel export
/// Provides core abstractions for game entity management with clean zone isolation
///
/// TODO @many: Evaluate complex ECS vs simple direct arrays - complex may be better for:
/// - Dynamic component composition
/// - Cache-friendly iteration patterns  
/// - Easier addition of new component types
/// - Better tooling/debugging support
/// Need benchmark comparison and feature evaluation in followup session
/// Currently UNUSED - hex game uses simple arrays in hex_game.zig
pub const entity = @import("entity.zig");
pub const storage = @import("storage.zig");
pub const components = @import("components.zig");
pub const component_registry = @import("component_registry.zig");
pub const archetype_storage = @import("archetype_storage.zig");
pub const world = @import("world.zig");
pub const zone = @import("zone.zig");
pub const game = @import("game.zig");
pub const system_registry = @import("system_registry.zig");

// Legacy exports (deprecated - files removed)
// pub const legacy_world = @import("legacy_world.zig");
// pub const zoned_world = @import("zoned_world.zig");

// Core types
pub const EntityId = entity.EntityId;
pub const EntityAllocator = entity.EntityAllocator;

// New composable architecture (recommended)
pub const ComponentRegistry = component_registry.ComponentRegistry;
pub const ArchetypeRegistry = component_registry.ArchetypeRegistry;
pub const World = world.World;
pub const Zone = zone.Zone;
pub const ZoneMetadata = zone.ZoneMetadata;
pub const Game = game.Game;
pub const EntityWithZone = world.EntityWithZone;
pub const SystemRegistry = system_registry.SystemRegistry;
pub const GameSystems = system_registry.GameSystems;

// Archetype storage types
pub const PlayerArchetype = archetype_storage.PlayerArchetype;
pub const UnitArchetype = archetype_storage.UnitArchetype;
pub const ProjectileArchetype = archetype_storage.ProjectileArchetype;
pub const ObstacleArchetype = archetype_storage.ObstacleArchetype;
pub const LifestoneArchetype = archetype_storage.LifestoneArchetype;
pub const PortalArchetype = archetype_storage.PortalArchetype;

// Legacy types (deprecated - temporary compatibility aliases)
// TODO: Migrate hex game to use new Game/Zone architecture
pub const ZonedWorld = Game; // Temporary alias for backward compatibility
pub const ZoneStorage = World; // Temporary alias for backward compatibility

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
pub const PlayerInput = components.PlayerInput;
pub const Projectile = components.Projectile;
pub const Terrain = components.Terrain;
pub const Awakeable = components.Awakeable;
pub const Interactable = components.Interactable;
