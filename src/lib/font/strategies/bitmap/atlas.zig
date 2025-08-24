const std = @import("std");
const c = @import("../../../platform/sdl.zig");
const rasterizer_core = @import("rasterizer.zig");
const vector_path = @import("../../../vector/path.zig");
const loggers = @import("../../../debug/loggers.zig");
const texture_formats = @import("../../../rendering/core/texture_formats.zig");
const rendering_core = @import("../../../rendering/core/mod.zig");

const log = std.log.scoped(.font_atlas);

// TODO: @many font rendering with quads

// Bitmap atlas only handles bitmap rendering
// SDF rendering is handled by the SDF strategy

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
    sampler: ?*c.sdl.SDL_GPUSampler, // Shared sampler for all atlas textures

    // Performance optimization fields
    max_memory_bytes: usize,
    current_memory_bytes: usize,
    lru_order: std.ArrayList(u64), // Track access order for LRU eviction

    pub fn init(allocator: std.mem.Allocator, gpu_device: *c.sdl.SDL_GPUDevice, atlas_size: u32) !FontAtlas {
        const max_memory = texture_formats.calculateTextureSize(atlas_size, atlas_size, .r8g8b8a8_unorm) * 4; // 4 atlases max by default
        var atlas = FontAtlas{
            .allocator = allocator,
            .gpu_device = gpu_device,
            .atlases = std.ArrayList(AtlasTexture).init(allocator),
            .glyph_cache = std.AutoHashMap(u64, GlyphInfo).init(allocator),
            .atlas_size = atlas_size,
            .padding = 1, // Reduced padding for better packing
            .sampler = null,
            .max_memory_bytes = max_memory,
            .current_memory_bytes = 0,
            .lru_order = std.ArrayList(u64).init(allocator),
        };

        // Create shared sampler for all atlas textures
        try atlas.createSampler();

        return atlas;
    }

    /// Create a shared sampler for all atlas textures
    fn createSampler(self: *FontAtlas) !void {
        self.sampler = try rendering_core.Samplers.createLinearSampler(self.gpu_device);
    }

    // SDF functionality moved to SDF strategy - bitmap atlas only handles bitmap rendering

    pub fn deinit(self: *FontAtlas) void {
        // Release sampler
        if (self.sampler) |sampler| {
            c.sdl.SDL_ReleaseGPUSampler(self.gpu_device, sampler);
        }

        // Release atlas textures
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
        const texture = try texture_formats.TextureCreation.createFontAtlasTexture(
            self.gpu_device,
            self.atlas_size,
            self.atlas_size,
        );

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
            };
            try self.glyph_cache.put(cache_key, info);
            return info;
        }

        // Process glyph - bitmap atlas only handles bitmap rendering
        const final_bitmap: []u8 = try self.allocator.alloc(u8, rasterized.bitmap.len);
        @memcpy(final_bitmap, rasterized.bitmap);

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
        // Use shared texture upload utilities
        try texture_formats.TextureTransfer.uploadToTexture(
            self.gpu_device,
            texture,
            bitmap,
            width,
            height,
            x,
            y,
        );
    }

    pub fn getAtlasTexture(self: *FontAtlas, atlas_index: u32) ?*c.sdl.SDL_GPUTexture {
        if (atlas_index >= self.atlases.items.len) return null;
        return self.atlases.items[atlas_index].texture;
    }

    /// Get the shared sampler for atlas textures
    pub fn getAtlasSampler(self: *FontAtlas) ?*c.sdl.SDL_GPUSampler {
        return self.sampler;
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
