const std = @import("std");
const c = @import("../../platform/sdl.zig");
const texture_formats = @import("texture_formats.zig");

/// GPU texture upload utilities for different formats and buffer types
/// Consolidates duplicate texture transfer logic across the codebase
pub const TextureUpload = struct {
    /// Create and map a transfer buffer for texture upload
    pub fn createTransferBuffer(
        gpu_device: *c.sdl.SDL_GPUDevice,
        size_bytes: u32,
    ) !struct { buffer: *c.sdl.SDL_GPUTransferBuffer, mapped_ptr: *anyopaque } {
        const transfer_buffer_info = c.sdl.SDL_GPUTransferBufferCreateInfo{
            .usage = c.sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            .size = size_bytes,
        };

        const transfer_buffer = c.sdl.SDL_CreateGPUTransferBuffer(gpu_device, &transfer_buffer_info) orelse {
            return error.TransferBufferCreationFailed;
        };

        const mapped_ptr = c.sdl.SDL_MapGPUTransferBuffer(gpu_device, transfer_buffer, false) orelse {
            c.sdl.SDL_ReleaseGPUTransferBuffer(gpu_device, transfer_buffer);
            return error.TransferBufferMapFailed;
        };

        return .{ .buffer = transfer_buffer, .mapped_ptr = mapped_ptr };
    }

    /// Upload RGBA data to GPU texture (4 bytes per pixel)
    pub fn uploadRGBA(
        gpu_device: *c.sdl.SDL_GPUDevice,
        texture: *c.sdl.SDL_GPUTexture,
        data: []const u8,
        width: u32,
        height: u32,
        x: u32,
        y: u32,
    ) !void {
        return uploadBitmap(gpu_device, texture, data, width, height, x, y, .r8g8b8a8_unorm);
    }

    /// Upload grayscale data to GPU texture (1 byte per pixel)
    pub fn uploadGrayscale(
        gpu_device: *c.sdl.SDL_GPUDevice,
        texture: *c.sdl.SDL_GPUTexture,
        data: []const u8,
        width: u32,
        height: u32,
        x: u32,
        y: u32,
    ) !void {
        return uploadBitmap(gpu_device, texture, data, width, height, x, y, .r8_unorm);
    }

    /// Upload bitmap data to GPU texture with format awareness
    pub fn uploadBitmap(
        gpu_device: *c.sdl.SDL_GPUDevice,
        texture: *c.sdl.SDL_GPUTexture,
        data: []const u8,
        width: u32,
        height: u32,
        x: u32,
        y: u32,
        format: texture_formats.TextureFormat,
    ) !void {
        // Validate data size matches expected format
        const expected_size = texture_formats.calculateTextureSize(width, height, format);
        if (data.len != expected_size) {
            return error.InvalidDataSize;
        }

        const transfer = try createTransferBuffer(gpu_device, @intCast(data.len));
        defer {
            c.sdl.SDL_UnmapGPUTransferBuffer(gpu_device, transfer.buffer);
            c.sdl.SDL_ReleaseGPUTransferBuffer(gpu_device, transfer.buffer);
        }

        // Copy data to transfer buffer
        @memcpy(@as([*]u8, @ptrCast(transfer.mapped_ptr))[0..data.len], data);

        // Create command buffer and copy pass
        const cmd_buffer = c.sdl.SDL_AcquireGPUCommandBuffer(gpu_device) orelse {
            return error.CommandBufferFailed;
        };

        const copy_pass = c.sdl.SDL_BeginGPUCopyPass(cmd_buffer);

        const texture_transfer_info = c.sdl.SDL_GPUTextureTransferInfo{
            .transfer_buffer = transfer.buffer,
            .offset = 0,
            .pixels_per_row = width,
            .rows_per_layer = height,
        };

        const texture_region = c.sdl.SDL_GPUTextureRegion{
            .texture = texture,
            .mip_level = 0,
            .layer = 0,
            .x = x,
            .y = y,
            .z = 0,
            .w = width,
            .h = height,
            .d = 1,
        };

        c.sdl.SDL_UploadToGPUTexture(copy_pass, &texture_transfer_info, &texture_region, false);
        c.sdl.SDL_EndGPUCopyPass(copy_pass);

        _ = c.sdl.SDL_SubmitGPUCommandBuffer(cmd_buffer);
    }

    /// Create and populate vertex transfer buffer (for vertex_renderer.zig compatibility)
    pub fn createVertexBuffer(
        gpu_device: *c.sdl.SDL_GPUDevice,
        vertex_data: []const u8,
    ) !struct { buffer: *c.sdl.SDL_GPUTransferBuffer, mapped_ptr: *anyopaque } {
        const transfer = try createTransferBuffer(gpu_device, @intCast(vertex_data.len));

        // Copy vertex data to transfer buffer
        @memcpy(@as([*]u8, @ptrCast(transfer.mapped_ptr))[0..vertex_data.len], vertex_data);

        return transfer;
    }
};

/// Backward compatibility - keep existing TextureTransfer interface
pub const TextureTransfer = struct {
    /// Upload data to GPU texture using transfer buffer (RGBA format assumed)
    pub fn uploadToTexture(
        gpu_device: *c.sdl.SDL_GPUDevice,
        texture: *c.sdl.SDL_GPUTexture,
        data: []const u8,
        width: u32,
        height: u32,
        x: u32,
        y: u32,
    ) !void {
        return TextureUpload.uploadRGBA(gpu_device, texture, data, width, height, x, y);
    }
};

test "texture upload utilities" {
    // Test data size calculation validation
    const rgba_size = texture_formats.calculateTextureSize(64, 64, .r8g8b8a8_unorm);
    const r8_size = texture_formats.calculateTextureSize(64, 64, .r8_unorm);

    try std.testing.expect(rgba_size == 64 * 64 * 4);
    try std.testing.expect(r8_size == 64 * 64 * 1);

    // Test would validate data size mismatches if we had GPU context
    // const invalid_data = [_]u8{0} ** 100; // Wrong size
    // try std.testing.expectError(error.InvalidDataSize, uploadBitmap(..., invalid_data, ...));
}
