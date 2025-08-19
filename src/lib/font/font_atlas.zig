const std = @import("std");
const c = @import("../platform/sdl.zig");
const rasterizer_core = @import("rasterizer_core.zig");
const sdf_renderer = @import("../text/sdf_renderer.zig");
const vector_path = @import("../vector/path.zig");
const loggers = @import("../debug/loggers.zig");

const log = std.log.scoped(.font_atlas);

pub const RenderMode = enum {
    bitmap, // Traditional bitmap rendering
    sdf, // Signed Distance Field rendering
};

pub const GlyphInfo = struct {
    texture_x: f32,
    texture_y: f32,
    width: f32,
    height: f32,
    bearing_x: f32,
    bearing_y: f32,
    advance: f32,
    atlas_index: u32, // Keep as int - it's an index
    bitmap: ?[]u8, // Store the actual bitmap data for reuse
    render_mode: RenderMode, // How this glyph was rendered
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

    // Performance optimization fields
    max_memory_bytes: usize,
    current_memory_bytes: usize,
    lru_order: std.ArrayList(u64), // Track access order for LRU eviction

    pub fn init(allocator: std.mem.Allocator, gpu_device: *c.sdl.SDL_GPUDevice, atlas_size: u32) !FontAtlas {
        const max_memory = atlas_size * atlas_size * 4; // 4 atlases max by default
        return FontAtlas{
            .allocator = allocator,
            .gpu_device = gpu_device,
            .atlases = std.ArrayList(AtlasTexture).init(allocator),
            .glyph_cache = std.AutoHashMap(u64, GlyphInfo).init(allocator),
            .atlas_size = atlas_size,
            .padding = 1, // Reduced padding for better packing
            .default_render_mode = .bitmap, // Start with bitmap rendering
            .sdf_generator = null, // Initialize SDF generator when needed
            .max_memory_bytes = max_memory,
            .current_memory_bytes = 0,
            .lru_order = std.ArrayList(u64).init(allocator),
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
        self.lru_order.deinit();
    }

    pub fn getCachedBitmap(self: *FontAtlas, info: GlyphInfo) ?[]u8 {
        _ = self; // Not needed, but kept for potential future use
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

    pub fn getOrRasterizeGlyph(self: *FontAtlas, rasterizer: *rasterizer_core.RasterizerCore, codepoint: u32, font_id: u32, size: u32) !GlyphInfo {
        const cache_key = (@as(u64, font_id) << 32) | (@as(u64, size) << 16) | @as(u64, codepoint);

        if (self.glyph_cache.get(cache_key)) |info| {
            // Update LRU order on cache hit
            self.updateLRUOrder(cache_key);
            return info;
        }

        const rasterized = try rasterizer.rasterizeGlyph(codepoint, 0, 0);
        // Don't free the bitmap yet - we'll store it in the cache

        loggers.getFontLog().debug("rasterize", "Rasterized glyph '{}' (U+{X:0>4}): {}x{} pixels, {} bytes", .{ codepoint, codepoint, rasterized.width, rasterized.height, rasterized.bitmap.len });

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

        const padded_width = @as(u32, @intFromFloat(@ceil(rasterized.width))) + self.padding * 2;
        const padded_height = @as(u32, @intFromFloat(@ceil(rasterized.height))) + self.padding * 2;

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

        try self.uploadGlyphToAtlas(atlas.texture, final_bitmap, @as(u32, @intFromFloat(@ceil(rasterized.width))), @as(u32, @intFromFloat(@ceil(rasterized.height))), texture_x, texture_y);

        atlas.current_x += padded_width;
        atlas.row_height = @max(atlas.row_height, padded_height);

        const info = GlyphInfo{
            .texture_x = @floatFromInt(texture_x),
            .texture_y = @floatFromInt(texture_y),
            .width = rasterized.width,
            .height = rasterized.height,
            .bearing_x = rasterized.bearing_x,
            .bearing_y = rasterized.bearing_y,
            .advance = rasterized.advance,
            .atlas_index = @intCast(self.atlases.items.len - 1),
            .bitmap = final_bitmap, // Store the processed bitmap
            .render_mode = self.default_render_mode,
        };

        // Check memory limit before adding new glyph
        const bitmap_size = if (final_bitmap.len > 0) final_bitmap.len else 0;
        try self.ensureMemoryLimit(bitmap_size);

        self.current_memory_bytes += bitmap_size;
        try self.glyph_cache.put(cache_key, info);
        try self.lru_order.append(cache_key);
        return info;
    }

    fn uploadGlyphToAtlas(self: *FontAtlas, texture: *c.sdl.SDL_GPUTexture, bitmap: []const u8, width: u32, height: u32, x: u32, y: u32) !void {
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
        self.lru_order.clearRetainingCapacity();
        self.current_memory_bytes = 0;
    }

    /// Update LRU order when glyph is accessed
    fn updateLRUOrder(self: *FontAtlas, cache_key: u64) void {
        // Find and remove the key from its current position
        for (self.lru_order.items, 0..) |key, i| {
            if (key == cache_key) {
                _ = self.lru_order.orderedRemove(i);
                break;
            }
        }
        // Add to end (most recently used)
        self.lru_order.append(cache_key) catch {
            // If append fails, just log and continue - LRU tracking is best effort
            loggers.getFontLog().debug("lru_append", "Failed to update LRU order for glyph key {}", .{cache_key});
        };
    }

    /// Ensure memory usage stays within limits by evicting LRU glyphs
    fn ensureMemoryLimit(self: *FontAtlas, needed_bytes: usize) !void {
        while (self.current_memory_bytes + needed_bytes > self.max_memory_bytes and self.lru_order.items.len > 0) {
            const oldest_key = self.lru_order.orderedRemove(0);

            if (self.glyph_cache.get(oldest_key)) |info| {
                if (info.bitmap) |bitmap| {
                    self.current_memory_bytes -= bitmap.len;
                    self.allocator.free(bitmap);
                }
                _ = self.glyph_cache.remove(oldest_key);
                loggers.getFontLog().debug("evict_glyph", "Evicted glyph key {} to free memory", .{oldest_key});
            }
        }
    }

    /// Pre-generate commonly used glyphs for better performance
    pub fn pregenerateCommonGlyphs(self: *FontAtlas, rasterizer: *rasterizer_core.RasterizerCore, font_id: u32, size: u32) !void {
        // ASCII printable characters (space through tilde)
        const common_chars = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";

        loggers.getFontLog().info("pregenerate", "Pre-generating {} common glyphs for font {} size {}", .{ common_chars.len, font_id, size });

        for (common_chars) |char| {
            const codepoint = @as(u32, @intCast(char));
            _ = self.getOrRasterizeGlyph(rasterizer, codepoint, font_id, size) catch |err| {
                loggers.getFontLog().debug("pregenerate_fail", "Failed to pregenerate glyph '{}': {}", .{ char, err });
                continue;
            };
        }
    }

    /// Get memory usage statistics
    pub fn getMemoryStats(self: *FontAtlas) struct { used: usize, max: usize, glyphs: usize } {
        return .{
            .used = self.current_memory_bytes,
            .max = self.max_memory_bytes,
            .glyphs = self.glyph_cache.count(),
        };
    }
};
