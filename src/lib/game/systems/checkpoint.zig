const std = @import("std");
const math = @import("../../math/mod.zig");
const queries = @import("../../physics/queries.zig");

const Vec2 = math.Vec2;

/// Generic checkpoint data for respawn systems
pub const CheckpointData = struct {
    position: Vec2,
    zone_index: ?u32, // Optional zone association
    is_active: bool,  // Whether this checkpoint can be used
    data: ?*anyopaque, // Game-specific data
};

/// Result of a checkpoint search
pub const CheckpointSearchResult = struct {
    checkpoint: CheckpointData,
    distance: f32,
};

/// Generic checkpoint interface for games to implement
pub const CheckpointProvider = struct {
    /// Function pointer to get all available checkpoints
    getAllCheckpointsFn: *const fn (game_data: *anyopaque, checkpoints: []CheckpointData) usize,
    
    /// Game-specific data pointer
    game_data: *anyopaque,
    
    pub fn getAllCheckpoints(self: CheckpointProvider, checkpoints: []CheckpointData) usize {
        return self.getAllCheckpointsFn(self.game_data, checkpoints);
    }
};

/// Find the nearest active checkpoint to a given position
pub fn findNearestCheckpoint(provider: CheckpointProvider, position: Vec2, max_checkpoints: usize) ?CheckpointSearchResult {
    const allocator = std.heap.page_allocator; // Use a temporary allocator
    const checkpoints = allocator.alloc(CheckpointData, max_checkpoints) catch return null;
    defer allocator.free(checkpoints);
    
    const checkpoint_count = provider.getAllCheckpoints(checkpoints);
    if (checkpoint_count == 0) return null;
    
    // Convert to entity data for physics queries
    var entities: [256]queries.EntityData = undefined; // Reasonable limit
    const actual_count = @min(checkpoint_count, entities.len);
    
    for (0..actual_count) |i| {
        const checkpoint = checkpoints[i];
        if (!checkpoint.is_active) continue;
        
        entities[i] = queries.EntityData{
            .position = checkpoint.position,
            .radius = 10.0, // Default checkpoint radius
            .is_alive = true,
        };
    }
    
    const result = queries.PhysicsQueries.findNearestEntity(position, entities[0..actual_count], true);
    if (!result.found) return null;
    
    return CheckpointSearchResult{
        .checkpoint = checkpoints[result.index],
        .distance = result.distance,
    };
}

/// Zone-specific checkpoint search
pub fn findNearestCheckpointInZone(provider: CheckpointProvider, position: Vec2, zone_index: u32, max_checkpoints: usize) ?CheckpointSearchResult {
    const allocator = std.heap.page_allocator;
    const checkpoints = allocator.alloc(CheckpointData, max_checkpoints) catch return null;
    defer allocator.free(checkpoints);
    
    const checkpoint_count = provider.getAllCheckpoints(checkpoints);
    var zone_checkpoints: [256]CheckpointData = undefined;
    var zone_count: usize = 0;
    
    // Filter to specific zone
    for (0..checkpoint_count) |i| {
        const checkpoint = checkpoints[i];
        if (checkpoint.zone_index == zone_index and checkpoint.is_active) {
            zone_checkpoints[zone_count] = checkpoint;
            zone_count += 1;
            if (zone_count >= zone_checkpoints.len) break;
        }
    }
    
    if (zone_count == 0) return null;
    
    // Convert to entity data for physics queries
    var entities: [256]queries.EntityData = undefined;
    for (0..zone_count) |i| {
        entities[i] = queries.EntityData{
            .position = zone_checkpoints[i].position,
            .radius = 10.0,
            .is_alive = true,
        };
    }
    
    const result = queries.PhysicsQueries.findNearestEntity(position, entities[0..zone_count], true);
    if (!result.found) return null;
    
    return CheckpointSearchResult{
        .checkpoint = zone_checkpoints[result.index],
        .distance = result.distance,
    };
}