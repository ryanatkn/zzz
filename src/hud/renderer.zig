const std = @import("std");
const c = @import("../lib/c.zig");
const types = @import("../lib/types.zig");
const lib_renderer = @import("../lib/renderer.zig");
const game_renderer = @import("../hex/game_renderer.zig");
const page = @import("page.zig");
const font_config = @import("../lib/font/config.zig");
const text_renderer = @import("../lib/text/renderer.zig");
const menu_text = @import("../lib/ui/menu_text.zig");
const drawing = @import("../lib/drawing.zig");
const multi_text_renderer = @import("../lib/text/multi_renderer.zig");

const Color = types.Color;
const Vec2 = types.Vec2;

/// Configuration for font grid test rendering
const FontGridConfig = struct {
    test_text: []const u8 = "Ag123@",
    font_sizes: []const f32 = &[_]f32{ 8, 10, 12, 14, 16, 20, 24, 32, 48, 64, 72 },
    start_pos: Vec2 = Vec2{ .x = 150.0, .y = 120.0 },
    cell_spacing: Vec2 = Vec2{ .x = 10.0, .y = 10.0 },

    /// Create default configuration
    pub fn default() FontGridConfig {
        return FontGridConfig{};
    }

    /// Create configuration optimized for small screens
    pub fn compact() FontGridConfig {
        return FontGridConfig{
            .test_text = "Ag@",
            .font_sizes = &[_]f32{ 10, 12, 16, 20, 24, 32, 48 }, // Fewer sizes
            .start_pos = Vec2{ .x = 100.0, .y = 100.0 },
            .cell_spacing = Vec2{ .x = 5.0, .y = 5.0 }, // Tighter spacing
        };
    }

    /// Create configuration for detailed analysis
    pub fn detailed() FontGridConfig {
        return FontGridConfig{
            .test_text = "AaBbCc123@#",
            .font_sizes = &[_]f32{ 6, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 24, 28, 32, 36, 40, 48, 56, 64, 72 },
            .start_pos = Vec2{ .x = 50.0, .y = 80.0 },
            .cell_spacing = Vec2{ .x = 8.0, .y = 8.0 },
        };
    }
};

pub const BrowserRenderer = struct {
    base_renderer: *game_renderer.GameRenderer,

    // Font grid test renderer for special diagnostic page
    font_grid_renderer: ?multi_text_renderer.MultiTextRenderer,
    font_grid_config: FontGridConfig,

    pub fn init(base_renderer: *game_renderer.GameRenderer) BrowserRenderer {
        return .{
            .base_renderer = base_renderer,
            .font_grid_renderer = null,
            .font_grid_config = FontGridConfig.default(),
        };
    }

    pub fn initFonts(self: *BrowserRenderer, allocator: std.mem.Allocator) !void {
        _ = self;
        _ = allocator;
        const log = std.log.scoped(.browser_renderer);
        log.info("HUD using main game's FontManager and TextRenderer - no separate initialization needed", .{});
    }

    pub fn deinitFonts(self: *BrowserRenderer, allocator: std.mem.Allocator) void {
        _ = allocator;
        // Clean up font grid renderer if it exists
        self.cleanupFontGridRenderer();
        // No separate font manager or text renderer to clean up - using main game's
    }

    /// Clean up the font grid renderer and set it to null
    fn cleanupFontGridRenderer(self: *BrowserRenderer) void {
        if (self.font_grid_renderer) |*renderer| {
            renderer.deinit();
            self.font_grid_renderer = null;
        }
    }

    /// Clean up all resources (call this when destroying the BrowserRenderer)
    pub fn deinit(self: *BrowserRenderer) void {
        self.cleanupFontGridRenderer();
    }

    /// Update font grid configuration (useful for testing different setups)
    pub fn setFontGridConfig(self: *BrowserRenderer, config: FontGridConfig) void {
        self.font_grid_config = config;

        // Reset the renderer to force recreation with new config
        self.cleanupFontGridRenderer();
    }

    pub fn renderOverlay(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass) !void {

        // Render semi-transparent background using rectangles
        // Draw a dark overlay by rendering multiple dark rectangles
        const screen_width = 1920.0;
        const screen_height = 1080.0;
        const overlay_color = Color{ .r = 10, .g = 10, .b = 15, .a = 120 };

        // Use drawBlendedRect for transparent overlay
        self.base_renderer.gpu.drawBlendedRect(cmd_buffer, render_pass, .{ .x = 0, .y = 0 }, .{ .x = screen_width, .y = screen_height }, overlay_color);
    }

    pub fn renderPage(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, current_page: *const page.Page, links: *std.ArrayList(page.Link)) !void {
        // Check if this is the font-grid-test page and handle special rendering
        if (std.mem.eql(u8, current_page.path, "/font-grid-test")) {
            try self.renderFontGridTestPage(cmd_buffer, render_pass, current_page, links);
        } else {
            // Regular page rendering
            try current_page.render(links);
        }
    }

    fn renderFontGridTestPage(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, current_page: *const page.Page, links: *std.ArrayList(page.Link)) !void {
        // First, let the page render its basic UI elements (headers, navigation)
        try current_page.render(links);

        // Initialize the font grid renderer if not already done
        if (self.font_grid_renderer == null) {
            self.font_grid_renderer = multi_text_renderer.MultiTextRenderer.init(self.base_renderer.allocator, self.base_renderer.gpu.device, &self.base_renderer.gpu.text_renderer, self.base_renderer.font_manager);

            // Create the comparison grid using configuration
            try self.font_grid_renderer.?.createComparisonGrid(
                self.font_grid_config.test_text,
                self.font_grid_config.font_sizes,
                self.font_grid_config.start_pos,
                self.font_grid_config.cell_spacing,
            );
        }

        // Render the comparison grid
        try self.font_grid_renderer.?.renderGrid(render_pass);

        // Render quality indicators
        try self.font_grid_renderer.?.renderQualityIndicators(render_pass);

        _ = cmd_buffer;
    }

    pub fn renderLinks(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, links: []const page.Link, hovered_link: ?usize) !void {
        for (links, 0..) |link, i| {
            const is_hovered = if (hovered_link) |h| h == i else false;

            // Render link background as rectangle
            const link_color = if (is_hovered)
                Color{ .r = 60, .g = 80, .b = 120, .a = 255 }
            else
                Color{ .r = 40, .g = 50, .b = 80, .a = 255 };

            self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, link.bounds.position, link.bounds.size, link_color);

            // Render the link text using menu text renderer directly
            const link_rect = drawing.Rectangle{
                .position = link.bounds.position,
                .size = link.bounds.size,
            };
            var menu_renderer = menu_text.MenuTextRenderer.init(&self.base_renderer.gpu.text_renderer, self.base_renderer.font_manager);
            menu_renderer.queueButtonText(link.text, link_rect, is_hovered);
        }
    }

    pub fn renderNavigationBar(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, current_path: []const u8, can_go_back: bool, can_go_forward: bool) !void {
        const screen_width = 1920.0;
        const screen_height = 1080.0;

        const bar_height = 50.0;
        const bar_y = screen_height * 0.1 - bar_height / 2.0;
        const bar_width = screen_width * 0.8;
        const bar_x = (screen_width - bar_width) / 2.0;

        // Navigation bar background
        self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, .{ .x = bar_x, .y = bar_y }, .{ .x = bar_width, .y = bar_height }, Color{ .r = 20, .g = 25, .b = 35, .a = 255 });

        // Back button
        const button_size = 40.0;
        const button_margin = 5.0;
        const back_color = if (can_go_back)
            Color{ .r = 60, .g = 70, .b = 90, .a = 255 }
        else
            Color{ .r = 30, .g = 35, .b = 45, .a = 128 };

        self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, .{ .x = bar_x + button_margin, .y = bar_y + button_margin }, .{ .x = button_size, .y = button_size }, back_color);

        // Draw back arrow indicator
        if (can_go_back) {
            self.drawArrow(cmd_buffer, render_pass, bar_x + button_margin + button_size / 2.0, bar_y + button_margin + button_size / 2.0, 10.0, .Left, Color{ .r = 200, .g = 200, .b = 220, .a = 255 });
        }

        // Forward button
        const forward_color = if (can_go_forward)
            Color{ .r = 60, .g = 70, .b = 90, .a = 255 }
        else
            Color{ .r = 30, .g = 35, .b = 45, .a = 128 };

        self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, .{ .x = bar_x + button_margin * 2 + button_size, .y = bar_y + button_margin }, .{ .x = button_size, .y = button_size }, forward_color);

        // Draw forward arrow indicator
        if (can_go_forward) {
            self.drawArrow(cmd_buffer, render_pass, bar_x + button_margin * 2 + button_size + button_size / 2.0, bar_y + button_margin + button_size / 2.0, 10.0, .Right, Color{ .r = 200, .g = 200, .b = 220, .a = 255 });
        }

        // Address bar background
        const address_x = bar_x + button_margin * 3 + button_size * 2;
        const address_width = bar_width - (button_margin * 4 + button_size * 2);

        self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, .{ .x = address_x, .y = bar_y + button_margin }, .{ .x = address_width, .y = button_size }, Color{ .r = 15, .g = 18, .b = 25, .a = 255 });

        // Address bar border (to make it look like an input field)
        self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, .{ .x = address_x, .y = bar_y + button_margin }, .{ .x = address_width, .y = 2 }, Color{ .r = 40, .g = 45, .b = 55, .a = 255 });
        self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, .{ .x = address_x, .y = bar_y + button_margin + button_size - 2 }, .{ .x = address_width, .y = 2 }, Color{ .r = 40, .g = 45, .b = 55, .a = 255 });

        // Queue the path text for rendering using shared utility with main game renderers
        var menu_text_renderer = menu_text.MenuTextRenderer.init(&self.base_renderer.gpu.text_renderer, self.base_renderer.font_manager);
        menu_text_renderer.queueNavigationText(current_path, .{ .x = address_x + 10, .y = bar_y + button_margin + 15 });
    }

    const ArrowDirection = enum { Left, Right };

    fn drawArrow(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, x: f32, y: f32, size: f32, direction: ArrowDirection, color: Color) void {
        // Draw simple arrow using rectangles
        const thickness = 2.0;

        switch (direction) {
            .Left => {
                // Draw <
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, .{ .x = x - size / 2, .y = y }, .{ .x = size, .y = thickness }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, .{ .x = x - size / 2, .y = y - thickness }, .{ .x = thickness, .y = size / 2 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, .{ .x = x - size / 2, .y = y + thickness }, .{ .x = thickness, .y = size / 2 }, color);
            },
            .Right => {
                // Draw >
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, .{ .x = x - size / 2, .y = y }, .{ .x = size, .y = thickness }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, .{ .x = x + size / 2 - thickness, .y = y - thickness }, .{ .x = thickness, .y = size / 2 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, .{ .x = x + size / 2 - thickness, .y = y + thickness }, .{ .x = thickness, .y = size / 2 }, color);
            },
        }
    }
};
