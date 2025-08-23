// GPU Renderer Coordinator - Modular rendering system for SDL3 GPU API
//
// This file coordinates specialized rendering modules rather than handling everything directly.
// The monolithic approach has been refactored into focused, single-responsibility components:
//
// - Core modules: device, shaders, pipelines, frame management, text integration
// - Primitive renderers: circles, rectangles, particles
// - Each component can be tested and maintained independently
//
// The GPURenderer maintains the same public API for backward compatibility while
// internally delegating to the appropriate specialized modules.

const std = @import("std");
const math = @import("../../math/mod.zig");
const colors = @import("../../core/colors.zig");
const constants = @import("../../core/constants.zig");
const performance = @import("../optimization/performance.zig");

// Core component modules
const device = @import("device.zig");
const shaders_mod = @import("shaders.zig");
const pipelines_mod = @import("pipelines.zig");
const frame_mod = @import("frame.zig");
const text_integration = @import("text_integration.zig");

// Primitive renderer modules
const circles = @import("../primitives/circles.zig");
const rectangles = @import("../primitives/rectangles.zig");
const particles = @import("../primitives/particles.zig");

// Platform and text renderer
const c = @import("../../platform/sdl.zig");
const TextRenderer = @import("../../text/renderer.zig").TextRenderer;

const Vec2 = math.Vec2;
const Color = colors.Color;

/// GPU Renderer - Coordinates modular rendering pipeline
///
/// Manages the complete GPU rendering pipeline through specialized components:
/// - Device management and initialization
/// - Shader loading and pipeline creation
/// - Primitive rendering (circles, rectangles, particles)
/// - Text rendering integration
/// - Performance monitoring and batching
///
/// Maintains full API compatibility with the original monolithic implementation
/// while providing better maintainability and extensibility.
pub const GPURenderer = struct {
    allocator: std.mem.Allocator,
    device: *c.sdl.SDL_GPUDevice,
    window: *c.sdl.SDL_Window,

    // Component systems
    shaders: shaders_mod.ShaderSet,
    pipelines: pipelines_mod.PipelineSet,
    text_integration: text_integration.TextIntegration, // Public for direct access to text rendering

    // Primitive renderers
    circle_renderer: circles.CircleRenderer,
    rect_renderer: rectangles.RectangleRenderer,
    particle_renderer: particles.ParticleRenderer,

    // Current frame data
    screen_width: f32,
    screen_height: f32,

    // Performance monitoring
    perf_monitor: performance.PerformanceMonitor,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, window: *c.sdl.SDL_Window) !Self {
        // Create GPU device
        const gpu_device = try device.createDevice(window);

        // Initialize shaders
        var shader_set = try shaders_mod.ShaderSet.init(gpu_device);
        errdefer shader_set.deinit(gpu_device);

        // Initialize pipelines
        var pipeline_set = try pipelines_mod.PipelineSet.init(gpu_device, window, &shader_set);
        errdefer pipeline_set.deinit(gpu_device);

        // Initialize text integration
        const initial_width = constants.SCREEN.BASE_WIDTH;
        const initial_height = constants.SCREEN.BASE_HEIGHT;
        var text_int = try text_integration.TextIntegration.init(gpu_device, allocator, initial_width, initial_height);
        errdefer text_int.deinit();

        // Initialize performance monitor
        var perf_monitor = performance.PerformanceMonitor.init(performance.Config.DEFAULT_LOGGING_FREQUENCY);

        // Initialize primitive renderers
        var circle_renderer = try circles.CircleRenderer.init(
            allocator,
            gpu_device,
            pipeline_set.circle_pipeline,
            &perf_monitor,
        );
        errdefer circle_renderer.deinit(gpu_device);

        var rect_renderer = try rectangles.RectangleRenderer.init(
            allocator,
            gpu_device,
            pipeline_set.rect_pipeline,
            pipeline_set.circle_pipeline, // For blended rectangles
            &perf_monitor,
        );
        errdefer rect_renderer.deinit(gpu_device);

        var particle_renderer = try particles.ParticleRenderer.init(
            allocator,
            gpu_device,
            pipeline_set.particle_pipeline,
            &perf_monitor,
        );
        errdefer particle_renderer.deinit(gpu_device);

        // Show window now that GPU is set up
        _ = c.sdl.SDL_ShowWindow(window);

        return Self{
            .allocator = allocator,
            .device = gpu_device,
            .window = window,
            .shaders = shader_set,
            .pipelines = pipeline_set,
            .text_integration = text_int,
            .circle_renderer = circle_renderer,
            .rect_renderer = rect_renderer,
            .particle_renderer = particle_renderer,
            .screen_width = initial_width,
            .screen_height = initial_height,
            .perf_monitor = perf_monitor,
        };
    }

    pub fn deinit(self: *Self) void {
        // Clean up primitive renderers
        self.circle_renderer.deinit(self.device);
        self.rect_renderer.deinit(self.device);
        self.particle_renderer.deinit(self.device);

        // Clean up component systems
        self.text_integration.deinit();
        self.pipelines.deinit(self.device);
        self.shaders.deinit(self.device);

        // Always destroy the device since we always own it now
        device.destroyDevice(self.device);
    }

    // Begin frame and get command buffer ready for rendering
    pub fn beginFrame(self: *Self, window: *c.sdl.SDL_Window) !*c.sdl.SDL_GPUCommandBuffer {
        // Update screen size
        const screen_size = frame_mod.updateScreenSize(window);
        self.screen_width = screen_size.width;
        self.screen_height = screen_size.height;

        // Update text renderer screen size
        self.text_integration.updateScreenSize(self.screen_width, self.screen_height);

        // Acquire command buffer
        return frame_mod.beginFrame(self.device, window);
    }

    // Start a render pass with the given background color
    pub fn beginRenderPass(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, window: *c.sdl.SDL_Window, bg_color: Color) !*c.sdl.SDL_GPURenderPass {
        _ = self; // TODO: Could be made static, but kept for API consistency
        return frame_mod.beginRenderPass(cmd_buffer, window, bg_color);
    }

    // === PERFORMANCE MONITORING API ===

    pub fn startFrameTiming(self: *Self) void {
        self.perf_monitor.startFrame();
    }

    pub fn endFrameTiming(self: *Self) void {
        self.perf_monitor.endFrame();
    }

    pub fn getPerformanceStats(self: *const Self) performance.FrameMetrics {
        return self.perf_monitor.getMetrics();
    }

    // === INDIVIDUAL PRIMITIVE DRAWING API ===

    // Draw a single circle with distance field anti-aliasing
    pub fn drawCircle(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, radius: f32, color: Color) void {
        self.circle_renderer.drawCircle(cmd_buffer, render_pass, pos, radius, color, self.screen_width, self.screen_height);
    }

    // Draw a single rectangle
    pub fn drawRect(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, size: Vec2, color: Color) void {
        self.rect_renderer.drawRect(cmd_buffer, render_pass, pos, size, color, self.screen_width, self.screen_height);
    }

    // Draw a rectangle with alpha blending (for transparent overlays)
    pub fn drawBlendedRect(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, size: Vec2, color: Color) void {
        self.rect_renderer.drawBlendedRect(cmd_buffer, render_pass, pos, size, color, self.screen_width, self.screen_height);
    }

    // Draw a visual particle with animated rings and pulsing
    pub fn drawParticle(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, radius: f32, color: Color, intensity: f32, time: f32) void {
        self.particle_renderer.drawParticle(cmd_buffer, render_pass, pos, radius, color, intensity, time, self.screen_width, self.screen_height);
    }

    // === BATCHED RENDERING API ===

    // Add a circle to the current batch
    pub fn addCircleToTrace(self: *Self, pos: Vec2, radius: f32, color: Color) void {
        self.circle_renderer.addCircleToTrace(pos, radius, color);
    }

    // Add a rectangle to the current batch
    pub fn addRectToTrace(self: *Self, pos: Vec2, size: Vec2, color: Color) void {
        self.rect_renderer.addRectToTrace(pos, size, color);
    }

    // Add an effect to the current batch
    pub fn addEffectToTrace(self: *Self, pos: Vec2, radius: f32, color: Color, intensity: f32) void {
        self.particle_renderer.addEffectToTrace(pos, radius, color, intensity);
    }

    // Render all batched circles
    pub fn flushCircles(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass) void {
        self.circle_renderer.flushCircles(cmd_buffer, render_pass, self.screen_width, self.screen_height);
    }

    // Render all batched rectangles
    pub fn flushRects(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass) void {
        self.rect_renderer.flushRects(cmd_buffer, render_pass, self.screen_width, self.screen_height);
    }

    // Render all batched effects
    pub fn flushEffects(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, time: f32) void {
        self.particle_renderer.flushEffects(cmd_buffer, render_pass, time, self.screen_width, self.screen_height);
    }

    // === FRAME MANAGEMENT API ===

    // End render pass
    pub fn endRenderPass(self: *Self, render_pass: *c.sdl.SDL_GPURenderPass) void {
        _ = self; // TODO: Could be made static, but kept for API consistency
        frame_mod.endRenderPass(render_pass);
    }

    // End frame and submit
    pub fn endFrame(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer) void {
        _ = self; // TODO: Could be made static, but kept for API consistency
        frame_mod.endFrame(cmd_buffer);
    }

    // === TEXT RENDERING API ===

    // Queue a texture-based text for drawing
    pub fn queueTextTexture(self: *Self, texture: *c.sdl.SDL_GPUTexture, position: Vec2, width: u32, height: u32, color: Color) void {
        self.text_integration.queueTextTexture(texture, position, width, height, color);
    }

    // Draw all queued text (call during render pass)
    pub fn drawQueuedText(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass) void {
        self.text_integration.drawQueuedText(cmd_buffer, render_pass);
    }

    // Debug function to test texture pipeline
    pub fn debugTestTexturePipeline(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass) !void {
        try self.text_integration.debugTestTexturePipeline(cmd_buffer, render_pass);
    }

    // === COMPATIBILITY/UTILITY API ===

    // TODO: Set render color (compatibility function - not needed for GPU but game expects it)
    // Remove this once all game code is updated to pass colors to primitives directly
    pub fn setRenderColor(self: *Self, color: Color) void {
        _ = self;
        _ = color;
        // No-op for GPU rendering - color is passed per primitive
    }

    // Draw pixel (fallback for HUD text - draw as tiny rectangle)
    pub fn drawPixel(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, x: f32, y: f32, color: Color) void {
        self.drawRect(cmd_buffer, render_pass, Vec2{ .x = x, .y = y }, Vec2{ .x = 1.0, .y = 1.0 }, color);
    }
};
