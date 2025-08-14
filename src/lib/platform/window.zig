const std = @import("std");
const c = @import("sdl.zig");

/// Window creation and management utilities
/// This is platform-level functionality that doesn't depend on rendering

/// Common error types for window operations
pub const WindowError = error{
    WindowCreationFailed,
    DeviceCreationFailed,
    OutOfMemory,
};

/// Window configuration structure
pub const WindowConfig = struct {
    title: [*:0]const u8,
    width: i32,
    height: i32,
    flags: u32 = c.sdl.SDL_WINDOW_VULKAN,
};

/// Create a window with the specified configuration
pub fn createWindow(config: WindowConfig) WindowError!*c.sdl.SDL_Window {
    return c.sdl.SDL_CreateWindow(config.title, config.width, config.height, config.flags) orelse {
        const log = std.log.scoped(.window);
        log.err("Failed to create window: {s} {}x{}", .{ config.title, config.width, config.height });
        return WindowError.WindowCreationFailed;
    };
}

/// Create a GPU device
pub fn createGPUDevice() WindowError!*c.sdl.SDL_GPUDevice {
    return c.sdl.SDL_CreateGPUDevice(
        c.sdl.SDL_GPU_SHADERFORMAT_SPIRV,
        true, // debug mode
        null  // preferred backend (let SDL choose)
    ) orelse {
        const log = std.log.scoped(.window);
        log.err("Failed to create GPU device", .{});
        return WindowError.DeviceCreationFailed;
    };
}

/// Claim a window for GPU rendering
pub fn claimWindowForGPU(device: *c.sdl.SDL_GPUDevice, window: *c.sdl.SDL_Window) WindowError!void {
    if (!c.sdl.SDL_ClaimWindowForGPUDevice(device, window)) {
        const log = std.log.scoped(.window);
        log.err("Failed to claim window for GPU device", .{});
        return WindowError.DeviceCreationFailed;
    }
}

/// Window and GPU device bundle
pub const WindowGPU = struct {
    window: *c.sdl.SDL_Window,
    device: *c.sdl.SDL_GPUDevice,

    pub fn init(config: WindowConfig) WindowError!WindowGPU {
        const window = try createWindow(config);
        errdefer c.sdl.SDL_DestroyWindow(window);

        const device = try createGPUDevice();
        errdefer c.sdl.SDL_DestroyGPUDevice(device);

        try claimWindowForGPU(device, window);

        return WindowGPU{
            .window = window,
            .device = device,
        };
    }

    pub fn deinit(self: *WindowGPU) void {
        c.sdl.SDL_DestroyGPUDevice(self.device);
        c.sdl.SDL_DestroyWindow(self.window);
    }
};