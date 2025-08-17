pub const entity_storage = @import("entity_storage.zig");

// Re-export key types
pub const EntityStorage = entity_storage.EntityStorage;
pub const MultiComponentStorage = entity_storage.MultiComponentStorage;
pub const EntityIterator = entity_storage.EntityIterator;