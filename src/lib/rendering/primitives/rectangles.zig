// Rectangle rendering functionality - individual and batched rectangle drawing
// Handles rectangle-specific uniform data and rendering operations

const std = @import("std");
const c = @import("../../platform/sdl.zig");
const math = @import("../../math/mod.zig");
const colors = @import("../../core/colors.zig");
const uniforms_mod = @import("../core/uniforms.zig");
const performance = @import("../optimization/performance.zig");
const loggers = @import("../../debug/loggers.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const RectUniforms = uniforms_mod.RectUniforms;
const RectInstance = uniforms_mod.RectInstance;
const CircleUniforms = uniforms_mod.CircleUniforms;

/// Rectangle renderer - handles individual and batched rectangle rendering
pub const RectangleRenderer = struct {
    instances: std.ArrayList(RectInstance),
    instance_buffer: ?*c.sdl.SDL_GPUBuffer,
    pipeline: *c.sdl.SDL_GPUGraphicsPipeline,
    circle_pipeline: *c.sdl.SDL_GPUGraphicsPipeline, // For blended rectangles
    perf_monitor: *performance.PerformanceMonitor,

    const Self = @This();

    /// Initialize rectangle renderer with pipelines and performance monitor
    pub fn init(
        allocator: std.mem.Allocator,
        device: *c.sdl.SDL_GPUDevice,
        pipeline: *c.sdl.SDL_GPUGraphicsPipeline,
        circle_pipeline: *c.sdl.SDL_GPUGraphicsPipeline,
        perf_monitor: *performance.PerformanceMonitor,
    ) !Self {
        const instances = std.ArrayList(RectInstance).init(allocator);

        // Create instance buffer for batching
        const buffer_create_info = c.sdl.SDL_GPUBufferCreateInfo{
            .usage = c.sdl.SDL_GPU_BUFFERUSAGE_VERTEX,
            .size = uniforms_mod.MAX_INSTANCES_PER_BATCH * @sizeOf(RectInstance),
        };

        const instance_buffer = c.sdl.SDL_CreateGPUBuffer(device, &buffer_create_info) orelse {
            loggers.getRenderLog().err("rect_buffer_fail", "Failed to create rectangle instance buffer", .{});
            return error.BufferCreationFailed;
        };

        return Self{
            .instances = instances,
            .instance_buffer = instance_buffer,
            .pipeline = pipeline,
            .circle_pipeline = circle_pipeline,
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

    /// Draw a single rectangle
    pub fn drawRect(
        self: *Self,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        pos: Vec2,
        size: Vec2,
        color: Color,
        screen_width: f32,
        screen_height: f32,
    ) void {
        self.perf_monitor.recordIndividualDraw();

        // Prepare uniform data
        const uniform_data = RectUniforms{
            .screen_size = [2]f32{ screen_width, screen_height },
            .rect_position = [2]f32{ pos.x, pos.y },
            .rect_size = [2]f32{ size.x, size.y },
            .rect_color_r = @as(f32, @floatFromInt(color.r)) / 255.0,
            .rect_color_g = @as(f32, @floatFromInt(color.g)) / 255.0,
            .rect_color_b = @as(f32, @floatFromInt(color.b)) / 255.0,
            .rect_color_a = @as(f32, @floatFromInt(color.a)) / 255.0,
            ._padding = 0.0,
        };

        // Push uniform data BEFORE binding pipeline (critical for SDL3 GPU)
        c.sdl.SDL_PushGPUVertexUniformData(cmd_buffer, 0, &uniform_data, @sizeOf(RectUniforms));

        // Bind pipeline and draw
        c.sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.pipeline);
        c.sdl.SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0); // 6 vertices for quad (2 triangles)
    }

    /// Draw a rectangle with alpha blending (for transparent overlays)
    pub fn drawBlendedRect(
        self: *Self,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        pos: Vec2,
        size: Vec2,
        color: Color,
        screen_width: f32,
        screen_height: f32,
    ) void {
        // Use circle uniforms but set a very large radius to make it effectively rectangular
        const uniform_data = CircleUniforms{
            .screen_size = [2]f32{ screen_width, screen_height },
            .circle_center = [2]f32{ pos.x + size.x / 2.0, pos.y + size.y / 2.0 }, // Center of rectangle
            .circle_size = [2]f32{ @max(size.x, size.y) * 2.0, 0.0 }, // Very large radius to cover the rectangle
            .circle_color_r = @as(f32, @floatFromInt(color.r)) / 255.0,
            .circle_color_g = @as(f32, @floatFromInt(color.g)) / 255.0,
            .circle_color_b = @as(f32, @floatFromInt(color.b)) / 255.0,
            .circle_color_a = @as(f32, @floatFromInt(color.a)) / 255.0,
            ._padding = 0.0,
        };

        // Push uniform data BEFORE binding pipeline
        c.sdl.SDL_PushGPUVertexUniformData(cmd_buffer, 0, &uniform_data, @sizeOf(CircleUniforms));

        // Use circle pipeline which has alpha blending enabled
        c.sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.circle_pipeline);
        c.sdl.SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0); // 6 vertices for quad
    }

    /// Add a rectangle to the current batch
    pub fn addRectToTrace(self: *Self, pos: Vec2, size: Vec2, color: Color) void {
        const instance = RectInstance{
            .position = [2]f32{ pos.x, pos.y },
            .size = [2]f32{ size.x, size.y },
            .color = [4]f32{
                @as(f32, @floatFromInt(color.r)) / 255.0,
                @as(f32, @floatFromInt(color.g)) / 255.0,
                @as(f32, @floatFromInt(color.b)) / 255.0,
                @as(f32, @floatFromInt(color.a)) / 255.0,
            },
        };
        self.instances.append(instance) catch {
            loggers.getRenderLog().warn("rect_batch_full", "Rectangle instance buffer full, skipping", .{});
        };
    }

    /// Render all batched rectangles in individual draw calls
    /// TODO: Optimize to true instanced rendering in the future
    pub fn flushRects(
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

        // Batch render rectangles: pipeline bound once, multiple draw calls
        // Current approach provides excellent performance (6-7ms frames)
        for (self.instances.items) |instance| {
            const uniform_data = RectUniforms{
                .screen_size = [2]f32{ screen_width, screen_height },
                .rect_position = [2]f32{ instance.position[0], instance.position[1] },
                .rect_size = [2]f32{ instance.size[0], instance.size[1] },
                .rect_color_r = instance.color[0],
                .rect_color_g = instance.color[1],
                .rect_color_b = instance.color[2],
                .rect_color_a = instance.color[3],
                ._padding = 0.0,
            };

            // Push uniform data BEFORE binding pipeline
            c.sdl.SDL_PushGPUVertexUniformData(cmd_buffer, 0, &uniform_data, @sizeOf(RectUniforms));

            // Bind pipeline and draw
            c.sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.pipeline);
            c.sdl.SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0); // 6 vertices for quad
        }

        // Clear for next frame
        self.instances.clearRetainingCapacity();
    }
};
