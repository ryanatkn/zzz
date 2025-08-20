const std = @import("std");
const kernel = @import("../../kernel/mod.zig");

/// Line buffer capability - manages current input line editing
pub const LineBuffer = struct {
    pub const name = "line_buffer";
    pub const capability_type = "state";
    pub const dependencies = &[_][]const u8{ "keyboard_input", "basic_writer" };

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
            .active = false,
            .initialized = false,
            .event_bus = null,
            .allocator = allocator,
            .current_line = std.ArrayList(u8).init(allocator),
            .cursor_x = 0,
            .command_history = std.ArrayList([]u8).init(allocator),
            .history_index = null,
        };
    }

    /// Create a new line buffer capability
    pub fn create(allocator: std.mem.Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = Self.init(allocator);
        return self;
    }

    /// Destroy line buffer capability
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

    /// Get required dependencies
    pub fn getDependencies(self: *Self) []const []const u8 {
        _ = self;
        return dependencies;
    }

    /// Initialize capability with dependencies
    pub fn initialize(self: *Self, deps: []const kernel.TypeSafeCapability, event_bus: *kernel.EventBus) !void {
        _ = deps; // Dependencies verified by registry

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
        try self.emitStateChange(.char_inserted);
    }

    /// Handle backspace - delete character before cursor
    fn handleBackspace(self: *Self) !void {
        if (self.cursor_x > 0 and self.current_line.items.len > 0) {
            _ = self.current_line.orderedRemove(self.cursor_x - 1);
            self.cursor_x -= 1;
            try self.emitStateChange(.char_deleted);
        }
    }

    /// Handle delete - delete character at cursor
    fn handleDelete(self: *Self) !void {
        if (self.cursor_x < self.current_line.items.len) {
            _ = self.current_line.orderedRemove(self.cursor_x);
            try self.emitStateChange(.char_deleted);
        }
    }

    /// Handle arrow key navigation
    fn handleArrowKey(self: *Self, direction: kernel.events.SpecialKey) !void {
        switch (direction) {
            .left_arrow => {
                if (self.cursor_x > 0) {
                    self.cursor_x -= 1;
                    try self.emitStateChange(.cursor_moved);
                }
            },
            .right_arrow => {
                if (self.cursor_x < self.current_line.items.len) {
                    self.cursor_x += 1;
                    try self.emitStateChange(.cursor_moved);
                }
            },
            .up_arrow => self.navigateHistory(-1),
            .down_arrow => self.navigateHistory(1),
            else => {},
        }
    }

    /// Handle home/end keys
    fn handlePositioning(self: *Self, key: kernel.events.SpecialKey) !void {
        switch (key) {
            .home => {
                self.cursor_x = 0;
                try self.emitStateChange(.cursor_moved);
            },
            .end => {
                self.cursor_x = self.current_line.items.len;
                try self.emitStateChange(.cursor_moved);
            },
            else => {},
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
            self.emitStateChange(.history_loaded) catch {};
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
        try self.emitStateChange(.line_executed);
    }

    /// Clear current line
    fn clearLine(self: *Self) !void {
        self.current_line.clearRetainingCapacity();
        self.cursor_x = 0;
        try self.emitStateChange(.line_cleared);
    }

    /// Emit state change event
    fn emitStateChange(self: *Self, state: kernel.events.LineBufferState) !void {
        if (self.event_bus) |bus| {
            const event = kernel.Event.init(.state_change, kernel.EventData{
                .state_change = kernel.events.StateChangeData{
                    .component = .line_buffer,
                    .state = .{ .line_buffer = state },
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

    /// Set cursor position
    pub fn setCursorPosition(self: *Self, pos: usize) void {
        self.cursor_x = @min(pos, self.current_line.items.len);
    }

    /// Set the current line content
    pub fn setCurrentLine(self: *Self, text: []const u8) !void {
        self.current_line.clearRetainingCapacity();
        try self.current_line.appendSlice(text);
        self.cursor_x = @min(self.cursor_x, text.len);
        try self.emitStateChange(.char_inserted);
    }

    /// Insert text at specific position
    pub fn insertTextAt(self: *Self, pos: usize, text: []const u8) !void {
        const insert_pos = @min(pos, self.current_line.items.len);

        // Use ArrayList's insertSlice method directly - no temporary allocation needed
        try self.current_line.insertSlice(insert_pos, text);

        // Update cursor if at or after insertion point
        if (self.cursor_x >= insert_pos) {
            self.cursor_x += text.len;
        }

        try self.emitStateChange(.char_inserted);
    }

    /// Delete range of characters
    pub fn deleteRange(self: *Self, start: usize, end: usize) !void {
        if (start >= end or start >= self.current_line.items.len) return;

        const actual_end = @min(end, self.current_line.items.len);
        const delete_count = actual_end - start;

        // Use ArrayList's replaceRange method to delete - replace with empty slice
        try self.current_line.replaceRange(start, delete_count, &[_]u8{});

        // Update cursor if in or after deleted range
        if (self.cursor_x > start) {
            if (self.cursor_x >= actual_end) {
                self.cursor_x -= delete_count;
            } else {
                self.cursor_x = start;
            }
        }

        try self.emitStateChange(.char_deleted);
    }

    /// Get history count
    pub fn getHistoryCount(self: *const Self) usize {
        return self.command_history.items.len;
    }

    /// Get history item at index
    pub fn getHistoryItem(self: *const Self, index: usize) ?[]const u8 {
        if (index >= self.command_history.items.len) return null;
        return self.command_history.items[index];
    }

    /// Public wrapper for inserting a character
    pub fn insertCharAt(self: *Self, pos: usize, ch: u8) !void {
        const old_cursor = self.cursor_x;
        self.cursor_x = pos;
        try self.insertChar(ch);
        self.cursor_x = old_cursor + 1;
    }

    /// Public wrapper for handling special keys
    pub fn handleSpecialKey(self: *Self, key: kernel.events.SpecialKey) !void {
        switch (key) {
            .backspace => try self.handleBackspace(),
            .delete => try self.handleDelete(),
            .enter => try self.executeCurrentLine(),
            .left_arrow, .right_arrow, .up_arrow, .down_arrow => try self.handleArrowKey(key),
            .home, .end => try self.handlePositioning(key),
            .ctrl_c => try self.clearLine(),
            else => {},
        }
    }
};

/// Event callback for handling input events from keyboard
fn inputEventCallback(event: kernel.Event, context: ?*anyopaque) !void {
    const self: *LineBuffer = @ptrCast(@alignCast(context.?));

    switch (event.data) {
        .input => |input_data| {
            switch (input_data.key) {
                .char => |ch| {
                    // Single character input
                    try self.insertChar(ch);
                },
                .special => |special_key| {
                    // Handle special keys with enum matching
                    switch (special_key) {
                        .backspace => try self.handleBackspace(),
                        .delete => try self.handleDelete(),
                        .enter => try self.executeCurrentLine(),
                        .ctrl_c => try self.clearLine(),
                        .left_arrow, .right_arrow, .up_arrow, .down_arrow => {
                            try self.handleArrowKey(special_key);
                        },
                        .home, .end => {
                            try self.handlePositioning(special_key);
                        },
                        // TAB, CTRL_L, etc. are handled by other capabilities
                        else => {},
                    }
                },
                .text => |text| {
                    // Handle pasted text - insert each character
                    for (text) |ch| {
                        try self.insertChar(ch);
                    }
                },
            }
        },
        else => {}, // Ignore other event types
    }
}
