const std = @import("std");
const math = @import("../../lib/math/mod.zig");
const camera = @import("../../lib/game/camera/camera.zig");
const entity_queries = @import("../entity_queries.zig");
const world_state_mod = @import("../world_state.zig");

const Vec2 = math.Vec2;
const Camera = camera.Camera;
const HexGame = world_state_mod.HexGame;

/// Targeting helper functions for combat
pub const TargetingHelpers = struct {
    /// Convert mouse position to world position
    pub fn mouseToWorld(mouse_pos: Vec2, cam: *const Camera) Vec2 {
        return cam.screenToWorldSafe(mouse_pos);
    }

    /// Get current player/controlled entity position
    pub fn getPlayerPos(game: *HexGame) ?Vec2 {
        if (game.getControlledEntity()) |entity_id| {
            return entity_queries.getEntityPos(game, entity_id);
        }
        return null;
    }

    /// Check if player/controlled entity is alive and can act
    pub fn isPlayerAlive(game: *HexGame) bool {
        return game.hasLiveControlledEntity();
    }

    /// Calculate direction from shooter to target
    pub fn getShootDirection(shooter_pos: Vec2, target_pos: Vec2) Vec2 {
        return target_pos.sub(shooter_pos).normalize();
    }

    /// Calculate distance between shooter and target
    pub fn getTargetDistance(shooter_pos: Vec2, target_pos: Vec2) f32 {
        return shooter_pos.distance(target_pos);
    }

    /// Calculate squared distance (for performance-sensitive comparisons)
    pub fn getTargetDistanceSquared(shooter_pos: Vec2, target_pos: Vec2) f32 {
        return shooter_pos.distanceSquared(target_pos);
    }

    /// Check if target position is within range
    pub fn isInRange(shooter_pos: Vec2, target_pos: Vec2, max_range: f32) bool {
        const distance_squared = getTargetDistanceSquared(shooter_pos, target_pos);
        return distance_squared <= max_range * max_range;
    }

    /// Get angle from shooter to target (in radians)
    pub fn getTargetAngle(shooter_pos: Vec2, target_pos: Vec2) f32 {
        const direction = target_pos.sub(shooter_pos);
        return std.math.atan2(direction.y, direction.x);
    }
};
