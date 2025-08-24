// Strategy-based Text Renderer - coordinates high-level text rendering with automatic strategy selection
// Uses vertex, bitmap, or SDF strategies based on font size and requirements

const std = @import("std");
const c = @import("../platform/sdl.zig");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const font_manager = @import("../font/manager.zig");
const vertex_renderer = @import("renderers/vertex_renderer.zig");
const texture_renderer = @import("renderers/texture_renderer.zig");
const strategy_interface = @import("../font/strategies/interface.zig");
const font_config = @import("../font/config.zig");
const loggers = @import("../debug/loggers.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const FontManager = font_manager.FontManager;
const VertexTextRenderer = vertex_renderer.VertexTextRenderer;
const TextureTextRenderer = texture_renderer.TextureTextRenderer;
const RenderingStrategy = strategy_interface.RenderingStrategy;

/// High-level strategy-based text renderer
/// Automatically selects the best rendering strategy based on font size and requirements
pub const TextRenderer = struct {
    allocator: std.mem.Allocator,
    font_manager: *FontManager,
    vertex_renderer: VertexTextRenderer,
    texture_renderer: TextureTextRenderer,

    /// Override strategy selection (null = automatic)
    strategy_override: ?RenderingStrategy,

    pub fn init(allocator: std.mem.Allocator, font_mgr: *FontManager) TextRenderer {
        return TextRenderer{
            .allocator = allocator,
            .font_manager = font_mgr,
            .vertex_renderer = VertexTextRenderer.init(allocator, font_mgr),
            .texture_renderer = TextureTextRenderer.init(allocator, font_mgr),
            .strategy_override = null,
        };
    }

    pub fn deinit(self: *TextRenderer, gpu_device: ?*c.sdl.SDL_GPUDevice) void {
        self.vertex_renderer.deinit();
        self.texture_renderer.deinit(gpu_device);
    }

    /// Override automatic strategy selection
    pub fn setStrategyOverride(self: *TextRenderer, strategy: ?RenderingStrategy) void {
        self.strategy_override = strategy;
        if (strategy) |s| {
            self.texture_renderer.setStrategy(s);
        }
    }

    /// Render text immediately at the given position using automatic strategy selection
    pub fn renderText(
        self: *TextRenderer,
        gpu_renderer: anytype,
        cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
        render_pass: *c.sdl.SDL_GPURenderPass,
        text: []const u8,
        position: Vec2,
        font_category: font_config.FontCategory,
        font_size: f32,
        color: Color,
    ) !void {
        const font_id = try self.font_manager.loadFont(font_category, font_size);

        // Select strategy (override or automatic)
        const strategy = self.strategy_override orelse self.font_manager.selectRenderingStrategy(font_size, .ui);

        // Route to appropriate renderer
        switch (strategy) {
            .vertex => {
                try self.vertex_renderer.renderString(
                    gpu_renderer,
                    cmd_buffer,
                    render_pass,
                    text,
                    font_id,
                    font_size,
                    position,
                    color,
                );
            },
            .bitmap, .sdf => {
                _ = try self.texture_renderer.renderText(
                    gpu_renderer,
                    cmd_buffer,
                    render_pass,
                    text,
                    position,
                    font_size,
                    color,
                );
            },
        }
    }

    /// Batch render text (add to GPU batch, then flush all at once)
    pub fn batchRenderText(
        self: *TextRenderer,
        gpu_renderer: anytype,
        text: []const u8,
        position: Vec2,
        font_category: font_config.FontCategory,
        font_size: f32,
        color: Color,
    ) !void {
        const font_id = try self.font_manager.loadFont(font_category, font_size);

        // Select strategy (override or automatic)
        const strategy = self.strategy_override orelse self.font_manager.selectRenderingStrategy(font_size, .ui);

        // Route to appropriate renderer
        switch (strategy) {
            .vertex => {
                try self.vertex_renderer.batchRenderString(
                    gpu_renderer,
                    text,
                    font_id,
                    font_size,
                    position,
                    color,
                );
            },
            .bitmap, .sdf => {
                // TODO: Implement batch rendering for texture renderer
                _ = try self.texture_renderer.renderText(
                    gpu_renderer,
                    text,
                    position,
                    font_size,
                    color,
                );
            },
        }
    }

    /// Calculate text dimensions for layout purposes
    pub fn measureText(
        self: *TextRenderer,
        text: []const u8,
        font_category: font_config.FontCategory,
        font_size: f32,
    ) !Vec2 {
        const font_id = try self.font_manager.loadFont(font_category, font_size);

        const width = try self.vertex_renderer.getStringWidth(text, font_id, font_size);
        const height = try self.vertex_renderer.getStringHeight(font_id, font_size);

        return Vec2{ .x = width, .y = height };
    }

    /// Check if text fits within given dimensions
    pub fn textFits(
        self: *TextRenderer,
        text: []const u8,
        max_size: Vec2,
        font_category: font_config.FontCategory,
        font_size: f32,
    ) !bool {
        const text_size = try self.measureText(text, font_category, font_size);
        return text_size.x <= max_size.x and text_size.y <= max_size.y;
    }
};

// Tests
test "buffer text renderer basic functionality" {
    const testing = std.testing;

    var font_mgr = try FontManager.init(testing.allocator);
    defer font_mgr.deinit();

    var text_renderer = TextRenderer.init(testing.allocator, &font_mgr);
    defer text_renderer.deinit(null);

    // Test that renderer initializes correctly
    try testing.expect(text_renderer.allocator.ptr == testing.allocator.ptr);
}
