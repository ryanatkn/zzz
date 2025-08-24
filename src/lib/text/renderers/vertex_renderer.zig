// Vertex-based text renderer - uses vertex strategy for high-quality text rendering
// Renders text using procedural vertex generation (2000+ vertices per glyph)

const std = @import("std");
const math = @import("../../math/mod.zig");
const colors = @import("../../core/colors.zig");
const font_manager = @import("../../font/manager.zig");
const glyph_vertices = @import("../../font/strategies/vertex/vertex_builder.zig");
const glyph_extractor = @import("../../font/core/glyph_extractor.zig");
const glyph_triangulator = @import("../../font/strategies/vertex/triangulator.zig");
const loggers = @import("../../debug/loggers.zig");

// Import GPU renderer type for direct glyph rendering
const GPURenderer = @import("../../rendering/core/gpu.zig").GPURenderer;
const c = @import("../../platform/sdl.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const FontManager = font_manager.FontManager;
const GlyphVertexBuilder = glyph_vertices.GlyphVertexBuilder;
const GlyphExtractor = glyph_extractor.GlyphExtractor;
const GlyphTriangulator = glyph_triangulator.GlyphTriangulator;

/// Vertex-based text renderer - uses vertex strategy for high-quality text rendering
pub const VertexTextRenderer = struct {
    allocator: std.mem.Allocator,
    font_manager: *FontManager,
    vertex_builder: GlyphVertexBuilder,
    glyph_extractor: GlyphExtractor,
    triangulator: GlyphTriangulator,

    pub fn init(allocator: std.mem.Allocator, font_mgr: *FontManager) VertexTextRenderer {
        return VertexTextRenderer{
            .allocator = allocator,
            .font_manager = font_mgr,
            .vertex_builder = GlyphVertexBuilder.init(allocator),
            .glyph_extractor = GlyphExtractor.init(allocator, undefined, 1.0), // Will set parser later
            .triangulator = GlyphTriangulator.init(allocator),
        };
    }

    pub fn deinit(self: *VertexTextRenderer) void {
        self.triangulator.deinit();
    }

    /// Render a single character at the specified position
    pub fn renderChar(
        self: *VertexTextRenderer,
        gpu_renderer: *GPURenderer,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        char: u8,
        font_id: u32,
        size: f32,
        pos: Vec2,
        color: Color,
    ) !void {
        const render_log = loggers.getRenderLog();
        render_log.info("render_char", "Rendering character '{c}' (codepoint: {}) with font_id: {}", .{ if (char > 31 and char < 127) char else '?', char, font_id });

        // Get the font parser for this font_id
        const parser = self.font_manager.getParser(font_id) orelse {
            render_log.warn("no_parser", "No parser found for font_id: {}, falling back to placeholder", .{font_id});
            // Fallback to simple quad
            const glyph_size = Vec2{ .x = size * 0.6, .y = size };
            gpu_renderer.drawGlyph(cmd_buffer, render_pass, pos, glyph_size, color);
            return;
        };

        // Set up extractor with the parser and appropriate scaling
        // Calculate proper scale based on font size and actual units_per_em
        const units_per_em = if (parser.head) |head| head.units_per_em else 1000;
        const scale = size / @as(f32, @floatFromInt(units_per_em)); // Font units to pixels
        var extractor = GlyphExtractor.init(self.allocator, parser, scale);

        // Extract glyph outline
        const glyph_outline = extractor.extractGlyph(char) catch |err| {
            render_log.warn("extract_failed", "Failed to extract glyph for '{c}': {}, using placeholder", .{ if (char > 31 and char < 127) char else '?', err });
            // Fallback to simple quad
            const glyph_size = Vec2{ .x = size * 0.6, .y = size };
            gpu_renderer.drawGlyph(cmd_buffer, render_pass, pos, glyph_size, color);
            return;
        };
        defer glyph_outline.deinit(self.allocator);

        render_log.info("glyph_extracted", "Extracted glyph with bounds: ({d}, {d}) to ({d}, {d})", .{ glyph_outline.bounds.x_min, glyph_outline.bounds.y_min, glyph_outline.bounds.x_max, glyph_outline.bounds.y_max });

        // Triangulate the glyph outline to get vertex data (with caching)
        var triangulated_glyph = self.triangulator.triangulateGlyph(char, font_id, size, glyph_outline) catch |err| {
            render_log.warn("triangulate_failed", "Failed to triangulate glyph: {}, using fallback quad", .{err});
            // Fallback to simple quad
            const glyph_size = Vec2{ .x = size * 0.6, .y = size };
            gpu_renderer.drawGlyph(cmd_buffer, render_pass, pos, glyph_size, color);
            return;
        };
        defer triangulated_glyph.deinit(self.allocator);

        render_log.info("glyph_triangulated", "Triangulated glyph '{c}' (code:{}) into {} vertices", .{ if (char > 31 and char < 127) char else '?', char, triangulated_glyph.vertex_count });

        // Handle empty glyphs (like space)
        if (triangulated_glyph.vertex_count == 0) {
            render_log.info("empty_glyph", "Empty glyph, skipping vertex rendering", .{});
            return;
        }

        render_log.info("calling_vertex_render", "Calling renderTriangulatedGlyph with {} vertices at pos ({d}, {d})", .{ triangulated_glyph.vertex_count, pos.x, pos.y });

        // DEBUG: Log first few vertices to verify coordinates
        if (triangulated_glyph.vertices.len > 0) {
            const v0 = triangulated_glyph.vertices[0];
            render_log.warn("vertex_coords_debug", "VERTEX DEBUG: First vertex: position=({d}, {d})", .{ v0.position[0], v0.position[1] });
            if (triangulated_glyph.vertices.len > 2) {
                const v2 = triangulated_glyph.vertices[2];
                render_log.warn("vertex_coords_debug", "VERTEX DEBUG: Third vertex: position=({d}, {d})", .{ v2.position[0], v2.position[1] });
            }
            render_log.warn("vertex_position_debug", "VERTEX DEBUG: Text position=({d}, {d}), glyph has {} vertices", .{ pos.x, pos.y, triangulated_glyph.vertex_count });
        }

        // Create vertex buffer and upload triangulated data
        try self.renderTriangulatedGlyph(gpu_renderer, cmd_buffer, render_pass, &triangulated_glyph, pos, color);
    }

    /// Render a triangulated glyph using vertex buffers
    fn renderTriangulatedGlyph(
        self: *VertexTextRenderer,
        gpu_renderer: *GPURenderer,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        triangulated_glyph: *const glyph_triangulator.TriangulatedGlyph,
        pos: Vec2,
        color: Color,
    ) !void {
        _ = self; // Suppress unused parameter warning
        const render_log = loggers.getRenderLog();

        // Create GPU vertex buffer
        const vertex_buffer_size: u32 = @intCast(triangulated_glyph.vertices.len * @sizeOf(glyph_triangulator.GlyphVertex));
        render_log.info("vertex_buffer_create", "Creating vertex buffer with {} vertices, size: {} bytes", .{ triangulated_glyph.vertex_count, vertex_buffer_size });

        const vertex_buffer_create_info = c.sdl.SDL_GPUBufferCreateInfo{
            .usage = c.sdl.SDL_GPU_BUFFERUSAGE_VERTEX,
            .size = vertex_buffer_size,
        };

        const vertex_buffer = c.sdl.SDL_CreateGPUBuffer(gpu_renderer.device, &vertex_buffer_create_info) orelse {
            render_log.err("vertex_buffer_create_fail", "Failed to create vertex buffer for glyph", .{});
            return error.BufferCreationFailed;
        };
        defer c.sdl.SDL_ReleaseGPUBuffer(gpu_renderer.device, vertex_buffer);

        render_log.info("vertex_buffer_created", "Successfully created vertex buffer", .{});

        // Create transfer buffer for uploading vertex data
        const transfer_buffer_create_info = c.sdl.SDL_GPUTransferBufferCreateInfo{
            .usage = c.sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            .size = vertex_buffer_size,
        };

        const transfer_buffer = c.sdl.SDL_CreateGPUTransferBuffer(gpu_renderer.device, &transfer_buffer_create_info) orelse {
            render_log.err("transfer_buffer_create_fail", "Failed to create transfer buffer", .{});
            return error.BufferCreationFailed;
        };
        defer c.sdl.SDL_ReleaseGPUTransferBuffer(gpu_renderer.device, transfer_buffer);

        // Map transfer buffer and copy vertex data
        const mapped_data = c.sdl.SDL_MapGPUTransferBuffer(gpu_renderer.device, transfer_buffer, false);
        if (mapped_data == null) {
            render_log.err("transfer_buffer_map_fail", "Failed to map transfer buffer", .{});
            return error.BufferMappingFailed;
        }

        // Copy vertex data to mapped buffer
        const vertex_data_ptr: [*]u8 = @ptrCast(triangulated_glyph.vertices.ptr);
        @memcpy(@as([*]u8, @ptrCast(mapped_data))[0..vertex_buffer_size], vertex_data_ptr[0..vertex_buffer_size]);

        c.sdl.SDL_UnmapGPUTransferBuffer(gpu_renderer.device, transfer_buffer);

        // Upload vertex data to GPU buffer
        const copy_pass = c.sdl.SDL_BeginGPUCopyPass(cmd_buffer) orelse {
            render_log.err("copy_pass_fail", "Failed to begin copy pass", .{});
            return error.CopyPassFailed;
        };

        const transfer_location = c.sdl.SDL_GPUTransferBufferLocation{
            .transfer_buffer = transfer_buffer,
            .offset = 0,
        };

        const buffer_region = c.sdl.SDL_GPUBufferRegion{
            .buffer = vertex_buffer,
            .offset = 0,
            .size = vertex_buffer_size,
        };

        c.sdl.SDL_UploadToGPUBuffer(copy_pass, &transfer_location, &buffer_region, false);
        c.sdl.SDL_EndGPUCopyPass(copy_pass);

        // Draw using the vertex buffer
        gpu_renderer.drawGlyphVertexBuffer(cmd_buffer, render_pass, vertex_buffer, triangulated_glyph.vertex_count, pos, color) catch |err| {
            render_log.err("vertex_glyph_draw_fail", "Failed to draw glyph vertex buffer: {}", .{err});
            return;
        };

        render_log.info("vertex_glyph_rendered", "Rendered glyph with {} triangulated vertices", .{triangulated_glyph.vertex_count});
    }

    /// Render a string at the specified position
    pub fn renderString(
        self: *VertexTextRenderer,
        gpu_renderer: *GPURenderer,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        text: []const u8,
        font_id: u32,
        size: f32,
        start_pos: Vec2,
        color: Color,
    ) !void {
        const render_log = loggers.getRenderLog();
        render_log.info("buffer_render", "Rendering string: '{s}' (font_id: {}, size: {d})", .{ text, font_id, size });

        var current_pos = start_pos;
        var prev_char: ?u8 = null;

        for (text) |char| {
            // Skip non-printable characters
            if (char < 32 or char > 126) {
                if (char == ' ') {
                    // Handle space by advancing position (typical advance width)
                    current_pos.x += size * 0.5; // Rough space width
                    prev_char = char;
                }
                continue;
            }

            // Apply kerning adjustment if we have a previous character
            if (prev_char) |prev| {
                if (prev >= 32 and prev <= 126) { // Only apply kerning between printable chars
                    const units_per_em = if (self.font_manager.getParser(font_id)) |parser|
                        if (parser.head) |head| @as(f32, @floatFromInt(head.units_per_em)) else 1000.0
                    else
                        1000.0;
                    const scale = size / units_per_em;
                    const kern_adjustment = self.font_manager.getKerning(font_id, prev, char, scale);
                    current_pos.x += kern_adjustment;
                }
            }

            // Render character
            try self.renderChar(gpu_renderer, cmd_buffer, render_pass, char, font_id, size, current_pos, color);

            // Get advance width for positioning from basic font metrics
            if (self.font_manager.getBasicGlyphMetrics(font_id, char)) |metrics| {
                const units_per_em = if (self.font_manager.getParser(font_id)) |parser|
                    if (parser.head) |head| @as(f32, @floatFromInt(head.units_per_em)) else 1000.0
                else
                    1000.0;
                const scale = size / units_per_em;
                current_pos.x += metrics.advance_width * scale;
            } else {
                // Fallback advance
                current_pos.x += size * 0.6; // Rough character width
            }

            prev_char = char;
        }
    }

    /// Batch render a string (add all glyphs to trace, then flush)
    pub fn batchRenderString(
        self: *VertexTextRenderer,
        gpu_renderer: *GPURenderer,
        text: []const u8,
        font_id: u32,
        size: f32,
        start_pos: Vec2,
        color: Color,
    ) !void {
        var current_pos = start_pos;
        var prev_char: ?u8 = null;

        // Add all glyphs to the batch
        for (text) |char| {
            // Skip non-printable characters
            if (char < 32 or char > 126) {
                if (char == ' ') {
                    // Handle space by advancing position
                    current_pos.x += size * 0.5; // Rough space width
                    prev_char = char;
                }
                continue;
            }

            // Apply kerning adjustment if we have a previous character
            if (prev_char) |prev| {
                if (prev >= 32 and prev <= 126) {
                    const units_per_em = if (self.font_manager.getParser(font_id)) |parser|
                        if (parser.head) |head| @as(f32, @floatFromInt(head.units_per_em)) else 1000.0
                    else
                        1000.0;
                    const scale = size / units_per_em;
                    const kern_adjustment = self.font_manager.getKerning(font_id, prev, char, scale);
                    current_pos.x += kern_adjustment;
                }
            }

            // Use simple procedural glyph size for batching
            const glyph_size = Vec2{ .x = size * 0.6, .y = size }; // Rough character proportions
            gpu_renderer.addGlyphToTrace(current_pos, glyph_size, color);

            // Get advance width for positioning from basic font metrics
            if (self.font_manager.getBasicGlyphMetrics(font_id, char)) |metrics| {
                const units_per_em = if (self.font_manager.getParser(font_id)) |parser|
                    if (parser.head) |head| @as(f32, @floatFromInt(head.units_per_em)) else 1000.0
                else
                    1000.0;
                const scale = size / units_per_em;
                current_pos.x += metrics.advance_width * scale;
            } else {
                current_pos.x += size * 0.6; // Fallback advance
            }

            prev_char = char;
        }
    }

    /// Calculate the width of a string in pixels
    pub fn getStringWidth(self: *VertexTextRenderer, text: []const u8, font_id: u32, size: f32) !f32 {
        var total_width: f32 = 0.0;
        var prev_char: ?u8 = null;

        for (text) |char| {
            if (char < 32 or char > 126) {
                if (char == ' ') {
                    total_width += size * 0.5; // Rough space width
                    prev_char = char;
                }
                continue;
            }

            // Apply kerning adjustment if we have a previous character
            if (prev_char) |prev| {
                if (prev >= 32 and prev <= 126) {
                    const units_per_em = if (self.font_manager.getParser(font_id)) |parser|
                        if (parser.head) |head| @as(f32, @floatFromInt(head.units_per_em)) else 1000.0
                    else
                        1000.0;
                    const scale = size / units_per_em;
                    const kern_adjustment = self.font_manager.getKerning(font_id, prev, char, scale);
                    total_width += kern_adjustment;
                }
            }

            // Get advance width from basic font metrics
            if (self.font_manager.getBasicGlyphMetrics(font_id, char)) |metrics| {
                const units_per_em = if (self.font_manager.getParser(font_id)) |parser|
                    if (parser.head) |head| @as(f32, @floatFromInt(head.units_per_em)) else 1000.0
                else
                    1000.0;
                const scale = size / units_per_em;
                total_width += metrics.advance_width * scale;
            } else {
                total_width += size * 0.6; // Fallback character width
            }

            prev_char = char;
        }

        return total_width;
    }

    /// Get the height of text for a given font
    pub fn getStringHeight(self: *VertexTextRenderer, font_id: u32, size: f32) !f32 {
        // For buffer-based rendering, height is simply the font size
        // TODO: Could get more accurate metrics from font parser if needed
        _ = self;
        _ = font_id;
        return size;
    }
};

// Tests
test "buffer text renderer basic functionality" {
    const testing = std.testing;

    // Create a mock font manager (would need actual implementation for full test)
    var font_mgr = try FontManager.init(testing.allocator);
    defer font_mgr.deinit();

    var renderer = VertexTextRenderer.init(testing.allocator, &font_mgr);
    defer renderer.deinit();

    // Test that renderer initializes correctly
    try testing.expect(renderer.allocator.ptr == testing.allocator.ptr);
}

test "string width calculation" {
    const testing = std.testing;

    // This test would need a proper font manager setup to work fully
    // For now, we just verify the structure compiles
    _ = testing;
}
