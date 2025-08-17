pub const entity_storage = @import("entity_storage.zig");
pub const hex_archetypes = @import("hex_archetypes.zig");

// Re-export key types
pub const EntityStorage = entity_storage.EntityStorage;
pub const MultiComponentStorage = entity_storage.MultiComponentStorage;
pub const EntityIterator = entity_storage.EntityIterator;

// Re-export archetype storages
pub const PlayerStorage = hex_archetypes.PlayerStorage;
pub const UnitStorage = hex_archetypes.UnitStorage;
pub const ProjectileStorage = hex_archetypes.ProjectileStorage;
pub const TerrainStorage = hex_archetypes.TerrainStorage;
pub const InteractiveStorage = hex_archetypes.InteractiveStorage;