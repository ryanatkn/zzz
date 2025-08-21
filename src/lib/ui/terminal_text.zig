/// Safe terminal text rendering component with cursor support
const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const reactive = @import("../reactive/mod.zig");
const terminal_core = @import("../terminal/core.zig");
const text_baseline = @import("../layout/text_baseline.zig");
const font_metrics = @import("../font/font_metrics.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;
const Color = colors.Color;
const Line = terminal_core.Line;
const Cursor = terminal_core.Cursor;
const FontMetrics = font_metrics.FontMetrics;
const TextPositioning = text_baseline.TextPositioning;

pub const CursorStyle = enum {
    block,
    underline,
    vertical_bar,
};

pub const TerminalTextConfig = struct {
    font_size: f32 = 16.0,
    line_height: f32 = 18.0,
    char_width: f32 = 8.0,
    text_color: Color = Color{ .r = 200, .g = 200, .b = 200, .a = 255 },
    cursor_color: Color = Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
    cursor_style: CursorStyle = .block,
    cursor_blink_rate: f32 = 1.0, // blinks per second
    max_line_length: usize = 1000,
    // Font metrics for proper baseline calculations
    font_metrics_info: FontMetrics = FontMetrics.init(
        1000,    // units_per_em
        800,     // ascender
        -200,    // descender
        100,     // line_gap
        0.016    // scale factor for 16pt
    ),
};

pub const TerminalText = struct {
    config: reactive.Signal(TerminalTextConfig),
    cursor_visible: reactive.Signal(bool),
    blink_timer: f32 = 0.0,

    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: TerminalTextConfig) !Self {
        return Self{
            .config = try reactive.signal(allocator, TerminalTextConfig, config),
            .cursor_visible = try reactive.signal(allocator, bool, true),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.config.deinit();
        self.cursor_visible.deinit();
    }

    /// Update cursor blinking
    pub fn update(self: *Self, dt: f32) void {
        self.blink_timer += dt;
        const config = self.config.get();

        // Update cursor visibility based on blink rate
        const blink_period = 1.0 / config.cursor_blink_rate;
        const should_show = @mod(self.blink_timer, blink_period) < (blink_period / 2.0);
        self.cursor_visible.set(should_show);
    }

    /// Render a single terminal line safely
    pub fn renderLine(self: *const Self, renderer: anytype, line: *const Line, position: Vec2, max_width: f32) !void {
        const config = self.config.get();
        const text = line.getText();

        // Safety: Check for valid text
        if (text.len == 0) return;

        // Calculate maximum characters that fit
        const max_chars = @min(text.len, @as(usize, @intFromFloat(max_width / config.char_width)));
        const safe_text = text[0..max_chars];

        // Validate text is printable ASCII for safety
        const display_text = try self.sanitizeText(safe_text);
        defer self.allocator.free(display_text);

        if (display_text.len > 0) {
            try self.renderText(renderer, display_text, position, config.text_color);
        }
    }

    /// Render current input line with prompt and cursor
    pub fn renderInputLine(self: *const Self, renderer: anytype, prompt: []const u8, input: []const u8, cursor: Cursor, position: Vec2, max_width: f32) !void {
        const config = self.config.get();

        // Calculate available space for prompt + input
        const prompt_width = @as(f32, @floatFromInt(prompt.len)) * config.char_width;
        const available_input_width = max_width - prompt_width;

        // Render prompt
        if (prompt.len > 0) {
            try self.renderText(renderer, prompt, position, config.text_color);
        }

        // Calculate input display area
        const input_position = Vec2{ .x = position.x + prompt_width, .y = position.y };
        const max_input_chars = @max(0, @as(usize, @intFromFloat(available_input_width / config.char_width)));

        // Handle input text scrolling for long input
        const display_input = self.getVisibleInput(input, cursor.x, max_input_chars);

        // Render input text
        if (display_input.len > 0) {
            const sanitized_input = try self.sanitizeText(display_input);
            defer self.allocator.free(sanitized_input);
            try self.renderText(renderer, sanitized_input, input_position, config.text_color);
        }

        // Render cursor using proper baseline positioning
        if (cursor.visible and self.cursor_visible.get()) {
            const cursor_char_pos = @min(cursor.x, max_input_chars);
            const cursor_position = TextPositioning.getCursorPosition(
                input_position, 
                cursor_char_pos, 
                config.char_width, 
                config.font_metrics_info
            );
            try self.renderCursor(renderer, cursor_position, config.font_metrics_info);
        }
    }

    /// Render text at specified position with color
    fn renderText(self: *const Self, renderer: anytype, text: []const u8, position: Vec2, color: Color) !void {
        const config = self.config.get();

        if (@hasDecl(@TypeOf(renderer), "drawText")) {
            try renderer.drawText(text, position.x, position.y, config.font_size, color);
        } else if (@hasDecl(@TypeOf(renderer), "drawSimpleText")) {
            try renderer.drawSimpleText(text, position);
        }
    }

    /// Render cursor based on style with proper baseline alignment
    fn renderCursor(self: *const Self, renderer: anytype, position: Vec2, font_metrics_info: FontMetrics) !void {
        const config = self.config.get();

        if (!@hasDecl(@TypeOf(renderer), "drawRect")) return;

        // Calculate cursor height using font metrics
        const cursor_height = TextPositioning.getCursorHeight(font_metrics_info);
        
        const cursor_size = switch (config.cursor_style) {
            .block => Vec2{ .x = config.char_width, .y = cursor_height },
            .underline => Vec2{ .x = config.char_width, .y = 2.0 },
            .vertical_bar => Vec2{ .x = 2.0, .y = cursor_height },
        };

        const cursor_position = switch (config.cursor_style) {
            .block => position,
            .underline => Vec2{ 
                .x = position.x, 
                .y = position.y + cursor_height - 2.0 
            },
            .vertical_bar => position,
        };

        try renderer.drawRect(cursor_position, cursor_size, config.cursor_color);
    }

    /// Get visible portion of input text based on cursor position
    fn getVisibleInput(self: *const Self, input: []const u8, cursor_pos: usize, max_chars: usize) []const u8 {
        _ = self;

        if (input.len <= max_chars) return input;

        // If cursor is near the end, show the end of the string
        if (cursor_pos >= input.len - max_chars / 2) {
            const start = input.len - max_chars;
            return input[start..];
        }

        // If cursor is near the beginning, show the beginning
        if (cursor_pos < max_chars / 2) {
            return input[0..max_chars];
        }

        // Center the cursor in the visible area
        const start = cursor_pos - max_chars / 2;
        const end = @min(start + max_chars, input.len);
        return input[start..end];
    }

    /// Sanitize text to ensure it's safe to render
    fn sanitizeText(self: *const Self, text: []const u8) ![]u8 {
        const config = self.config.get();
        const max_len = @min(text.len, config.max_line_length);

        var result = try self.allocator.alloc(u8, max_len);
        var result_len: usize = 0;

        for (text[0..max_len]) |ch| {
            // Only include printable ASCII characters and common whitespace
            if ((ch >= 32 and ch <= 126) or ch == '\t' or ch == ' ') {
                result[result_len] = ch;
                result_len += 1;
            } else {
                // Replace unprintable characters with '?'
                result[result_len] = '?';
                result_len += 1;
            }
        }

        // Resize to actual length
        result = try self.allocator.realloc(result, result_len);
        return result;
    }

    /// Create with default configuration
    pub fn createDefault(allocator: std.mem.Allocator) !Self {
        return try Self.init(allocator, TerminalTextConfig{});
    }

    /// Set text color
    pub fn setTextColor(self: *Self, color: Color) void {
        var config = self.config.get();
        config.text_color = color;
        self.config.set(config);
    }

    /// Set cursor color
    pub fn setCursorColor(self: *Self, color: Color) void {
        var config = self.config.get();
        config.cursor_color = color;
        self.config.set(config);
    }

    /// Set cursor style
    pub fn setCursorStyle(self: *Self, style: CursorStyle) void {
        var config = self.config.get();
        config.cursor_style = style;
        self.config.set(config);
    }
};
