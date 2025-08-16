/// ECS (Entity Component System) barrel export
/// Provides both clear primitives and complex abstractions for comparison
///
/// CLEAR PRIMITIVES (New, recommended):
/// - ZonedWorld: Clear multi-zone manager
/// - ZoneStorage: Simple array-based storage per zone
/// - EntityId: Simple monotonic ID generation
///
/// COMPLEX SYSTEM (Preserved for comparison):
/// - Game/Zone/World: Complex multi-layer abstraction
/// - ArchetypeStorage: Metaprogramming-based storage
/// - EntityAllocator: Generation-tracked entity system

// ============================================================================
// CLEAR PRIMITIVES - Primary exports with understandable names
// ============================================================================

const zoned_world = @import("zoned_world.zig");
const zone_storage = @import("zone_storage.zig");
const entity_id = @import("entity_id.zig");

// Primary clear types - these are the recommended simple approach
pub const ZonedWorld = zoned_world.ZonedWorld;
pub const ZoneStorage = zone_storage.ZoneStorage;
pub const EntityId = entity_id.EntityId;
pub const EntityIdGenerator = entity_id.EntityIdGenerator;
pub const INVALID_ENTITY = entity_id.INVALID_ENTITY;

// ============================================================================
// COMPLEX SYSTEM - Preserved for comparison and benchmarking
// ============================================================================

const entity = @import("entity.zig");
const storage = @import("storage.zig");
const component_registry = @import("component_registry.zig");
const archetype_storage = @import("archetype_storage.zig");
const world = @import("world.zig");
const zone = @import("zone.zig");
const game = @import("game.zig");
const system_registry = @import("system_registry.zig");

// Complex system types (prefixed to avoid naming conflicts)
pub const ComplexEntityId = entity.EntityId;
pub const ComplexEntityAllocator = entity.EntityAllocator;

// Complex architecture components
pub const ComponentRegistry = component_registry.ComponentRegistry;
pub const ArchetypeRegistry = component_registry.ArchetypeRegistry;
pub const World = world.World;
pub const Zone = zone.Zone;
pub const Game = game.Game;
pub const EntityWithZone = world.EntityWithZone;
pub const SystemRegistry = system_registry.SystemRegistry;
pub const GameSystems = system_registry.GameSystems;

// Complex archetype storage types
pub const PlayerArchetype = archetype_storage.PlayerArchetype;
pub const UnitArchetype = archetype_storage.UnitArchetype;
pub const ProjectileArchetype = archetype_storage.ProjectileArchetype;
pub const ObstacleArchetype = archetype_storage.ObstacleArchetype;
pub const LifestoneArchetype = archetype_storage.LifestoneArchetype;
pub const PortalArchetype = archetype_storage.PortalArchetype;

// Complex storage strategies
pub const DenseStorage = storage.DenseStorage;
pub const SparseStorage = storage.SparseStorage;

// ============================================================================
// SHARED COMPONENTS - Used by both systems
// ============================================================================

const components = @import("components.zig");

// Zone metadata (shared between both systems)
pub const ZoneMetadata = zone.ZoneMetadata;

// Component types (shared between both systems)
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