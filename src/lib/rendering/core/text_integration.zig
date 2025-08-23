// Text rendering integration for GPU renderer
// Bridges between GPU renderer and text rendering system

const std = @import("std");
const c = @import("../../platform/sdl.zig");
const math = @import("../../math/mod.zig");
const colors = @import("../../core/colors.zig");
const TextRenderer = @import("../../text/renderer.zig").TextRenderer;

const Vec2 = math.Vec2;
const Color = colors.Color;

/// Text integration handler - manages text renderer integration
pub const TextIntegration = struct {
    text_renderer: TextRenderer,

    const Self = @This();

    /// Initialize text integration with GPU device
    pub fn init(device: *c.sdl.SDL_GPUDevice, allocator: std.mem.Allocator, screen_width: f32, screen_height: f32) !Self {
        const text_renderer = try TextRenderer.init(device, allocator, screen_width, screen_height);

        return Self{
            .text_renderer = text_renderer,
        };
    }

    /// Clean up text renderer resources
    pub fn deinit(self: *Self) void {
        self.text_renderer.deinit();
    }

    /// Update screen size for text renderer
    pub fn updateScreenSize(self: *Self, screen_width: f32, screen_height: f32) void {
        self.text_renderer.updateScreenSize(screen_width, screen_height);
    }

    /// Queue a texture-based text for drawing
    pub fn queueTextTexture(
        self: *Self,
        texture: *c.sdl.SDL_GPUTexture,
        position: Vec2,
        width: u32,
        height: u32,
        color: Color,
    ) void {
        self.text_renderer.queueTextTexture(texture, position, width, height, color);
    }

    /// Draw all queued text (call during render pass)
    pub fn drawQueuedText(
        self: *Self,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
    ) void {
        // Delegate to text renderer for proper textured rendering
        self.text_renderer.drawQueuedText(cmd_buffer, render_pass);
    }

    /// Debug function to test texture pipeline
    pub fn debugTestTexturePipeline(
        self: *Self,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
    ) !void {
        try self.text_renderer.debugTestTexturePipeline(cmd_buffer, render_pass);
    }

    /// Draw pixel fallback for HUD text (draws as tiny rectangle)
    /// This function bridges to primitive rendering if needed
    pub fn drawPixel(
        self: *Self,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        x: f32,
        y: f32,
        color: Color,
        draw_rect_fn: *const fn (
            cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
            render_pass: *c.sdl.SDL_GPURenderPass,
            pos: Vec2,
            size: Vec2,
            color: Color,
        ) void,
    ) void {
        _ = self; // Not used in current implementation
        draw_rect_fn(cmd_buffer, render_pass, Vec2{ .x = x, .y = y }, Vec2{ .x = 1.0, .y = 1.0 }, color);
    }
};
