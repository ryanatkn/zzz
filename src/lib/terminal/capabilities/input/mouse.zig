const std = @import("std");
const kernel = @import("../../kernel/mod.zig");

/// Mouse input capability - handle mouse events in the terminal
pub const MouseInput = struct {
    pub const name = "mouse_input";
    pub const capability_type = "input";
    pub const dependencies = &[_][]const u8{ "ansi_writer" }; // For sending mouse mode sequences
    
    active: bool = false,
    initialized: bool = false,
    
    // Dependencies
    ansi_writer: ?*@import("../output/ansi_writer.zig").AnsiWriter = null,
    
    // Event bus
    event_bus: ?*kernel.EventBus = null,
    allocator: std.mem.Allocator,
    
    // Mouse state
    mouse_mode: MouseMode = .off,
    last_x: u16 = 0,
    last_y: u16 = 0,
    button_state: ButtonState = .{},
    drag_start: ?MousePosition = null,
    
    // Click detection
    last_click_time: i64 = 0,
    last_click_pos: MousePosition = .{ .x = 0, .y = 0 },
    click_count: u8 = 0,
    
    const Self = @This();
    
    pub const MouseMode = enum {
        off,
        click,          // Button press/release events
        drag,           // Button press/release + motion while pressed
        motion,         // All motion events
        sgr,            // SGR extended mode (supports coordinates > 223)
    };
    
    pub const MouseButton = enum {
        left,
        middle,
        right,
        scroll_up,
        scroll_down,
    };
    
    pub const MousePosition = struct {
        x: u16,
        y: u16,
    };
    
    pub const ButtonState = struct {
        left: bool = false,
        middle: bool = false,
        right: bool = false,
    };
    
    pub const MouseEvent = struct {
        button: ?MouseButton,
        action: Action,
        position: MousePosition,
        modifiers: Modifiers = .{},
        
        pub const Action = enum {
            press,
            release,
            move,
            scroll,
            click,
            double_click,
            triple_click,
        };
        
        pub const Modifiers = struct {
            shift: bool = false,
            ctrl: bool = false,
            alt: bool = false,
        };
    };
    
    /// Initialize mouse input
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }
    
    /// Create a new mouse input capability
    pub fn create(allocator: std.mem.Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = Self.init(allocator);
        return self;
    }
    
    /// Destroy mouse input capability
    pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {
        self.deinit();
        allocator.destroy(self);
    }

    /// Get capability name
    pub fn getName(self: *Self) []const u8 {
        _ = self;
        return name;
    }

    /// Get capability type
    pub fn getType(self: *Self) []const u8 {
        _ = self;
        return capability_type;
    }

    /// Get dependencies
    pub fn getDependencies(self: *Self) []const []const u8 {
        _ = self;
        return dependencies;
    }
    
    /// Initialize with dependencies
    pub fn initialize(self: *Self, deps: []const kernel.TypeSafeCapability, event_bus: *kernel.EventBus) !void {
        // Resolve dependencies
        for (deps) |dep| {
            if (dep.cast(@import("../output/ansi_writer.zig").AnsiWriter)) |aw| {
                self.ansi_writer = aw;
            }
        }
        
        // AnsiWriter is optional - we can work without it
        
        self.event_bus = event_bus;
        
        // Subscribe to raw input events for mouse sequence parsing
        try event_bus.subscribe(.input, handleRawInput, self);
        
        self.initialized = true;
        self.active = true;
    }

    /// Deinitialize capability
    pub fn deinit(self: *Self) void {
        // Disable mouse mode if it was enabled
        if (self.mouse_mode != .off and self.ansi_writer != null) {
            self.disableMouseMode() catch {};
        }
        
        self.active = false;
        self.initialized = false;
    }

    /// Check if capability is active
    pub fn isActive(self: *Self) bool {
        return self.active;
    }
    
    /// Enable mouse mode
    pub fn enableMouseMode(self: *Self, mode: MouseMode) !void {
        const writer = self.ansi_writer orelse return error.NoAnsiWriter;
        
        // Disable previous mode
        if (self.mouse_mode != .off) {
            try self.disableMouseMode();
        }
        
        // Enable new mode
        self.mouse_mode = mode;
        
        switch (mode) {
            .off => {},
            .click => {
                // Enable click tracking
                try writer.write("\x1b[?1000h");
            },
            .drag => {
                // Enable click and drag tracking
                try writer.write("\x1b[?1002h");
            },
            .motion => {
                // Enable all motion tracking
                try writer.write("\x1b[?1003h");
            },
            .sgr => {
                // Enable SGR extended mode
                try writer.write("\x1b[?1006h");
            },
        }
    }
    
    /// Disable mouse mode
    pub fn disableMouseMode(self: *Self) !void {
        const writer = self.ansi_writer orelse return error.NoAnsiWriter;
        
        switch (self.mouse_mode) {
            .off => {},
            .click => try writer.write("\x1b[?1000l"),
            .drag => try writer.write("\x1b[?1002l"),
            .motion => try writer.write("\x1b[?1003l"),
            .sgr => try writer.write("\x1b[?1006l"),
        }
        
        self.mouse_mode = .off;
    }
    
    /// Process mouse event
    pub fn processMouseEvent(self: *Self, event: MouseEvent) !void {
        // Update position
        self.last_x = event.position.x;
        self.last_y = event.position.y;
        
        // Update button state
        switch (event.action) {
            .press => {
                if (event.button) |button| {
                    switch (button) {
                        .left => self.button_state.left = true,
                        .middle => self.button_state.middle = true,
                        .right => self.button_state.right = true,
                        else => {},
                    }
                    
                    // Start drag if button pressed
                    if (self.drag_start == null) {
                        self.drag_start = event.position;
                    }
                }
                
                // Check for multi-click
                const now = std.time.milliTimestamp();
                const double_click_time = 500; // ms
                
                if (event.button == .left) {
                    if (now - self.last_click_time < double_click_time and
                        self.last_click_pos.x == event.position.x and
                        self.last_click_pos.y == event.position.y) {
                        self.click_count += 1;
                        if (self.click_count == 2) {
                            // Emit double-click event
                            var double_click = event;
                            double_click.action = .double_click;
                            try self.emitMouseEvent(double_click);
                        } else if (self.click_count == 3) {
                            // Emit triple-click event
                            var triple_click = event;
                            triple_click.action = .triple_click;
                            try self.emitMouseEvent(triple_click);
                            self.click_count = 0; // Reset after triple
                        }
                    } else {
                        self.click_count = 1;
                        // Emit single click
                        var click = event;
                        click.action = .click;
                        try self.emitMouseEvent(click);
                    }
                    
                    self.last_click_time = now;
                    self.last_click_pos = event.position;
                }
            },
            .release => {
                if (event.button) |button| {
                    switch (button) {
                        .left => self.button_state.left = false,
                        .middle => self.button_state.middle = false,
                        .right => self.button_state.right = false,
                        else => {},
                    }
                    
                    // End drag if no buttons pressed
                    if (!self.button_state.left and !self.button_state.middle and !self.button_state.right) {
                        self.drag_start = null;
                    }
                }
            },
            else => {},
        }
        
        // Emit the raw event
        try self.emitMouseEvent(event);
    }
    
    /// Parse X10 mouse protocol
    fn parseX10Mouse(self: *Self, data: []const u8) !void {
        if (data.len < 6) return error.InvalidMouseSequence;
        if (data[0] != '\x1b' or data[1] != '[' or data[2] != 'M') return error.InvalidMouseSequence;
        
        const button_byte = data[3] - 32;
        const x = data[4] - 32;
        const y = data[5] - 32;
        
        var event = MouseEvent{
            .button = null,
            .action = .move,
            .position = .{ .x = x, .y = y },
        };
        
        // Parse button and modifiers
        const button_code = button_byte & 0x03;
        const shift = (button_byte & 0x04) != 0;
        const alt = (button_byte & 0x08) != 0;
        const ctrl = (button_byte & 0x10) != 0;
        
        event.modifiers = .{
            .shift = shift,
            .alt = alt,
            .ctrl = ctrl,
        };
        
        // Decode button
        if ((button_byte & 0x40) != 0) {
            // Scroll events
            if (button_code == 0) {
                event.button = .scroll_up;
                event.action = .scroll;
            } else if (button_code == 1) {
                event.button = .scroll_down;
                event.action = .scroll;
            }
        } else if ((button_byte & 0x20) != 0) {
            // Motion event
            event.action = .move;
        } else {
            // Button press/release
            switch (button_code) {
                0 => event.button = .left,
                1 => event.button = .middle,
                2 => event.button = .right,
                else => {},
            }
            
            // Bit 0x20 indicates release in some modes
            event.action = if ((button_byte & 0x03) == 3) .release else .press;
        }
        
        try self.processMouseEvent(event);
    }
    
    /// Parse SGR mouse protocol
    fn parseSGRMouse(self: *Self, data: []const u8) !void {
        // SGR format: \x1b[<button;x;y;M (press) or m (release)
        if (data.len < 9) return error.InvalidMouseSequence;
        if (data[0] != '\x1b' or data[1] != '[' or data[2] != '<') return error.InvalidMouseSequence;
        
        var i: usize = 3;
        var button: u16 = 0;
        var x: u16 = 0;
        var y: u16 = 0;
        
        // Parse button
        while (i < data.len and data[i] != ';') {
            if (data[i] >= '0' and data[i] <= '9') {
                button = button * 10 + (data[i] - '0');
            }
            i += 1;
        }
        i += 1; // Skip ';'
        
        // Parse X
        while (i < data.len and data[i] != ';') {
            if (data[i] >= '0' and data[i] <= '9') {
                x = x * 10 + (data[i] - '0');
            }
            i += 1;
        }
        i += 1; // Skip ';'
        
        // Parse Y
        while (i < data.len and data[i] != 'M' and data[i] != 'm') {
            if (data[i] >= '0' and data[i] <= '9') {
                y = y * 10 + (data[i] - '0');
            }
            i += 1;
        }
        
        const is_release = data[i] == 'm';
        
        var event = MouseEvent{
            .button = null,
            .action = if (is_release) .release else .press,
            .position = .{ .x = x, .y = y },
        };
        
        // Parse button and modifiers
        const button_code = button & 0x03;
        event.modifiers = .{
            .shift = (button & 0x04) != 0,
            .alt = (button & 0x08) != 0,
            .ctrl = (button & 0x10) != 0,
        };
        
        // Decode button
        if ((button & 0x40) != 0) {
            // Scroll events
            if (button_code == 0) {
                event.button = .scroll_up;
                event.action = .scroll;
            } else if (button_code == 1) {
                event.button = .scroll_down;
                event.action = .scroll;
            }
        } else if ((button & 0x20) != 0) {
            // Motion event
            event.action = .move;
        } else {
            // Button press/release
            switch (button_code) {
                0 => event.button = .left,
                1 => event.button = .middle,
                2 => event.button = .right,
                else => {},
            }
        }
        
        try self.processMouseEvent(event);
    }
    
    /// Emit mouse event
    fn emitMouseEvent(self: *Self, event: MouseEvent) !void {
        const event_bus = self.event_bus orelse return;
        
        // Format mouse event as text for now
        // In a real implementation, we'd extend InputEventData to support mouse properly
        const mouse_text = try std.fmt.allocPrint(self.allocator, "MOUSE:{},{},{}", .{
            event.position.x,
            event.position.y,
            @intFromEnum(event.action),
        });
        defer self.allocator.free(mouse_text);
        
        const terminal_event = kernel.Event.init(.input, kernel.EventData{
            .input = kernel.events.InputEventData{
                .input_type = .mouse,
                .key = .{ .text = mouse_text },
            },
        });
        
        try event_bus.emit(terminal_event);
    }
    
    /// Handle raw input for mouse sequence detection
    fn handleRawInput(event: kernel.Event, context: ?*anyopaque) !void {
        const self = @as(*Self, @ptrCast(@alignCast(context.?)));
        
        if (self.mouse_mode == .off) return;
        if (event.data != .input) return;
        
        const input_data = event.data.input;
        if (input_data.input_type != .keyboard) return;
        
        // Check for mouse escape sequences
        if (input_data.key == .text) {
            const text = input_data.key.text;
            
            // Check for mouse sequences
            if (text.len >= 6 and text[0] == '\x1b' and text[1] == '[') {
                if (text[2] == 'M') {
                    // X10 protocol
                    try self.parseX10Mouse(text);
                } else if (text[2] == '<') {
                    // SGR protocol
                    try self.parseSGRMouse(text);
                }
            }
        }
    }
};