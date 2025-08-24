// SDL3 GPU device management - handles device creation, backend selection, and cleanup
// Provides abstraction over SDL3 GPU device lifecycle

const std = @import("std");
const c = @import("../../platform/sdl.zig");
const loggers = @import("../../debug/loggers.zig");

pub const DeviceCreationError = error{
    GPUDeviceCreationFailed,
    WindowClaimFailed,
};

/// Creates an SDL3 GPU device with backend fallback strategy
/// Priority: OpenGL → Software → Auto-select (Vulkan)
pub fn createDevice(window: *c.sdl.SDL_Window) DeviceCreationError!*c.sdl.SDL_GPUDevice {
    loggers.getRenderLog().info("gpu_create", "Creating simple GPU device", .{});

    // Try different backends to work around NVIDIA Vulkan driver issues
    // Priority: 1) OpenGL first 2) Software 3) Auto-select as last resort
    const backends = [_]?[*:0]const u8{
        "opengl", // Force OpenGL backend first
        "software", // Software fallback
        null, // Auto-select (usually Vulkan) as last resort
    };

    var device: ?*c.sdl.SDL_GPUDevice = null;
    var backend_used: []const u8 = "unknown";

    for (backends) |backend_name| {
        const name_str = if (backend_name) |name| std.mem.span(name) else "auto-select";
        loggers.getRenderLog().info("gpu_backend_try", "Trying GPU backend: {s}", .{name_str});

        device = c.sdl.SDL_CreateGPUDevice(
            c.sdl.SDL_GPU_SHADERFORMAT_SPIRV | c.sdl.SDL_GPU_SHADERFORMAT_DXIL,
            false, // CRITICAL FIX: Disable debug mode to avoid device->debug_mode crash
            backend_name,
        );

        if (device != null) {
            backend_used = name_str;
            break;
        } else {
            const err = c.sdl.SDL_GetError();
            loggers.getRenderLog().warn("gpu_backend_fail", "Failed to create GPU device with {s}: {s}", .{ name_str, err });
        }
    }

    const final_device = device orelse {
        loggers.getRenderLog().err("gpu_create_fail", "Failed to create GPU device", .{});
        return DeviceCreationError.GPUDeviceCreationFailed;
    };

    if (!c.sdl.SDL_ClaimWindowForGPUDevice(final_device, window)) {
        loggers.getRenderLog().err("gpu_claim_fail", "Failed to claim window for GPU device", .{});
        c.sdl.SDL_DestroyGPUDevice(final_device);
        return DeviceCreationError.WindowClaimFailed;
    }

    loggers.getRenderLog().info("gpu_create_success", "GPU device created successfully using backend: {s}", .{backend_used});

    return final_device;
}

/// Destroys the GPU device and releases resources
pub fn destroyDevice(device: *c.sdl.SDL_GPUDevice) void {
    c.sdl.SDL_DestroyGPUDevice(device);
}
