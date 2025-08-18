// Zzz - Renderer Interface
// Common interface for drawing operations that can be implemented by different renderers

const std = @import("std");
const c = @import("../platform/sdl.zig");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;

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

/// Type-safe renderer interface creation with comptime validation
/// Validates renderer methods at compile time for better type safety
pub fn createInterface(renderer: anytype) RendererInterface {
    const T = @TypeOf(renderer);
    const PtrT = switch (@typeInfo(T)) {
        .pointer => |ptr_info| ptr_info.child,
        else => T,
    };

    // Compile-time validation that renderer has required methods
    comptime {
        if (!@hasDecl(PtrT, "drawRect")) {
            @compileError("Renderer must have drawRect method with signature: fn(*Self, *SDL_GPUCommandBuffer, *SDL_GPURenderPass, Vec2, Vec2, Color) void");
        }
        if (!@hasDecl(PtrT, "drawCircle")) {
            @compileError("Renderer must have drawCircle method with signature: fn(*Self, *SDL_GPUCommandBuffer, *SDL_GPURenderPass, Vec2, f32, Color) void");
        }
        if (!@hasDecl(PtrT, "drawEffect")) {
            @compileError("Renderer must have drawEffect method with signature: fn(*Self, *SDL_GPUCommandBuffer, *SDL_GPURenderPass, Vec2, f32, Color, f32, f32) void");
        }
    }

    const impl = struct {
        fn drawRect(ptr: *anyopaque, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, size: Vec2, color: Color) void {
            const self: T = @ptrCast(@alignCast(ptr));
            self.drawRect(cmd_buffer, render_pass, pos, size, color);
        }

        fn drawCircle(ptr: *anyopaque, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, radius: f32, color: Color) void {
            const self: T = @ptrCast(@alignCast(ptr));
            self.drawCircle(cmd_buffer, render_pass, pos, radius, color);
        }

        fn drawEffect(ptr: *anyopaque, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, radius: f32, color: Color, intensity: f32, time: f32) void {
            const self: T = @ptrCast(@alignCast(ptr));
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

/// Generic renderer interface that provides compile-time type safety
/// Alternative to RendererInterface for when you know the renderer type at compile time
pub fn RendererGeneric(comptime RendererType: type) type {
    return struct {
        renderer: *RendererType,

        const Self = @This();

        pub fn init(renderer: *RendererType) Self {
            return Self{ .renderer = renderer };
        }

        pub fn drawRect(self: Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, size: Vec2, color: Color) void {
            self.renderer.drawRect(cmd_buffer, render_pass, pos, size, color);
        }

        pub fn drawCircle(self: Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, radius: f32, color: Color) void {
            self.renderer.drawCircle(cmd_buffer, render_pass, pos, radius, color);
        }

        pub fn drawEffect(self: Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, radius: f32, color: Color, intensity: f32, time: f32) void {
            self.renderer.drawEffect(cmd_buffer, render_pass, pos, radius, color, intensity, time);
        }

        /// Convert to runtime interface when needed
        pub fn toInterface(self: *Self) RendererInterface {
            return createInterface(self.renderer);
        }
    };
}
