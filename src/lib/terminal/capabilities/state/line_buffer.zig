const std = @import("std");
const kernel = @import("../../kernel/mod.zig");

/// Line buffer capability - manages current input line editing
pub const LineBuffer = struct {
    name: []const u8 = "line_buffer",
    capability_type: []const u8 = "state",
    dependencies: []const []const u8 = &[_][]const u8{ "keyboard_input", "basic_writer" },
    
    active: bool = false,
    initialized: bool = false,
    
    // Event bus for emitting events and subscribing to input events
    event_bus: ?*kernel.EventBus = null,
    allocator: std.mem.Allocator,
    
    // Line buffer state
    current_line: std.ArrayList(u8),
    cursor_x: usize = 0,
    
    // Command history
    command_history: std.ArrayList([]u8),
    history_index: ?usize = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .current_line = std.ArrayList(u8).init(allocator),
            .command_history = std.ArrayList([]u8).init(allocator),
        };
    }

    /// Get capability name
    pub fn getName(self: *Self) []const u8 {
        return self.name;
    }

    /// Get capability type
    pub fn getType(self: *Self) []const u8 {
        return self.capability_type;
    }

    /// Get required dependencies
    pub fn getDependencies(self: *Self) []const []const u8 {
        return self.dependencies;
    }

    /// Initialize capability with dependencies
    pub fn initialize(self: *Self, dependencies: []const kernel.ICapability, event_bus: *kernel.EventBus) !void {
        _ = dependencies; // Dependencies verified by registry
        
        self.event_bus = event_bus;
        
        // Subscribe to input events from keyboard
        try event_bus.subscribe(.input, inputEventCallback, self);
        
        self.initialized = true;
        self.active = true;
    }

    /// Cleanup capability resources
    pub fn deinit(self: *Self) void {
        // Unsubscribe from events
        if (self.event_bus) |bus| {
            bus.unsubscribe(.input, inputEventCallback, self);
        }
        
        // Clean up history
        for (self.command_history.items) |cmd| {
            self.allocator.free(cmd);
        }
        self.command_history.deinit();
        self.current_line.deinit();
        
        self.active = false;
        self.initialized = false;
        self.event_bus = null;
    }

    /// Check if capability is active
    pub fn isActive(self: *Self) bool {
        return self.active;
    }

    /// Insert character at cursor position
    fn insertChar(self: *Self, ch: u8) !void {
        try self.current_line.insert(self.cursor_x, ch);
        self.cursor_x += 1;
        try self.emitStateChange("char_inserted");
    }

    /// Handle backspace - delete character before cursor
    fn handleBackspace(self: *Self) !void {
        if (self.cursor_x > 0 and self.current_line.items.len > 0) {
            _ = self.current_line.orderedRemove(self.cursor_x - 1);
            self.cursor_x -= 1;
            try self.emitStateChange("char_deleted");
        }
    }

    /// Handle delete - delete character at cursor
    fn handleDelete(self: *Self) !void {
        if (self.cursor_x < self.current_line.items.len) {
            _ = self.current_line.orderedRemove(self.cursor_x);
            try self.emitStateChange("char_deleted");
        }
    }

    /// Handle arrow key navigation
    fn handleArrowKey(self: *Self, direction: []const u8) !void {
        if (std.mem.eql(u8, direction, "LEFT_ARROW")) {
            if (self.cursor_x > 0) {
                self.cursor_x -= 1;
                try self.emitStateChange("cursor_moved");
            }
        } else if (std.mem.eql(u8, direction, "RIGHT_ARROW")) {
            if (self.cursor_x < self.current_line.items.len) {
                self.cursor_x += 1;
                try self.emitStateChange("cursor_moved");
            }
        } else if (std.mem.eql(u8, direction, "UP_ARROW")) {
            self.navigateHistory(-1);
        } else if (std.mem.eql(u8, direction, "DOWN_ARROW")) {
            self.navigateHistory(1);
        }
    }

    /// Handle home/end keys
    fn handlePositioning(self: *Self, key: []const u8) !void {
        if (std.mem.eql(u8, key, "HOME")) {
            self.cursor_x = 0;
            try self.emitStateChange("cursor_moved");
        } else if (std.mem.eql(u8, key, "END")) {
            self.cursor_x = self.current_line.items.len;
            try self.emitStateChange("cursor_moved");
        }
    }

    /// Navigate command history
    fn navigateHistory(self: *Self, direction: i32) void {
        const history_len = self.command_history.items.len;
        if (history_len == 0) return;

        if (self.history_index) |current| {
            const new_index: i32 = @as(i32, @intCast(current)) + direction;
            if (new_index >= 0 and new_index < history_len) {
                self.history_index = @intCast(new_index);
            } else if (new_index < 0) {
                self.history_index = 0;
            } else {
                self.history_index = history_len - 1;
            }
        } else {
            // First time navigating history
            if (direction < 0) {
                self.history_index = history_len - 1;
            } else {
                self.history_index = 0;
            }
        }

        // Load the history command into current line
        if (self.history_index) |idx| {
            const cmd = self.command_history.items[idx];
            self.current_line.clearRetainingCapacity();
            self.current_line.appendSlice(cmd) catch return;
            self.cursor_x = cmd.len;
            self.emitStateChange("history_loaded") catch {};
        }
    }

    /// Execute current line - add to history and clear buffer
    fn executeCurrentLine(self: *Self) !void {
        const command = try self.allocator.dupe(u8, self.current_line.items);
        
        // Add to history if not empty
        if (command.len > 0) {
            try self.command_history.append(command);
            self.history_index = null;
        }

        // Emit the command execution event with actual command
        if (self.event_bus) |bus| {
            const event = kernel.Event.init(.command_execute, kernel.EventData{
                .command_execute = kernel.events.CommandExecuteData{
                    .command = command,
                    .args = null,
                },
            });
            try bus.emit(event);
        }

        // Clear current line
        self.current_line.clearRetainingCapacity();
        self.cursor_x = 0;
        try self.emitStateChange("line_executed");
    }

    /// Clear current line
    fn clearLine(self: *Self) !void {
        self.current_line.clearRetainingCapacity();
        self.cursor_x = 0;
        try self.emitStateChange("line_cleared");
    }

    /// Emit state change event
    fn emitStateChange(self: *Self, change_type: []const u8) !void {
        if (self.event_bus) |bus| {
            const event = kernel.Event.init(.state_change, kernel.EventData{
                .state_change = kernel.events.StateChangeData{
                    .component = "line_buffer",
                    .old_state = null,
                    .new_state = change_type,
                },
            });
            try bus.emit(event);
        }
    }

    /// Get current line content
    pub fn getCurrentLine(self: *const Self) []const u8 {
        return self.current_line.items;
    }

    /// Get cursor position
    pub fn getCursorPosition(self: *const Self) usize {
        return self.cursor_x;
    }
};

/// Event callback for handling input events from keyboard
fn inputEventCallback(event: kernel.Event, context: ?*anyopaque) !void {
    const self: *LineBuffer = @ptrCast(@alignCast(context.?));
    
    switch (event.data) {
        .input => |input_data| {
            if (input_data.data.len == 1) {
                // Single character input
                try self.insertChar(input_data.data[0]);
            } else {
                // Special key handling
                const key_name = input_data.data;
                if (std.mem.eql(u8, key_name, "BACKSPACE")) {
                    try self.handleBackspace();
                } else if (std.mem.eql(u8, key_name, "DELETE")) {
                    try self.handleDelete();
                } else if (std.mem.endsWith(u8, key_name, "_ARROW")) {
                    try self.handleArrowKey(key_name);
                } else if (std.mem.eql(u8, key_name, "HOME") or std.mem.eql(u8, key_name, "END")) {
                    try self.handlePositioning(key_name);
                } else if (std.mem.eql(u8, key_name, "ENTER")) {
                    try self.executeCurrentLine();
                } else if (std.mem.eql(u8, key_name, "CTRL_C")) {
                    try self.clearLine();
                }
                // TAB, CTRL_L, etc. are handled by other capabilities
            }
        },
        else => {}, // Ignore other event types
    }
}

