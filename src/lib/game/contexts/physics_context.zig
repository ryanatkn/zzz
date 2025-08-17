/// Physics context for physics update operations
const std = @import("std");
const UpdateContext = @import("update_context.zig").UpdateContext;
const math = @import("../../math/mod.zig");

const Vec2 = math.Vec2;

/// Physics context for physics update operations
pub const PhysicsContext = struct {
    base: UpdateContext,

    // Physics world settings
    gravity: Vec2,
    time_scale: f32,

    // Collision settings
    collision_iterations: u32,
    position_iterations: u32,

    // Spatial partitioning info
    world_bounds: struct {
        min_x: f32,
        min_y: f32,
        max_x: f32,
        max_y: f32,
    },

    pub fn init(base_context: UpdateContext) PhysicsContext {
        return .{
            .base = base_context,
            .gravity = Vec2.ZERO,
            .time_scale = 1.0,
            .collision_iterations = 8,
            .position_iterations = 3,
            .world_bounds = .{
                .min_x = -1000,
                .min_y = -1000,
                .max_x = 1000,
                .max_y = 1000,
            },
        };
    }

    pub fn withGravity(self: PhysicsContext, gravity: Vec2) PhysicsContext {
        var result = self;
        result.gravity = gravity;
        return result;
    }

    pub fn withTimeScale(self: PhysicsContext, scale: f32) PhysicsContext {
        var result = self;
        result.time_scale = scale;
        return result;
    }

    pub fn withWorldBounds(self: PhysicsContext, min_x: f32, min_y: f32, max_x: f32, max_y: f32) PhysicsContext {
        var result = self;
        result.world_bounds = .{
            .min_x = min_x,
            .min_y = min_y,
            .max_x = max_x,
            .max_y = max_y,
        };
        return result;
    }

    pub fn withCollisionSettings(self: PhysicsContext, collision_iter: u32, position_iter: u32) PhysicsContext {
        var result = self;
        result.collision_iterations = collision_iter;
        result.position_iterations = position_iter;
        return result;
    }

    /// Get effective delta time for physics (scaled and paused)
    pub fn physicsDeltaTime(self: PhysicsContext) f32 {
        return self.base.effectiveDeltaTime() * self.time_scale;
    }

    /// Check if a point is within world bounds
    pub fn isPointInBounds(self: PhysicsContext, point: Vec2) bool {
        return point.x >= self.world_bounds.min_x and point.x <= self.world_bounds.max_x and
            point.y >= self.world_bounds.min_y and point.y <= self.world_bounds.max_y;
    }

    /// Clamp a point to world bounds
    pub fn clampToBounds(self: PhysicsContext, point: Vec2) Vec2 {
        return Vec2.init(
            std.math.clamp(point.x, self.world_bounds.min_x, self.world_bounds.max_x),
            std.math.clamp(point.y, self.world_bounds.min_y, self.world_bounds.max_y),
        );
    }

    /// Get world bounds as a rectangle
    pub fn getWorldRect(self: PhysicsContext) struct { x: f32, y: f32, width: f32, height: f32 } {
        return .{
            .x = self.world_bounds.min_x,
            .y = self.world_bounds.min_y,
            .width = self.world_bounds.max_x - self.world_bounds.min_x,
            .height = self.world_bounds.max_y - self.world_bounds.min_y,
        };
    }
};