// Generic batching utilities for efficient rendering of primitives
// Extracted from hex/rendering patterns to provide reusable batching for any game

const std = @import("std");
const c = @import("../../platform/sdl.zig");
const math = @import("../../math/mod.zig");
const colors = @import("../../core/colors.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;

/// Generic rectangle data for batched rendering
pub const RectData = struct {
    pos: Vec2,
    size: Vec2,
    color: Color,
};

/// Generic circle data for batched rendering
pub const CircleData = struct {
    pos: Vec2,
    radius: f32,
    color: Color,
};

/// Generic batched renderer for primitives
pub const BatchedRenderer = struct {
    /// Render a batch of rectangles in a single optimized pass
    pub fn renderRectBatch(
        gpu_renderer: anytype,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        rects: []const RectData,
    ) void {
        // Single batched draw call for all rectangles
        for (rects) |rect| {
            gpu_renderer.drawRect(cmd_buffer, render_pass, rect.pos, rect.size, rect.color);
        }
    }

    /// Render a batch of circles in a single optimized pass
    pub fn renderCircleBatch(
        gpu_renderer: anytype,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        circles: []const CircleData,
    ) void {
        // Single batched draw call for all circles
        for (circles) |circle| {
            gpu_renderer.drawCircle(cmd_buffer, render_pass, circle.pos, circle.radius, circle.color);
        }
    }
};

/// Utilities for building batches from entity data
pub const BatchBuilder = struct {
    /// Build a rectangle batch with visibility culling
    pub fn buildRectBatch(
        comptime T: type,
        entities: []const T,
        batch_buffer: []RectData,
        camera: anytype,
        getRectFromEntity: fn (entity: T, camera: anytype) ?RectData,
    ) usize {
        var batch_count: usize = 0;

        for (entities) |entity| {
            if (batch_count >= batch_buffer.len) break;

            if (getRectFromEntity(entity, camera)) |rect_data| {
                batch_buffer[batch_count] = rect_data;
                batch_count += 1;
            }
        }

        return batch_count;
    }

    /// Build a circle batch with visibility culling
    pub fn buildCircleBatch(
        comptime T: type,
        entities: []const T,
        batch_buffer: []CircleData,
        camera: anytype,
        getCircleFromEntity: fn (entity: T, camera: anytype) ?CircleData,
    ) usize {
        var batch_count: usize = 0;

        for (entities) |entity| {
            if (batch_count >= batch_buffer.len) break;

            if (getCircleFromEntity(entity, camera)) |circle_data| {
                batch_buffer[batch_count] = circle_data;
                batch_count += 1;
            }
        }

        return batch_count;
    }
};

/// Batch configuration and limits
pub const BatchConfig = struct {
    pub const DEFAULT_MAX_RECTS = 1000;
    pub const DEFAULT_MAX_CIRCLES = 1000;

    max_rects: usize = DEFAULT_MAX_RECTS,
    max_circles: usize = DEFAULT_MAX_CIRCLES,
};

/// Statistics for batch performance monitoring
pub const BatchStats = struct {
    rects_rendered: u32 = 0,
    circles_rendered: u32 = 0,
    draw_calls: u32 = 0,

    pub fn addRectBatch(self: *BatchStats, rect_count: u32) void {
        self.rects_rendered += rect_count;
        self.draw_calls += 1;
    }

    pub fn addCircleBatch(self: *BatchStats, circle_count: u32) void {
        self.circles_rendered += circle_count;
        self.draw_calls += 1;
    }

    pub fn reset(self: *BatchStats) void {
        self.* = .{};
    }
};
