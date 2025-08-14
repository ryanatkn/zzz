const std = @import("std");
const c = @import("c.zig");
const font_rasterizer = @import("font_rasterizer.zig");
const sdf_renderer = @import("sdf_renderer.zig");
const vector_path = @import("vector_path.zig");

const log = std.log.scoped(.font_atlas);

pub const RenderMode = enum {
    bitmap,     // Traditional bitmap rendering
    sdf,        // Signed Distance Field rendering
};

pub const GlyphInfo = struct {
    texture_x: u32,
    texture_y: u32,
    width: u32,
    height: u32,
    bearing_x: i32,
    bearing_y: i32,
    advance: f32,
    atlas_index: u32,
    bitmap: ?[]u8,  // Store the actual bitmap data for reuse
    render_mode: RenderMode,  // How this glyph was rendered
};

pub const AtlasTexture = struct {
    texture: *c.sdl.SDL_GPUTexture,
    width: u32,
    height: u32,
    current_x: u32,
    current_y: u32,
    row_height: u32,
};

pub const FontAtlas = struct {
    allocator: std.mem.Allocator,
    gpu_device: *c.sdl.SDL_GPUDevice,
    atlases: std.ArrayList(AtlasTexture),
    glyph_cache: std.AutoHashMap(u64, GlyphInfo),
    atlas_size: u32,
    padding: u32,
    default_render_mode: RenderMode,
    sdf_generator: ?sdf_renderer.SDFGenerator,
    
    pub fn init(allocator: std.mem.Allocator, gpu_device: *c.sdl.SDL_GPUDevice, atlas_size: u32) !FontAtlas {
        return FontAtlas{
            .allocator = allocator,
            .gpu_device = gpu_device,
            .atlases = std.ArrayList(AtlasTexture).init(allocator),
            .glyph_cache = std.AutoHashMap(u64, GlyphInfo).init(allocator),
            .atlas_size = atlas_size,
            .padding = 1, // Reduced padding for better packing
            .default_render_mode = .bitmap, // Start with bitmap rendering
            .sdf_generator = null, // Initialize SDF generator when needed
        };
    }
    
    pub fn enableSDF(self: *FontAtlas, config: sdf_renderer.SDFConfig) void {
        self.sdf_generator = sdf_renderer.SDFGenerator.init(self.allocator, config);
        self.default_render_mode = .sdf;
    }
    
    pub fn deinit(self: *FontAtlas) void {
        for (self.atlases.items) |atlas| {
            c.sdl.SDL_ReleaseGPUTexture(self.gpu_device, atlas.texture);
        }
        self.atlases.deinit();
        
        // Free all cached bitmaps
        var iter = self.glyph_cache.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.bitmap) |bitmap| {
                self.allocator.free(bitmap);
            }
        }
        self.glyph_cache.deinit();
    }
    
    pub fn getCachedBitmap(self: *FontAtlas, info: GlyphInfo) ?[]u8 {
        _ = self;  // Not needed, but kept for potential future use
        return info.bitmap;
    }
    
    fn createNewAtlas(self: *FontAtlas) !*AtlasTexture {
        const texture_info = c.sdl.SDL_GPUTextureCreateInfo{
            .type = c.sdl.SDL_GPU_TEXTURETYPE_2D,
            .format = c.sdl.SDL_GPU_TEXTUREFORMAT_R8_UNORM,
            .usage = c.sdl.SDL_GPU_TEXTUREUSAGE_SAMPLER,
            .width = self.atlas_size,
            .height = self.atlas_size,
            .layer_count_or_depth = 1,
            .num_levels = 1,
            .sample_count = c.sdl.SDL_GPU_SAMPLECOUNT_1,
            .props = 0,
        };
        
        const texture = c.sdl.SDL_CreateGPUTexture(self.gpu_device, &texture_info) orelse {
            return error.TextureCreationFailed;
        };
        
        const atlas = AtlasTexture{
            .texture = texture,
            .width = self.atlas_size,
            .height = self.atlas_size,
            .current_x = self.padding,
            .current_y = self.padding,
            .row_height = 0,
        };
        
        try self.atlases.append(atlas);
        return &self.atlases.items[self.atlases.items.len - 1];
    }
    
    pub fn getOrRasterizeGlyph(
        self: *FontAtlas,
        rasterizer: *font_rasterizer.FontRasterizer,
        codepoint: u32,
        font_id: u32,
        size: u32
    ) !GlyphInfo {
        const cache_key = (@as(u64, font_id) << 32) | (@as(u64, size) << 16) | @as(u64, codepoint);
        
        if (self.glyph_cache.get(cache_key)) |info| {
            return info;
        }
        
        const rasterized = try rasterizer.rasterizeGlyph(codepoint, 0, 0);
        // Don't free the bitmap yet - we'll store it in the cache
        
        const raster_log = std.log.scoped(.font_atlas_raster);
        raster_log.info("Rasterized glyph '{}' (U+{X:0>4}): {}x{} pixels, {} bytes", .{
            codepoint, codepoint, rasterized.width, rasterized.height, rasterized.bitmap.len
        });
        
        if (rasterized.width == 0 or rasterized.height == 0) {
            // For empty glyphs, we can free immediately since we don't need to store
            rasterizer.allocator.free(rasterized.bitmap);
            const info = GlyphInfo{
                .texture_x = 0,
                .texture_y = 0,
                .width = 0,
                .height = 0,
                .bearing_x = rasterized.bearing_x,
                .bearing_y = rasterized.bearing_y,
                .advance = rasterized.advance,
                .atlas_index = 0,
                .bitmap = null,
                .render_mode = self.default_render_mode,
            };
            try self.glyph_cache.put(cache_key, info);
            return info;
        }
        
        // Process glyph based on rendering mode
        var final_bitmap: []u8 = undefined;
        if (self.default_render_mode == .sdf and self.sdf_generator != null) {
            // Future: Convert bitmap to SDF using distance transform
            // For now, fall back to bitmap mode
            final_bitmap = try self.allocator.alloc(u8, rasterized.bitmap.len);
            @memcpy(final_bitmap, rasterized.bitmap);
        } else {
            // Standard bitmap processing
            final_bitmap = try self.allocator.alloc(u8, rasterized.bitmap.len);
            @memcpy(final_bitmap, rasterized.bitmap);
        }
        
        // Now we can free the original
        rasterizer.allocator.free(rasterized.bitmap);
        
        var atlas = if (self.atlases.items.len > 0) 
            &self.atlases.items[self.atlases.items.len - 1]
        else 
            try self.createNewAtlas();
        
        const padded_width = rasterized.width + self.padding * 2;
        const padded_height = rasterized.height + self.padding * 2;
        
        if (atlas.current_x + padded_width > atlas.width) {
            atlas.current_x = self.padding;
            atlas.current_y += atlas.row_height + self.padding;
            atlas.row_height = 0;
        }
        
        if (atlas.current_y + padded_height > atlas.height) {
            atlas = try self.createNewAtlas();
        }
        
        const texture_x = atlas.current_x + self.padding;
        const texture_y = atlas.current_y + self.padding;
        
        try self.uploadGlyphToAtlas(
            atlas.texture,
            final_bitmap,
            rasterized.width,
            rasterized.height,
            texture_x,
            texture_y
        );
        
        atlas.current_x += padded_width;
        atlas.row_height = @max(atlas.row_height, padded_height);
        
        const info = GlyphInfo{
            .texture_x = texture_x,
            .texture_y = texture_y,
            .width = rasterized.width,
            .height = rasterized.height,
            .bearing_x = rasterized.bearing_x,
            .bearing_y = rasterized.bearing_y,
            .advance = rasterized.advance,
            .atlas_index = @intCast(self.atlases.items.len - 1),
            .bitmap = final_bitmap,  // Store the processed bitmap
            .render_mode = self.default_render_mode,
        };
        
        try self.glyph_cache.put(cache_key, info);
        return info;
    }
    
    fn uploadGlyphToAtlas(
        self: *FontAtlas,
        texture: *c.sdl.SDL_GPUTexture,
        bitmap: []const u8,
        width: u32,
        height: u32,
        x: u32,
        y: u32
    ) !void {
        const transfer_size = width * height;
        
        const transfer_buffer_info = c.sdl.SDL_GPUTransferBufferCreateInfo{
            .usage = c.sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            .size = transfer_size,
        };
        
        const transfer_buffer = c.sdl.SDL_CreateGPUTransferBuffer(self.gpu_device, &transfer_buffer_info) orelse {
            return error.TransferBufferCreationFailed;
        };
        defer c.sdl.SDL_ReleaseGPUTransferBuffer(self.gpu_device, transfer_buffer);
        
        const mapped_ptr = c.sdl.SDL_MapGPUTransferBuffer(self.gpu_device, transfer_buffer, false) orelse {
            return error.TransferBufferMapFailed;
        };
        
        @memcpy(@as([*]u8, @ptrCast(mapped_ptr))[0..transfer_size], bitmap);
        
        c.sdl.SDL_UnmapGPUTransferBuffer(self.gpu_device, transfer_buffer);
        
        const cmd_buffer = c.sdl.SDL_AcquireGPUCommandBuffer(self.gpu_device) orelse {
            return error.CommandBufferFailed;
        };
        
        const copy_pass = c.sdl.SDL_BeginGPUCopyPass(cmd_buffer);
        
        const texture_transfer_info = c.sdl.SDL_GPUTextureTransferInfo{
            .transfer_buffer = transfer_buffer,
            .offset = 0,
            .pixels_per_row = width, // Width in pixels, not bytes
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
    
    pub fn getAtlasTexture(self: *FontAtlas, atlas_index: u32) ?*c.sdl.SDL_GPUTexture {
        if (atlas_index >= self.atlases.items.len) return null;
        return self.atlases.items[atlas_index].texture;
    }
    
    pub fn clearCache(self: *FontAtlas) void {
        for (self.atlases.items) |atlas| {
            c.sdl.SDL_ReleaseGPUTexture(self.gpu_device, atlas.texture);
        }
        self.atlases.clearRetainingCapacity();
        self.glyph_cache.clearRetainingCapacity();
    }
};