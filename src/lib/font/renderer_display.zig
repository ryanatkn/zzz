const std = @import("std");
const c = @import("../platform/sdl.zig");
const types = @import("../core/types.zig");
const renderer_interface = @import("renderers/renderer_interface.zig");
const multi_strategy_renderer = @import("multi_strategy_renderer.zig");

const Vec2 = types.Vec2;
const Color = types.Color;
const RenderResult = renderer_interface.RenderResult;
const RenderStrategy = renderer_interface.RenderStrategy;
const MultiRenderResult = multi_strategy_renderer.MultiRenderResult;

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
            .size = rgba_data.len,
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

        // Upload to texture
        const copy_pass = c.sdl.SDL_BeginGPUCopyPass(self.device, null) orelse {
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

        return texture;
    }

    /// Create special display texture for ASCII renderer output
    fn createAsciiDisplayTexture(self: *RendererDisplay, result: RenderResult) !*c.sdl.SDL_GPUTexture {
        // ASCII renderer stores ASCII characters in bitmap
        // We'll create a visual texture showing the ASCII art
        
        const char_width = 8;  // Pixels per ASCII character
        const char_height = 12; 
        const display_width = result.width * char_width;
        const display_height = result.height * char_height;
        
        const rgba_data = try self.allocator.alloc(u8, display_width * display_height * 4);
        defer self.allocator.free(rgba_data);
        @memset(rgba_data, 0);

        // Render each ASCII character as pixels
        for (result.bitmap, 0..) |ascii_char, i| {
            const char_x = i % result.width;
            const char_y = i / result.width;
            
            // Simple character visualization
            const intensity = switch (ascii_char) {
                ' ' => 0,
                '.' => 64,
                ':' => 128, 
                '+' => 192,
                '*' => 220,
                '#' => 255,
                '@' => 255,
                else => 128,
            };

            // Fill character area with intensity
            var py: u32 = 0;
            while (py < char_height) : (py += 1) {
                var px: u32 = 0;
                while (px < char_width) : (px += 1) {
                    const pixel_x = char_x * char_width + px;
                    const pixel_y = char_y * char_height + py;
                    const pixel_idx = (pixel_y * display_width + pixel_x) * 4;
                    
                    if (pixel_idx + 3 < rgba_data.len) {
                        rgba_data[pixel_idx + 0] = intensity; // R
                        rgba_data[pixel_idx + 1] = intensity; // G
                        rgba_data[pixel_idx + 2] = intensity; // B
                        rgba_data[pixel_idx + 3] = if (intensity > 0) 255 else 0; // A
                    }
                }
            }
        }

        return try self.createTextureFromRGBA(rgba_data, display_width, display_height);
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
            .size = rgba_data.len,
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

        const copy_pass = c.sdl.SDL_BeginGPUCopyPass(self.device, null) orelse {
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

        const copy_pass = c.sdl.SDL_BeginGPUCopyPass(self.device, null) orelse {
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

        return texture;
    }

    /// Get cached display texture for a strategy (returns null if not available)
    pub fn getDisplayTexture(self: *const RendererDisplay, strategy: RenderStrategy) ?*c.sdl.SDL_GPUTexture {
        return self.display_textures.get(strategy);
    }
};