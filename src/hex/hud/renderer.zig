const std = @import("std");
const c = @import("../../lib/platform/sdl.zig");
const math = @import("../../lib/math/mod.zig");
const colors = @import("../../lib/core/colors.zig");
const constants = @import("../../lib/core/constants.zig");
const loggers = @import("../../lib/debug/loggers.zig");
const lib_renderer = @import("../../lib/rendering/core/interface.zig");
const game_renderer = @import("../game_renderer.zig");
const page = @import("../../lib/browser/page.zig");
const font_config = @import("../../lib/font/config.zig");
const text_renderer = @import("../../lib/text/renderer.zig");
const menu_text = @import("../../lib/ui/menu_text.zig");
const drawing = @import("../../lib/rendering/ui/drawing.zig");
const TerminalComponent = @import("../../lib/ui/terminal.zig").TerminalComponent;
const font_grid_test_page = @import("../../roots/menu/font_grid_test/+page.zig");
const ide_page = @import("../../roots/menu/ide/+page.zig");
const ide_constants = @import("../../roots/menu/ide/constants.zig");
const directory_scanner = @import("../../lib/platform/directory_scanner.zig");
const syntax_highlighter = @import("../../roots/menu/ide/syntax_highlighter.zig");
const bitmap_strategy = @import("../../lib/font/strategies/bitmap/mod.zig");
const text_alignment = @import("../../lib/text/alignment.zig");
const file_tree_mod = @import("../../lib/ui/file_tree.zig");
const ui = @import("../../lib/ui.zig");

// Throttled logging to prevent spam
const Logger = @import("../../lib/debug/logger.zig").Logger;
const outputs = @import("../../lib/debug/outputs.zig");
const filters = @import("../../lib/debug/filters.zig");

const Color = colors.Color;
const Vec2 = math.Vec2;
const FileIcon = file_tree_mod.FileIcon;

/// Adapter to make SDL GPU compatible with TerminalLayoutRenderer interface
const SDLGPUTerminalAdapter = struct {
    renderer: *BrowserRenderer,
    cmd_buffer: *c.sdl.SDL_GPUCommandBuffer,
    render_pass: *c.sdl.SDL_GPURenderPass,

    pub fn drawRect(self: SDLGPUTerminalAdapter, rect: Rectangle, color: Color) void {
        self.renderer.base_renderer.gpu.drawRect(self.cmd_buffer, self.render_pass, rect.position, rect.size, color);
    }

    pub fn drawText(self: SDLGPUTerminalAdapter, text: []const u8, x: f32, y: f32, font_size: f32, color: Color) void {
        _ = font_size; // HUD uses fixed font size from constants
        _ = color; // HUD uses fixed text color
        self.renderer.drawSimpleText(self.cmd_buffer, self.render_pass, text, Vec2{ .x = x, .y = y });
    }
};

const Rectangle = math.Rectangle;

/// Terminal helper messages (consolidated to eliminate duplication)
const TERMINAL_MESSAGES = struct {
    pub const CLICK_TO_FOCUS = "Click to focus and start typing";
    pub const READY_FOR_INPUT = "Ready for input! Try typing 'help'";
    pub const INITIALIZING = "Terminal initializing...";
};

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

    // Terminal layout renderer for unified rendering
    terminal_layout_renderer: ui.TerminalLayoutRenderer,

    pub fn init(base_renderer: *game_renderer.GameRenderer) BrowserRenderer {
        // Create layout renderer with HUD-specific configuration
        const hud_terminal_config = ui.TerminalLayoutConfig{
            .top_margin = 10,
            .bottom_margin = 15,
            .side_margin = 10,
            .input_padding = 6,
            .line_spacing_multiplier = 1.3,
            .input_bg_focused = colors.DARK_GRAY_40,
            .input_bg_unfocused = colors.DARK_GRAY_25,
            .input_border = ide_constants.COLORS.TEXT_NORMAL,
            .text_color = ide_constants.COLORS.TEXT_NORMAL,
        };

        return .{
            .base_renderer = base_renderer,
            .font_grid_config = FontGridConfig.default(),
            .terminal_layout_renderer = ui.TerminalLayoutRenderer.init(hud_terminal_config),
        };
    }

    pub fn initFonts(self: *BrowserRenderer, allocator: std.mem.Allocator) !void {
        _ = self;
        _ = allocator;
        const ui_log = loggers.getUILog();
        ui_log.info("browser_renderer", "HUD using main game's FontManager and TextRenderer - no separate initialization needed", .{});
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
        const overlay_color = colors.DARK_OVERLAY;

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
                colors.LINK_HOVERED
            else
                colors.LINK_NORMAL;

            self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, link.bounds.position, link.bounds.size, link_color);

            // Render the link text using menu text renderer directly
            const link_rect = drawing.Rectangle.init(link.bounds.position, link.bounds.size);
            var menu_renderer = menu_text.MenuTextRenderer.init(&self.base_renderer.gpu.text_integration, self.base_renderer.font_manager);

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
        const screen_width = constants.SCREEN.BASE_WIDTH;
        const screen_height = constants.SCREEN.BASE_HEIGHT;

        const bar_height = 50.0;
        const bar_y = screen_height * 0.05 - bar_height / 2.0; // Moved up from 0.1 to 0.05
        const bar_width = screen_width * 0.8;
        const bar_x = (screen_width - bar_width) / 2.0;

        // Navigation bar background
        self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, .{ .x = bar_x, .y = bar_y }, .{ .x = bar_width, .y = bar_height }, colors.NAV_BACKGROUND);

        // Back button
        const button_size = 40.0;
        const button_margin = 5.0;
        const back_color = if (can_go_back)
            colors.BUTTON_NORMAL
        else
            colors.BUTTON_DISABLED;

        self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, .{ .x = bar_x + button_margin, .y = bar_y + button_margin }, .{ .x = button_size, .y = button_size }, back_color);

        // Draw back arrow indicator
        if (can_go_back) {
            self.drawArrow(cmd_buffer, render_pass, bar_x + button_margin + button_size / 2.0, bar_y + button_margin + button_size / 2.0, 10.0, .Left, colors.LIGHT_GRAY_220);
        }

        // Forward button
        const forward_color = if (can_go_forward)
            colors.BUTTON_NORMAL
        else
            colors.BUTTON_DISABLED;

        self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, .{ .x = bar_x + button_margin * 2 + button_size, .y = bar_y + button_margin }, .{ .x = button_size, .y = button_size }, forward_color);

        // Draw forward arrow indicator
        if (can_go_forward) {
            self.drawArrow(cmd_buffer, render_pass, bar_x + button_margin * 2 + button_size + button_size / 2.0, bar_y + button_margin + button_size / 2.0, 10.0, .Right, colors.LIGHT_GRAY_220);
        }

        // Address bar background
        const address_x = bar_x + button_margin * 3 + button_size * 2;
        const address_width = bar_width - (button_margin * 4 + button_size * 2);

        self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, .{ .x = address_x, .y = bar_y + button_margin }, .{ .x = address_width, .y = button_size }, colors.ADDRESS_BAR_BG);

        // Address bar border (to make it look like an input field)
        self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, .{ .x = address_x, .y = bar_y + button_margin }, .{ .x = address_width, .y = 2 }, colors.NAV_BORDER);
        self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, .{ .x = address_x, .y = bar_y + button_margin + button_size - 2 }, .{ .x = address_width, .y = 2 }, colors.NAV_BORDER);

        // Queue the path text for rendering using shared utility with main game renderers
        var menu_text_renderer = menu_text.MenuTextRenderer.init(&self.base_renderer.gpu.text_integration, self.base_renderer.font_manager);
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
        const header_rect = math.Rectangle.sized(Vec2{ .x = screen_size.x, .y = header_height });
        self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, header_rect.position, header_rect.size, ide_constants.COLORS.HEADER_BG);

        // File explorer panel (left)
        const explorer_rect = math.Rectangle.init(Vec2{ .x = panel_gap, .y = header_height + panel_gap }, Vec2{ .x = explorer_width, .y = screen_size.y - header_height - (panel_gap * 2) });

        drawing.drawBorderedRect(&self.base_renderer.gpu, cmd_buffer, render_pass, explorer_rect.position, explorer_rect.size, ide_constants.COLORS.PANEL_BG, ide_constants.COLORS.PANEL_BORDER, 1.0);

        // Main content panel (center, constrained width)
        const content_x = explorer_width + (panel_gap * 2);
        const content_rect = math.Rectangle.init(Vec2{ .x = content_x, .y = header_height + panel_gap }, Vec2{ .x = content_width, .y = screen_size.y - header_height - (panel_gap * 2) });

        drawing.drawBorderedRect(&self.base_renderer.gpu, cmd_buffer, render_pass, content_rect.position, content_rect.size, ide_constants.COLORS.PANEL_BG, ide_constants.COLORS.PANEL_BORDER, 1.0);

        // Preview panel (right)
        const preview_x = content_x + content_width + panel_gap;
        const preview_rect = math.Rectangle.init(Vec2{ .x = preview_x, .y = header_height + panel_gap }, Vec2{ .x = preview_width, .y = screen_size.y - header_height - (panel_gap * 2) });

        drawing.drawBorderedRect(&self.base_renderer.gpu, cmd_buffer, render_pass, preview_rect.position, preview_rect.size, ide_constants.COLORS.PANEL_BG, ide_constants.COLORS.PANEL_BORDER, 1.0);

        // Render the actual panel content
        try self.renderFileTree(cmd_buffer, render_pass, ide_page_impl, explorer_rect);
        try self.renderContentArea(cmd_buffer, render_pass, ide_page_impl, content_rect);
        try self.renderPreviewPanel(cmd_buffer, render_pass, ide_page_impl, preview_rect);

        // Draw resolution info in header
        var resolution_buf: [64]u8 = undefined;
        const resolution_text = std.fmt.bufPrint(&resolution_buf, "Resolution: {d}x{d}", .{ @as(u32, @intFromFloat(screen_size.x)), @as(u32, @intFromFloat(screen_size.y)) }) catch "Resolution: Unknown";
        self.drawSimpleText(cmd_buffer, render_pass, resolution_text, Vec2{ .x = screen_size.x - 200, .y = 15 });
    }

    /// Render file tree in explorer panel using Link system
    fn renderFileTree(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, ide_page_impl: *const ide_page.IDEPage, panel_rect: math.Rectangle) !void {

        // Panel header - queue for rendering
        self.queueTextForRender(cmd_buffer, render_pass, "FILE EXPLORER", Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 10 }, ide_constants.COLORS.TEXT_NORMAL);

        // Check for loading or error states
        if (ide_page_impl.loading) {
            self.queueTextForRender(cmd_buffer, render_pass, "Loading...", Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 40 }, ide_constants.COLORS.TEXT_NORMAL);
            return;
        }

        if (ide_page_impl.error_message) |error_msg| {
            self.queueTextForRender(cmd_buffer, render_pass, "Error:", Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 40 }, ide_constants.COLORS.TEXT_NORMAL);
            self.queueTextForRender(cmd_buffer, render_pass, error_msg, Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 60 }, ide_constants.COLORS.TEXT_NORMAL);
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
            self.queueTextForRender(cmd_buffer, render_pass, header_text, Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 10 }, ide_constants.COLORS.TEXT_NORMAL);
        } else {
            self.queueTextForRender(cmd_buffer, render_pass, "CONTENT EDITOR (~800px max)", Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 10 }, ide_constants.COLORS.TEXT_NORMAL);
        }

        // Display file content or error
        if (ide_page_impl.current_file_error) |error_msg| {
            // Show error message
            self.queueTextForRender(cmd_buffer, render_pass, "Error:", Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 40 }, ide_constants.COLORS.TEXT_NORMAL);
            self.queueTextForRender(cmd_buffer, render_pass, error_msg, Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 60 }, ide_constants.COLORS.TEXT_NORMAL);
        } else if (ide_page_impl.current_file_content) |content| {
            // Show file content line by line
            try self.renderFileContentWithHighlighting(cmd_buffer, render_pass, content, panel_rect, ide_page_impl);
        } else {
            // No file selected
            self.queueTextForRender(cmd_buffer, render_pass, "Select a file to view its contents", Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 40 }, ide_constants.COLORS.TEXT_NORMAL);
        }
    }

    /// Render terminal panel with improved safety and error handling
    fn renderPreviewPanel(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, ide_page_impl: *const ide_page.IDEPage, panel_rect: math.Rectangle) !void {
        const focused_panel = ide_page_impl.getFocusedPanel();
        const is_terminal_focused = focused_panel == .terminal;

        // Draw focus border if terminal is focused
        if (is_terminal_focused) {
            try self.drawFocusBorder(cmd_buffer, render_pass, panel_rect);
        }

        // Panel header with focus indication
        const header_text = if (is_terminal_focused) "TERMINAL [FOCUSED]" else "TERMINAL";
        self.drawSimpleText(cmd_buffer, render_pass, header_text, Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 10 });

        // Check if terminal component exists and render content
        if (ide_page_impl.terminal_component) |*terminal| {
            try self.renderTerminalContentSafe(cmd_buffer, render_pass, terminal, panel_rect, is_terminal_focused);
        } else {
            // Fallback display when terminal not initialized
            self.drawSimpleText(cmd_buffer, render_pass, TERMINAL_MESSAGES.INITIALIZING, Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 40 });
            self.drawSimpleText(cmd_buffer, render_pass, TERMINAL_MESSAGES.CLICK_TO_FOCUS, Vec2{ .x = panel_rect.position.x + 10, .y = panel_rect.position.y + 60 });
        }
    }

    /// Draw focus border around panel
    fn drawFocusBorder(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, panel_rect: math.Rectangle) !void {
        const border_color = ide_constants.COLORS.SELECTION_BG;
        const border_width = 2.0;

        // Draw border rectangles (top, bottom, left, right)
        self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = panel_rect.position.x - border_width, .y = panel_rect.position.y - border_width }, Vec2{ .x = panel_rect.size.x + 2 * border_width, .y = border_width }, border_color); // Top

        self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = panel_rect.position.x - border_width, .y = panel_rect.position.y + panel_rect.size.y }, Vec2{ .x = panel_rect.size.x + 2 * border_width, .y = border_width }, border_color); // Bottom

        self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = panel_rect.position.x - border_width, .y = panel_rect.position.y }, Vec2{ .x = border_width, .y = panel_rect.size.y }, border_color); // Left

        self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = panel_rect.position.x + panel_rect.size.x, .y = panel_rect.position.y }, Vec2{ .x = border_width, .y = panel_rect.size.y }, border_color); // Right
    }

    /// Render terminal content with improved safety checks
    fn renderTerminalContentSafe(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, terminal: *const TerminalComponent, panel_rect: math.Rectangle, is_focused: bool) !void {
        // Get terminal content safely with error handling
        const terminal_content = terminal.terminal.getVisibleContent();

        // Create SDL GPU adapter for the layout renderer
        const gpu_adapter = SDLGPUTerminalAdapter{
            .renderer = self,
            .cmd_buffer = cmd_buffer,
            .render_pass = render_pass,
        };

        // Create TerminalContent for the layout renderer
        var terminal_lines = terminal_content.lines;

        // Convert capability cursor to simple cursor for layout renderer
        const simple_cursor = @import("../../lib/terminal/core.zig").Cursor{
            .x = terminal_content.cursor.x,
            .y = terminal_content.cursor.y,
            .visible = terminal_content.cursor.visible,
            .blink_timer = terminal_content.cursor.blink_timer,
            .blink_rate = terminal_content.cursor.blink_rate,
        };

        const layout_content = ui.TerminalContent{
            .lines = &terminal_lines,
            .current_input = terminal_content.current,
            .prompt = "$ ",
            .cursor = simple_cursor,
            .is_focused = is_focused,
        };

        // Use the unified layout renderer - this replaces ~134 lines of duplicate code!
        try self.terminal_layout_renderer.render(
            gpu_adapter,
            panel_rect,
            layout_content,
            ide_constants.TEXT.CONTENT_FONT_SIZE, // HUD uses fixed font size
            ide_constants.TEXT.LINE_HEIGHT,
            ide_constants.TEXT.CHAR_WIDTH,
        );

        // Show helpful message if no terminal content and there's space (simplified)
        const content_area_top = panel_rect.position.y + 30;
        if (is_focused) {
            self.drawSimpleText(cmd_buffer, render_pass, TERMINAL_MESSAGES.READY_FOR_INPUT, Vec2{ .x = panel_rect.position.x + 10, .y = content_area_top });
        } else {
            self.drawSimpleText(cmd_buffer, render_pass, TERMINAL_MESSAGES.CLICK_TO_FOCUS, Vec2{ .x = panel_rect.position.x + 10, .y = content_area_top });
        }
    }

    /// Check if text contains only safe printable characters
    fn isTextSafe(self: *const BrowserRenderer, text: []const u8) bool {
        _ = self;
        if (text.len == 0) return false;

        for (text) |ch| {
            // Allow printable ASCII and common whitespace
            if (ch < 32 or ch > 126) {
                if (ch != ' ' and ch != '\t') {
                    return false;
                }
            }
        }
        return true;
    }

    /// Draw file type icon
    fn drawFileIcon(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, icon: FileIcon, position: Vec2) !void {
        const icon_color = icon.getColor();
        const icon_size = ide_constants.FILE_TREE.ICON_SIZE;

        switch (icon) {
            .folder_closed, .folder_open => {
                // Draw folder icon - rectangle with slight indent at top
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = position.x, .y = position.y + 2 }, Vec2{ .x = icon_size, .y = icon_size - 2 }, icon_color);
                // Draw folder tab
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, position, Vec2{ .x = icon_size - 3, .y = 3 }, icon_color);
            },
            else => {
                // Draw file icon - simple rectangle
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass, position, Vec2{ .x = icon_size, .y = icon_size }, icon_color);
            },
        }
    }

    /// Render file content with syntax highlighting support
    fn renderFileContentWithHighlighting(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, content: []const u8, panel_rect: math.Rectangle, ide_page_impl: *const ide_page.IDEPage) !void {
        _ = render_pass;
        const line_height = ide_constants.TEXT.LINE_HEIGHT;
        const char_width = ide_constants.TEXT.CHAR_WIDTH;
        const start_y = panel_rect.position.y + 40; // Below header
        const max_lines = @as(u32, @intFromFloat((panel_rect.size.y - 50) / line_height)); // Available space for content
        const max_chars_per_line = @as(u32, @intFromFloat((panel_rect.size.x - 20) / char_width)); // Characters that fit

        // Safety check: disable highlighting for large files
        const file_too_large = content.len > ide_constants.SYNTAX.MAX_FILE_SIZE_BYTES;

        // Check if syntax highlighting should be enabled
        const enable_highlighting = ide_constants.SYNTAX.ENABLE_HIGHLIGHTING and ide_page_impl.*.shouldHighlightCurrentFile() and !file_too_large;

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
            self.drawTextWithColor(cmd_buffer, line_num_text, Vec2{ .x = panel_rect.position.x + 10, .y = y_pos }, ide_constants.COLORS.TEXT_LINE_NUMBERS);

            // Render line content with or without syntax highlighting
            const line_start_x = panel_rect.position.x + ide_constants.TEXT.LINE_NUMBER_OFFSET;
            if (enable_highlighting and display_line.len <= ide_constants.SYNTAX.MAX_HIGHLIGHT_LINE_LENGTH) {
                try self.renderLineWithHighlighting(cmd_buffer, display_line, Vec2{ .x = line_start_x, .y = y_pos }, ide_page_impl);
            } else {
                // Fallback to normal rendering
                self.drawTextWithColor(cmd_buffer, display_line, Vec2{ .x = line_start_x, .y = y_pos }, ide_constants.COLORS.TEXT_NORMAL);
            }

            line_num += 1;
        }

        // Show truncation message if content is too long
        if (line_num >= max_lines) {
            const truncate_msg = "... (file truncated for display)";
            self.drawTextWithColor(cmd_buffer, truncate_msg, Vec2{ .x = panel_rect.position.x + 10, .y = start_y + @as(f32, @floatFromInt(max_lines)) * line_height }, ide_constants.COLORS.TEXT_TRUNCATION);
        }
    }

    /// Render a single line with syntax highlighting
    fn renderLineWithHighlighting(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, line: []const u8, position: Vec2, ide_page_impl: *const ide_page.IDEPage) !void {
        // Get mutable access to the syntax highlighter
        const ide_page_mut = @constCast(ide_page_impl);
        var highlighter = ide_page_mut.*.getSyntaxHighlighter();

        // Highlight the line with timeout protection
        const start_time = std.time.milliTimestamp();
        const tokens = highlighter.highlightLine(line) catch {
            // Fallback to normal rendering on error
            self.drawTextWithColor(cmd_buffer, line, position, ide_constants.COLORS.TEXT_NORMAL);
            return;
        };
        const end_time = std.time.milliTimestamp();

        // Check if highlighting took too long (safety measure)
        if (end_time - start_time > ide_constants.SYNTAX.HIGHLIGHT_TIMEOUT_MS) {
            // Log warning but still render the tokens we got
            var throttled_logger = @import("../../lib/debug/logger.zig").Logger(.{
                .output = @import("../../lib/debug/outputs.zig").Console,
                .filter = @import("../../lib/debug/filters.zig").Throttle,
            }).init(std.heap.c_allocator);
            throttled_logger.warn("syntax_highlight", "Highlighting took {d}ms (limit: {d}ms)", .{ end_time - start_time, ide_constants.SYNTAX.HIGHLIGHT_TIMEOUT_MS });
        }
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
                    self.drawTextWithColor(cmd_buffer, gap_text, Vec2{ .x = current_x, .y = position.y }, ide_constants.COLORS.TEXT_NORMAL);
                    current_x += @as(f32, @floatFromInt(gap_text.len)) * char_width;
                }
            }

            // Render the token with its color
            if (token.text.len > 0) {
                self.drawTextWithColor(cmd_buffer, token.text, Vec2{ .x = current_x, .y = position.y }, token.token_type.getColor());
                current_x += @as(f32, @floatFromInt(token.text.len)) * char_width;
            }

            last_pos = token.end_pos;
        }

        // Render any remaining text at the end
        if (last_pos < line.len) {
            const remaining_text = line[last_pos..];
            if (remaining_text.len > 0) {
                self.drawTextWithColor(cmd_buffer, remaining_text, Vec2{ .x = current_x, .y = position.y }, ide_constants.COLORS.TEXT_NORMAL);
            }
        }
    }

    /// Draw simple text using proper font rendering
    fn drawSimpleText(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, text: []const u8, position: Vec2) void {
        _ = render_pass;
        const text_color = colors.LIGHT_GRAY_200;
        self.drawTextWithColor(cmd_buffer, text, position, text_color);
    }

    /// Draw text with specified color using MenuTextRenderer (16pt font for compatibility)
    fn drawTextWithColor(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, text: []const u8, position: Vec2, text_color: Color) void {
        _ = cmd_buffer; // TODO: Remove when text integration is complete
        // Skip rendering empty or whitespace-only text to avoid texture creation failures
        if (text.len == 0 or std.mem.trim(u8, text, " \t\r\n").len == 0) {
            return;
        }

        // Use the same approach as working buttons - 16pt font renders reliably
        var menu_renderer = menu_text.MenuTextRenderer.init(&self.base_renderer.gpu.text_integration, self.base_renderer.font_manager);
        menu_renderer.queueCustomText(text, position, ide_constants.TEXT.CONTENT_FONT_SIZE, text_color);
    }

    /// Queue text using the proper persistent text system (like working buttons)
    fn queueTextForRender(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, text: []const u8, position: Vec2, text_color: Color) void {
        self.queueAlignedTextForRender(cmd_buffer, render_pass, text, position, text_color, .left);
    }

    /// Queue text for rendering with specified alignment
    fn queueAlignedTextForRender(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, text: []const u8, position: Vec2, text_color: Color, alignment: text_alignment.TextAlign) void {
        _ = render_pass; // Not used in current implementation
        _ = cmd_buffer; // TODO: Remove when text integration is complete

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
        self.base_renderer.gpu.text_integration.queuePersistentText(text, aligned_position, self.base_renderer.font_manager, .sans, font_size, text_color) catch |err| {
            const ui_log = loggers.getUILog();
            ui_log.err("ide_text", "Failed to queue IDE text '{s}': {}", .{ text, err });
        };
    }
};
