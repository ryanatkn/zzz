// Texture-based text renderer - handles bitmap and SDF strategies
// Renders text using textured quads (6 vertices per glyph with texture sampling)

const std = @import("std");
const math = @import("../../math/mod.zig");
const colors = @import("../../core/colors.zig");
const font_manager = @import("../../font/manager.zig");
const strategy_interface = @import("../../font/strategies/interface.zig");
const bitmap_strategy = @import("../../font/strategies/bitmap/mod.zig");
const sdf_strategy = @import("../../font/strategies/sdf/mod.zig");
const loggers = @import("../../debug/loggers.zig");

// Import GPU renderer type for texture rendering
const GPURenderer = @import("../../rendering/core/gpu.zig").GPURenderer;
const c = @import("../../platform/sdl.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const FontManager = font_manager.FontManager;
const RenderingStrategy = strategy_interface.RenderingStrategy;

/// Texture-based text renderer - handles bitmap and SDF strategies
/// Both strategies create textures that are rendered as quads
pub const TextureTextRenderer = struct {
    allocator: std.mem.Allocator,
    font_manager: *FontManager,
    current_strategy: RenderingStrategy,

    /// GPU texture cache for rendered glyphs
    texture_cache: std.AutoHashMap(u32, TextureGlyph),

    /// Configuration for texture generation
    config: TextureConfig,

    /// Batch rendering for multiple glyphs
    batch_queue: std.ArrayList(BatchedGlyph),

    pub const BatchedGlyph = struct {
        texture_glyph: TextureGlyph,
        position: Vec2,
        color: Color,
    };

    pub const TextureConfig = struct {
        /// Maximum texture atlas size
        max_atlas_size: u32 = 2048,

        /// Padding between glyphs in atlas
        glyph_padding: u32 = 2,

        /// Whether to use mipmapping
        use_mipmaps: bool = false,

        /// Texture filtering mode
        filter_mode: FilterMode = .linear,

        pub const FilterMode = enum {
            nearest,
            linear,
        };
    };

    pub const TextureGlyph = struct {
        texture: *c.sdl.SDL_GPUTexture,
        width: f32,
        height: f32,
        bearing_x: f32,
        bearing_y: f32,
        advance: f32,

        /// UV coordinates in atlas (if using atlas)
        uv_min: Vec2,
        uv_max: Vec2,

        /// Which strategy was used to generate this glyph
        strategy: RenderingStrategy,
    };

    pub fn init(allocator: std.mem.Allocator, font_mgr: *FontManager) TextureTextRenderer {
        return TextureTextRenderer{
            .allocator = allocator,
            .font_manager = font_mgr,
            .current_strategy = .bitmap, // Default to bitmap
            .texture_cache = std.AutoHashMap(u32, TextureGlyph).init(allocator),
            .config = TextureConfig{},
            .batch_queue = std.ArrayList(BatchedGlyph).init(allocator),
        };
    }

    pub fn deinit(self: *TextureTextRenderer, gpu_device: ?*c.sdl.SDL_GPUDevice) void {
        // Clean up cached textures
        var iterator = self.texture_cache.iterator();
        while (iterator.next()) |entry| {
            const texture_glyph = entry.value_ptr;
            // Only clean up real textures (not placeholder @ptrFromInt(1))
            if (gpu_device != null and @intFromPtr(texture_glyph.texture) > 1) {
                // Note: Atlas textures are owned by FontAtlas, not individual glyphs
                // So we don't call SDL_ReleaseGPUTexture here - FontManager handles atlas cleanup
                const font_log = loggers.getFontLog();
                font_log.debug("texture_cleanup", "Cached texture glyph cleaned up (atlas texture managed by FontManager)", .{});
            }
        }
        self.texture_cache.deinit();
        self.batch_queue.deinit();
    }

    /// Set the rendering strategy (bitmap or SDF)
    pub fn setStrategy(self: *TextureTextRenderer, strategy: RenderingStrategy) void {
        if (strategy == .vertex) {
            const font_log = loggers.getFontLog();
            font_log.warn("texture_strategy_warn", "TextureRenderer cannot use vertex strategy, keeping current strategy: {}", .{self.current_strategy});
            return;
        }
        self.current_strategy = strategy;
    }

    /// Render a single character using texture approach
    pub fn renderGlyph(
        self: *TextureTextRenderer,
        gpu_renderer: anytype,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        character: u32,
        position: Vec2,
        font_size: f32,
        color: Color,
    ) !void {
        // Get or create texture glyph
        const glyph_key = self.calculateGlyphKey(character, font_size);
        const texture_glyph = try self.getOrCreateTextureGlyph(character, font_size, glyph_key);

        // Render the textured quad
        try self.renderTextureQuad(gpu_renderer, cmd_buffer, render_pass, texture_glyph, position, color);
    }

    /// Render a string of text using texture approach
    pub fn renderText(
        self: *TextureTextRenderer,
        gpu_renderer: anytype,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        text: []const u8,
        position: Vec2,
        font_size: f32,
        color: Color,
    ) !Vec2 {
        var current_pos = position;

        for (text) |byte| {
            const character = @as(u32, byte);

            try self.renderGlyph(gpu_renderer, cmd_buffer, render_pass, character, current_pos, font_size, color);

            // Advance position
            const glyph_key = self.calculateGlyphKey(character, font_size);
            if (self.texture_cache.get(glyph_key)) |texture_glyph| {
                current_pos.x += texture_glyph.advance;
            } else {
                // Fallback advance
                current_pos.x += font_size * 0.6;
            }
        }

        return current_pos;
    }

    /// Add a glyph to the batch queue for later rendering
    pub fn batchGlyph(
        self: *TextureTextRenderer,
        character: u32,
        position: Vec2,
        font_size: f32,
        color: Color,
    ) !void {
        // Get or create texture glyph
        const glyph_key = self.calculateGlyphKey(character, font_size);
        const texture_glyph = try self.getOrCreateTextureGlyph(character, font_size, glyph_key);

        // Add to batch queue
        try self.batch_queue.append(BatchedGlyph{
            .texture_glyph = texture_glyph.*,
            .position = position,
            .color = color,
        });
    }

    /// Add text string to batch queue for later rendering
    pub fn batchText(
        self: *TextureTextRenderer,
        text: []const u8,
        position: Vec2,
        font_size: f32,
        color: Color,
    ) !Vec2 {
        var current_pos = position;

        for (text) |byte| {
            const character = @as(u32, byte);

            try self.batchGlyph(character, current_pos, font_size, color);

            // Advance position
            const glyph_key = self.calculateGlyphKey(character, font_size);
            if (self.texture_cache.get(glyph_key)) |texture_glyph| {
                current_pos.x += texture_glyph.advance;
            } else {
                // Fallback advance
                current_pos.x += font_size * 0.6;
            }
        }

        return current_pos;
    }

    /// Render all batched glyphs at once and clear the batch
    pub fn flushBatch(
        self: *TextureTextRenderer,
        gpu_renderer: anytype,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
    ) !void {
        if (self.batch_queue.items.len == 0) {
            return;
        }

        const batch_count = self.batch_queue.items.len;
        const font_log = loggers.getFontLog();
        font_log.debug("batch_flush_start", "Flushing {} batched glyphs", .{batch_count});

        // Group glyphs by texture to minimize texture binding
        // For now, render individually but track texture switches
        var current_texture: ?*c.sdl.SDL_GPUTexture = null;
        var texture_switches: u32 = 0;

        for (self.batch_queue.items) |batched_glyph| {
            // Count texture switches (for performance monitoring)
            if (current_texture != batched_glyph.texture_glyph.texture) {
                current_texture = batched_glyph.texture_glyph.texture;
                texture_switches += 1;
            }

            try self.renderTextureQuad(gpu_renderer, cmd_buffer, render_pass, &batched_glyph.texture_glyph, batched_glyph.position, batched_glyph.color);
        }

        // Clear the batch
        self.batch_queue.clearRetainingCapacity();

        font_log.debug("batch_flush_complete", "Flushed {} glyphs with {} texture switches", .{ batch_count, texture_switches });

        // TODO: Future optimization:
        // 1. Sort batch by texture to minimize switches
        // 2. Create single vertex buffer with all quads
        // 3. Use instanced rendering or single draw call with vertex buffer
        // 4. Implement texture array or atlas sharing
    }

    /// Get number of batched glyphs waiting to be rendered
    pub fn getBatchSize(self: *TextureTextRenderer) usize {
        return self.batch_queue.items.len;
    }

    /// Get or create a texture glyph for the given character and font size
    fn getOrCreateTextureGlyph(
        self: *TextureTextRenderer,
        character: u32,
        font_size: f32,
        glyph_key: u32,
    ) !*const TextureGlyph {
        if (self.texture_cache.getPtr(glyph_key)) |existing| {
            return existing;
        }

        // Create new texture glyph based on current strategy
        const texture_glyph = switch (self.current_strategy) {
            .bitmap => try self.createBitmapGlyph(character, font_size),
            .sdf => try self.createSDFGlyph(character, font_size),
            .vertex => unreachable, // Should not reach here due to setStrategy check
        };

        try self.texture_cache.put(glyph_key, texture_glyph);
        return self.texture_cache.getPtr(glyph_key).?;
    }

    /// Create a bitmap texture glyph using font manager's bitmap strategy
    fn createBitmapGlyph(self: *TextureTextRenderer, character: u32, font_size: f32) !TextureGlyph {
        const font_log = loggers.getFontLog();

        // Load font at the requested size (font manager handles caching)
        const font_id = try self.font_manager.loadFont(.sans, font_size); // TODO: Make font category configurable

        // Get bitmap atlas and rasterizer from font manager
        const atlas = self.font_manager.getBitmapAtlas(font_id) catch |err| {
            font_log.warn("texture_bitmap_atlas", "Failed to get bitmap atlas for font {}: {}", .{ font_id, err });
            return self.createFallbackGlyph(character, font_size);
        };

        const rasterizer = self.font_manager.getBitmapRasterizer(font_id) catch |err| {
            font_log.warn("texture_bitmap_rasterizer", "Failed to get bitmap rasterizer for font {}: {}", .{ font_id, err });
            return self.createFallbackGlyph(character, font_size);
        };

        // Get or rasterize the glyph using the bitmap strategy
        const glyph_info = atlas.getOrRasterizeGlyph(rasterizer, character, font_id, @as(u32, @intFromFloat(font_size))) catch |err| {
            font_log.warn("texture_bitmap_glyph", "Failed to rasterize glyph '{}' ({}): {}", .{ character, character, err });
            return self.createFallbackGlyph(character, font_size);
        };

        // Get atlas texture
        const texture = atlas.getAtlasTexture(glyph_info.atlas_index) orelse {
            font_log.err("texture_bitmap_atlas_tex", "No atlas texture found for glyph '{}'", .{character});
            return self.createFallbackGlyph(character, font_size);
        };

        // Calculate UV coordinates from atlas
        const atlas_width = @as(f32, @floatFromInt(atlas.atlas_size));
        const atlas_height = @as(f32, @floatFromInt(atlas.atlas_size));

        const uv_min = Vec2{
            .x = glyph_info.texture_x / atlas_width,
            .y = glyph_info.texture_y / atlas_height,
        };
        const uv_max = Vec2{
            .x = (glyph_info.texture_x + glyph_info.width) / atlas_width,
            .y = (glyph_info.texture_y + glyph_info.height) / atlas_height,
        };

        font_log.debug("texture_bitmap_success", "Created bitmap glyph '{}': {}x{} at ({}, {}) UV: ({:.3},{:.3}) to ({:.3},{:.3})", .{ character, @as(u32, @intFromFloat(glyph_info.width)), @as(u32, @intFromFloat(glyph_info.height)), @as(u32, @intFromFloat(glyph_info.texture_x)), @as(u32, @intFromFloat(glyph_info.texture_y)), uv_min.x, uv_min.y, uv_max.x, uv_max.y });

        return TextureGlyph{
            .texture = texture,
            .width = glyph_info.width,
            .height = glyph_info.height,
            .bearing_x = glyph_info.bearing_x,
            .bearing_y = glyph_info.bearing_y,
            .advance = glyph_info.advance,
            .uv_min = uv_min,
            .uv_max = uv_max,
            .strategy = .bitmap,
        };
    }

    /// Create a fallback glyph when bitmap strategy fails
    fn createFallbackGlyph(self: *TextureTextRenderer, character: u32, font_size: f32) !TextureGlyph {
        _ = self;

        const font_log = loggers.getFontLog();
        font_log.warn("texture_fallback", "Creating fallback glyph for character '{}' at size {d}", .{ character, font_size });

        // Create a basic placeholder glyph with dummy texture
        const dummy_texture = @as(*c.sdl.SDL_GPUTexture, @ptrFromInt(1)); // Placeholder non-null

        return TextureGlyph{
            .texture = dummy_texture,
            .width = font_size * 0.6,
            .height = font_size,
            .bearing_x = 0.0,
            .bearing_y = font_size * 0.75, // Approximate bearing
            .advance = font_size * 0.6,
            .uv_min = Vec2{ .x = 0.0, .y = 0.0 },
            .uv_max = Vec2{ .x = 1.0, .y = 1.0 },
            .strategy = .bitmap,
        };
    }

    /// Create an SDF texture glyph
    fn createSDFGlyph(self: *TextureTextRenderer, character: u32, font_size: f32) !TextureGlyph {
        // Use SDF strategy from font manager
        // For now, create a simple bitmap-based SDF until SDF generator is complete
        // TODO: Integrate with actual SDF generation from sdf_strategy when implemented

        const font_log = loggers.getFontLog();
        font_log.warn("texture_sdf", "SDF rendering not yet implemented, falling back to bitmap", .{});

        // Create bitmap glyph as fallback
        var bitmap_glyph = try self.createBitmapGlyph(character, font_size);
        bitmap_glyph.strategy = .sdf; // Mark as SDF for potential future handling

        return bitmap_glyph;
    }

    /// Create a single-glyph GPU texture (for non-atlas use cases)
    fn createSingleGlyphTexture(self: *TextureTextRenderer, bitmap: []const u8, width: u32, height: u32, gpu_device: *c.sdl.SDL_GPUDevice) !*c.sdl.SDL_GPUTexture {

        // Create texture
        const texture_info = c.sdl.SDL_GPUTextureCreateInfo{
            .type = c.sdl.SDL_GPU_TEXTURETYPE_2D,
            .format = c.sdl.SDL_GPU_TEXTUREFORMAT_R8_UNORM,
            .usage = c.sdl.SDL_GPU_TEXTUREUSAGE_SAMPLER,
            .width = width,
            .height = height,
            .layer_count_or_depth = 1,
            .num_levels = 1,
            .sample_count = c.sdl.SDL_GPU_SAMPLECOUNT_1,
            .props = 0,
        };

        const texture = c.sdl.SDL_CreateGPUTexture(gpu_device, &texture_info) orelse {
            return error.TextureCreationFailed;
        };

        // Upload bitmap data to texture
        try self.uploadBitmapToTexture(texture, bitmap, width, height, gpu_device);

        return texture;
    }

    /// Upload bitmap data to a GPU texture
    fn uploadBitmapToTexture(self: *TextureTextRenderer, texture: *c.sdl.SDL_GPUTexture, bitmap: []const u8, width: u32, height: u32, gpu_device: *c.sdl.SDL_GPUDevice) !void {
        _ = self;

        const transfer_size = width * height;

        const transfer_buffer_info = c.sdl.SDL_GPUTransferBufferCreateInfo{
            .usage = c.sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            .size = transfer_size,
        };

        const transfer_buffer = c.sdl.SDL_CreateGPUTransferBuffer(gpu_device, &transfer_buffer_info) orelse {
            return error.TransferBufferCreationFailed;
        };
        defer c.sdl.SDL_ReleaseGPUTransferBuffer(gpu_device, transfer_buffer);

        const mapped_ptr = c.sdl.SDL_MapGPUTransferBuffer(gpu_device, transfer_buffer, false) orelse {
            return error.TransferBufferMapFailed;
        };

        @memcpy(@as([*]u8, @ptrCast(mapped_ptr))[0..transfer_size], bitmap);

        c.sdl.SDL_UnmapGPUTransferBuffer(gpu_device, transfer_buffer);

        const cmd_buffer = c.sdl.SDL_AcquireGPUCommandBuffer(gpu_device) orelse {
            return error.CommandBufferFailed;
        };

        const copy_pass = c.sdl.SDL_BeginGPUCopyPass(cmd_buffer);

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

    /// Render a textured quad for a glyph
    fn renderTextureQuad(
        self: *TextureTextRenderer,
        gpu_renderer: anytype,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        texture_glyph: *const TextureGlyph,
        position: Vec2,
        color: Color,
    ) !void {
        _ = self;

        // Skip rendering if texture is a placeholder dummy
        if (@intFromPtr(texture_glyph.texture) <= 1) {
            return;
        }

        // Calculate glyph position with bearing offsets
        const glyph_pos = Vec2{
            .x = position.x + texture_glyph.bearing_x,
            .y = position.y - texture_glyph.bearing_y, // Y-up to Y-down conversion
        };

        const glyph_size = Vec2{
            .x = texture_glyph.width,
            .y = texture_glyph.height,
        };

        // Prepare uniform data for text rendering
        const uniforms_mod = @import("../../rendering/core/uniforms.zig");
        const uniform_data = uniforms_mod.TextUniforms{
            .uv_min = [2]f32{ texture_glyph.uv_min.x, texture_glyph.uv_min.y },
            .uv_max = [2]f32{ texture_glyph.uv_max.x, texture_glyph.uv_max.y },
            .screen_size = [2]f32{ gpu_renderer.screen_width, gpu_renderer.screen_height },
            .glyph_position = [2]f32{ glyph_pos.x, glyph_pos.y },
            .glyph_size = [2]f32{ glyph_size.x, glyph_size.y },
            .text_color_r = @as(f32, @floatFromInt(color.r)) / 255.0,
            .text_color_g = @as(f32, @floatFromInt(color.g)) / 255.0,
            .text_color_b = @as(f32, @floatFromInt(color.b)) / 255.0,
            .text_color_a = @as(f32, @floatFromInt(color.a)) / 255.0,
            ._padding = [2]f32{ 0.0, 0.0 },
        };

        const font_log = loggers.getFontLog();
        font_log.warn("texture_quad_uniforms", "Rendering glyph: pos=({:.1},{:.1}), size=({:.1},{:.1}), UV=({:.3},{:.3}) to ({:.3},{:.3})", .{ glyph_pos.x, glyph_pos.y, glyph_size.x, glyph_size.y, texture_glyph.uv_min.x, texture_glyph.uv_min.y, texture_glyph.uv_max.x, texture_glyph.uv_max.y });

        // Push uniform data BEFORE binding pipeline
        c.sdl.SDL_PushGPUVertexUniformData(cmd_buffer, 0, &uniform_data, @sizeOf(uniforms_mod.TextUniforms));

        // Bind text pipeline for texture rendering (not text_vertex_pipeline)
        c.sdl.SDL_BindGPUGraphicsPipeline(render_pass, gpu_renderer.pipelines.text_pipeline);

        // Create sampler for texture filtering
        const sampler_create_info = c.sdl.SDL_GPUSamplerCreateInfo{
            .min_filter = c.sdl.SDL_GPU_FILTER_LINEAR,
            .mag_filter = c.sdl.SDL_GPU_FILTER_LINEAR,
            .mipmap_mode = c.sdl.SDL_GPU_SAMPLERMIPMAPMODE_NEAREST,
            .address_mode_u = c.sdl.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
            .address_mode_v = c.sdl.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
            .address_mode_w = c.sdl.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
        };

        const sampler = c.sdl.SDL_CreateGPUSampler(gpu_renderer.device, &sampler_create_info);
        defer c.sdl.SDL_ReleaseGPUSampler(gpu_renderer.device, sampler);

        // Bind texture and sampler
        const texture_sampler_binding = c.sdl.SDL_GPUTextureSamplerBinding{
            .texture = texture_glyph.texture,
            .sampler = sampler,
        };
        c.sdl.SDL_BindGPUFragmentSamplers(render_pass, 0, &texture_sampler_binding, 1);

        // Draw procedural quad (6 vertices for 2 triangles)
        c.sdl.SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0);
    }

    /// Calculate a cache key for a glyph
    fn calculateGlyphKey(self: *TextureTextRenderer, character: u32, font_size: f32) u32 {
        _ = self;
        // Simple hash combining character and font size
        const size_bits = @as(u32, @intFromFloat(font_size * 100.0)); // Precision to 0.01
        return character ^ (size_bits << 16);
    }
};
