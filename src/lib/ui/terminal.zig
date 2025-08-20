const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const reactive = @import("../reactive/mod.zig");
const loggers = @import("../debug/loggers.zig");
const input = @import("../platform/input.zig");
const sdl = @import("../platform/sdl.zig");
const terminal_mod = @import("../terminal/mod.zig");
const text_renderer = @import("../text/renderer.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;
const Color = colors.Color;
const InputState = input.InputState;
const CommandTerminal = terminal_mod.presets.CommandTerminal;
const Key = terminal_mod.kernel.Key;
const TextRenderer = text_renderer.TextRenderer;

/// Reactive terminal UI component
pub const TerminalComponent = struct {
    // Core
    allocator: std.mem.Allocator,
    terminal: CommandTerminal,

    // Reactive state
    bounds: reactive.Signal(Rectangle),
    font_size: reactive.Signal(f32),
    line_height: reactive.Signal(f32),
    char_width: reactive.Signal(f32),

    // Colors
    background_color: reactive.Signal(Color),
    text_color: reactive.Signal(Color),
    cursor_color: reactive.Signal(Color),
    selection_color: reactive.Signal(Color),

    // State
    visible_rows: reactive.Signal(usize),
    visible_columns: reactive.Signal(usize),
    scroll_offset: reactive.Signal(usize),
    is_focused: reactive.Signal(bool),

    // Input state
    last_key_time: f32 = 0.0,
    key_repeat_delay: f32 = 0.5, // Initial delay before repeat
    key_repeat_rate: f32 = 0.05, // Repeat rate after initial delay
    current_key: ?Key = null,

    const Self = @This();

    /// Initialize terminal component
    pub fn init(allocator: std.mem.Allocator, bounds: Rectangle) !Self {
        // Initialize all reactive signals first, then create the component
        const bounds_signal = try reactive.signal(allocator, Rectangle, bounds);
        const font_size_signal = try reactive.signal(allocator, f32, 14.0);
        const line_height_signal = try reactive.signal(allocator, f32, 18.0);
        const char_width_signal = try reactive.signal(allocator, f32, 8.0);

        const background_color_signal = try reactive.signal(allocator, Color, Color{ .r = 0, .g = 0, .b = 0, .a = 255 });
        const text_color_signal = try reactive.signal(allocator, Color, Color{ .r = 255, .g = 255, .b = 255, .a = 255 });
        const cursor_color_signal = try reactive.signal(allocator, Color, Color{ .r = 255, .g = 255, .b = 255, .a = 255 });
        const selection_color_signal = try reactive.signal(allocator, Color, Color{ .r = 60, .g = 100, .b = 160, .a = 128 });

        const visible_rows_signal = try reactive.signal(allocator, usize, 24);
        const visible_columns_signal = try reactive.signal(allocator, usize, 80);
        const scroll_offset_signal = try reactive.signal(allocator, usize, 0);
        const is_focused_signal = try reactive.signal(allocator, bool, true);

        var component = Self{
            .allocator = allocator,
            .terminal = try CommandTerminal.init(allocator),
            .bounds = bounds_signal,
            .font_size = font_size_signal,
            .line_height = line_height_signal,
            .char_width = char_width_signal,

            .background_color = background_color_signal,
            .text_color = text_color_signal,
            .cursor_color = cursor_color_signal,
            .selection_color = selection_color_signal,

            .visible_rows = visible_rows_signal,
            .visible_columns = visible_columns_signal,
            .scroll_offset = scroll_offset_signal,
            .is_focused = is_focused_signal,
        };

        // Calculate visible dimensions based on bounds and font
        component.updateDimensions();

        return component;
    }

    /// Cleanup terminal component
    pub fn deinit(self: *Self) void {
        self.terminal.deinit();
        self.bounds.deinit();
        self.font_size.deinit();
        self.line_height.deinit();
        self.char_width.deinit();
        self.background_color.deinit();
        self.text_color.deinit();
        self.cursor_color.deinit();
        self.selection_color.deinit();
        self.visible_rows.deinit();
        self.visible_columns.deinit();
        self.scroll_offset.deinit();
        self.is_focused.deinit();
    }

    /// Update terminal component (called each frame)
    pub fn update(self: *Self, dt: f32) void {
        self.terminal.update(dt) catch {};

        // Handle key repeat
        if (self.current_key) |key| {
            self.last_key_time += dt;
            const delay = if (self.last_key_time < self.key_repeat_delay) self.key_repeat_delay else self.key_repeat_rate;

            if (self.last_key_time >= delay) {
                self.terminal.handleKey(key) catch {};
                self.last_key_time = 0.0;
            }
        }

        // Update dimensions if bounds changed
        self.updateDimensions();

        // Update terminal engine dimensions
        const rows = self.visible_rows.get();
        const cols = self.visible_columns.get();
        self.terminal.resize(cols, rows) catch {};
    }

    /// Render terminal content
    pub fn render(self: *const Self, renderer: anytype) !void {
        const bounds_rect = self.bounds.get();
        const bg_color = self.background_color.get();

        // Draw background
        if (@hasDecl(@TypeOf(renderer), "drawRect")) {
            try renderer.drawRect(bounds_rect, bg_color);
        }

        // Get visible content from terminal engine
        const content = self.terminal.getVisibleContent();
        const line_height = self.line_height.get();
        const char_width = self.char_width.get();
        const text_color = self.text_color.get();

        // Improved spacing and margins
        const bottom_margin: f32 = 12; // More bottom margin
        const top_margin: f32 = 8;
        const side_margin: f32 = 8;
        const line_spacing: f32 = line_height * 1.2; // 20% more spacing between lines
        const input_padding: f32 = 4; // Padding inside input area

        // Start from bottom of the terminal, leaving space for proper margins
        const bottom_y = bounds_rect.position.y + bounds_rect.size.y - bottom_margin;
        const input_height = line_height + (input_padding * 2); // Input with padding
        var current_y = bottom_y - input_height;

        // First render the input background with styling
        const input_y = current_y;
        const input_bg_rect = Rectangle{
            .position = Vec2{ .x = bounds_rect.position.x + side_margin, .y = input_y },
            .size = Vec2{ .x = bounds_rect.size.x - (side_margin * 2), .y = input_height },
        };

        // Draw input background - slightly different color when focused
        const input_bg_color = if (self.is_focused.get())
            Color{ .r = 30, .g = 35, .b = 40, .a = 255 } // Slightly lighter when focused
        else
            Color{ .r = 15, .g = 20, .b = 25, .a = 255 }; // Darker when not focused

        if (@hasDecl(@TypeOf(renderer), "drawRect")) {
            try renderer.drawRect(input_bg_rect, input_bg_color);
        }

        // Render input border when focused
        if (self.is_focused.get()) {
            const border_color = Color{ .r = 70, .g = 130, .b = 180, .a = 255 }; // Blue border
            const border_width: f32 = 1;

            if (@hasDecl(@TypeOf(renderer), "drawRect")) {
                // Top border
                try renderer.drawRect(Rectangle{
                    .position = input_bg_rect.position,
                    .size = Vec2{ .x = input_bg_rect.size.x, .y = border_width },
                }, border_color);
                // Bottom border
                try renderer.drawRect(Rectangle{
                    .position = Vec2{ .x = input_bg_rect.position.x, .y = input_bg_rect.position.y + input_bg_rect.size.y - border_width },
                    .size = Vec2{ .x = input_bg_rect.size.x, .y = border_width },
                }, border_color);
                // Left border
                try renderer.drawRect(Rectangle{
                    .position = input_bg_rect.position,
                    .size = Vec2{ .x = border_width, .y = input_bg_rect.size.y },
                }, border_color);
                // Right border
                try renderer.drawRect(Rectangle{
                    .position = Vec2{ .x = input_bg_rect.position.x + input_bg_rect.size.x - border_width, .y = input_bg_rect.position.y },
                    .size = Vec2{ .x = border_width, .y = input_bg_rect.size.y },
                }, border_color);
            }
        }

        // Render input text with padding
        const text_y = input_y + input_padding;
        const text_x = bounds_rect.position.x + side_margin + input_padding;

        // Show prompt
        const prompt = try self.getPrompt();
        defer self.allocator.free(prompt);

        try self.renderLine(renderer, prompt, text_x, text_y, text_color);
        const prompt_width = @as(f32, @floatFromInt(prompt.len)) * char_width;

        try self.renderLine(renderer, content.current, text_x + prompt_width, text_y, text_color);

        // Render cursor for input line
        if (self.is_focused.get() and content.cursor.visible) {
            const cursor_x = text_x + prompt_width + @as(f32, @floatFromInt(content.cursor.x)) * char_width;
            const cursor_rect = Rectangle{
                .position = Vec2{ .x = cursor_x, .y = text_y },
                .size = Vec2{ .x = char_width, .y = line_height },
            };

            if (@hasDecl(@TypeOf(renderer), "drawRect")) {
                try renderer.drawRect(cursor_rect, self.cursor_color.get());
            }
        }

        // Now render scrollback lines going upward from the input line with better spacing
        // TODO: Improve scrollback rendering design to be more efficient and explicit (viewport-aware)
        // Simple approach: render lines as they come from iterator (newest at bottom)

        var lines_iter = content.lines;
        while (lines_iter.next()) |line| {
            // Move up with proper line spacing
            current_y -= line_spacing;

            // Stop if we've reached the top of the terminal bounds
            if (current_y < bounds_rect.position.y + top_margin) break;

            try self.renderLine(renderer, line.getText(), bounds_rect.position.x + side_margin, current_y, text_color);
        }
    }

    /// Handle keyboard input
    pub fn handleInput(self: *Self, input_state: *const InputState, dt: f32) !bool {
        _ = dt;

        if (!self.is_focused.get()) return false;

        var handled = false;

        // Convert SDL scancodes to terminal keys

        // Check for key presses
        if (input_state.isKeyDown(sdl.sdl.SDL_SCANCODE_RETURN)) {
            try self.processKey(.enter);
            handled = true;
        }

        if (input_state.isKeyDown(sdl.sdl.SDL_SCANCODE_BACKSPACE)) {
            try self.processKey(.backspace);
            handled = true;
        }

        if (input_state.isKeyDown(sdl.sdl.SDL_SCANCODE_DELETE)) {
            try self.processKey(.delete);
            handled = true;
        }

        if (input_state.isKeyDown(sdl.sdl.SDL_SCANCODE_TAB)) {
            try self.processKey(.tab);
            handled = true;
        }

        if (input_state.isKeyDown(sdl.sdl.SDL_SCANCODE_UP)) {
            try self.processKey(.up_arrow);
            handled = true;
        }

        if (input_state.isKeyDown(sdl.sdl.SDL_SCANCODE_DOWN)) {
            try self.processKey(.down_arrow);
            handled = true;
        }

        if (input_state.isKeyDown(sdl.sdl.SDL_SCANCODE_LEFT)) {
            try self.processKey(.left_arrow);
            handled = true;
        }

        if (input_state.isKeyDown(sdl.sdl.SDL_SCANCODE_RIGHT)) {
            try self.processKey(.right_arrow);
            handled = true;
        }

        if (input_state.isKeyDown(sdl.sdl.SDL_SCANCODE_HOME)) {
            try self.processKey(.home);
            handled = true;
        }

        if (input_state.isKeyDown(sdl.sdl.SDL_SCANCODE_END)) {
            try self.processKey(.end);
            handled = true;
        }

        if (input_state.isKeyDown(sdl.sdl.SDL_SCANCODE_PAGEUP)) {
            try self.processKey(.page_up);
            handled = true;
        }

        if (input_state.isKeyDown(sdl.sdl.SDL_SCANCODE_PAGEDOWN)) {
            try self.processKey(.page_down);
            handled = true;
        }

        // Ctrl combinations
        if (input_state.isCtrlHeld()) {
            if (input_state.isKeyDown(sdl.sdl.SDL_SCANCODE_C)) {
                try self.processKey(.ctrl_c);
                handled = true;
            }
            if (input_state.isKeyDown(sdl.sdl.SDL_SCANCODE_L)) {
                try self.processKey(.ctrl_l);
                handled = true;
            }
            if (input_state.isKeyDown(sdl.sdl.SDL_SCANCODE_D)) {
                try self.processKey(.ctrl_d);
                handled = true;
            }
            if (input_state.isKeyDown(sdl.sdl.SDL_SCANCODE_Z)) {
                try self.processKey(.ctrl_z);
                handled = true;
            }
        }

        // Handle printable characters
        // This is a simplified version - in a real implementation, we'd need proper text input handling
        for (0..255) |scancode_int| {
            const scancode: u32 = @intCast(scancode_int);
            if (input_state.isKeyDown(scancode)) {
                if (self.scancodeToChar(scancode, input_state.isShiftHeld())) |ch| {
                    try self.processKey(Key{ .char = ch });
                    handled = true;
                    break; // Handle only one character per frame
                }
            }
        }

        return handled;
    }

    /// Handle text input (for proper Unicode support)
    pub fn handleTextInput(self: *Self, text: []const u8) !void {
        for (text) |ch| {
            if (ch >= 32 and ch <= 126) { // Printable ASCII
                try self.processKey(Key{ .char = ch });
            }
        }
    }

    /// Execute a command
    pub fn executeCommand(self: *Self, command: []const u8) !void {
        try self.terminal.executeCommand(command);
    }

    /// Clear terminal
    pub fn clear(self: *Self) void {
        self.terminal.clear();
    }

    /// Set focus state
    pub fn setFocus(self: *Self, focused: bool) void {
        const ui_log = loggers.getUILog();
        const old_focus = self.is_focused.get();
        ui_log.info("terminal_focus", "Focus change: {} -> {}", .{ old_focus, focused });
        self.is_focused.set(focused);
    }

    /// Get current working directory
    pub fn getWorkingDirectory(self: *const Self) []const u8 {
        return self.terminal.getWorkingDirectory();
    }

    /// Set bounds for terminal component
    pub fn setBounds(self: *Self, bounds: Rectangle) void {
        self.bounds.set(bounds);
        self.updateDimensions();
    }

    /// Handle key press with repeat logic (internal method)
    fn processKey(self: *Self, key: Key) !void {
        try self.terminal.handleKey(key);
        self.current_key = key;
        self.last_key_time = 0.0;
    }

    /// Handle key release
    pub fn handleKeyRelease(self: *Self, key: Key) void {
        if (self.current_key) |current| {
            if (std.meta.eql(current, key)) {
                self.current_key = null;
            }
        }
    }

    /// Handle SDL keyboard event directly (called from HUD)
    pub fn handleKeyPress(self: *Self, key_event: sdl.sdl.SDL_KeyboardEvent) bool {
        const ui_log = loggers.getUILog();

        ui_log.info("terminal_input", "Terminal handleKeyPress called - scancode: {d}, focused: {}", .{ key_event.scancode, self.is_focused.get() });

        if (!self.is_focused.get()) {
            ui_log.warn("terminal_input", "Terminal not focused, ignoring key input", .{});
            return false;
        }

        // Convert SDL key event to terminal key
        var handled = false;

        switch (key_event.scancode) {
            sdl.sdl.SDL_SCANCODE_RETURN => {
                self.terminal.handleKey(.enter) catch {};
                handled = true;
            },
            sdl.sdl.SDL_SCANCODE_BACKSPACE => {
                self.terminal.handleKey(.backspace) catch {};
                handled = true;
            },
            sdl.sdl.SDL_SCANCODE_DELETE => {
                self.terminal.handleKey(.delete) catch {};
                handled = true;
            },
            sdl.sdl.SDL_SCANCODE_TAB => {
                self.terminal.handleKey(.tab) catch {};
                handled = true;
            },
            sdl.sdl.SDL_SCANCODE_UP => {
                self.terminal.handleKey(.up_arrow) catch {};
                handled = true;
            },
            sdl.sdl.SDL_SCANCODE_DOWN => {
                self.terminal.handleKey(.down_arrow) catch {};
                handled = true;
            },
            sdl.sdl.SDL_SCANCODE_LEFT => {
                self.terminal.handleKey(.left_arrow) catch {};
                handled = true;
            },
            sdl.sdl.SDL_SCANCODE_RIGHT => {
                self.terminal.handleKey(.right_arrow) catch {};
                handled = true;
            },
            else => {
                // Check for printable characters
                const shift_held = (key_event.mod & sdl.sdl.SDL_KMOD_SHIFT) != 0;

                if (self.scancodeToChar(key_event.scancode, shift_held)) |ch| {
                    ui_log.info("terminal_input", "Character input: '{c}' (ASCII {d})", .{ ch, ch });
                    self.terminal.handleKey(Key{ .char = ch }) catch {};
                    handled = true;
                } else {
                    ui_log.warn("terminal_input", "Unknown scancode: {d} (shift: {})", .{ key_event.scancode, shift_held });
                }
            },
        }

        return handled;
    }

    /// Handle click to set focus
    pub fn handleClick(self: *Self, point: Vec2) bool {
        _ = point; // For now, any click in terminal area sets focus
        self.setFocus(true);
        return true;
    }

    /// Update visible dimensions based on current bounds and font settings
    fn updateDimensions(self: *Self) void {
        const bounds_rect = self.bounds.get();
        const line_height = self.line_height.get();
        const char_width = self.char_width.get();

        const available_height = bounds_rect.size.y - 8; // Margins
        const available_width = bounds_rect.size.x - 8;

        const rows = @max(1, @as(usize, @intFromFloat(available_height / line_height)));
        const cols = @max(1, @as(usize, @intFromFloat(available_width / char_width)));

        self.visible_rows.set(rows);
        self.visible_columns.set(cols);
    }

    /// Render a single line of text using persistent rendering when available
    fn renderLine(self: *const Self, renderer: anytype, text: []const u8, x: f32, y: f32, color: Color) !void {
        // Prefer persistent text rendering for better performance
        if (@hasDecl(@TypeOf(renderer), "queuePersistentText")) {
            // Use persistent/retained mode rendering for stable text
            renderer.queuePersistentText(text, Vec2{ .x = x, .y = y }, null, .sans, self.font_size.get(), color) catch |err| {
                // Fallback to immediate mode on error
                if (@hasDecl(@TypeOf(renderer), "drawText")) {
                    try renderer.drawText(text, x, y, self.font_size.get(), color);
                } else {
                    _ = err; // Silence unused error
                }
            };
        } else if (@hasDecl(@TypeOf(renderer), "drawText")) {
            // Fallback to immediate mode for renderers without persistent text
            try renderer.drawText(text, x, y, self.font_size.get(), color);
        }
    }

    /// Get command prompt string
    fn getPrompt(self: *const Self) ![]u8 {
        const cwd = self.terminal.getWorkingDirectory();

        // Extract directory name from full path
        const dir_name = if (std.fs.path.basename(cwd).len > 0)
            std.fs.path.basename(cwd)
        else
            cwd;

        return std.fmt.allocPrint(self.allocator, "{s}$ ", .{dir_name});
    }

    /// Convert SDL scancode to ASCII character
    fn scancodeToChar(self: *const Self, scancode: u32, shift_held: bool) ?u8 {
        _ = self;

        return switch (scancode) {
            sdl.sdl.SDL_SCANCODE_A => if (shift_held) 'A' else 'a',
            sdl.sdl.SDL_SCANCODE_B => if (shift_held) 'B' else 'b',
            sdl.sdl.SDL_SCANCODE_C => if (shift_held) 'C' else 'c',
            sdl.sdl.SDL_SCANCODE_D => if (shift_held) 'D' else 'd',
            sdl.sdl.SDL_SCANCODE_E => if (shift_held) 'E' else 'e',
            sdl.sdl.SDL_SCANCODE_F => if (shift_held) 'F' else 'f',
            sdl.sdl.SDL_SCANCODE_G => if (shift_held) 'G' else 'g',
            sdl.sdl.SDL_SCANCODE_H => if (shift_held) 'H' else 'h',
            sdl.sdl.SDL_SCANCODE_I => if (shift_held) 'I' else 'i',
            sdl.sdl.SDL_SCANCODE_J => if (shift_held) 'J' else 'j',
            sdl.sdl.SDL_SCANCODE_K => if (shift_held) 'K' else 'k',
            sdl.sdl.SDL_SCANCODE_L => if (shift_held) 'L' else 'l',
            sdl.sdl.SDL_SCANCODE_M => if (shift_held) 'M' else 'm',
            sdl.sdl.SDL_SCANCODE_N => if (shift_held) 'N' else 'n',
            sdl.sdl.SDL_SCANCODE_O => if (shift_held) 'O' else 'o',
            sdl.sdl.SDL_SCANCODE_P => if (shift_held) 'P' else 'p',
            sdl.sdl.SDL_SCANCODE_Q => if (shift_held) 'Q' else 'q',
            sdl.sdl.SDL_SCANCODE_R => if (shift_held) 'R' else 'r',
            sdl.sdl.SDL_SCANCODE_S => if (shift_held) 'S' else 's',
            sdl.sdl.SDL_SCANCODE_T => if (shift_held) 'T' else 't',
            sdl.sdl.SDL_SCANCODE_U => if (shift_held) 'U' else 'u',
            sdl.sdl.SDL_SCANCODE_V => if (shift_held) 'V' else 'v',
            sdl.sdl.SDL_SCANCODE_W => if (shift_held) 'W' else 'w',
            sdl.sdl.SDL_SCANCODE_X => if (shift_held) 'X' else 'x',
            sdl.sdl.SDL_SCANCODE_Y => if (shift_held) 'Y' else 'y',
            sdl.sdl.SDL_SCANCODE_Z => if (shift_held) 'Z' else 'z',

            sdl.sdl.SDL_SCANCODE_1 => if (shift_held) '!' else '1',
            sdl.sdl.SDL_SCANCODE_2 => if (shift_held) '@' else '2',
            sdl.sdl.SDL_SCANCODE_3 => if (shift_held) '#' else '3',
            sdl.sdl.SDL_SCANCODE_4 => if (shift_held) '$' else '4',
            sdl.sdl.SDL_SCANCODE_5 => if (shift_held) '%' else '5',
            sdl.sdl.SDL_SCANCODE_6 => if (shift_held) '^' else '6',
            sdl.sdl.SDL_SCANCODE_7 => if (shift_held) '&' else '7',
            sdl.sdl.SDL_SCANCODE_8 => if (shift_held) '*' else '8',
            sdl.sdl.SDL_SCANCODE_9 => if (shift_held) '(' else '9',
            sdl.sdl.SDL_SCANCODE_0 => if (shift_held) ')' else '0',

            sdl.sdl.SDL_SCANCODE_SPACE => ' ',
            sdl.sdl.SDL_SCANCODE_MINUS => if (shift_held) '_' else '-',
            sdl.sdl.SDL_SCANCODE_EQUALS => if (shift_held) '+' else '=',
            sdl.sdl.SDL_SCANCODE_LEFTBRACKET => if (shift_held) '{' else '[',
            sdl.sdl.SDL_SCANCODE_RIGHTBRACKET => if (shift_held) '}' else ']',
            sdl.sdl.SDL_SCANCODE_BACKSLASH => if (shift_held) '|' else '\\',
            sdl.sdl.SDL_SCANCODE_SEMICOLON => if (shift_held) ':' else ';',
            sdl.sdl.SDL_SCANCODE_APOSTROPHE => if (shift_held) '"' else '\'',
            sdl.sdl.SDL_SCANCODE_GRAVE => if (shift_held) '~' else '`',
            sdl.sdl.SDL_SCANCODE_COMMA => if (shift_held) '<' else ',',
            sdl.sdl.SDL_SCANCODE_PERIOD => if (shift_held) '>' else '.',
            sdl.sdl.SDL_SCANCODE_SLASH => if (shift_held) '?' else '/',

            else => null,
        };
    }
};
