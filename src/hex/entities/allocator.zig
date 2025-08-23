const std = @import("std");

/// Entity ID type
pub const EntityId = u32;
pub const INVALID_ENTITY: EntityId = std.math.maxInt(u32);

/// Simple entity allocator extracted from hex_game.zig
pub const EntityAllocator = struct {
    next_id: EntityId = 1, // Start from 1, 0 is invalid

    pub fn create(self: *EntityAllocator) EntityId {
        const id = self.next_id;
        self.next_id += 1;
        return id;
    }
};
