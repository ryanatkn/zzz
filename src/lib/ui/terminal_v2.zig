/// Enhanced terminal UI component using new rendering components
const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const reactive = @import("../reactive/mod.zig");
const input = @import("../platform/input.zig");
const terminal_mod = @import("../terminal/mod.zig");

// New rendering components
const terminal_renderer = @import("terminal_renderer.zig");
const scrollable_terminal = @import("scrollable_terminal.zig");
const focusable_border = @import("focusable_border.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;
const Color = colors.Color;
const InputState = input.InputState;
const TerminalEngine = terminal_mod.TerminalEngine;
const Key = terminal_mod.Key;

const TerminalRenderer = terminal_renderer.TerminalRenderer;
const TerminalContent = terminal_renderer.TerminalContent;
const ScrollableTerminal = scrollable_terminal.ScrollableTerminal;
const FocusableBorder = focusable_border.FocusableBorder;

/// Enhanced terminal component with better rendering and error handling
pub const TerminalComponentV2 = struct {
    // Core
    allocator: std.mem.Allocator,
    terminal_engine: TerminalEngine,
    
    // New rendering components
    scrollable_terminal: ?*ScrollableTerminal = null,
    
    // Reactive state
    bounds: reactive.Signal(Rectangle),
    is_focused: reactive.Signal(bool),
    header_text: reactive.Signal(?[]const u8),
    
    // Input handling
    last_key_time: f32 = 0.0,
    key_repeat_delay: f32 = 0.5,
    key_repeat_rate: f32 = 0.05,
    current_key: ?Key = null,
    
    const Self = @This();
    
    /// Initialize enhanced terminal component
    pub fn init(allocator: std.mem.Allocator, bounds: Rectangle) !Self {
        const bounds_signal = try reactive.signal(allocator, Rectangle, bounds);
        const is_focused_signal = try reactive.signal(allocator, bool, false);
        const header_text_signal = try reactive.signal(allocator, ?[]const u8, "TERMINAL");
        
        var component = Self{
            .allocator = allocator,
            .terminal_engine = try TerminalEngine.init(allocator),
            .bounds = bounds_signal,
            .is_focused = is_focused_signal,
            .header_text = header_text_signal,
        };
        
        // Initialize scrollable terminal component
        try component.initScrollableTerminal();
        
        return component;
    }
    
    /// Initialize the scrollable terminal component
    fn initScrollableTerminal(self: *Self) !void {
        const bounds_rect = self.bounds.get();
        self.scrollable_terminal = try scrollable_terminal.createScrollableTerminal(self.allocator, bounds_rect);
        
        // Initialize border for focus indication
        try self.scrollable_terminal.?.initBorder(bounds_rect);
        
        // Set initial content
        self.updateTerminalContent();
    }
    
    /// Cleanup terminal component
    pub fn deinit(self: *Self) void {
        if (self.scrollable_terminal) |st| {
            st.base.base.vtable.destroy(&st.base.base, self.allocator);
        }
        
        self.terminal_engine.deinit();
        self.bounds.deinit();
        self.is_focused.deinit();
        self.header_text.deinit();
    }
    
    /// Update terminal component (called each frame)
    pub fn update(self: *Self, dt: f32) void {
        // Update terminal engine
        self.terminal_engine.update(dt);
        
        // Handle key repeat
        if (self.current_key) |key| {
            self.last_key_time += dt;
            const delay = if (self.last_key_time < self.key_repeat_delay) self.key_repeat_delay else self.key_repeat_rate;
            
            if (self.last_key_time >= delay) {
                self.terminal_engine.handleKey(key) catch {};
                self.last_key_time = 0.0;
                self.updateTerminalContent();
            }
        }
        
        // Update scrollable terminal if initialized
        if (self.scrollable_terminal) |st| {
            st.base.base.vtable.update(&st.base.base, dt);
            
            // Sync focus state
            st.setFocus(self.is_focused.get());
            
            // Update header text
            st.setHeaderText(self.header_text.get());
            
            // Update bounds if changed
            const current_bounds = self.bounds.get();
            st.base.base.props.bounds.set(current_bounds);
        }
        
        // Update terminal engine dimensions
        self.updateDimensions();
    }
    
    /// Render terminal using new components
    pub fn render(self: *const Self, renderer: anytype) !void {
        if (self.scrollable_terminal) |st| {
            try st.base.base.vtable.render(&st.base.base, renderer);
        }
    }
    
    /// Handle SDL keyboard event directly
    pub fn handleKeyPress(self: *Self, key_event: @import("../platform/sdl.zig").sdl.SDL_KeyboardEvent) bool {
        if (!self.is_focused.get()) return false;
        
        const sdl = @import("../platform/sdl.zig");
        
        // Convert SDL key event to terminal key
        var handled = false;
        
        switch (key_event.scancode) {
            sdl.sdl.SDL_SCANCODE_RETURN => {
                self.processKeyWithUpdate(.enter) catch {};
                handled = true;
            },
            sdl.sdl.SDL_SCANCODE_BACKSPACE => {
                self.processKeyWithUpdate(.backspace) catch {};
                handled = true;
            },
            sdl.sdl.SDL_SCANCODE_DELETE => {
                self.processKeyWithUpdate(.delete) catch {};
                handled = true;
            },
            sdl.sdl.SDL_SCANCODE_TAB => {
                self.processKeyWithUpdate(.tab) catch {};
                handled = true;
            },
            sdl.sdl.SDL_SCANCODE_UP => {
                self.processKeyWithUpdate(.up_arrow) catch {};
                handled = true;
            },
            sdl.sdl.SDL_SCANCODE_DOWN => {
                self.processKeyWithUpdate(.down_arrow) catch {};
                handled = true;
            },
            sdl.sdl.SDL_SCANCODE_LEFT => {
                self.processKeyWithUpdate(.left_arrow) catch {};
                handled = true;
            },
            sdl.sdl.SDL_SCANCODE_RIGHT => {
                self.processKeyWithUpdate(.right_arrow) catch {};
                handled = true;
            },
            sdl.sdl.SDL_SCANCODE_PAGEUP => {
                if (self.scrollable_terminal) |st| {
                    st.scrollUp(5);
                }
                handled = true;
            },
            sdl.sdl.SDL_SCANCODE_PAGEDOWN => {
                if (self.scrollable_terminal) |st| {
                    st.scrollDown(5);
                }
                handled = true;
            },
            else => {
                // Check for printable characters
                const shift_held = (key_event.mod & sdl.sdl.SDL_KMOD_SHIFT) != 0;
                if (self.scancodeToChar(key_event.scancode, shift_held)) |ch| {
                    self.processKeyWithUpdate(Key{ .char = ch }) catch {};
                    handled = true;
                }
            },
        }
        
        return handled;
    }
    
    /// Process key and update terminal content
    fn processKeyWithUpdate(self: *Self, key: Key) !void {
        try self.terminal_engine.handleKey(key);
        self.updateTerminalContent();
    }
    
    /// Update terminal content in scrollable component
    fn updateTerminalContent(self: *Self) void {
        if (self.scrollable_terminal) |st| {
            const content = TerminalContent.fromTerminalEngine(&self.terminal_engine);
            st.setContent(content);
        }
    }
    
    /// Handle click to set focus
    pub fn handleClick(self: *Self, point: Vec2) bool {
        const bounds_rect = self.bounds.get();
        
        // Check if click is within terminal bounds
        if (point.x >= bounds_rect.position.x and 
            point.x <= bounds_rect.position.x + bounds_rect.size.x and
            point.y >= bounds_rect.position.y and 
            point.y <= bounds_rect.position.y + bounds_rect.size.y) {
            
            self.setFocus(true);
            return true;
        }
        
        return false;
    }
    
    /// Set focus state
    pub fn setFocus(self: *Self, focused: bool) void {
        self.is_focused.set(focused);
        
        if (self.scrollable_terminal) |st| {
            st.setFocus(focused);
        }
    }
    
    /// Get current focus state
    pub fn isFocused(self: *const Self) bool {
        return self.is_focused.get();
    }
    
    /// Set bounds
    pub fn setBounds(self: *Self, bounds: Rectangle) void {
        self.bounds.set(bounds);
        
        if (self.scrollable_terminal) |st| {
            st.base.base.props.bounds.set(bounds);
            // Update border bounds as well
            if (st.terminal_renderer.border) |border| {
                var border_bounds = bounds;
                border_bounds.position.x -= 2;
                border_bounds.position.y -= 2;
                border_bounds.size.x += 4;
                border_bounds.size.y += 4;
                border.base.props.bounds.set(border_bounds);
            }
        }
    }
    
    /// Update visible dimensions based on current bounds
    fn updateDimensions(self: *Self) void {
        const bounds_rect = self.bounds.get();
        
        // Calculate terminal dimensions (simplified)
        const line_height = 18.0;
        const char_width = 8.0;
        
        const available_height = bounds_rect.size.y - 16; // Margins
        const available_width = bounds_rect.size.x - 16;
        
        const rows = @max(1, @as(usize, @intFromFloat(available_height / line_height)));
        const cols = @max(1, @as(usize, @intFromFloat(available_width / char_width)));
        
        // Update terminal engine dimensions
        self.terminal_engine.resize(cols, rows);
    }
    
    /// Convert SDL scancode to ASCII character
    fn scancodeToChar(self: *const Self, scancode: u32, shift_held: bool) ?u8 {
        _ = self;
        const sdl = @import("../platform/sdl.zig");
        
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
    
    /// Execute a command directly (for testing)
    pub fn executeCommand(self: *Self, command: []const u8) !void {
        // Write command to terminal
        try self.terminal_engine.write(command);
        try self.terminal_engine.handleKey(.enter);
        self.updateTerminalContent();
    }
    
    /// Get terminal working directory
    pub fn getWorkingDirectory(self: *const Self) []const u8 {
        return self.terminal_engine.getWorkingDirectory();
    }
    
    /// Set header text
    pub fn setHeaderText(self: *Self, text: ?[]const u8) void {
        self.header_text.set(text);
    }
};