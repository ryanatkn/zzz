// Frame and render pass management for GPU rendering
// Handles command buffer lifecycle and render pass operations

const std = @import("std");
const c = @import("../../platform/sdl.zig");
const Color = @import("../../core/colors.zig").Color;

pub const FrameError = error{
    CommandBufferFailed,
    SwapchainFailed,
    RenderPassFailed,
};

/// Begin a new frame and acquire command buffer
pub fn beginFrame(device: *c.sdl.SDL_GPUDevice, window: *c.sdl.SDL_Window) FrameError!*c.sdl.SDL_GPUCommandBuffer {
    // Update screen size is handled by the caller (GPURenderer)
    _ = window; // Currently unused but kept for API compatibility

    // Acquire command buffer
    const cmd_buffer = c.sdl.SDL_AcquireGPUCommandBuffer(device) orelse {
        return FrameError.CommandBufferFailed;
    };

    return cmd_buffer;
}

/// Start a render pass with the given background color
pub fn beginRenderPass(cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, window: *c.sdl.SDL_Window, bg_color: Color) FrameError!*c.sdl.SDL_GPURenderPass {
    // Acquire swapchain texture
    var swapchain_texture: ?*c.sdl.SDL_GPUTexture = null;
    if (!c.sdl.SDL_WaitAndAcquireGPUSwapchainTexture(cmd_buffer, window, &swapchain_texture, null, null)) {
        return FrameError.SwapchainFailed;
    }

    if (swapchain_texture) |texture| {
        const color_target_info = c.sdl.SDL_GPUColorTargetInfo{
            .texture = texture,
            .clear_color = .{ .r = bg_color.r, .g = bg_color.g, .b = bg_color.b, .a = bg_color.a },
            .load_op = c.sdl.SDL_GPU_LOADOP_CLEAR,
            .store_op = c.sdl.SDL_GPU_STOREOP_STORE,
            .cycle = false,
        };

        const render_pass = c.sdl.SDL_BeginGPURenderPass(cmd_buffer, &color_target_info, 1, null) orelse {
            return FrameError.RenderPassFailed;
        };

        return render_pass;
    }

    return FrameError.SwapchainFailed;
}

/// End render pass
pub fn endRenderPass(render_pass: *c.sdl.SDL_GPURenderPass) void {
    c.sdl.SDL_EndGPURenderPass(render_pass);
}

/// End frame and submit command buffer
pub fn endFrame(cmd_buffer: *c.sdl.SDL_GPUCommandBuffer) void {
    _ = c.sdl.SDL_SubmitGPUCommandBuffer(cmd_buffer);
}

/// Update screen dimensions from window
pub fn updateScreenSize(window: *c.sdl.SDL_Window) struct { width: f32, height: f32 } {
    var window_w: c_int = undefined;
    var window_h: c_int = undefined;
    _ = c.sdl.SDL_GetWindowSize(window, &window_w, &window_h);

    return .{
        .width = @floatFromInt(window_w),
        .height = @floatFromInt(window_h),
    };
}
