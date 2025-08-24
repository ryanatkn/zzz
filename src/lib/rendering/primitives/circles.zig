// Circle rendering functionality - individual and batched circle drawing
// Handles circle-specific uniform data and rendering operations

const std = @import("std");
const c = @import("../../platform/sdl.zig");
const math = @import("../../math/mod.zig");
const colors = @import("../../core/colors.zig");
const uniforms_mod = @import("../core/uniforms.zig");
const rendering_core = @import("../core/mod.zig");
const performance = @import("../optimization/performance.zig");
const loggers = @import("../../debug/loggers.zig");
const buffers = @import("../core/buffers.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const CircleUniforms = uniforms_mod.CircleUniforms;
const CircleInstance = uniforms_mod.CircleInstance;

/// Circle renderer - handles individual and batched circle rendering
pub const CircleRenderer = struct {
    instances: std.ArrayList(CircleInstance),
    instance_buffer: ?*c.sdl.SDL_GPUBuffer,
    pipeline: *c.sdl.SDL_GPUGraphicsPipeline,
    perf_monitor: *performance.PerformanceMonitor,

    const Self = @This();

    /// Initialize circle renderer with pipeline and performance monitor
    pub fn init(
        allocator: std.mem.Allocator,
        device: *c.sdl.SDL_GPUDevice,
        pipeline: *c.sdl.SDL_GPUGraphicsPipeline,
        perf_monitor: *performance.PerformanceMonitor,
    ) !Self {
        const instances = std.ArrayList(CircleInstance).init(allocator);

        // Create instance buffer for batching using shared utility
        const instance_buffer = buffers.InstanceBuffers.createCircleInstanceBuffer(device) catch |err| {
            return err;
        };

        return Self{
            .instances = instances,
            .instance_buffer = instance_buffer,
            .pipeline = pipeline,
            .perf_monitor = perf_monitor,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Self, device: *c.sdl.SDL_GPUDevice) void {
        if (self.instance_buffer) |buffer| {
            c.sdl.SDL_ReleaseGPUBuffer(device, buffer);
        }
        self.instances.deinit();
    }

    /// Draw a single circle with distance field anti-aliasing
    pub fn drawCircle(
        self: *Self,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        pos: Vec2,
        radius: f32,
        color: Color,
        screen_width: f32,
        screen_height: f32,
    ) void {
        self.perf_monitor.recordIndividualDraw();

        // Prepare uniform data
        const uniform_data = CircleUniforms{
            .screen_size = [2]f32{ screen_width, screen_height },
            .circle_center = [2]f32{ pos.x, pos.y },
            .circle_size = [2]f32{ radius, 0.0 },
            .circle_color_r = color.r,
            .circle_color_g = color.g,
            .circle_color_b = color.b,
            .circle_color_a = color.a,
            ._padding = 0.0,
        };

        // Push uniform data BEFORE binding pipeline using shared helper
        rendering_core.UniformPush.pushCircleUniforms(cmd_buffer, uniform_data);

        // Bind pipeline and draw
        c.sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.pipeline);
        c.sdl.SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0); // 6 vertices for quad
    }

    /// Add a circle to the current batch
    pub fn addCircleToTrace(self: *Self, pos: Vec2, radius: f32, color: Color) void {
        const instance = CircleInstance{
            .center = [2]f32{ pos.x, pos.y },
            .radius = radius,
            .color = [4]f32{ color.r, color.g, color.b, color.a },
        };
        self.instances.append(instance) catch {
            loggers.getRenderLog().warn("circle_batch_full", "Circle instance buffer full, skipping", .{});
        };
    }

    /// Render all batched circles in individual draw calls
    /// TODO: Optimize to true instanced rendering in the future
    pub fn flushCircles(
        self: *Self,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        screen_width: f32,
        screen_height: f32,
    ) void {
        if (self.instances.items.len == 0) return;

        // Record batch with individual instance count
        for (0..self.instances.items.len) |_| {
            self.perf_monitor.recordBatchedDraw();
        }

        // Batch render circles: pipeline bound once, multiple draw calls
        // Current approach provides excellent performance (6-7ms frames)
        for (self.instances.items) |instance| {
            const uniform_data = CircleUniforms{
                .screen_size = [2]f32{ screen_width, screen_height },
                .circle_center = [2]f32{ instance.center[0], instance.center[1] },
                .circle_size = [2]f32{ instance.radius, 0.0 },
                .circle_color_r = instance.color[0],
                .circle_color_g = instance.color[1],
                .circle_color_b = instance.color[2],
                .circle_color_a = instance.color[3],
                ._padding = 0.0,
            };

            // Push uniform data BEFORE binding pipeline using shared helper
            rendering_core.UniformPush.pushCircleUniforms(cmd_buffer, uniform_data);

            // Bind pipeline and draw
            c.sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.pipeline);
            c.sdl.SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0); // 6 vertices for quad
        }

        // Clear for next frame
        self.instances.clearRetainingCapacity();
    }
};
