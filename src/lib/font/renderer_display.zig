const std = @import("std");
const c = @import("../platform/sdl.zig");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const renderer_interface = @import("renderers/renderer_interface.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const RenderResult = renderer_interface.RenderResult;
const RenderStrategy = renderer_interface.RenderStrategy;

/// Display utilities for renderer output debugging
pub const RendererDisplay = struct {
    allocator: std.mem.Allocator,
    device: *c.sdl.SDL_GPUDevice,

    /// Cached GPU textures for display
    display_textures: std.AutoHashMap(RenderStrategy, *c.sdl.SDL_GPUTexture),

    pub fn init(allocator: std.mem.Allocator, device: *c.sdl.SDL_GPUDevice) RendererDisplay {
        return RendererDisplay{
            .allocator = allocator,
            .device = device,
            .display_textures = std.AutoHashMap(RenderStrategy, *c.sdl.SDL_GPUTexture).init(allocator),
        };
    }

    pub fn deinit(self: *RendererDisplay) void {
        // Clean up cached textures
        var iterator = self.display_textures.iterator();
        while (iterator.next()) |entry| {
            c.sdl.SDL_ReleaseGPUTexture(self.device, entry.value_ptr.*);
        }
        self.display_textures.deinit();
    }

    /// Convert a RenderResult to a GPU texture for display
    pub fn createDisplayTexture(self: *RendererDisplay, result: RenderResult, strategy: RenderStrategy) !*c.sdl.SDL_GPUTexture {
        // Clean up previous texture for this strategy if it exists
        if (self.display_textures.get(strategy)) |old_texture| {
            c.sdl.SDL_ReleaseGPUTexture(self.device, old_texture);
        }

        // Handle special case for ASCII renderer (convert to visual representation)
        if (strategy == .debug_ascii) {
            return try self.createAsciiDisplayTexture(result);
        }

        // Create GPU texture from bitmap
        const texture = try self.createTextureFromBitmap(result.bitmap, result.width, result.height);

        // Cache the texture
        try self.display_textures.put(strategy, texture);

        return texture;
    }

    /// Create GPU texture from grayscale bitmap
    fn createTextureFromBitmap(self: *RendererDisplay, bitmap: []const u8, width: u32, height: u32) !*c.sdl.SDL_GPUTexture {
        if (width == 0 or height == 0) {
            // Create a minimal 1x1 texture for empty results
            return try self.createEmptyTexture();
        }

        // Convert grayscale bitmap to RGBA for display
        const rgba_data = try self.allocator.alloc(u8, width * height * 4);
        defer self.allocator.free(rgba_data);

        for (bitmap, 0..) |gray_value, i| {
            const rgba_idx = i * 4;
            // White text on transparent background
            rgba_data[rgba_idx + 0] = 255; // R
            rgba_data[rgba_idx + 1] = 255; // G
            rgba_data[rgba_idx + 2] = 255; // B
            rgba_data[rgba_idx + 3] = gray_value; // A (coverage)
        }

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

        const texture = c.sdl.SDL_CreateGPUTexture(self.device, &texture_info) orelse {
            return error.TextureCreationFailed;
        };

        // Upload data to texture
        const transfer_buffer_info = c.sdl.SDL_GPUTransferBufferCreateInfo{
            .usage = c.sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            .size = @intCast(rgba_data.len),
            .props = 0,
        };

        const transfer_buffer = c.sdl.SDL_CreateGPUTransferBuffer(self.device, &transfer_buffer_info) orelse {
            c.sdl.SDL_ReleaseGPUTexture(self.device, texture);
            return error.TransferBufferCreationFailed;
        };
        defer c.sdl.SDL_ReleaseGPUTransferBuffer(self.device, transfer_buffer);

        // Map and copy data
        const mapped_data = c.sdl.SDL_MapGPUTransferBuffer(self.device, transfer_buffer, false) orelse {
            c.sdl.SDL_ReleaseGPUTexture(self.device, texture);
            return error.TransferBufferMapFailed;
        };

        @memcpy(@as([*]u8, @ptrCast(mapped_data))[0..rgba_data.len], rgba_data);
        c.sdl.SDL_UnmapGPUTransferBuffer(self.device, transfer_buffer);

        // Upload to texture - need command buffer for copy pass
        const cmd_buffer = c.sdl.SDL_AcquireGPUCommandBuffer(self.device) orelse {
            c.sdl.SDL_ReleaseGPUTexture(self.device, texture);
            return error.CommandBufferCreationFailed;
        };

        const copy_pass = c.sdl.SDL_BeginGPUCopyPass(cmd_buffer) orelse {
            c.sdl.SDL_ReleaseGPUTexture(self.device, texture);
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

        // Submit command buffer to execute the upload
        _ = c.sdl.SDL_SubmitGPUCommandBuffer(cmd_buffer);

        return texture;
    }

    /// Create special display texture for ASCII renderer output
    fn createAsciiDisplayTexture(self: *RendererDisplay, result: RenderResult) !*c.sdl.SDL_GPUTexture {
        // Debug ASCII renderer now stores grayscale values (0-255) instead of ASCII characters
        // Treat it like a regular grayscale bitmap but with enhanced contrast for debugging

        if (result.width == 0 or result.height == 0) {
            return try self.createEmptyTexture();
        }

        // Convert grayscale bitmap to RGBA for display with enhanced contrast
        const rgba_data = try self.allocator.alloc(u8, result.width * result.height * 4);
        defer self.allocator.free(rgba_data);

        for (result.bitmap, 0..) |gray_value, i| {
            const rgba_idx = i * 4;

            // Enhanced contrast for debug visualization
            const enhanced_value: u8 = if (gray_value == 0) 0 else if (gray_value < 64) 64 // Light coverage -> dark gray
                else if (gray_value < 128) 128 // Medium coverage -> medium gray
                else if (gray_value < 192) 192 // Heavy coverage -> light gray
                else 255; // Full coverage -> white

            // Use different colors for different coverage levels for easier debugging
            if (gray_value == 0) {
                // Empty -> black/transparent
                rgba_data[rgba_idx + 0] = 0; // R
                rgba_data[rgba_idx + 1] = 0; // G
                rgba_data[rgba_idx + 2] = 0; // B
                rgba_data[rgba_idx + 3] = 32; // A (slight transparency)
            } else if (gray_value < 128) {
                // Light coverage -> blue tint
                rgba_data[rgba_idx + 0] = 0; // R
                rgba_data[rgba_idx + 1] = enhanced_value / 2; // G
                rgba_data[rgba_idx + 2] = enhanced_value; // B
                rgba_data[rgba_idx + 3] = 255; // A
            } else {
                // Heavy coverage -> white
                rgba_data[rgba_idx + 0] = enhanced_value; // R
                rgba_data[rgba_idx + 1] = enhanced_value; // G
                rgba_data[rgba_idx + 2] = enhanced_value; // B
                rgba_data[rgba_idx + 3] = 255; // A
            }
        }

        return try self.createTextureFromRGBA(rgba_data, result.width, result.height);
    }

    /// Create texture from RGBA data
    fn createTextureFromRGBA(self: *RendererDisplay, rgba_data: []const u8, width: u32, height: u32) !*c.sdl.SDL_GPUTexture {
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

        const texture = c.sdl.SDL_CreateGPUTexture(self.device, &texture_info) orelse {
            return error.TextureCreationFailed;
        };

        // Upload RGBA data (similar to grayscale upload but no conversion needed)
        const transfer_buffer_info = c.sdl.SDL_GPUTransferBufferCreateInfo{
            .usage = c.sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            .size = @intCast(rgba_data.len),
            .props = 0,
        };

        const transfer_buffer = c.sdl.SDL_CreateGPUTransferBuffer(self.device, &transfer_buffer_info) orelse {
            c.sdl.SDL_ReleaseGPUTexture(self.device, texture);
            return error.TransferBufferCreationFailed;
        };
        defer c.sdl.SDL_ReleaseGPUTransferBuffer(self.device, transfer_buffer);

        const mapped_data = c.sdl.SDL_MapGPUTransferBuffer(self.device, transfer_buffer, false) orelse {
            c.sdl.SDL_ReleaseGPUTexture(self.device, texture);
            return error.TransferBufferMapFailed;
        };

        @memcpy(@as([*]u8, @ptrCast(mapped_data))[0..rgba_data.len], rgba_data);
        c.sdl.SDL_UnmapGPUTransferBuffer(self.device, transfer_buffer);

        // Acquire command buffer for copy operations
        const cmd_buffer = c.sdl.SDL_AcquireGPUCommandBuffer(self.device) orelse {
            c.sdl.SDL_ReleaseGPUTexture(self.device, texture);
            return error.CommandBufferCreationFailed;
        };

        const copy_pass = c.sdl.SDL_BeginGPUCopyPass(cmd_buffer) orelse {
            c.sdl.SDL_ReleaseGPUTexture(self.device, texture);
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

        // Submit command buffer to execute the upload
        _ = c.sdl.SDL_SubmitGPUCommandBuffer(cmd_buffer);

        return texture;
    }

    /// Create empty 1x1 texture for failed/empty results
    fn createEmptyTexture(self: *RendererDisplay) !*c.sdl.SDL_GPUTexture {
        const empty_data = [_]u8{ 128, 128, 128, 255 }; // Gray pixel

        const texture_info = c.sdl.SDL_GPUTextureCreateInfo{
            .type = c.sdl.SDL_GPU_TEXTURETYPE_2D,
            .format = c.sdl.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
            .usage = c.sdl.SDL_GPU_TEXTUREUSAGE_SAMPLER,
            .width = 1,
            .height = 1,
            .layer_count_or_depth = 1,
            .num_levels = 1,
            .sample_count = c.sdl.SDL_GPU_SAMPLECOUNT_1,
            .props = 0,
        };

        const texture = c.sdl.SDL_CreateGPUTexture(self.device, &texture_info) orelse {
            return error.TextureCreationFailed;
        };

        // Upload single pixel
        const transfer_buffer_info = c.sdl.SDL_GPUTransferBufferCreateInfo{
            .usage = c.sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            .size = empty_data.len,
            .props = 0,
        };

        const transfer_buffer = c.sdl.SDL_CreateGPUTransferBuffer(self.device, &transfer_buffer_info) orelse {
            c.sdl.SDL_ReleaseGPUTexture(self.device, texture);
            return error.TransferBufferCreationFailed;
        };
        defer c.sdl.SDL_ReleaseGPUTransferBuffer(self.device, transfer_buffer);

        const mapped_data = c.sdl.SDL_MapGPUTransferBuffer(self.device, transfer_buffer, false) orelse {
            c.sdl.SDL_ReleaseGPUTexture(self.device, texture);
            return error.TransferBufferMapFailed;
        };

        @memcpy(@as([*]u8, @ptrCast(mapped_data))[0..empty_data.len], &empty_data);
        c.sdl.SDL_UnmapGPUTransferBuffer(self.device, transfer_buffer);

        // Acquire command buffer for copy operations
        const cmd_buffer = c.sdl.SDL_AcquireGPUCommandBuffer(self.device) orelse {
            c.sdl.SDL_ReleaseGPUTexture(self.device, texture);
            return error.CommandBufferCreationFailed;
        };

        const copy_pass = c.sdl.SDL_BeginGPUCopyPass(cmd_buffer) orelse {
            c.sdl.SDL_ReleaseGPUTexture(self.device, texture);
            return error.CopyPassCreationFailed;
        };

        const texture_transfer_info = c.sdl.SDL_GPUTextureTransferInfo{
            .transfer_buffer = transfer_buffer,
            .offset = 0,
            .pixels_per_row = 1,
            .rows_per_layer = 1,
        };

        const texture_region = c.sdl.SDL_GPUTextureRegion{
            .texture = texture,
            .mip_level = 0,
            .layer = 0,
            .x = 0,
            .y = 0,
            .z = 0,
            .w = 1,
            .h = 1,
            .d = 1,
        };

        c.sdl.SDL_UploadToGPUTexture(copy_pass, &texture_transfer_info, &texture_region, false);
        c.sdl.SDL_EndGPUCopyPass(copy_pass);

        // Submit command buffer to execute the upload
        _ = c.sdl.SDL_SubmitGPUCommandBuffer(cmd_buffer);

        return texture;
    }

    /// Get cached display texture for a strategy (returns null if not available)
    pub fn getDisplayTexture(self: *const RendererDisplay, strategy: RenderStrategy) ?*c.sdl.SDL_GPUTexture {
        return self.display_textures.get(strategy);
    }
};
