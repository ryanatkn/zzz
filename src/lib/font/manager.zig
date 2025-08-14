const std = @import("std");
const c = @import("../c.zig");
const types = @import("../types.zig");
const ttf_parser = @import("ttf_parser.zig");
const rasterizer_core = @import("rasterizer_core.zig");
const font_atlas = @import("font_atlas.zig");
const text_layout = @import("../text/layout.zig");
const font_config = @import("config.zig");

const log = std.log.scoped(.pure_font_manager);

pub const LoadedFont = struct {
    id: u32,
    path: []const u8,
    data: []u8,
    parser: *ttf_parser.TTFParser,
    rasterizers: std.AutoHashMap(u32, *rasterizer_core.RasterizerCore),
};

pub const FontManager = struct {
    allocator: std.mem.Allocator,
    gpu_device: *c.sdl.SDL_GPUDevice,
    settings: font_config.FontSettings,
    loaded_fonts: std.ArrayList(LoadedFont),
    atlas: font_atlas.FontAtlas,
    layout_engine: ?text_layout.TextLayoutEngine,
    next_font_id: u32,

    pub fn init(allocator: std.mem.Allocator, gpu_device: *c.sdl.SDL_GPUDevice) !FontManager {
        return FontManager{
            .allocator = allocator,
            .gpu_device = gpu_device,
            .settings = font_config.FontSettings{},
            .loaded_fonts = std.ArrayList(LoadedFont).init(allocator),
            .atlas = try font_atlas.FontAtlas.init(allocator, gpu_device, 1024),
            .layout_engine = null,
            .next_font_id = 1,
        };
    }

    pub fn deinit(self: *FontManager) void {
        for (self.loaded_fonts.items) |*font| {
            var iter = font.rasterizers.iterator();
            while (iter.next()) |entry| {
                self.allocator.destroy(entry.value_ptr.*);
            }
            font.rasterizers.deinit();
            font.parser.deinit();
            self.allocator.destroy(font.parser);
            self.allocator.free(font.data);
        }
        self.loaded_fonts.deinit();
        self.atlas.deinit();
    }

    pub fn loadFont(self: *FontManager, category: font_config.FontCategory, size: f32) !u32 {
        const family_name = switch (category) {
            .mono => self.settings.mono_family,
            .sans => self.settings.sans_family,
            .serif_display => self.settings.serif_display_family,
            .serif_text => self.settings.serif_text_family,
        };

        const weight = switch (category) {
            .mono => self.settings.mono_weight,
            .sans => self.settings.sans_weight,
            .serif_display => self.settings.serif_display_weight,
            .serif_text => self.settings.serif_text_weight,
        };

        const italic = switch (category) {
            .mono => self.settings.mono_italic,
            .sans => self.settings.sans_italic,
            .serif_display => self.settings.serif_display_italic,
            .serif_text => self.settings.serif_text_italic,
        };

        var font_family: ?font_config.FontFamily = null;
        for (font_config.available_fonts) |family| {
            if (std.mem.eql(u8, family.name, family_name)) {
                font_family = family;
                break;
            }
        }

        if (font_family == null) {
            log.err("Font family not found: {s}", .{family_name});
            return error.FontFamilyNotFound;
        }

        var best_variant: ?font_config.FontVariant = null;
        var best_score: i32 = std.math.maxInt(i32);

        for (font_family.?.variants) |variant| {
            const weight_diff: i32 = @intCast(@abs(variant.weight - weight));
            const italic_match: i32 = if (variant.italic == italic) 0 else 1000;
            const score = weight_diff + italic_match;

            if (score < best_score) {
                best_score = score;
                best_variant = variant;
            }
        }

        if (best_variant == null) {
            return error.FontVariantNotFound;
        }

        for (self.loaded_fonts.items) |*font| {
            if (std.mem.eql(u8, font.path, best_variant.?.path)) {
                const size_key = @as(u32, @intFromFloat(size * 100));

                if (font.rasterizers.get(size_key)) |_| {
                    return font.id;
                }

                const rasterizer = try self.allocator.create(rasterizer_core.RasterizerCore);
                rasterizer.* = rasterizer_core.RasterizerCore.init(self.allocator, font.parser, size, 96);
                //rasterizer.setDebugMode(true);  // Enable debug mode - disabled for now
                try font.rasterizers.put(size_key, rasterizer);

                return font.id;
            }
        }

        const file = std.fs.cwd().openFile(best_variant.?.path, .{}) catch |err| {
            log.err("Failed to open font file {s}: {}", .{ best_variant.?.path, err });
            return error.FontLoadFailed;
        };
        defer file.close();

        const file_size = try file.getEndPos();
        const data = try self.allocator.alloc(u8, file_size);
        _ = try file.read(data);

        const parser_ptr = try self.allocator.create(ttf_parser.TTFParser);
        parser_ptr.* = try ttf_parser.TTFParser.init(self.allocator, data);

        var rasterizers = std.AutoHashMap(u32, *rasterizer_core.RasterizerCore).init(self.allocator);
        const size_key = @as(u32, @intFromFloat(size * 100));
        const rasterizer = try self.allocator.create(rasterizer_core.RasterizerCore);
        rasterizer.* = rasterizer_core.RasterizerCore.init(self.allocator, parser_ptr, size, 96);
        //rasterizer.setDebugMode(true);  // Enable debug mode - disabled for now
        try rasterizers.put(size_key, rasterizer);

        const font_id = self.next_font_id;
        self.next_font_id += 1;

        try self.loaded_fonts.append(LoadedFont{
            .id = font_id,
            .path = best_variant.?.path,
            .data = data,
            .parser = parser_ptr,
            .rasterizers = rasterizers,
        });

        const loaded_font = &self.loaded_fonts.items[self.loaded_fonts.items.len - 1];
        const actual_rasterizer = loaded_font.rasterizers.get(size_key).?;

        if (self.layout_engine == null) {
            self.layout_engine = text_layout.TextLayoutEngine.init(self.allocator, &self.atlas, actual_rasterizer);
        }

        log.info("Loaded font: {s} (id: {}, size: {d})", .{ best_variant.?.path, font_id, size });

        return font_id;
    }

    pub fn renderTextToTexture(
        self: *FontManager,
        text: []const u8,
        category: font_config.FontCategory,
        size: f32,
        color: types.Color,
    ) !struct {
        texture: *c.sdl.SDL_GPUTexture,
        width: u32,
        height: u32,
    } {
        const font_id = try self.loadFont(category, size);

        var font_obj: ?*LoadedFont = null;
        for (self.loaded_fonts.items) |*font| {
            if (font.id == font_id) {
                font_obj = font;
                break;
            }
        }

        if (font_obj == null) return error.FontNotFound;

        const size_key = @as(u32, @intFromFloat(size * 100));
        const rasterizer = font_obj.?.rasterizers.get(size_key) orelse return error.RasterizerNotFound;

        if (self.layout_engine == null) {
            self.layout_engine = text_layout.TextLayoutEngine.init(self.allocator, &self.atlas, rasterizer);
        }

        const layout_options = text_layout.LayoutOptions{
            .alignment = .left,
            .baseline = .alphabetic,
        };

        const layout = try self.layout_engine.?.layoutText(text, font_id, @intFromFloat(size), layout_options);
        defer self.layout_engine.?.freeLayout(layout);

        if (layout.lines.len == 0) {
            return error.EmptyText;
        }

        const width = @as(u32, @intFromFloat(@ceil(layout.total_width)));
        const height = @as(u32, @intFromFloat(@ceil(layout.total_height)));

        if (width == 0 or height == 0) {
            return error.EmptyLayout;
        }

        var bitmap = try self.allocator.alloc(u8, width * height * 4);
        defer self.allocator.free(bitmap);
        @memset(bitmap, 0);

        for (layout.lines) |line| {
            for (line.glyphs) |glyph| {
                const glyph_info = try self.atlas.getOrRasterizeGlyph(rasterizer, glyph.codepoint, font_id, @intFromFloat(size));

                if (glyph_info.width == 0 or glyph_info.height == 0) continue;

                const glyph_x = @as(i32, @intFromFloat(@round(glyph.position.x)));
                const glyph_y = @as(i32, @intFromFloat(@round(glyph.position.y)));

                // Get the bitmap from the atlas cache instead of re-rasterizing
                const cached_bitmap = self.atlas.getCachedBitmap(glyph_info) orelse {
                    // Fallback: only rasterize if not in cache (shouldn't happen)
                    log.warn("Glyph not in cache, falling back to rasterization for codepoint {}", .{glyph.codepoint});
                    const rasterized = try rasterizer.rasterizeGlyph(glyph.codepoint, 0, 0);
                    defer rasterizer.allocator.free(rasterized.bitmap);

                    // Still use the rasterized data but log this shouldn't happen
                    var py: u32 = 0;
                    while (py < glyph_info.height) : (py += 1) {
                        var px: u32 = 0;
                        while (px < glyph_info.width) : (px += 1) {
                            const dst_x = glyph_x + @as(i32, @intCast(px));
                            const dst_y = glyph_y + @as(i32, @intCast(py));

                            if (dst_x >= 0 and dst_x < width and dst_y >= 0 and dst_y < height) {
                                const src_idx = py * glyph_info.width + px;
                                const dst_idx = (@as(usize, @intCast(dst_y)) * width + @as(usize, @intCast(dst_x))) * 4;

                                if (src_idx < rasterized.bitmap.len) {
                                    const alpha = rasterized.bitmap[src_idx];
                                    bitmap[dst_idx + 0] = color.r;
                                    bitmap[dst_idx + 1] = color.g;
                                    bitmap[dst_idx + 2] = color.b;
                                    bitmap[dst_idx + 3] = alpha;
                                }
                            }
                        }
                    }
                    continue;
                };

                // Use the cached bitmap directly
                var py: u32 = 0;
                while (py < glyph_info.height) : (py += 1) {
                    var px: u32 = 0;
                    while (px < glyph_info.width) : (px += 1) {
                        const dst_x = glyph_x + @as(i32, @intCast(px));
                        const dst_y = glyph_y + @as(i32, @intCast(py));

                        if (dst_x >= 0 and dst_x < width and dst_y >= 0 and dst_y < height) {
                            const src_idx = py * glyph_info.width + px;
                            const dst_idx = (@as(usize, @intCast(dst_y)) * width + @as(usize, @intCast(dst_x))) * 4;

                            if (src_idx < cached_bitmap.len) {
                                const alpha = cached_bitmap[src_idx];
                                bitmap[dst_idx + 0] = color.r;
                                bitmap[dst_idx + 1] = color.g;
                                bitmap[dst_idx + 2] = color.b;
                                bitmap[dst_idx + 3] = alpha;
                            }
                        }
                    }
                }
            }
        }

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

        const texture = c.sdl.SDL_CreateGPUTexture(self.gpu_device, &texture_info) orelse {
            return error.TextureCreationFailed;
        };

        const transfer_size = width * height * 4;
        const transfer_buffer_info = c.sdl.SDL_GPUTransferBufferCreateInfo{
            .usage = c.sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            .size = transfer_size,
        };

        const transfer_buffer = c.sdl.SDL_CreateGPUTransferBuffer(self.gpu_device, &transfer_buffer_info) orelse {
            c.sdl.SDL_ReleaseGPUTexture(self.gpu_device, texture);
            return error.TransferBufferCreationFailed;
        };
        defer c.sdl.SDL_ReleaseGPUTransferBuffer(self.gpu_device, transfer_buffer);

        const mapped_ptr = c.sdl.SDL_MapGPUTransferBuffer(self.gpu_device, transfer_buffer, false) orelse {
            c.sdl.SDL_ReleaseGPUTexture(self.gpu_device, texture);
            return error.TransferBufferMapFailed;
        };

        @memcpy(@as([*]u8, @ptrCast(mapped_ptr))[0..transfer_size], bitmap);
        c.sdl.SDL_UnmapGPUTransferBuffer(self.gpu_device, transfer_buffer);

        const cmd_buffer = c.sdl.SDL_AcquireGPUCommandBuffer(self.gpu_device) orelse {
            c.sdl.SDL_ReleaseGPUTexture(self.gpu_device, texture);
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

        return .{
            .texture = texture,
            .width = width,
            .height = height,
        };
    }
};
