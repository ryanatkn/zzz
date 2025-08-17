const std = @import("std");
const math = @import("../../math/mod.zig");

const Vec2 = math.Vec2;

/// Generic respawn system interface
/// Games implement specific checkpoint finding and respawn logic
pub const RespawnInterface = struct {
    /// Generic checkpoint/spawn point data
    pub const CheckpointData = struct {
        position: Vec2,
        zone_index: ?usize = null,
        active: bool = true,
        
        pub fn init(position: Vec2) CheckpointData {
            return .{ .position = position };
        }
        
        pub fn withZone(self: CheckpointData, zone_index: usize) CheckpointData {
            var checkpoint = self;
            checkpoint.zone_index = zone_index;
            return checkpoint;
        }
    };

    /// Result of finding nearest checkpoint
    pub const CheckpointResult = struct {
        checkpoint: CheckpointData,
        distance_squared: f32,
        
        pub fn init(checkpoint: CheckpointData, player_pos: Vec2) CheckpointResult {
            return .{
                .checkpoint = checkpoint,
                .distance_squared = checkpoint.position.distanceSquared(player_pos),
            };
        }
    };

    /// Generic respawn state management
    pub const RespawnState = struct {
        is_respawning: bool = false,
        respawn_position: Vec2 = Vec2{ .x = 0, .y = 0 },
        target_zone: ?usize = null,
        
        pub fn init() RespawnState {
            return .{};
        }
        
        pub fn startRespawn(self: *RespawnState, position: Vec2, zone: ?usize) void {
            self.is_respawning = true;
            self.respawn_position = position;
            self.target_zone = zone;
        }
        
        pub fn finishRespawn(self: *RespawnState) void {
            self.is_respawning = false;
            self.target_zone = null;
        }
    };
};

/// Generic checkpoint management patterns
pub const CheckpointPatterns = struct {
    /// Find nearest active checkpoint from a list
    pub fn findNearest(checkpoints: []const RespawnInterface.CheckpointData, player_pos: Vec2) ?RespawnInterface.CheckpointResult {
        var nearest: ?RespawnInterface.CheckpointResult = null;
        
        for (checkpoints) |checkpoint| {
            if (!checkpoint.active) continue;
            
            const result = RespawnInterface.CheckpointResult.init(checkpoint, player_pos);
            
            if (nearest == null or result.distance_squared < nearest.?.distance_squared) {
                nearest = result;
            }
        }
        
        return nearest;
    }

    /// Find nearest checkpoint in specific zone
    pub fn findNearestInZone(checkpoints: []const RespawnInterface.CheckpointData, player_pos: Vec2, zone_index: usize) ?RespawnInterface.CheckpointResult {
        var nearest: ?RespawnInterface.CheckpointResult = null;
        
        for (checkpoints) |checkpoint| {
            if (!checkpoint.active) continue;
            if (checkpoint.zone_index != zone_index) continue;
            
            const result = RespawnInterface.CheckpointResult.init(checkpoint, player_pos);
            
            if (nearest == null or result.distance_squared < nearest.?.distance_squared) {
                nearest = result;
            }
        }
        
        return nearest;
    }

    /// Activate checkpoint (e.g., when player touches it)
    pub fn activateCheckpoint(checkpoints: []RespawnInterface.CheckpointData, checkpoint_index: usize) void {
        if (checkpoint_index < checkpoints.len) {
            checkpoints[checkpoint_index].active = true;
        }
    }

    /// Check if player is near checkpoint (for activation)
    pub fn isPlayerNearCheckpoint(checkpoint: RespawnInterface.CheckpointData, player_pos: Vec2, activation_radius: f32) bool {
        if (!checkpoint.active) return false;
        const dist_sq = checkpoint.position.distanceSquared(player_pos);
        return dist_sq <= activation_radius * activation_radius;
    }
};

/// Generic respawn effect patterns
pub const RespawnEffects = struct {
    /// Standard respawn effect data
    pub const RespawnEffectData = struct {
        position: Vec2,
        radius: f32,
        duration: f32 = 1.0,
        
        pub fn init(position: Vec2, radius: f32) RespawnEffectData {
            return .{ .position = position, .radius = radius };
        }
    };
};