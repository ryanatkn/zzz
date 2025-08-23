// Entity system modules - extracted from hex_game.zig for better organization

pub const EntityFactory = @import("factory.zig").EntityFactory;
pub const EntityQueries = @import("queries.zig").EntityQueries;
pub const EntityAllocator = @import("allocator.zig").EntityAllocator;
pub const EntityId = @import("allocator.zig").EntityId;
pub const INVALID_ENTITY = @import("allocator.zig").INVALID_ENTITY;
pub const EntityType = @import("queries.zig").EntityType;

// Re-export for convenience
pub const factory = @import("factory.zig");
pub const queries = @import("queries.zig");
pub const allocator = @import("allocator.zig");
