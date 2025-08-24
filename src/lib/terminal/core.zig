const std = @import("std");
const colors = @import("../core/colors.zig");
const loggers = @import("../debug/loggers.zig");

const Color = colors.Color;

/// Ring buffer for efficient scrollback with fixed memory usage
pub fn RingBuffer(comptime T: type, comptime capacity: usize) type {
    return struct {
        items: [capacity]T = undefined,
        start: usize = 0,
        len: usize = 0,

        const Self = @This();

        pub fn init() Self {
            return Self{};
        }

        pub fn push(self: *Self, item: T) void {
            if (self.len < capacity) {
                self.items[self.len] = item;
                self.len += 1;
            } else {
                self.items[self.start] = item;
                self.start = (self.start + 1) % capacity;
            }
        }

        pub inline fn get(self: *const Self, index: usize) ?T {
            if (index >= self.len) return null;
            const real_index = (self.start + index) % capacity;
            return self.items[real_index];
        }

        pub inline fn getMutable(self: *Self, index: usize) ?*T {
            if (index >= self.len) return null;
            const real_index = (self.start + index) % capacity;
            return &self.items[real_index];
        }

        pub inline fn clear(self: *Self) void {
            self.start = 0;
            self.len = 0;
        }

        pub inline fn isEmpty(self: *const Self) bool {
            return self.len == 0;
        }

        pub inline fn isFull(self: *const Self) bool {
            return self.len == capacity;
        }

        pub inline fn count(self: *const Self) usize {
            return self.len;
        }

        /// Get the last item in the buffer (most recently added)
        pub fn getLast(self: *const Self) ?T {
            if (self.len == 0) return null;
            // Last item is at index len - 1
            return self.get(self.len - 1);
        }

        /// Get mutable reference to the last item in the buffer
        pub fn getLastMutable(self: *Self) ?*T {
            if (self.len == 0) return null;
            // Last item is at index len - 1
            return self.getMutable(self.len - 1);
        }

        /// Replace the last item in the buffer
        pub fn replaceLast(self: *Self, item: T) bool {
            if (self.len == 0) return false;
            const last_real_index = if (self.len < capacity)
                self.len - 1
            else
                (self.start + self.len - 1) % capacity;
            self.items[last_real_index] = item;
            return true;
        }
    };
}

/// Key input type for terminal
pub const Key = union(enum) {
    char: u8,
    backspace,
    delete,
    enter,
    tab,
    escape,
    up_arrow,
    down_arrow,
    left_arrow,
    right_arrow,
    home,
    end,
    page_up,
    page_down,
    ctrl_c,
    ctrl_d,
    ctrl_l,
    ctrl_z,
};

/// Terminal line with styling information
pub const Line = struct {
    allocator: std.mem.Allocator,
    text: std.ArrayList(u8),
    colors: std.ArrayList(Color),
    bold: std.ArrayList(bool),

    pub fn init(allocator: std.mem.Allocator) Line {
        return Line{
            .allocator = allocator,
            .text = std.ArrayList(u8).init(allocator),
            .colors = std.ArrayList(Color).init(allocator),
            .bold = std.ArrayList(bool).init(allocator),
        };
    }

    pub fn appendChar(self: *Line, ch: u8, color: Color, is_bold: bool) !void {
        try self.text.append(ch);
        try self.colors.append(color);
        try self.bold.append(is_bold);
    }

    pub fn appendText(self: *Line, text: []const u8, color: Color, is_bold: bool) !void {
        for (text) |ch| {
            try self.appendChar(ch, color, is_bold);
        }
    }

    pub fn clear(self: *Line) void {
        self.text.clearRetainingCapacity();
        self.colors.clearRetainingCapacity();
        self.bold.clearRetainingCapacity();
    }

    pub inline fn length(self: *const Line) usize {
        return self.text.items.len;
    }

    pub inline fn getText(self: *const Line) []const u8 {
        return self.text.items;
    }
};

/// Terminal cursor state
pub const Cursor = struct {
    x: usize = 0,
    y: usize = 0,
    visible: bool = true,
    blink_timer: f32 = 0.0,
    blink_rate: f32 = 0.5, // seconds

    pub fn update(self: *Cursor, dt: f32) void {
        self.blink_timer += dt;
        if (self.blink_timer >= self.blink_rate) {
            self.blink_timer = 0.0;
            self.visible = !self.visible;
        }
    }

    pub fn show(self: *Cursor) void {
        self.visible = true;
        self.blink_timer = 0.0;
    }

    pub fn hide(self: *Cursor) void {
        self.visible = false;
    }
};

/// Command execution callback function type
pub const CommandExecutorFn = *const fn (context: *anyopaque, command: []const u8) anyerror!void;

/// Iterator for visible lines that avoids memory allocation
pub const VisibleLinesIterator = struct {
    scrollback: *const RingBuffer(Line, 1000),
    start_index: usize,
    count: usize,
    current: usize = 0,

    pub fn init(scrollback: *const RingBuffer(Line, 1000), max_rows: usize) VisibleLinesIterator {
        const total_lines = scrollback.count();
        const visible_count = @min(max_rows, total_lines);
        // Show the most recent lines: if we have 10 lines and want 3, start at index 7
        const start_index = if (total_lines > max_rows) total_lines - max_rows else 0;

        return VisibleLinesIterator{
            .scrollback = scrollback,
            .start_index = start_index,
            .count = visible_count,
        };
    }

    pub fn next(self: *VisibleLinesIterator) ?Line {
        if (self.current >= self.count) return null;

        // Return lines in chronological order (oldest first)
        const line_index = self.start_index + self.current;
        const line = self.scrollback.get(line_index) orelse return null;
        self.current += 1;

        return line;
    }

    pub fn reset(self: *VisibleLinesIterator) void {
        self.current = 0;
    }
};

/// Terminal state and configuration
pub const Terminal = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,

    // Dimensions
    columns: usize = 80,
    rows: usize = 24,

    // State
    scrollback: RingBuffer(Line, 1000),
    current_line: std.ArrayList(u8),
    cursor: Cursor = Cursor{},
    viewport_offset: usize = 0, // Scrolling offset

    // History
    command_history: RingBuffer([]const u8, 100),
    history_index: ?usize = null,

    // Styling
    current_color: Color = colors.ANSI_BRIGHT_WHITE,
    current_bold: bool = false,
    background_color: Color = colors.ANSI_BLACK,

    // Working directory
    working_directory: std.ArrayList(u8),

    // Command execution callback
    command_executor: ?CommandExecutorFn = null,
    command_executor_context: ?*anyopaque = null,

    pub fn init(allocator: std.mem.Allocator) Terminal {
        const arena = std.heap.ArenaAllocator.init(allocator);

        return Terminal{
            .allocator = allocator,
            .arena = arena,
            .scrollback = RingBuffer(Line, 1000).init(),
            // Use regular allocator for frequently resizing buffers
            // Arena is for long-lived allocations only (like Line objects in scrollback)
            .current_line = std.ArrayList(u8).init(allocator),
            .command_history = RingBuffer([]const u8, 100).init(),
            .working_directory = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *Terminal) void {
        // Clean up ArrayLists that use regular allocator
        self.current_line.deinit();
        self.working_directory.deinit();

        // Arena allocator cleanup handles Line allocations in scrollback
        self.arena.deinit();
    }

    /// Write text to the terminal
    pub fn write(self: *Terminal, text: []const u8) !void {
        if (loggers.game_log) |*log| {
            log.info("terminal_write", "write() called with text: '{s}'", .{text});
        }
        for (text) |ch| {
            try self.writeChar(ch);
        }
    }

    /// Write a single character to the terminal
    pub fn writeChar(self: *Terminal, ch: u8) !void {
        switch (ch) {
            '\n' => try self.newline(),
            '\r' => self.cursor.x = 0,
            '\t' => {
                const spaces = 4 - (self.cursor.x % 4);
                var i: usize = 0;
                while (i < spaces) : (i += 1) {
                    try self.current_line.append(' ');
                    self.cursor.x += 1;
                }
            },
            else => {
                try self.current_line.append(ch);
                self.cursor.x += 1;
            },
        }

        // Wrap long lines
        if (self.cursor.x >= self.columns) {
            try self.newline();
        }
    }

    /// Move to new line
    fn newline(self: *Terminal) !void {
        // Create a new line from current buffer
        var line = Line.init(self.arena.allocator());
        try line.appendText(self.current_line.items, self.current_color, self.current_bold);

        // Add to scrollback
        self.scrollback.push(line);

        // DEBUG: Log scrollback update
        if (loggers.game_log) |*log| {
            log.info("terminal_scrollback", "Added line to scrollback: '{s}' (total lines: {d})", .{ self.current_line.items, self.scrollback.count() });
        }

        // Clear current line
        self.current_line.clearRetainingCapacity();
        self.cursor.x = 0;
        self.cursor.y += 1;
    }

    /// Handle keyboard input
    pub fn handleKey(self: *Terminal, key: Key) !void {
        switch (key) {
            .char => |ch| {
                try self.current_line.insert(self.cursor.x, ch);
                self.cursor.x += 1;
            },
            .backspace => {
                if (self.cursor.x > 0 and self.current_line.items.len > 0) {
                    _ = self.current_line.orderedRemove(self.cursor.x - 1);
                    self.cursor.x -= 1;
                }
            },
            .delete => {
                if (self.cursor.x < self.current_line.items.len) {
                    _ = self.current_line.orderedRemove(self.cursor.x);
                }
            },
            .enter => {
                try self.executeCurrentLine();
            },
            .tab => {
                // Tab completion - cycle through history or available commands
                if (self.current_line.items.len > 0) {
                    // Simple completion: find matching history entries
                    const prefix = self.current_line.items;
                    for (self.command_history.items) |hist_entry| {
                        if (hist_entry.len >= prefix.len and
                            std.mem.startsWith(u8, hist_entry, prefix))
                        {
                            // Clear current line and replace with completion
                            self.current_line.clearRetainingCapacity();
                            try self.current_line.appendSlice(hist_entry);
                            self.cursor_position = self.current_line.items.len;
                            break;
                        }
                    }
                }
            },
            .up_arrow => {
                self.navigateHistory(-1);
            },
            .down_arrow => {
                self.navigateHistory(1);
            },
            .left_arrow => {
                if (self.cursor.x > 0) {
                    self.cursor.x -= 1;
                }
            },
            .right_arrow => {
                if (self.cursor.x < self.current_line.items.len) {
                    self.cursor.x += 1;
                }
            },
            .home => {
                self.cursor.x = 0;
            },
            .end => {
                self.cursor.x = self.current_line.items.len;
            },
            .page_up => {
                self.scrollUp(self.rows / 2);
            },
            .page_down => {
                self.scrollDown(self.rows / 2);
            },
            .ctrl_c => {
                try self.write("^C\n");
                self.clearCurrentLine();
            },
            .ctrl_l => {
                self.clear();
            },
            else => {},
        }
    }

    /// Get prompt text for command echoing
    fn getPromptText(self: *Terminal) ![]u8 {
        const cwd = self.working_directory.items;

        // Extract directory name from full path
        const dir_name = if (std.fs.path.basename(cwd).len > 0)
            std.fs.path.basename(cwd)
        else
            cwd;

        return std.fmt.allocPrint(self.arena.allocator(), "{s}$ ", .{dir_name});
    }

    /// Execute the current command line
    fn executeCurrentLine(self: *Terminal) !void {
        const command = try self.arena.allocator().dupe(u8, self.current_line.items);

        // Echo the command with prompt to scrollback
        if (command.len > 0) {
            // Add command to history
            const command_copy = try self.arena.allocator().dupe(u8, command);
            self.command_history.push(command_copy);
            self.history_index = null;

            // Create prompt + command line for display
            const prompt_text = try self.getPromptText();

            var echo_line = Line.init(self.arena.allocator());
            try echo_line.appendText(prompt_text, self.current_color, false);
            try echo_line.appendText(command, self.current_color, false);

            // Add echoed command to scrollback
            self.scrollback.push(echo_line);
        }

        // Clear current line and move cursor
        self.current_line.clearRetainingCapacity();
        self.cursor.x = 0;
        self.cursor.y += 1;

        // Execute command via callback if available
        if (self.command_executor) |executor| {
            if (self.command_executor_context) |context| {
                executor(context, command) catch |err| {
                    try self.write("Error executing command: ");
                    try self.write(@errorName(err));
                    try self.write("\n");
                };
            }
        } else {
            try self.write("No command executor available\n");
        }

        self.clearCurrentLine();
    }

    /// Navigate command history
    fn navigateHistory(self: *Terminal, direction: i32) void {
        if (self.command_history.count() == 0) return;

        if (self.history_index) |*index| {
            if (direction < 0 and index.* > 0) {
                index.* -= 1;
            } else if (direction > 0 and index.* < self.command_history.count() - 1) {
                index.* += 1;
            } else if (direction > 0 and index.* == self.command_history.count() - 1) {
                self.history_index = null;
                self.clearCurrentLine();
                return;
            }
        } else if (direction < 0) {
            self.history_index = self.command_history.count() - 1;
        }

        if (self.history_index) |index| {
            if (self.command_history.get(index)) |cmd| {
                self.clearCurrentLine();
                self.current_line.appendSlice(cmd) catch return;
                self.cursor.x = self.current_line.items.len;
            }
        }
    }

    /// Clear current input line
    fn clearCurrentLine(self: *Terminal) void {
        self.current_line.clearRetainingCapacity();
        self.cursor.x = 0;
    }

    /// Clear entire terminal
    pub fn clear(self: *Terminal) void {
        // Clear scrollback
        self.scrollback.clear();

        self.clearCurrentLine();
        self.cursor.x = 0;
        self.cursor.y = 0;
        self.viewport_offset = 0;
    }

    /// Scroll terminal up
    pub fn scrollUp(self: *Terminal, lines: usize) void {
        self.viewport_offset += lines;
        if (self.viewport_offset > self.scrollback.count()) {
            self.viewport_offset = self.scrollback.count();
        }
    }

    /// Scroll terminal down
    pub fn scrollDown(self: *Terminal, lines: usize) void {
        if (self.viewport_offset >= lines) {
            self.viewport_offset -= lines;
        } else {
            self.viewport_offset = 0;
        }
    }

    /// Get visible lines for rendering (iterator-based version)
    pub fn getVisibleLines(self: *const Terminal) struct { lines: VisibleLinesIterator, current: []const u8 } {
        return .{ .lines = VisibleLinesIterator.init(&self.scrollback, self.rows), .current = self.current_line.items };
    }

    /// Resize terminal
    pub fn resize(self: *Terminal, columns: usize, rows: usize) void {
        self.columns = columns;
        self.rows = rows;

        // Adjust cursor if needed
        if (self.cursor.x >= self.columns) {
            self.cursor.x = if (self.columns > 0) self.columns - 1 else 0;
        }
    }

    /// Update terminal state (called each frame)
    pub fn update(self: *Terminal, dt: f32) void {
        self.cursor.update(dt);
    }

    /// Get current working directory
    pub fn getWorkingDirectory(self: *const Terminal) []const u8 {
        return self.working_directory.items;
    }

    /// Set current working directory
    pub fn setWorkingDirectory(self: *Terminal, path: []const u8) !void {
        self.working_directory.clearRetainingCapacity();
        try self.working_directory.appendSlice(path);
    }

    /// Set command executor callback
    pub fn setCommandExecutor(self: *Terminal, executor: CommandExecutorFn, context: *anyopaque) void {
        self.command_executor = executor;
        self.command_executor_context = context;
    }
};
