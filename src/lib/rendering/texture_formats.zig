const std = @import("std");
const c = @import("../platform/sdl.zig");

/// Texture format enumeration with utility methods
pub const TextureFormat = enum {
    r8_unorm,
    r8g8b8a8_unorm,

    /// Get bytes per pixel for this format
    pub fn bytesPerPixel(self: TextureFormat) u32 {
        return switch (self) {
            .r8_unorm => 1,
            .r8g8b8a8_unorm => 4,
        };
    }

    /// Convert to SDL GPU texture format
    pub fn toSDLFormat(self: TextureFormat) c.sdl.SDL_GPUTextureFormat {
        return switch (self) {
            .r8_unorm => c.sdl.SDL_GPU_TEXTUREFORMAT_R8_UNORM,
            .r8g8b8a8_unorm => c.sdl.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
        };
    }

    /// Get recommended format for font atlases (industry standard)
    pub fn fontAtlasFormat() TextureFormat {
        return .r8g8b8a8_unorm;
    }

    /// Get format from SDL format (for compatibility)
    pub fn fromSDLFormat(sdl_format: c.sdl.SDL_GPUTextureFormat) ?TextureFormat {
        return switch (sdl_format) {
            c.sdl.SDL_GPU_TEXTUREFORMAT_R8_UNORM => .r8_unorm,
            c.sdl.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM => .r8g8b8a8_unorm,
            else => null,
        };
    }
};

/// RGBA pixel creation utilities
pub const RGBAPixel = struct {
    /// Create an RGBA pixel array from component values
    pub fn create(r: u8, g: u8, b: u8, a: u8) [4]u8 {
        return [4]u8{ r, g, b, a };
    }

    /// Create white pixel with alpha coverage (for font rendering)
    pub fn whiteCoverage(coverage: u8) [4]u8 {
        return [4]u8{ 255, 255, 255, coverage };
    }

    /// Create transparent pixel (no coverage)
    pub fn transparent() [4]u8 {
        return [4]u8{ 255, 255, 255, 0 };
    }

    /// Set RGBA pixel in buffer at specified index
    pub fn setInBuffer(buffer: []u8, pixel_index: usize, r: u8, g: u8, b: u8, a: u8) void {
        const byte_index = pixel_index * 4;
        if (byte_index + 3 < buffer.len) {
            buffer[byte_index + 0] = r;
            buffer[byte_index + 1] = g;
            buffer[byte_index + 2] = b;
            buffer[byte_index + 3] = a;
        }
    }

    /// Set white pixel with coverage at buffer index
    pub fn setWhiteCoverageInBuffer(buffer: []u8, pixel_index: usize, coverage: u8) void {
        setInBuffer(buffer, pixel_index, 255, 255, 255, coverage);
    }

    /// Set transparent pixel at buffer index
    pub fn setTransparentInBuffer(buffer: []u8, pixel_index: usize) void {
        setInBuffer(buffer, pixel_index, 255, 255, 255, 0);
    }
};

/// GPU texture transfer utilities
pub const TextureTransfer = struct {
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

    /// Upload data to GPU texture using transfer buffer
    pub fn uploadToTexture(
        gpu_device: *c.sdl.SDL_GPUDevice,
        texture: *c.sdl.SDL_GPUTexture,
        data: []const u8,
        width: u32,
        height: u32,
        x: u32,
        y: u32,
    ) !void {
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
};

/// Calculate buffer size for texture data
pub fn calculateTextureSize(width: u32, height: u32, format: TextureFormat) u32 {
    return width * height * format.bytesPerPixel();
}

/// Standard texture creation utilities
pub const TextureCreation = struct {
    /// Create a standard font atlas texture (2D, RGBA, sampler usage)
    pub fn createFontAtlasTexture(gpu_device: *c.sdl.SDL_GPUDevice, width: u32, height: u32) !*c.sdl.SDL_GPUTexture {
        const texture_info = c.sdl.SDL_GPUTextureCreateInfo{
            .type = c.sdl.SDL_GPU_TEXTURETYPE_2D,
            .format = TextureFormat.fontAtlasFormat().toSDLFormat(),
            .usage = c.sdl.SDL_GPU_TEXTUREUSAGE_SAMPLER,
            .width = width,
            .height = height,
            .layer_count_or_depth = 1,
            .num_levels = 1,
            .sample_count = c.sdl.SDL_GPU_SAMPLECOUNT_1,
            .props = 0,
        };

        return c.sdl.SDL_CreateGPUTexture(gpu_device, &texture_info) orelse {
            return error.TextureCreationFailed;
        };
    }
};

test "texture format utilities" {
    // Test bytes per pixel
    try std.testing.expect(TextureFormat.r8_unorm.bytesPerPixel() == 1);
    try std.testing.expect(TextureFormat.r8g8b8a8_unorm.bytesPerPixel() == 4);

    // Test RGBA pixel creation
    const pixel = RGBAPixel.create(255, 128, 64, 200);
    try std.testing.expect(pixel[0] == 255 and pixel[1] == 128 and pixel[2] == 64 and pixel[3] == 200);

    const white_pixel = RGBAPixel.whiteCoverage(128);
    try std.testing.expect(white_pixel[0] == 255 and white_pixel[3] == 128);

    // Test buffer operations
    var buffer = [_]u8{0} ** 16;
    RGBAPixel.setInBuffer(&buffer, 1, 100, 150, 200, 250);
    try std.testing.expect(buffer[4] == 100 and buffer[5] == 150 and buffer[6] == 200 and buffer[7] == 250);

    // Test size calculation
    const size = calculateTextureSize(64, 64, .r8g8b8a8_unorm);
    try std.testing.expect(size == 64 * 64 * 4);
}
