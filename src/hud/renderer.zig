const std = @import("std");
const c = @import("../lib/platform/sdl.zig");
const math = @import("../lib/math/mod.zig");
const colors = @import("../lib/core/colors.zig");
const lib_renderer = @import("../lib/rendering/interface.zig");
const game_renderer = @import("../hex/game_renderer.zig");
const page = @import("page.zig");
const font_config = @import("../lib/font/config.zig");
const text_renderer = @import("../lib/text/renderer.zig");
const menu_text = @import("../lib/ui/menu_text.zig");
const drawing = @import("../lib/rendering/drawing.zig");
const font_grid_test_page = @import("../menu/font_grid_test/+page.zig");
const ide_page = @import("../menu/ide/+page.zig");
const ide_constants = @import("../menu/ide/constants.zig");
const directory_scanner = @import("../lib/platform/directory_scanner.zig");
const syntax_highlighter = @import("../menu/ide/syntax_highlighter.zig");
const bitmap_simple = @import("../lib/font/renderers/bitmap_simple.zig");
const text_alignment = @import("../lib/text/alignment.zig");

// Throttled logging to prevent spam
const Logger = @import("../lib/debug/logger.zig").Logger;
const outputs = @import("../lib/debug/outputs.zig");
const filters = @import("../lib/debug/filters.zig");

const Color = colors.Color;
const Vec2 = math.Vec2;

// Configure throttled logger for rendering (compile-time)
const ThrottledLogger = Logger(.{
    .output = outputs.Console,
    .filter = filters.Throttle,
});

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

    // Font grid test configuration
    font_grid_config: FontGridConfig,

    pub fn init(base_renderer: *game_renderer.GameRenderer) BrowserRenderer {
        return .{
            .base_renderer = base_renderer,
            .font_grid_config = FontGridConfig.default(),
        };
    }

    pub fn initFonts(self: *BrowserRenderer, allocator: std.mem.Allocator) !void {
        _ = self;
        _ = allocator;
        const log = std.log.scoped(.browser_renderer);
        log.info("HUD using main game's FontManager and TextRenderer - no separate initialization needed", .{});
    }

    pub fn deinitFonts(_: *BrowserRenderer, _: std.mem.Allocator) void {
        // No separate font manager or text renderer to clean up - using main game's
    }

    /// Clean up all resources (call this when destroying the BrowserRenderer)
    pub fn deinit(_: *BrowserRenderer) void {
        // No cleanup needed - using shared resources
    }

    /// Update font grid configuration (useful for testing different setups)
    pub fn setFontGridConfig(self: *BrowserRenderer, config: FontGridConfig) void {
        self.font_grid_config = config;
    }

    /// Get current screen dimensions from the GPU renderer
    pub fn getScreenSize(self: *const BrowserRenderer) Vec2 {
        return Vec2{
            .x = self.base_renderer.gpu.screen_width,
            .y = self.base_renderer.gpu.screen_height,
        };
    }

    pub fn renderOverlay(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass) !void {

        // Render semi-transparent background using rectangles
        // Draw a dark overlay by rendering multiple dark rectangles
        const screen_size = self.getScreenSize();
        const overlay_color = Color{ .r = 10, .g = 10, .b = 15, .a = 120 };

        // Use drawBlendedRect for transparent overlay
        self.base_renderer.gpu.drawBlendedRect(cmd_buffer, render_pass, .{ .x = 0, .y = 0 }, screen_size, overlay_color);
    }

    /// Render custom GPU content for pages that need direct rendering
    /// This is called from the reactive HUD system after normal page rendering
    pub fn renderPageContent(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, current_page: *const page.Page) !void {
        // Fast path for special pages needing GPU rendering
        if (std.mem.eql(u8, current_page.path, "/font-grid-test")) {
            // Font grid test page - custom GPU rendering
            try self.renderFontGridTestContent(cmd_buffer, render_pass, current_page);
        } else if (std.mem.eql(u8, current_page.path, "/ide")) {
            // IDE page - dashboard rendering
            try self.renderIDEDashboard(cmd_buffer, render_pass, current_page);
        }
        // Add other special pages here as needed
    }

    /// Render font grid test custom content (separated from link rendering)
    fn renderFontGridTestContent(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, current_page: *const page.Page) !void {
        // Cast to FontGridTestPage to access font test functionality
        const grid_page: *font_grid_test_page.FontGridTestPage = @constCast(@fieldParentPtr("base", current_page));

        // Check font grid test auto-initialization status
        if (!grid_page.initialized) {
            // Auto-initialize font grid test
            // autoInitialize removed - using simplified font test page
        } else {
            // Font grid test already initialized
        }

        // Render strategy comparison grid using actual GPU textures
        try self.renderStrategyComparison(cmd_buffer, render_pass, grid_page);
    }

    fn renderFontGridTestPage(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, current_page: *const page.Page, links: *std.ArrayList(page.Link)) !void {
        // First, let the page render its basic UI elements (headers, navigation)
        try current_page.render(links);

        // Cast to FontGridTestPage to access new functionality
        const grid_page: *font_grid_test_page.FontGridTestPage = @fieldParentPtr("base", current_page);

        // Check auto-initialization status
        if (!grid_page.initialized) {
            // Auto-initialize if needed
            // autoInitialize removed - using simplified font test page
        } else {
            // Grid page already initialized
        }

        // Render strategy comparison grid using actual GPU textures
        try self.renderStrategyComparison(cmd_buffer, render_pass, grid_page);
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
            
            // Use left alignment for filesystem buttons (IDE file/directory listings)
            const is_filesystem_link = std.mem.startsWith(u8, link.path, "/ide?");
            if (is_filesystem_link) {
                menu_renderer.queueAlignedButtonText(link.text, link_rect, is_hovered, .left);
            } else {
                menu_renderer.queueButtonText(link.text, link_rect, is_hovered);
            }
        }
    }

    pub fn renderNavigationBar(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, current_path: []const u8, can_go_back: bool, can_go_forward: bool) !void {
        const constants = @import("../lib/core/constants.zig");
        const screen_width = constants.SCREEN.BASE_WIDTH;
        const screen_height = constants.SCREEN.BASE_HEIGHT;

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

    /// Font grid rendering stub - simplified for core functionality
    fn renderStrategyComparison(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, grid_page: *const font_grid_test_page.FontGridTestPage) !void {
        _ = self;
        _ = cmd_buffer;
        _ = render_pass;
        _ = grid_page;
        // No-op: Font grid functionality not implemented
    }
    
    /// Render IDE dashboard with modern file explorer layout
    fn renderIDEDashboard(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, current_page: *const page.Page) !void {
        const ide_page_impl: *const ide_page.IDEPage = @fieldParentPtr("base", current_page);
        
        if (!ide_page_impl.initialized) {
            return;
        }
        
        const screen_size = self.getScreenSize();
        
        // Dashboard layout - optimized for 2560x1440+ displays
        const header_height = ide_constants.LAYOUT.HEADER_HEIGHT;
        const panel_gap = ide_constants.LAYOUT.PANEL_GAP;
        const explorer_width = ide_constants.LAYOUT.EXPLORER_WIDTH;
        const max_content_width = ide_constants.LAYOUT.MAX_CONTENT_WIDTH;
        const preview_width = ide_constants.LAYOUT.PREVIEW_WIDTH;
        
        // Calculate actual content width based on screen size
        const available_width = screen_size.x - explorer_width - preview_width - (panel_gap * 4);
        const content_width = @min(max_content_width, available_width);
        
        // Header panel
        const header_rect = math.Rectangle{
            .position = Vec2{ .x = 0, .y = 0 },
            .size = Vec2{ .x = screen_size.x, .y = header_height },
        };
        self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, header_rect.position, header_rect.size, ide_constants.COLORS.HEADER_BG);
        
        // File explorer panel (left)
        const explorer_rect = math.Rectangle{
            .position = Vec2{ .x = panel_gap, .y = header_height + panel_gap },
            .size = Vec2{ .x = explorer_width, .y = screen_size.y - header_height - (panel_gap * 2) },
        };
        
        drawing.drawBorderedRect(
            &self.base_renderer.gpu,
            cmd_buffer,
            render_pass,
            explorer_rect.position,
            explorer_rect.size,
            ide_constants.COLORS.PANEL_BG,
            ide_constants.COLORS.PANEL_BORDER,
            1.0
        );
        
        // Main content panel (center, constrained width)
        const content_x = explorer_width + (panel_gap * 2);
        const content_rect = math.Rectangle{
            .position = Vec2{ .x = content_x, .y = header_height + panel_gap },
            .size = Vec2{ .x = content_width, .y = screen_size.y - header_height - (panel_gap * 2) },
        };
        
        drawing.drawBorderedRect(
            &self.base_renderer.gpu,
            cmd_buffer,
            render_pass,
            content_rect.position,
            content_rect.size,
            ide_constants.COLORS.PANEL_BG,
            ide_constants.COLORS.PANEL_BORDER,
            1.0
        );
        
        // Preview panel (right)
        const preview_x = content_x + content_width + panel_gap;
        const preview_rect = math.Rectangle{
            .position = Vec2{ .x = preview_x, .y = header_height + panel_gap },
            .size = Vec2{ .x = preview_width, .y = screen_size.y - header_height - (panel_gap * 2) },
        };
        
        drawing.drawBorderedRect(
            &self.base_renderer.gpu,
            cmd_buffer,
            render_pass,
            preview_rect.position,
            preview_rect.size,
            ide_constants.COLORS.PANEL_BG,
            ide_constants.COLORS.PANEL_BORDER,
            1.0
        );
        
        // Render the actual panel content
        try self.renderFileTree(cmd_buffer, render_pass, ide_page_impl, explorer_rect);
        try self.renderContentArea(cmd_buffer, render_pass, ide_page_impl, content_rect);
        try self.renderPreviewPanel(cmd_buffer, render_pass, ide_page_impl, preview_rect);
        
        // Draw resolution info in header
        var resolution_buf: [64]u8 = undefined;
        const resolution_text = std.fmt.bufPrint(&resolution_buf, "Resolution: {d}x{d}", .{ @as(u32, @intFromFloat(screen_size.x)), @as(u32, @intFromFloat(screen_size.y)) }) catch "Resolution: Unknown";
        self.drawSimpleText(cmd_buffer, render_pass, resolution_text,
            Vec2{ .x = screen_size.x - 200, .y = 15 });
    }
    
    /// Render file tree in explorer panel using Link system
    fn renderFileTree(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, ide_page_impl: *const ide_page.IDEPage, panel_rect: math.Rectangle) !void {
        
        // Panel header - queue for rendering
        self.queueTextForRender(cmd_buffer, render_pass, "FILE EXPLORER", 
            Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 10 },
            ide_constants.COLORS.TEXT_NORMAL);
        
        // Check for loading or error states
        if (ide_page_impl.loading) {
            self.queueTextForRender(cmd_buffer, render_pass, "Loading...", 
                Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 40 },
                ide_constants.COLORS.TEXT_NORMAL);
            return;
        }
        
        if (ide_page_impl.error_message) |error_msg| {
            self.queueTextForRender(cmd_buffer, render_pass, "Error:", 
                Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 40 },
                ide_constants.COLORS.TEXT_NORMAL);
            self.queueTextForRender(cmd_buffer, render_pass, error_msg, 
                Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 60 },
                ide_constants.COLORS.TEXT_NORMAL);
            return;
        }
        
        // Create Links for file tree items (handled by HUD link system)
        // This is much simpler and leverages the working button/link system
        // Links will be added by the IDE page's render function
    }
    
    /// Render content area
    fn renderContentArea(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, ide_page_impl: *const ide_page.IDEPage, panel_rect: math.Rectangle) !void {
        // Panel header
        if (ide_page_impl.file_tree_component.getSelectedEntry()) |selected| {
            // Show file name in header
            var header_buf: [256]u8 = undefined;
            const header_text = std.fmt.bufPrint(&header_buf, "FILE: {s}", .{selected.metadata.name}) catch "FILE: <name too long>";
            self.queueTextForRender(cmd_buffer, render_pass, header_text,
                Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 10 }, ide_constants.COLORS.TEXT_NORMAL);
        } else {
            self.queueTextForRender(cmd_buffer, render_pass, "CONTENT EDITOR (~800px max)", 
                Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 10 }, ide_constants.COLORS.TEXT_NORMAL);
        }
        
        // Display file content or error
        if (ide_page_impl.current_file_error) |error_msg| {
            // Show error message
            self.queueTextForRender(cmd_buffer, render_pass, "Error:", 
                Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 40 }, ide_constants.COLORS.TEXT_NORMAL);
            self.queueTextForRender(cmd_buffer, render_pass, error_msg, 
                Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 60 }, ide_constants.COLORS.TEXT_NORMAL);
        } else if (ide_page_impl.current_file_content) |content| {
            // Show file content line by line
            try self.renderFileContentWithHighlighting(cmd_buffer, render_pass, content, panel_rect, ide_page_impl);
        } else {
            // No file selected
            self.queueTextForRender(cmd_buffer, render_pass, "Select a file to view its contents", 
                Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 40 }, ide_constants.COLORS.TEXT_NORMAL);
        }
    }
    
    /// Render preview panel  
    fn renderPreviewPanel(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, ide_page_impl: *const ide_page.IDEPage, panel_rect: math.Rectangle) !void {
        // Panel header
        self.drawSimpleText(cmd_buffer, render_pass, "PREVIEW PANEL", 
            Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 10 });
            
        // Show selected file info
        if (ide_page_impl.file_tree_component.getSelectedEntry()) |selected| {
            self.drawSimpleText(cmd_buffer, render_pass, "Selected:", 
                Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 40 });
            self.drawSimpleText(cmd_buffer, render_pass, selected.metadata.name, 
                Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 60 });
                
            const file_type_name = selected.metadata.file_type.getDisplayName();
            self.drawSimpleText(cmd_buffer, render_pass, file_type_name, 
                Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 80 });
                
            // Show file size
            var size_buf: [32]u8 = undefined;
            const size_text = directory_scanner.formatFileSize(selected.metadata.size, &size_buf) catch "Unknown size";
            self.drawSimpleText(cmd_buffer, render_pass, size_text, 
                Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 100 });
        } else {
            self.drawSimpleText(cmd_buffer, render_pass, "No file selected", 
                Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 40 });
        }
    }
    
    /// Draw file type icon
    fn drawFileIcon(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, icon: @import("../lib/ui/file_tree.zig").FileIcon, position: Vec2) !void {
        const icon_color = icon.getColor();
        const icon_size = ide_constants.FILE_TREE.ICON_SIZE;
        
        switch (icon) {
            .folder_closed, .folder_open => {
                // Draw folder icon - rectangle with slight indent at top
                self.base_renderer.gpu.drawRect(
                    cmd_buffer,
                    render_pass,
                    Vec2{ .x = position.x, .y = position.y + 2 },
                    Vec2{ .x = icon_size, .y = icon_size - 2 },
                    icon_color
                );
                // Draw folder tab
                self.base_renderer.gpu.drawRect(
                    cmd_buffer,
                    render_pass,
                    position,
                    Vec2{ .x = icon_size - 3, .y = 3 },
                    icon_color
                );
            },
            else => {
                // Draw file icon - simple rectangle
                self.base_renderer.gpu.drawRect(
                    cmd_buffer,
                    render_pass,
                    position,
                    Vec2{ .x = icon_size, .y = icon_size },
                    icon_color
                );
            }
        }
    }
    
    /// Render file content with syntax highlighting support
    fn renderFileContentWithHighlighting(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, content: []const u8, panel_rect: math.Rectangle, ide_page_impl: *const ide_page.IDEPage) !void {
        _ = cmd_buffer;
        _ = render_pass;
        const line_height = ide_constants.TEXT.LINE_HEIGHT;
        const char_width = ide_constants.TEXT.CHAR_WIDTH;
        const start_y = panel_rect.position.y + 40; // Below header
        const max_lines = @as(u32, @intFromFloat((panel_rect.size.y - 50) / line_height)); // Available space for content
        const max_chars_per_line = @as(u32, @intFromFloat((panel_rect.size.x - 20) / char_width)); // Characters that fit
        
        // Check if syntax highlighting should be enabled
        const enable_highlighting = ide_constants.SYNTAX.ENABLE_HIGHLIGHTING and ide_page_impl.*.shouldHighlightCurrentFile();
        
        var line_num: u32 = 0;
        var lines = std.mem.splitScalar(u8, content, '\n');
        
        while (lines.next()) |line| {
            if (line_num >= max_lines) break;
            
            const y_pos = start_y + @as(f32, @floatFromInt(line_num)) * line_height;
            
            // Truncate long lines to fit in panel
            const display_line = if (line.len > max_chars_per_line) 
                line[0..max_chars_per_line] 
            else 
                line;
            
            // Draw line number
            var line_num_buf: [8]u8 = undefined;
            const line_num_text = std.fmt.bufPrint(&line_num_buf, "{d}:", .{line_num + 1}) catch "?:";
            
            // Line numbers in darker color
            self.drawTextWithColor(line_num_text, 
                Vec2{ .x = panel_rect.position.x + 10, .y = y_pos }, ide_constants.COLORS.TEXT_LINE_NUMBERS);
            
            // Render line content with or without syntax highlighting
            const line_start_x = panel_rect.position.x + ide_constants.TEXT.LINE_NUMBER_OFFSET;
            if (enable_highlighting and display_line.len <= ide_constants.SYNTAX.MAX_HIGHLIGHT_LINE_LENGTH) {
                try self.renderLineWithHighlighting(display_line, Vec2{ .x = line_start_x, .y = y_pos }, ide_page_impl);
            } else {
                // Fallback to normal rendering
                self.drawTextWithColor(display_line, Vec2{ .x = line_start_x, .y = y_pos }, ide_constants.COLORS.TEXT_NORMAL);
            }
            
            line_num += 1;
        }
        
        // Show truncation message if content is too long
        if (line_num >= max_lines) {
            const truncate_msg = "... (file truncated for display)";
            self.drawTextWithColor(truncate_msg,
                Vec2{ .x = panel_rect.position.x + 10, .y = start_y + @as(f32, @floatFromInt(max_lines)) * line_height },
                ide_constants.COLORS.TEXT_TRUNCATION);
        }
    }
    
    /// Render a single line with syntax highlighting
    fn renderLineWithHighlighting(self: *BrowserRenderer, line: []const u8, position: Vec2, ide_page_impl: *const ide_page.IDEPage) !void {
        // Get mutable access to the syntax highlighter
        const ide_page_mut = @constCast(ide_page_impl);
        var highlighter = ide_page_mut.*.getSyntaxHighlighter();
        
        // Highlight the line
        const tokens = highlighter.highlightLine(line) catch {
            // Fallback to normal rendering on error
            self.drawTextWithColor(line, position, ide_constants.COLORS.TEXT_NORMAL);
            return;
        };
        defer highlighter.freeTokens(tokens);
        
        // Render each token with its appropriate color
        var current_x = position.x;
        const char_width = ide_constants.TEXT.CHAR_WIDTH;
        
        var last_pos: u32 = 0;
        for (tokens) |token| {
            // Render any gap between tokens as normal text
            if (token.start_pos > last_pos) {
                const gap_text = line[last_pos..token.start_pos];
                if (gap_text.len > 0) {
                    self.drawTextWithColor(gap_text, Vec2{ .x = current_x, .y = position.y }, ide_constants.COLORS.TEXT_NORMAL);
                    current_x += @as(f32, @floatFromInt(gap_text.len)) * char_width;
                }
            }
            
            // Render the token with its color
            if (token.text.len > 0) {
                self.drawTextWithColor(token.text, Vec2{ .x = current_x, .y = position.y }, token.token_type.getColor());
                current_x += @as(f32, @floatFromInt(token.text.len)) * char_width;
            }
            
            last_pos = token.end_pos;
        }
        
        // Render any remaining text at the end
        if (last_pos < line.len) {
            const remaining_text = line[last_pos..];
            if (remaining_text.len > 0) {
                self.drawTextWithColor(remaining_text, Vec2{ .x = current_x, .y = position.y }, ide_constants.COLORS.TEXT_NORMAL);
            }
        }
    }

    /// Draw simple text using proper font rendering
    fn drawSimpleText(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, text: []const u8, position: Vec2) void {
        _ = cmd_buffer;
        _ = render_pass;
        const text_color = Color{ .r = 200, .g = 200, .b = 200, .a = 255 };
        self.drawTextWithColor(text, position, text_color);
    }
    
    /// Draw text with specified color using MenuTextRenderer (16pt font for compatibility)
    fn drawTextWithColor(self: *BrowserRenderer, text: []const u8, position: Vec2, text_color: Color) void {
        // Skip rendering empty or whitespace-only text to avoid texture creation failures
        if (text.len == 0 or std.mem.trim(u8, text, " \t\r\n").len == 0) {
            return;
        }
        
        // Use the same approach as working buttons - 16pt font renders reliably
        var menu_renderer = menu_text.MenuTextRenderer.init(&self.base_renderer.gpu.text_renderer, self.base_renderer.font_manager);
        menu_renderer.queueCustomText(text, position, ide_constants.TEXT.CONTENT_FONT_SIZE, text_color);
    }
    
    /// Queue text using the proper persistent text system (like working buttons)
    fn queueTextForRender(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, text: []const u8, position: Vec2, text_color: Color) void {
        self.queueAlignedTextForRender(cmd_buffer, render_pass, text, position, text_color, .left);
    }

    /// Queue text for rendering with specified alignment
    fn queueAlignedTextForRender(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, text: []const u8, position: Vec2, text_color: Color, alignment: text_alignment.TextAlign) void {
        _ = cmd_buffer;
        _ = render_pass;
        
        // Skip rendering empty or whitespace-only text to avoid texture creation failures
        if (text.len == 0 or std.mem.trim(u8, text, " \t\r\n").len == 0) {
            return;
        }
        
        const font_size = 16.0; // Use 16pt font size (proven to work)
        
        // Calculate text width for alignment (rough estimation)
        const estimated_text_width = @as(f32, @floatFromInt(text.len)) * font_size * 0.6;
        
        // Apply alignment to position
        const aligned_position = text_alignment.applyAlignment(position, alignment, estimated_text_width);
        
        // Use the exact same approach as working navigation text
        self.base_renderer.gpu.text_renderer.queuePersistentText(
            text, 
            aligned_position, 
            self.base_renderer.font_manager, 
            .sans, 
            font_size,
            text_color
        ) catch |err| {
            const log = std.log.scoped(.ide_text);
            log.err("Failed to queue IDE text '{s}': {}", .{ text, err });
        };
    }

};
