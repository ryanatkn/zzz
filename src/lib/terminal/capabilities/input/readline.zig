const std = @import("std");
const kernel = @import("../../kernel/mod.zig");
const core = @import("../../core.zig");
const LineBuffer = @import("../state/line_buffer.zig").LineBuffer;
const Cursor = @import("../state/cursor.zig").Cursor;
const KeyboardInput = @import("keyboard.zig").KeyboardInput;

/// Readline input capability - advanced line editing with cursor movement
pub const ReadlineInput = struct {
    pub const name = "readline_input";
    pub const capability_type = "input";
    pub const dependencies = &[_][]const u8{ "line_buffer", "cursor", "keyboard_input" };

    active: bool = false,
    initialized: bool = false,

    // Dependencies
    line_buffer: ?*LineBuffer = null,
    cursor: ?*Cursor = null,
    keyboard_input: ?*KeyboardInput = null,

    // Event bus
    event_bus: ?*kernel.EventBus = null,
    allocator: std.mem.Allocator,

    // Editing state
    edit_mode: EditMode = .insert,
    selection_start: ?usize = null,
    selection_end: ?usize = null,
    clipboard: std.ArrayList(u8),
    kill_ring: std.ArrayList([]const u8), // Emacs-style kill ring
    kill_ring_index: usize = 0,

    // Word boundaries cache
    word_boundaries: std.ArrayList(usize),

    const Self = @This();

    pub const EditMode = enum {
        insert,
        overwrite,
    };

    /// Initialize readline input
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .clipboard = std.ArrayList(u8).init(allocator),
            .kill_ring = std.ArrayList([]const u8).init(allocator),
            .word_boundaries = std.ArrayList(usize).init(allocator),
        };
    }

    /// Create a new readline input capability
    pub fn create(allocator: std.mem.Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = Self.init(allocator);
        return self;
    }

    /// Destroy readline input capability
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
            if (dep.cast(LineBuffer)) |lb| {
                self.line_buffer = lb;
            } else if (dep.cast(Cursor)) |c| {
                self.cursor = c;
            } else if (dep.cast(KeyboardInput)) |ki| {
                self.keyboard_input = ki;
            }
        }

        // Verify all dependencies resolved
        if (self.line_buffer == null) return error.MissingDependency;
        if (self.cursor == null) return error.MissingDependency;
        if (self.keyboard_input == null) return error.MissingDependency;

        self.event_bus = event_bus;

        // Subscribe to keyboard input events
        try event_bus.subscribe(.input, handleInputEvent, self);

        self.initialized = true;
        self.active = true;
    }

    /// Deinitialize capability
    pub fn deinit(self: *Self) void {
        // Clean up kill ring
        for (self.kill_ring.items) |text| {
            self.allocator.free(text);
        }
        self.kill_ring.deinit();
        self.clipboard.deinit();
        self.word_boundaries.deinit();

        self.active = false;
        self.initialized = false;
    }

    /// Check if capability is active
    pub fn isActive(self: *Self) bool {
        return self.active;
    }

    // Movement functions

    /// Move cursor left by one character
    pub fn moveLeft(self: *Self) !void {
        const line_buffer = self.line_buffer.?;
        const current_pos = line_buffer.getCursorPosition();

        if (current_pos > 0) {
            line_buffer.setCursorPosition(current_pos - 1);
        }
    }

    /// Move cursor right by one character
    pub fn moveRight(self: *Self) !void {
        const line_buffer = self.line_buffer.?;
        const current_pos = line_buffer.getCursorPosition();
        const line = line_buffer.getCurrentLine();

        if (current_pos < line.len) {
            line_buffer.setCursorPosition(current_pos + 1);
        }
    }

    /// Move cursor to previous word
    pub fn movePreviousWord(self: *Self) !void {
        const line_buffer = self.line_buffer.?;
        const line = line_buffer.getCurrentLine();
        const pos = line_buffer.getCursorPosition();

        // Update word boundaries
        try self.updateWordBoundaries(line);

        // Find current position in word boundaries
        for (self.word_boundaries.items, 0..) |boundary, i| {
            if (boundary >= pos and i > 0) {
                line_buffer.setCursorPosition(self.word_boundaries.items[i - 1]);
                return;
            }
        }

        // If not found, move to start of line
        line_buffer.setCursorPosition(0);
    }

    /// Move cursor to next word
    pub fn moveNextWord(self: *Self) !void {
        const line_buffer = self.line_buffer.?;
        const line = line_buffer.getCurrentLine();
        const pos = line_buffer.getCursorPosition();

        // Update word boundaries
        try self.updateWordBoundaries(line);

        // Find current position in word boundaries
        for (self.word_boundaries.items) |boundary| {
            if (boundary > pos) {
                line_buffer.setCursorPosition(boundary);
                return;
            }
        }

        // If not found, move to end of line
        line_buffer.setCursorPosition(line.len);
    }

    /// Move to start of line
    pub fn moveHome(self: *Self) !void {
        const line_buffer = self.line_buffer.?;
        line_buffer.setCursorPosition(0);
    }

    /// Move to end of line
    pub fn moveEnd(self: *Self) !void {
        const line_buffer = self.line_buffer.?;
        const line = line_buffer.getCurrentLine();
        line_buffer.setCursorPosition(line.len);
    }

    // Editing functions

    /// Delete character at cursor
    pub fn deleteChar(self: *Self) !void {
        const line_buffer = self.line_buffer.?;
        const pos = line_buffer.getCursorPosition();
        const line = line_buffer.getCurrentLine();

        if (pos < line.len) {
            try line_buffer.deleteRange(pos, pos + 1);
        }
    }

    /// Delete character before cursor (backspace)
    pub fn backspace(self: *Self) !void {
        const line_buffer = self.line_buffer.?;
        const pos = line_buffer.getCursorPosition();

        if (pos > 0) {
            try line_buffer.deleteRange(pos - 1, pos);
        }
    }

    /// Delete word before cursor
    pub fn deleteWordBackward(self: *Self) !void {
        const line_buffer = self.line_buffer.?;
        const line = line_buffer.getCurrentLine();
        const pos = line_buffer.getCursorPosition();

        if (pos == 0) return;

        // Update word boundaries
        try self.updateWordBoundaries(line);

        // Find word start
        var word_start: usize = 0;
        for (self.word_boundaries.items) |boundary| {
            if (boundary < pos) {
                word_start = boundary;
            } else {
                break;
            }
        }

        // Kill the word (save to kill ring)
        const killed = line[word_start..pos];
        try self.addToKillRing(killed);

        // Delete the word
        try line_buffer.deleteRange(word_start, pos);
    }

    /// Kill line from cursor to end
    pub fn killLine(self: *Self) !void {
        const line_buffer = self.line_buffer.?;
        const line = line_buffer.getCurrentLine();
        const pos = line_buffer.getCursorPosition();

        if (pos < line.len) {
            // Kill from cursor to end
            const killed = line[pos..];
            try self.addToKillRing(killed);

            // Delete from cursor to end
            try line_buffer.deleteRange(pos, line.len);
        }
    }

    /// Yank from kill ring
    pub fn yank(self: *Self) !void {
        if (self.kill_ring.items.len == 0) return;

        const line_buffer = self.line_buffer.?;
        const pos = line_buffer.getCursorPosition();
        const yanked = self.kill_ring.items[self.kill_ring_index];

        // Insert yanked text at cursor position
        try line_buffer.insertTextAt(pos, yanked);
    }

    /// Cycle through kill ring
    pub fn yankPop(self: *Self) !void {
        if (self.kill_ring.items.len == 0) return;

        self.kill_ring_index = (self.kill_ring_index + 1) % self.kill_ring.items.len;
        // Note: In a full implementation, we'd undo the previous yank and re-yank
    }

    // Selection functions

    /// Start selection at current cursor position
    pub fn startSelection(self: *Self) void {
        if (self.line_buffer) |line_buffer| {
            const pos = line_buffer.getCursorPosition();
            self.selection_start = pos;
            self.selection_end = pos;
        } else {
            // If no line buffer, start at position 0
            self.selection_start = 0;
            self.selection_end = 0;
        }
    }

    /// Extend selection to current cursor position
    pub fn extendSelection(self: *Self) void {
        if (self.selection_start) |_| {
            const line_buffer = self.line_buffer.?;
            const pos = line_buffer.getCursorPosition();
            self.selection_end = pos;
        }
    }

    /// Clear selection
    pub fn clearSelection(self: *Self) void {
        self.selection_start = null;
        self.selection_end = null;
    }

    /// Copy selection to clipboard
    pub fn copySelection(self: *Self) !void {
        const start = self.selection_start orelse return;
        const end = self.selection_end orelse return;

        const line_buffer = self.line_buffer.?;
        const line = line_buffer.getCurrentLine();

        const from = @min(start, end);
        const to = @max(start, end);

        if (from < line.len) {
            const selected = line[from..@min(to, line.len)];
            self.clipboard.clearRetainingCapacity();
            try self.clipboard.appendSlice(selected);
        }
    }

    /// Cut selection to clipboard
    pub fn cutSelection(self: *Self) !void {
        try self.copySelection();
        try self.deleteSelection();
    }

    /// Delete selected text
    pub fn deleteSelection(self: *Self) !void {
        const start = self.selection_start orelse return;
        const end = self.selection_end orelse return;

        const line_buffer = self.line_buffer.?;
        const line = line_buffer.getCurrentLine();

        const from = @min(start, end);
        const to = @max(start, end);

        if (from < line.len) {
            const actual_to = @min(to, line.len);
            try line_buffer.deleteRange(from, actual_to);
            self.clearSelection();
        }
    }

    /// Paste from clipboard
    pub fn paste(self: *Self) !void {
        if (self.clipboard.items.len == 0) return;

        const line_buffer = self.line_buffer.?;
        const pos = line_buffer.getCursorPosition();

        // Insert clipboard content at cursor position
        try line_buffer.insertTextAt(pos, self.clipboard.items);
    }

    // Helper functions

    /// Update word boundaries for current line
    pub fn updateWordBoundaries(self: *Self, line: []const u8) !void {
        self.word_boundaries.clearRetainingCapacity();

        var in_word = false;
        for (line, 0..) |ch, i| {
            const is_word_char = std.ascii.isAlphanumeric(ch) or ch == '_';

            if (!in_word and is_word_char) {
                // Start of word
                try self.word_boundaries.append(i);
                in_word = true;
            } else if (in_word and !is_word_char) {
                // End of word
                in_word = false;
            }
        }
    }

    /// Add text to kill ring
    pub fn addToKillRing(self: *Self, text: []const u8) !void {
        const killed = try self.allocator.dupe(u8, text);
        try self.kill_ring.append(killed);

        // Limit kill ring size
        const max_kill_ring_size = 10;
        if (self.kill_ring.items.len > max_kill_ring_size) {
            self.allocator.free(self.kill_ring.orderedRemove(0));
        }

        self.kill_ring_index = self.kill_ring.items.len - 1;
    }

    /// Handle input events
    fn handleInputEvent(event: kernel.Event, context: ?*anyopaque) !void {
        const self = @as(*Self, @ptrCast(@alignCast(context.?)));

        if (event.data != .input) return;
        const input_data = event.data.input;

        if (input_data.input_type != .keyboard) return;

        // Handle special keys
        switch (input_data.key) {
            .special => |special| {
                switch (special) {
                    .left_arrow => try self.moveLeft(),
                    .right_arrow => try self.moveRight(),
                    .up_arrow => {
                        // Move up in history or buffer
                    },
                    .down_arrow => {
                        // Move down in history or buffer
                    },
                    .home => try self.moveHome(),
                    .end => try self.moveEnd(),
                    .backspace => try self.backspace(),
                    .delete => try self.deleteChar(),
                    .ctrl_c => try self.copySelection(),
                    .ctrl_d => try self.deleteChar(),
                    .ctrl_l => {}, // Clear screen
                    .ctrl_z => {}, // Suspend
                    else => {},
                }
            },
            .char => |ch| {
                // Handle control characters
                if (ch == 0x0B) { // Ctrl+K
                    try self.killLine();
                } else if (ch == 0x19) { // Ctrl+Y
                    try self.yank();
                } else if (ch == 0x18) { // Ctrl+X
                    try self.cutSelection();
                } else if (ch == 0x16) { // Ctrl+V
                    try self.paste();
                } else if (ch == 0x00) { // Ctrl+Space
                    self.startSelection();
                } else if (ch == 0x01) { // Ctrl+A (home)
                    try self.moveHome();
                } else if (ch == 0x05) { // Ctrl+E (end)
                    try self.moveEnd();
                } else {
                    // Insert character at cursor position
                    const line_buffer = self.line_buffer.?;
                    const pos = line_buffer.getCursorPosition();

                    // Insert single character
                    const char_buf = [_]u8{ch};
                    try line_buffer.insertTextAt(pos, &char_buf);
                }
            },
            .text => |text| {
                // Insert text at cursor position
                const line_buffer = self.line_buffer.?;
                const pos = line_buffer.getCursorPosition();

                try line_buffer.insertTextAt(pos, text);
            },
        }
    }
};
