const std = @import("std");

/// Generic save system interface
/// Games implement specific save data structures but use these patterns
pub const SaveSystemInterface = struct {
    /// Generic save data creation pattern
    pub fn fromGameState(comptime SaveType: type, world: anytype, stats: anytype) !SaveType {
        // Call game-specific implementation
        return SaveType.fromGameStateImpl(world, stats);
    }

    /// Generic save data application pattern
    pub fn applyToGameState(save_data: anytype, world: anytype, stats: anytype) void {
        // Call game-specific implementation
        @TypeOf(save_data.*).applyToGameStateImpl(save_data, world, stats);
    }
};

/// Generic entity save data pattern
/// Games can use this as a base or define their own
pub fn EntitySaveData(comptime EntityId: type) type {
    return struct {
        entity_id: EntityId,
        pos: @Vector(2, f32),
        alive: bool,
        // Games can extend with additional fields
    };
}

/// Generic zone save data pattern
/// Games customize with their specific entity types and limits
pub fn ZoneSaveData(comptime EntityId: type, comptime max_entities: usize) type {
    return struct {
        entities: std.BoundedArray(EntitySaveData(EntityId), max_entities),

        pub fn init() @This() {
            return .{
                .entities = std.BoundedArray(EntitySaveData(EntityId), max_entities).init(0) catch unreachable,
            };
        }
    };
}

/// Cached data calculation patterns
pub const CachePatterns = struct {
    /// Calculate completion percentage from completed/total
    pub fn completionPercentage(completed: usize, total: usize) f32 {
        if (total == 0) return 0.0;
        return @as(f32, @floatFromInt(completed)) / @as(f32, @floatFromInt(total)) * 100.0;
    }

    /// Check if all items in array are completed
    pub fn allCompleted(items: anytype) bool {
        for (items) |item| {
            if (!item) return false;
        }
        return items.len > 0;
    }
};
