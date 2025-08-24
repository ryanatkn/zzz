pub const entity_storage = @import("entity_storage.zig");
pub const generic_archetypes = @import("generic_archetypes.zig");

// Re-export key types
pub const EntityStorage = entity_storage.EntityStorage;
pub const MultiComponentStorage = entity_storage.MultiComponentStorage;
pub const EntityIterator = entity_storage.EntityIterator;

// Re-export archetype storages
pub const UnitStorage = generic_archetypes.UnitStorage;
pub const ProjectileStorage = generic_archetypes.ProjectileStorage;
pub const TerrainStorage = generic_archetypes.TerrainStorage;
pub const InteractiveStorage = generic_archetypes.InteractiveStorage;
