const std = @import("std");
const c = @import("../platform/sdl.zig");

/// GPU texture creation and management utilities
/// Centralizes texture creation patterns used throughout the font and text systems
/// GPU texture wrapper for easier management
pub const Texture = struct {
    texture: *c.sdl.SDL_GPUTexture,
    width: u32,
    height: u32,

    pub fn deinit(self: Texture, device: *c.sdl.SDL_GPUDevice) void {
        c.sdl.SDL_ReleaseGPUTexture(device, self.texture);
    }
};

/// Create GPU texture from grayscale bitmap data
pub fn createFromBitmap(device: *c.sdl.SDL_GPUDevice, allocator: std.mem.Allocator, bitmap: []const u8, width: u32, height: u32) !Texture {
    if (width == 0 or height == 0) {
        return error.InvalidDimensions;
    }

    // Convert grayscale bitmap to RGBA for GPU texture
    const bitmap_utils = @import("bitmap.zig");
    const rgba_data = try bitmap_utils.Convert.grayscaleToRGBA(allocator, bitmap, width, height);
    defer allocator.free(rgba_data);

    return try createFromRGBA(device, rgba_data, width, height);
}

/// Create GPU texture from RGBA data
pub fn createFromRGBA(device: *c.sdl.SDL_GPUDevice, rgba_data: []const u8, width: u32, height: u32) !Texture {
    // Create SDL GPU texture
    const texture_info = c.sdl.SDL_GPUTextureCreateInfo{
        .type = c.sdl.SDL_GPU_TEXTURETYPE_2D,
        .format = c.sdl.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
        .usage = c.sdl.SDL_GPU_TEXTUREUSAGE_SAMPLER,
        .width = width,
        .height = height,
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .sample_count = c.sdl.SDL_GPU_SAMPLECOUNT_1,
        .props = 0,
    };

    const texture = c.sdl.SDL_CreateGPUTexture(device, &texture_info) orelse {
        return error.TextureCreationFailed;
    };

    // Upload data to texture
    try uploadRGBAData(device, texture, rgba_data, width, height);

    return Texture{
        .texture = texture,
        .width = width,
        .height = height,
    };
}

/// Upload RGBA data to an existing GPU texture
pub fn uploadRGBAData(device: *c.sdl.SDL_GPUDevice, texture: *c.sdl.SDL_GPUTexture, rgba_data: []const u8, width: u32, height: u32) !void {
    const transfer_size = rgba_data.len;

    // Create transfer buffer
    const transfer_buffer_info = c.sdl.SDL_GPUTransferBufferCreateInfo{
        .usage = c.sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
        .size = @intCast(transfer_size),
        .props = 0,
    };

    const transfer_buffer = c.sdl.SDL_CreateGPUTransferBuffer(device, &transfer_buffer_info) orelse {
        return error.TransferBufferCreationFailed;
    };
    defer c.sdl.SDL_ReleaseGPUTransferBuffer(device, transfer_buffer);

    // Map and copy data
    const mapped_data = c.sdl.SDL_MapGPUTransferBuffer(device, transfer_buffer, false) orelse {
        return error.TransferBufferMapFailed;
    };

    @memcpy(@as([*]u8, @ptrCast(mapped_data))[0..transfer_size], rgba_data);
    c.sdl.SDL_UnmapGPUTransferBuffer(device, transfer_buffer);

    // Upload to texture
    const cmd_buffer = c.sdl.SDL_AcquireGPUCommandBuffer(device) orelse {
        return error.CommandBufferCreationFailed;
    };

    const copy_pass = c.sdl.SDL_BeginGPUCopyPass(cmd_buffer) orelse {
        return error.CopyPassCreationFailed;
    };

    const texture_transfer_info = c.sdl.SDL_GPUTextureTransferInfo{
        .transfer_buffer = transfer_buffer,
        .offset = 0,
        .pixels_per_row = width,
        .rows_per_layer = height,
    };

    const texture_region = c.sdl.SDL_GPUTextureRegion{
        .texture = texture,
        .mip_level = 0,
        .layer = 0,
        .x = 0,
        .y = 0,
        .z = 0,
        .w = width,
        .h = height,
        .d = 1,
    };

    c.sdl.SDL_UploadToGPUTexture(copy_pass, &texture_transfer_info, &texture_region, false);
    c.sdl.SDL_EndGPUCopyPass(copy_pass);
    _ = c.sdl.SDL_SubmitGPUCommandBuffer(cmd_buffer);
}

/// Create a minimal 1x1 empty texture for fallback cases
pub fn createEmpty(device: *c.sdl.SDL_GPUDevice) !Texture {
    const empty_rgba = [_]u8{ 0, 0, 0, 0 }; // Transparent black
    return try createFromRGBA(device, &empty_rgba, 1, 1);
}

/// Create a 1x1 white texture for testing
pub fn createWhite(device: *c.sdl.SDL_GPUDevice) !Texture {
    const white_rgba = [_]u8{ 255, 255, 255, 255 }; // Opaque white
    return try createFromRGBA(device, &white_rgba, 1, 1);
}
