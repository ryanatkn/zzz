/// Safe terminal content renderer with proper error handling
const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const reactive = @import("../reactive/mod.zig");
const terminal_core = @import("../terminal/core.zig");
const terminal_text = @import("terminal_text.zig");
const focusable_border = @import("focusable_border.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;
const Color = colors.Color;
const Line = terminal_core.Line;
const Cursor = terminal_core.Cursor;
const TerminalText = terminal_text.TerminalText;
const FocusableBorder = focusable_border.FocusableBorder;

pub const TerminalViewport = struct {
    scroll_offset: usize = 0,
    visible_lines: usize = 20,
    visible_columns: usize = 80,
};

pub const TerminalRendererConfig = struct {
    background_color: Color = Color{ .r = 20, .g = 25, .b = 30, .a = 255 },
    margin: Vec2 = Vec2{ .x = 8, .y = 8 },
    header_height: f32 = 30,
    show_header: bool = true,
    show_border: bool = true,
};

pub const TerminalRenderer = struct {
    config: reactive.Signal(TerminalRendererConfig),
    viewport: reactive.Signal(TerminalViewport),
    text_renderer: TerminalText,
    border: ?*FocusableBorder = null,
    
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: TerminalRendererConfig) !Self {
        return Self{
            .config = try reactive.signal(allocator, TerminalRendererConfig, config),
            .viewport = try reactive.signal(allocator, TerminalViewport, TerminalViewport{}),
            .text_renderer = try TerminalText.createDefault(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.config.deinit();
        self.viewport.deinit();
        self.text_renderer.deinit();
        
        if (self.border) |border| {
            border.destroy(&border.base, self.allocator);
        }
    }

    /// Initialize border component for focus indication
    pub fn initBorder(self: *Self, bounds: Rectangle) !void {
        self.border = try focusable_border.createFocusableBorder(self.allocator, bounds);
        
        // Configure border colors for terminal theme
        self.border.?.setFocusColor(Color{ .r = 70, .g = 130, .b = 180, .a = 255 }); // Selection blue
        self.border.?.setNormalColor(Color{ .r = 60, .g = 65, .b = 75, .a = 255 }); // Subtle gray
        self.border.?.setBorderWidth(2.0);
    }

    /// Update components (cursor blinking, etc.)
    pub fn update(self: *Self, dt: f32) void {
        self.text_renderer.update(dt);
        
        if (self.border) |border| {
            border.base.vtable.update(&border.base, dt);
        }
    }

    /// Set focus state
    pub fn setFocus(self: *Self, focused: bool) void {
        if (self.border) |border| {
            border.setFocus(focused);
        }
    }

    /// Render complete terminal content in the given bounds
    pub fn render(self: *const Self, renderer: anytype, bounds: Rectangle, content: TerminalContent, header_text: ?[]const u8) !void {
        const config = self.config.get();
        
        // Render background
        if (config.background_color.a > 0) {
            if (@hasDecl(@TypeOf(renderer), "drawRect")) {
                try renderer.drawRect(bounds.position, bounds.size, config.background_color);
            }
        }
        
        // Render border if enabled
        if (config.show_border and self.border != null) {
            var border_bounds = bounds;
            border_bounds.position.x -= 2;
            border_bounds.position.y -= 2;
            border_bounds.size.x += 4;
            border_bounds.size.y += 4;
            
            self.border.?.base.props.bounds.set(border_bounds);
            try self.border.?.base.vtable.render(&self.border.?.base, renderer);
        }
        
        // Calculate content area
        const content_area = self.getContentArea(bounds);
        
        // Render header if enabled
        if (config.show_header and header_text != null) {
            const header_position = Vec2{ 
                .x = content_area.position.x, 
                .y = content_area.position.y 
            };
            try self.text_renderer.renderText(renderer, header_text.?, header_position, Color{ .r = 200, .g = 200, .b = 200, .a = 255 });
        }
        
        // Calculate terminal text area
        const text_area = self.getTextArea(content_area);
        
        // Render terminal content
        try self.renderTerminalContent(renderer, text_area, content);
    }

    /// Render terminal lines and input
    fn renderTerminalContent(self: *const Self, renderer: anytype, text_area: Rectangle, content: TerminalContent) !void {
        const viewport = self.viewport.get();
        const line_height = self.text_renderer.config.get().line_height;
        
        // Improved spacing and margins
        const bottom_margin: f32 = 12;
        const side_margin: f32 = 8;
        const line_spacing: f32 = line_height * 1.2; // 20% more spacing between lines
        const input_padding: f32 = 4;
        
        // Start from bottom of text area with proper margins
        const bottom_y = text_area.position.y + text_area.size.y - bottom_margin;
        const input_height = line_height + (input_padding * 2);
        var current_y = bottom_y - input_height;
        
        // Render input background with styling
        const input_y = current_y;
        const input_bg_rect = Rectangle{
            .position = Vec2{ .x = text_area.position.x + side_margin, .y = input_y },
            .size = Vec2{ .x = text_area.size.x - (side_margin * 2), .y = input_height },
        };
        
        // Draw input background - different color based on focus (we'll assume focused for now in this renderer)
        const input_bg_color = Color{ .r = 30, .g = 35, .b = 40, .a = 255 };
        if (@hasDecl(@TypeOf(renderer), "drawRect")) {
            try renderer.drawRect(input_bg_rect.position, input_bg_rect.size, input_bg_color);
        }
        
        // Draw input border
        const border_color = Color{ .r = 70, .g = 130, .b = 180, .a = 255 };
        const border_width: f32 = 1;
        
        if (@hasDecl(@TypeOf(renderer), "drawRect")) {
            // Top border
            try renderer.drawRect(
                input_bg_rect.position,
                Vec2{ .x = input_bg_rect.size.x, .y = border_width },
                border_color
            );
            // Bottom border
            try renderer.drawRect(
                Vec2{ .x = input_bg_rect.position.x, .y = input_bg_rect.position.y + input_bg_rect.size.y - border_width },
                Vec2{ .x = input_bg_rect.size.x, .y = border_width },
                border_color
            );
            // Left border
            try renderer.drawRect(
                input_bg_rect.position,
                Vec2{ .x = border_width, .y = input_bg_rect.size.y },
                border_color
            );
            // Right border
            try renderer.drawRect(
                Vec2{ .x = input_bg_rect.position.x + input_bg_rect.size.x - border_width, .y = input_bg_rect.position.y },
                Vec2{ .x = border_width, .y = input_bg_rect.size.y },
                border_color
            );
        }
        
        // Render input text with padding
        const input_position = Vec2{ 
            .x = text_area.position.x + side_margin + input_padding, 
            .y = input_y + input_padding 
        };
        try self.text_renderer.renderInputLine(
            renderer, 
            content.prompt, 
            content.current_input, 
            content.cursor, 
            input_position, 
            text_area.size.x - (side_margin * 2) - (input_padding * 2)
        );
        
        // Now render scrollback lines going upward from input line with better spacing
        const start_line = viewport.scroll_offset;
        const max_lines = @min(viewport.visible_lines, content.lines.len);
        
        var lines_rendered: usize = 0;
        for (content.lines[start_line..]) |*line| {
            // Move up with proper line spacing
            current_y -= line_spacing;
            
            // Stop if we've reached the top of the text area
            if (current_y < text_area.position.y or lines_rendered >= max_lines) break;
            
            const line_position = Vec2{ .x = text_area.position.x + side_margin, .y = current_y };
            try self.text_renderer.renderLine(renderer, line, line_position, text_area.size.x - (side_margin * 2));
            
            lines_rendered += 1;
        }
    }

    /// Calculate content area excluding margins
    fn getContentArea(self: *const Self, bounds: Rectangle) Rectangle {
        const config = self.config.get();
        
        return Rectangle{
            .position = Vec2{
                .x = bounds.position.x + config.margin.x,
                .y = bounds.position.y + config.margin.y,
            },
            .size = Vec2{
                .x = bounds.size.x - (config.margin.x * 2),
                .y = bounds.size.y - (config.margin.y * 2),
            },
        };
    }

    /// Calculate text area excluding header
    fn getTextArea(self: *const Self, content_area: Rectangle) Rectangle {
        const config = self.config.get();
        
        if (config.show_header) {
            return Rectangle{
                .position = Vec2{
                    .x = content_area.position.x,
                    .y = content_area.position.y + config.header_height,
                },
                .size = Vec2{
                    .x = content_area.size.x,
                    .y = content_area.size.y - config.header_height,
                },
            };
        } else {
            return content_area;
        }
    }

    /// Update viewport dimensions based on bounds
    pub fn updateViewport(self: *Self, bounds: Rectangle) void {
        const text_area = self.getTextArea(self.getContentArea(bounds));
        const text_config = self.text_renderer.config.get();
        
        const visible_lines = @max(1, @as(usize, @intFromFloat(text_area.size.y / text_config.line_height)));
        const visible_columns = @max(1, @as(usize, @intFromFloat(text_area.size.x / text_config.char_width)));
        
        var viewport = self.viewport.get();
        viewport.visible_lines = visible_lines;
        viewport.visible_columns = visible_columns;
        self.viewport.set(viewport);
    }

    /// Scroll the viewport
    pub fn scroll(self: *Self, delta: i32) void {
        var viewport = self.viewport.get();
        
        if (delta > 0) {
            viewport.scroll_offset += @intCast(delta);
        } else if (delta < 0) {
            const abs_delta: usize = @intCast(-delta);
            if (viewport.scroll_offset >= abs_delta) {
                viewport.scroll_offset -= abs_delta;
            } else {
                viewport.scroll_offset = 0;
            }
        }
        
        self.viewport.set(viewport);
    }

    /// Create with default configuration
    pub fn createDefault(allocator: std.mem.Allocator) !Self {
        return try Self.init(allocator, TerminalRendererConfig{});
    }
};

/// Terminal content structure for rendering
pub const TerminalContent = struct {
    lines: []const Line,
    current_input: []const u8,
    prompt: []const u8,
    cursor: Cursor,
    
    /// Create from terminal engine data
    pub fn fromTerminalEngine(engine: anytype) TerminalContent {
        const visible = engine.getVisibleContent();
        return TerminalContent{
            .lines = visible.lines,
            .current_input = visible.current,
            .prompt = "$ ", // Simple static prompt for now
            .cursor = visible.cursor,
        };
    }
    
    /// Create empty content for testing
    pub fn empty() TerminalContent {
        return TerminalContent{
            .lines = &[_]Line{},
            .current_input = "",
            .prompt = "$ ",
            .cursor = Cursor{ .x = 0, .y = 0, .visible = true },
        };
    }
};