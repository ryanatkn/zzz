// Dealt Engine - Renderer Interface
// Common interface for drawing operations that can be implemented by different renderers

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");

const Vec2 = types.Vec2;
const Color = types.Color;

/// Basic drawing interface that all renderers should implement
pub const RendererInterface = struct {
    const Self = @This();

    // Function pointers for the interface
    drawRectFn: *const fn (*anyopaque, *c.sdl.SDL_GPUCommandBuffer, *c.sdl.SDL_GPURenderPass, Vec2, Vec2, Color) void,
    drawCircleFn: *const fn (*anyopaque, *c.sdl.SDL_GPUCommandBuffer, *c.sdl.SDL_GPURenderPass, Vec2, f32, Color) void,
    drawEffectFn: *const fn (*anyopaque, *c.sdl.SDL_GPUCommandBuffer, *c.sdl.SDL_GPURenderPass, Vec2, f32, Color, f32, f32) void,

    // Opaque pointer to the actual renderer implementation
    impl: *anyopaque,

    /// Draw a rectangle
    pub fn drawRect(self: Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, size: Vec2, color: Color) void {
        self.drawRectFn(self.impl, cmd_buffer, render_pass, pos, size, color);
    }

    /// Draw a circle
    pub fn drawCircle(self: Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, radius: f32, color: Color) void {
        self.drawCircleFn(self.impl, cmd_buffer, render_pass, pos, radius, color);
    }

    /// Draw an effect (particle/visual effect)
    pub fn drawEffect(self: Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, radius: f32, color: Color, intensity: f32, time: f32) void {
        self.drawEffectFn(self.impl, cmd_buffer, render_pass, pos, radius, color, intensity, time);
    }
};

/// Helper function to create a RendererInterface from any compatible renderer
pub fn createInterface(renderer: anytype) RendererInterface {
    const T = @TypeOf(renderer);
    const impl = struct {
        fn drawRect(ptr: *anyopaque, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, size: Vec2, color: Color) void {
            const self: *T = @ptrCast(@alignCast(ptr));
            self.drawRect(cmd_buffer, render_pass, pos, size, color);
        }

        fn drawCircle(ptr: *anyopaque, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, radius: f32, color: Color) void {
            const self: *T = @ptrCast(@alignCast(ptr));
            self.drawCircle(cmd_buffer, render_pass, pos, radius, color);
        }

        fn drawEffect(ptr: *anyopaque, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, radius: f32, color: Color, intensity: f32, time: f32) void {
            const self: *T = @ptrCast(@alignCast(ptr));
            self.drawEffect(cmd_buffer, render_pass, pos, radius, color, intensity, time);
        }
    };

    return RendererInterface{
        .drawRectFn = impl.drawRect,
        .drawCircleFn = impl.drawCircle,
        .drawEffectFn = impl.drawEffect,
        .impl = renderer,
    };
}