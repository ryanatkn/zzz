// Text rendering functionality - individual and batched text glyph drawing
// Handles text-specific uniform data and rendering operations using buffer approach

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
const TextUniforms = uniforms_mod.TextUniforms;
const TextInstance = uniforms_mod.TextInstance;

/// Text renderer - handles individual and batched text glyph rendering using buffers
pub const TextRenderer = struct {
    instances: std.ArrayList(TextInstance),
    instance_buffer: ?*c.sdl.SDL_GPUBuffer,
    pipeline: *c.sdl.SDL_GPUGraphicsPipeline,
    perf_monitor: *performance.PerformanceMonitor,

    const Self = @This();

    /// Initialize text renderer with pipeline and performance monitor
    pub fn init(
        allocator: std.mem.Allocator,
        device: *c.sdl.SDL_GPUDevice,
        pipeline: *c.sdl.SDL_GPUGraphicsPipeline,
        perf_monitor: *performance.PerformanceMonitor,
    ) !Self {
        const instances = std.ArrayList(TextInstance).init(allocator);

        // Create instance buffer for batching using shared utility
        const instance_buffer = buffers.InstanceBuffers.createTextInstanceBuffer(device) catch |err| {
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

    /// Draw a single text glyph using buffer-based approach
    pub fn drawGlyph(
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

        // Prepare uniform data (following circles pattern exactly)
        const uniform_data = TextUniforms{
            .uv_min = [2]f32{ 0.0, 0.0 }, // Full texture for simple text rendering
            .uv_max = [2]f32{ 1.0, 1.0 }, // Full texture for simple text rendering
            .screen_size = [2]f32{ screen_width, screen_height },
            .glyph_position = [2]f32{ pos.x, pos.y },
            .glyph_size = [2]f32{ size.x, size.y },
            .text_color_r = @as(f32, @floatFromInt(color.r)) / 255.0,
            .text_color_g = @as(f32, @floatFromInt(color.g)) / 255.0,
            .text_color_b = @as(f32, @floatFromInt(color.b)) / 255.0,
            .text_color_a = @as(f32, @floatFromInt(color.a)) / 255.0,
            ._padding = [2]f32{ 0.0, 0.0 },
        };

        // Push uniform data BEFORE binding pipeline (critical SDL3 requirement)
        rendering_core.UniformPush.pushTextUniforms(cmd_buffer, uniform_data);

        // Bind pipeline and draw
        c.sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.pipeline);
        c.sdl.SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0); // 6 vertices for quad
    }

    /// Add a text glyph to the current batch
    pub fn addGlyphToTrace(self: *Self, pos: Vec2, size: Vec2, color: Color) void {
        const instance = TextInstance{
            .screen_pos = [2]f32{ pos.x, pos.y },
            .size = [2]f32{ size.x, size.y },
            .color = [4]f32{
                @as(f32, @floatFromInt(color.r)) / 255.0,
                @as(f32, @floatFromInt(color.g)) / 255.0,
                @as(f32, @floatFromInt(color.b)) / 255.0,
                @as(f32, @floatFromInt(color.a)) / 255.0,
            },
            .coverage_params = [4]f32{ 1.0, 1.0, 0.0, 0.0 }, // Default coverage parameters
        };
        self.instances.append(instance) catch {
            loggers.getRenderLog().warn("text_batch_full", "Text instance buffer full, skipping", .{});
        };
    }

    /// Render all batched text glyphs in individual draw calls
    /// Following the proven circles pattern that provides excellent performance
    pub fn flushGlyphs(
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

        // Batch render glyphs: pipeline bound once, multiple draw calls (like circles)
        for (self.instances.items) |instance| {
            const uniform_data = TextUniforms{
                .uv_min = [2]f32{ 0.0, 0.0 }, // Full texture for simple text rendering
                .uv_max = [2]f32{ 1.0, 1.0 }, // Full texture for simple text rendering
                .screen_size = [2]f32{ screen_width, screen_height },
                .glyph_position = [2]f32{ instance.screen_pos[0], instance.screen_pos[1] },
                .glyph_size = [2]f32{ instance.size[0], instance.size[1] },
                .text_color_r = instance.color[0],
                .text_color_g = instance.color[1],
                .text_color_b = instance.color[2],
                .text_color_a = instance.color[3],
                ._padding = [2]f32{ 0.0, 0.0 },
            };

            // Push uniform data BEFORE binding pipeline
            rendering_core.UniformPush.pushTextUniforms(cmd_buffer, uniform_data);

            // Bind pipeline and draw
            c.sdl.SDL_BindGPUGraphicsPipeline(render_pass, self.pipeline);
            c.sdl.SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0); // 6 vertices for quad
        }

        // Clear for next frame
        self.instances.clearRetainingCapacity();
    }
};

// Tests
test "text renderer initialization" {
    // Note: This test requires SDL3 device, so it's mainly a compile-time check
    const testing = std.testing;
    _ = testing; // Suppress unused import warning for now

    // TODO: Add proper device mock for testing
    // For now, we just verify the struct compiles correctly
}

test "text instance creation" {
    const testing = std.testing;

    // Test that we can create text instances with the right data
    const instance = TextInstance{
        .screen_pos = [2]f32{ 100.0, 200.0 },
        .size = [2]f32{ 16.0, 24.0 },
        .color = [4]f32{ 1.0, 0.5, 0.0, 1.0 },
        .coverage_params = [4]f32{ 1.0, 1.0, 0.0, 0.0 },
    };

    try testing.expect(instance.screen_pos[0] == 100.0);
    try testing.expect(instance.size[1] == 24.0);
    try testing.expect(instance.color[1] == 0.5);
}
