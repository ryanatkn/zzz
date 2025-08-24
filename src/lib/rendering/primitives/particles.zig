// Particle rendering functionality - visual effects and particle systems
// Handles particle-specific uniform data and rendering operations

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
const ParticleUniforms = uniforms_mod.ParticleUniforms;
const CircleInstance = uniforms_mod.CircleInstance; // Effects reuse circle data

/// Particle renderer - handles individual and batched particle/effect rendering
pub const ParticleRenderer = struct {
    instances: std.ArrayList(CircleInstance), // Effects reuse circle data
    instance_buffer: ?*c.sdl.SDL_GPUBuffer,
    pipeline: *c.sdl.SDL_GPUGraphicsPipeline,
    perf_monitor: *performance.PerformanceMonitor,

    const Self = @This();

    /// Initialize particle renderer with pipeline and performance monitor
    pub fn init(
        allocator: std.mem.Allocator,
        device: *c.sdl.SDL_GPUDevice,
        pipeline: *c.sdl.SDL_GPUGraphicsPipeline,
        perf_monitor: *performance.PerformanceMonitor,
    ) !Self {
        const instances = std.ArrayList(CircleInstance).init(allocator);

        // Create instance buffer for batching (particles use circle instances)
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

    /// Draw a visual particle with animated rings and pulsing
    pub fn drawParticle(
        self: *Self,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        pos: Vec2,
        radius: f32,
        color: Color,
        intensity: f32,
        time: f32,
        screen_width: f32,
        screen_height: f32,
    ) void {
        self.perf_monitor.recordIndividualDraw();

        // Prepare uniform data for particle shader
        const uniform_data = ParticleUniforms{
            .screen_size = [2]f32{ screen_width, screen_height },
            .center = [2]f32{ pos.x, pos.y },
            .radius = radius,
            .color_r = color.r,
            .color_g = color.g,
            .color_b = color.b,
            .color_a = color.a,
            .intensity = intensity,
            .time = time,
            ._padding = [3]f32{ 0.0, 0.0, 0.0 },
        };

        // Push uniform data BEFORE binding pipeline using shared helper
        rendering_core.UniformPush.pushParticleUniforms(cmd_buffer, uniform_data);

        // Bind particle pipeline and draw with alpha blending
        c.sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.pipeline);
        c.sdl.SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0); // 6 vertices for larger quad (effects need more space)
    }

    /// Add an effect to the current batch
    pub fn addEffectToTrace(self: *Self, pos: Vec2, radius: f32, color: Color, intensity: f32) void {
        const instance = CircleInstance{
            .center = [2]f32{ pos.x, pos.y },
            .radius = radius * intensity, // Scale radius by intensity
            .color = [4]f32{
                color.r,
                color.g,
                color.b,
                color.a * intensity, // Apply intensity to alpha
            },
        };
        self.instances.append(instance) catch {
            loggers.getRenderLog().warn("effect_batch_full", "Effect instance buffer full, skipping", .{});
        };
    }

    /// Render all batched effects in individual draw calls
    /// TODO: Optimize to true instanced rendering in the future
    pub fn flushEffects(
        self: *Self,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        time: f32,
        screen_width: f32,
        screen_height: f32,
    ) void {
        if (self.instances.items.len == 0) return;

        // Record batch with individual instance count
        for (0..self.instances.items.len) |_| {
            self.perf_monitor.recordBatchedDraw();
        }

        // Batch render particles: pipeline bound once, multiple draw calls
        // Current approach provides excellent performance (6-7ms frames)
        for (self.instances.items) |instance| {
            const uniform_data = ParticleUniforms{
                .screen_size = [2]f32{ screen_width, screen_height },
                .center = [2]f32{ instance.center[0], instance.center[1] },
                .radius = instance.radius,
                .color_r = instance.color[0],
                .color_g = instance.color[1],
                .color_b = instance.color[2],
                .color_a = instance.color[3],
                .intensity = 1.0, // Default intensity
                .time = time,
                ._padding = [3]f32{ 0.0, 0.0, 0.0 },
            };

            // Push uniform data BEFORE binding pipeline using shared helper
            rendering_core.UniformPush.pushParticleUniforms(cmd_buffer, uniform_data);

            // Bind pipeline and draw
            c.sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.pipeline);
            c.sdl.SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0); // 6 vertices for quad
        }

        // Clear for next frame
        self.instances.clearRetainingCapacity();
    }
};
