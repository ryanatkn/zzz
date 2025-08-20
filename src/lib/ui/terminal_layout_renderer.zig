const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const terminal_core = @import("../terminal/core.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;
const Color = colors.Color;
const Line = terminal_core.Line;
const Cursor = terminal_core.Cursor;

/// Configuration for terminal layout rendering
pub const TerminalLayoutConfig = struct {
    // Margins and spacing
    top_margin: f32 = 8,
    bottom_margin: f32 = 12,
    side_margin: f32 = 8,
    input_padding: f32 = 4,
    content_to_input_spacing: f32 = 2, // Small gap between content and input area
    line_spacing_multiplier: f32 = 1.2, // 20% extra spacing
    
    // Buffer limits
    max_lines_buffer: usize = 200, // Maximum lines to buffer for rendering (increased from hardcoded 100)

    // Colors
    input_bg_focused: Color = Color{ .r = 30, .g = 35, .b = 40, .a = 255 },
    input_bg_unfocused: Color = Color{ .r = 15, .g = 20, .b = 25, .a = 255 },
    input_border: Color = Color{ .r = 70, .g = 130, .b = 180, .a = 255 },
    text_color: Color = Color{ .r = 255, .g = 255, .b = 255, .a = 255 },

    // Layout
    show_cursor: bool = true,
    show_input_border: bool = true,
    render_direction: RenderDirection = .bottom_up,
};

pub const RenderDirection = enum {
    top_down,   // Render from top of content area downward
    bottom_up,  // Render from input area upward (traditional terminal approach)
};

/// Content structure for terminal rendering
pub const TerminalContent = struct {
    lines: *terminal_core.VisibleLinesIterator,
    current_input: []const u8,
    prompt: []const u8,
    cursor: Cursor,
    is_focused: bool = true,
};


/// Unified terminal layout renderer
pub const TerminalLayoutRenderer = struct {
    config: TerminalLayoutConfig,

    const Self = @This();

    pub fn init(config: TerminalLayoutConfig) Self {
        return Self{
            .config = config,
        };
    }

    /// Render complete terminal layout within given bounds
    pub fn render(
        self: *const Self,
        renderer: anytype,
        bounds: Rectangle,
        content: TerminalContent,
        font_size: f32,
        line_height: f32,
        char_width: f32,
    ) !void {
        const line_spacing = line_height * self.config.line_spacing_multiplier;

        // Calculate layout areas
        const layout = self.calculateLayout(bounds, line_height, line_spacing);

        // Render input area
        try self.renderInputArea(renderer, layout, content, font_size, char_width);

        // Render terminal content based on direction
        switch (self.config.render_direction) {
            .top_down => try self.renderContentTopDown(renderer, layout, content, line_spacing, font_size),
            .bottom_up => try self.renderContentBottomUp(renderer, layout, content, line_spacing, font_size),
        }
    }

    /// Calculate layout areas for terminal rendering
    fn calculateLayout(self: *const Self, bounds: Rectangle, line_height: f32, line_spacing: f32) TerminalLayout {
        const input_height = line_height + (self.config.input_padding * 2);
        const input_y = bounds.position.y + bounds.size.y - self.config.bottom_margin - input_height;

        const content_top = bounds.position.y + self.config.top_margin;
        const content_bottom = input_y - self.config.content_to_input_spacing;
        const available_height = content_bottom - content_top;
        const max_lines = @as(usize, @intFromFloat(@max(0, available_height / line_spacing)));

        return TerminalLayout{
            .bounds = bounds,
            .content_area = Rectangle{
                .position = Vec2{ .x = bounds.position.x + self.config.side_margin, .y = content_top },
                .size = Vec2{ 
                    .x = bounds.size.x - (self.config.side_margin * 2),
                    .y = available_height,
                },
            },
            .input_area = Rectangle{
                .position = Vec2{ .x = bounds.position.x + self.config.side_margin, .y = input_y },
                .size = Vec2{ 
                    .x = bounds.size.x - (self.config.side_margin * 2),
                    .y = input_height,
                },
            },
            .text_area = Rectangle{
                .position = Vec2{
                    .x = bounds.position.x + self.config.side_margin + self.config.input_padding,
                    .y = input_y + self.config.input_padding,
                },
                .size = Vec2{
                    .x = bounds.size.x - (self.config.side_margin * 2) - (self.config.input_padding * 2),
                    .y = line_height,
                },
            },
            .max_content_lines = max_lines,
            .content_top = content_top,
            .content_bottom = content_bottom,
        };
    }

    /// Render input area with background and border
    fn renderInputArea(
        self: *const Self,
        renderer: anytype,
        layout: TerminalLayout,
        content: TerminalContent,
        font_size: f32,
        char_width: f32,
    ) !void {
        // Draw input background
        const bg_color = if (content.is_focused) 
            self.config.input_bg_focused 
        else 
            self.config.input_bg_unfocused;

        if (@hasDecl(@TypeOf(renderer), "drawRect")) {
            renderer.drawRect(layout.input_area, bg_color);
        }

        // Draw input border if enabled
        if (self.config.show_input_border and content.is_focused) {
            try self.drawBorder(renderer, layout.input_area, self.config.input_border, 1.0);
        }

        // Render input text
        try self.renderInputText(renderer, layout, content, font_size, char_width);
    }

    /// Render input text (prompt + current input + cursor)
    fn renderInputText(
        self: *const Self,
        renderer: anytype,
        layout: TerminalLayout,
        content: TerminalContent,
        font_size: f32,
        char_width: f32,
    ) !void {
        const text_x = layout.text_area.position.x;
        const text_y = layout.text_area.position.y;

        // Render prompt
        try self.renderText(renderer, content.prompt, text_x, text_y, font_size, self.config.text_color);
        const prompt_width = @as(f32, @floatFromInt(content.prompt.len)) * char_width;

        // Render current input
        try self.renderText(renderer, content.current_input, text_x + prompt_width, text_y, font_size, self.config.text_color);

        // Render cursor if enabled and focused
        if (self.config.show_cursor and content.is_focused and content.cursor.visible) {
            const cursor_x = text_x + prompt_width + @as(f32, @floatFromInt(content.cursor.x)) * char_width;
            const cursor_rect = Rectangle{
                .position = Vec2{ .x = cursor_x, .y = text_y },
                .size = Vec2{ .x = char_width, .y = layout.text_area.size.y },
            };

            if (@hasDecl(@TypeOf(renderer), "drawRect")) {
                renderer.drawRect(cursor_rect, self.config.text_color);
            }
        }
    }

    /// Render terminal content from top to bottom
    fn renderContentTopDown(
        self: *const Self,
        renderer: anytype,
        layout: TerminalLayout,
        content: TerminalContent,
        line_spacing: f32,
        font_size: f32,
    ) !void {
        var render_index: usize = 0;
        var render_y = layout.content_top;

        while (content.lines.next()) |line| {
            if (render_index >= layout.max_content_lines) break;
            if (render_y + line_spacing > layout.content_bottom) break;

            const line_text = line.getText();
            if (line_text.len == 0) continue;

            try self.renderText(renderer, line_text, layout.content_area.position.x, render_y, font_size, self.config.text_color);
            render_y += line_spacing;
            render_index += 1;
        }
    }

    /// Render terminal content from bottom to top
    fn renderContentBottomUp(
        self: *const Self,
        renderer: anytype,
        layout: TerminalLayout,
        content: TerminalContent,
        line_spacing: f32,
        font_size: f32,
    ) !void {
        // Collect all lines first to render in correct order (newest closest to input)
        // Use a stack-allocated buffer sized by configuration
        var lines_buffer_storage: [500][]const u8 = undefined; // Large enough for most use cases
        const buffer_size = @min(self.config.max_lines_buffer, lines_buffer_storage.len);
        const lines_buffer = lines_buffer_storage[0..buffer_size];
        var lines_count: usize = 0;

        // Collect lines from iterator
        while (content.lines.next()) |line| {
            if (lines_count >= lines_buffer.len) break;  // Prevent overflow
            if (lines_count >= layout.max_content_lines) break;

            const line_text = line.getText();
            if (line_text.len == 0) continue;

            lines_buffer[lines_count] = line_text;
            lines_count += 1;
        }

        // Render lines in reverse order (newest first, closest to input)
        var render_y = layout.content_bottom - line_spacing;
        var i: usize = lines_count;
        while (i > 0) {
            i -= 1;
            if (render_y < layout.content_top) break;

            try self.renderText(renderer, lines_buffer[i], layout.content_area.position.x, render_y, font_size, self.config.text_color);
            render_y -= line_spacing;
        }
    }

    /// Draw border around a rectangle
    fn drawBorder(
        self: *const Self,
        renderer: anytype,
        rect: Rectangle,
        color: Color,
        width: f32,
    ) !void {
        _ = self;

        if (@hasDecl(@TypeOf(renderer), "drawRect")) {
            // Top border
            renderer.drawRect(Rectangle{
                .position = rect.position,
                .size = Vec2{ .x = rect.size.x, .y = width },
            }, color);
            // Bottom border
            renderer.drawRect(Rectangle{
                .position = Vec2{ .x = rect.position.x, .y = rect.position.y + rect.size.y - width },
                .size = Vec2{ .x = rect.size.x, .y = width },
            }, color);
            // Left border
            renderer.drawRect(Rectangle{
                .position = rect.position,
                .size = Vec2{ .x = width, .y = rect.size.y },
            }, color);
            // Right border
            renderer.drawRect(Rectangle{
                .position = Vec2{ .x = rect.position.x + rect.size.x - width, .y = rect.position.y },
                .size = Vec2{ .x = width, .y = rect.size.y },
            }, color);
        }
    }

    /// Render text using available renderer methods
    fn renderText(
        self: *const Self,
        renderer: anytype,
        text: []const u8,
        x: f32,
        y: f32,
        font_size: f32,
        color: Color,
    ) !void {
        _ = self;

        // Try persistent text rendering first (better performance)
        if (@hasDecl(@TypeOf(renderer), "queuePersistentText")) {
            renderer.queuePersistentText(text, Vec2{ .x = x, .y = y }, null, .sans, font_size, color) catch |err| {
                // Fallback to immediate mode on error
                if (@hasDecl(@TypeOf(renderer), "drawText")) {
                    renderer.drawText(text, x, y, font_size, color);
                } else {
                    _ = err; // Silence unused error
                }
            };
        } else if (@hasDecl(@TypeOf(renderer), "drawText")) {
            renderer.drawText(text, x, y, font_size, color);
        }
    }

    /// Create with default configuration
    pub fn createDefault() Self {
        return Self.init(TerminalLayoutConfig{});
    }
};

/// Layout calculation results
const TerminalLayout = struct {
    bounds: Rectangle,
    content_area: Rectangle,
    input_area: Rectangle,
    text_area: Rectangle,
    max_content_lines: usize,
    content_top: f32,
    content_bottom: f32,
};

// Tests
test "TerminalLayoutConfig buffer size configuration" {
    const testing = std.testing;
    
    // Test default configuration
    const default_config = TerminalLayoutConfig{};
    try testing.expect(default_config.max_lines_buffer == 200);
    
    // Test custom configuration
    const custom_config = TerminalLayoutConfig{ .max_lines_buffer = 500 };
    try testing.expect(custom_config.max_lines_buffer == 500);
}

test "TerminalLayoutRenderer layout calculation" {
    const testing = std.testing;
    
    const renderer = TerminalLayoutRenderer.initDefault();
    const bounds = Rectangle{
        .position = Vec2{ .x = 0, .y = 0 },
        .size = Vec2{ .x = 400, .y = 300 },
    };
    
    const layout = renderer.calculateLayout(bounds, 16.0, 20.0);
    
    // Check that input area is at the bottom
    try testing.expect(layout.input_area.position.y > layout.content_area.position.y);
    
    // Check that content area respects margins
    try testing.expect(layout.content_area.position.x == renderer.config.side_margin);
    try testing.expect(layout.content_area.position.y == renderer.config.top_margin);
    
    // Check that spacing between content and input is small
    const gap = layout.input_area.position.y - (layout.content_area.position.y + layout.content_area.size.y);
    try testing.expect(gap == renderer.config.content_to_input_spacing);
}