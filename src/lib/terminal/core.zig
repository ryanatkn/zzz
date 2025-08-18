const std = @import("std");
const colors = @import("../core/colors.zig");

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
        
        pub fn get(self: *const Self, index: usize) ?T {
            if (index >= self.len) return null;
            const real_index = (self.start + index) % capacity;
            return self.items[real_index];
        }
        
        pub fn clear(self: *Self) void {
            self.start = 0;
            self.len = 0;
        }
        
        pub fn isEmpty(self: *const Self) bool {
            return self.len == 0;
        }
        
        pub fn isFull(self: *const Self) bool {
            return self.len == capacity;
        }
        
        pub fn count(self: *const Self) usize {
            return self.len;
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
    text: std.ArrayList(u8),
    colors: std.ArrayList(Color),
    bold: std.ArrayList(bool),
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .text = std.ArrayList(u8).init(allocator),
            .colors = std.ArrayList(Color).init(allocator),
            .bold = std.ArrayList(bool).init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.text.deinit();
        self.colors.deinit();
        self.bold.deinit();
    }
    
    pub fn appendChar(self: *Self, ch: u8, color: Color, is_bold: bool) !void {
        try self.text.append(ch);
        try self.colors.append(color);
        try self.bold.append(is_bold);
    }
    
    pub fn appendText(self: *Self, text: []const u8, color: Color, is_bold: bool) !void {
        for (text) |ch| {
            try self.appendChar(ch, color, is_bold);
        }
    }
    
    pub fn clear(self: *Self) void {
        self.text.clearRetainingCapacity();
        self.colors.clearRetainingCapacity();
        self.bold.clearRetainingCapacity();
    }
    
    pub fn length(self: *const Self) usize {
        return self.text.items.len;
    }
    
    pub fn getText(self: *const Self) []const u8 {
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

/// Terminal state and configuration
pub const Terminal = struct {
    allocator: std.mem.Allocator,
    
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
    current_color: Color = Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
    current_bold: bool = false,
    background_color: Color = Color{ .r = 0, .g = 0, .b = 0, .a = 255 },
    
    // Working directory
    working_directory: std.ArrayList(u8),
    
    // Command execution callback
    command_executor: ?CommandExecutorFn = null,
    command_executor_context: ?*anyopaque = null,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .scrollback = RingBuffer(Line, 1000).init(),
            .current_line = std.ArrayList(u8).init(allocator),
            .command_history = RingBuffer([]const u8, 100).init(),
            .working_directory = std.ArrayList(u8).init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        // Clean up scrollback - lines are owned by scrollback, just clear it
        self.scrollback.clear();
        
        // Clean up history
        var i: usize = 0;
        while (i < self.command_history.count()) : (i += 1) {
            if (self.command_history.get(i)) |cmd| {
                self.allocator.free(cmd);
            }
        }
        
        self.current_line.deinit();
        self.working_directory.deinit();
    }
    
    /// Write text to the terminal
    pub fn write(self: *Self, text: []const u8) !void {
        for (text) |ch| {
            try self.writeChar(ch);
        }
    }
    
    /// Write a single character to the terminal
    pub fn writeChar(self: *Self, ch: u8) !void {
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
    fn newline(self: *Self) !void {
        // Create a new line from current buffer
        var line = Line.init(self.allocator);
        try line.appendText(self.current_line.items, self.current_color, self.current_bold);
        
        // Add to scrollback
        self.scrollback.push(line);
        
        // Clear current line
        self.current_line.clearRetainingCapacity();
        self.cursor.x = 0;
        self.cursor.y += 1;
    }
    
    /// Handle keyboard input
    pub fn handleKey(self: *Self, key: Key) !void {
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
                // TODO: Implement tab completion
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
    
    /// Execute the current command line
    fn executeCurrentLine(self: *Self) !void {
        const log = std.log.scoped(.terminal_core);
        const command = try self.allocator.dupe(u8, self.current_line.items);
        defer self.allocator.free(command);
        
        log.info("Terminal core executing: '{s}'", .{command});
        
        // Add to history if not empty
        if (command.len > 0) {
            const command_copy = try self.allocator.dupe(u8, command);
            self.command_history.push(command_copy);
            self.history_index = null;
            log.info("Added to history (total: {d})", .{self.command_history.count()});
        }
        
        // Move to new line before executing command
        try self.newline();
        log.info("Moved to new line, calling executor...", .{});
        
        // Execute command via callback if available
        if (self.command_executor) |executor| {
            if (self.command_executor_context) |context| {
                log.info("Calling command executor callback", .{});
                executor(context, command) catch |err| {
                    log.err("Command executor callback failed: {}", .{err});
                    try self.write("Error executing command: ");
                    try self.write(@errorName(err));
                    try self.write("\n");
                };
            }
        } else {
            // Fallback if no executor is set
            log.warn("No command executor available!", .{});
            try self.write("No command executor available\n");
        }
        
        self.clearCurrentLine();
        log.info("Command execution complete, line cleared", .{});
    }
    
    /// Navigate command history
    fn navigateHistory(self: *Self, direction: i32) void {
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
    fn clearCurrentLine(self: *Self) void {
        self.current_line.clearRetainingCapacity();
        self.cursor.x = 0;
    }
    
    /// Clear entire terminal
    pub fn clear(self: *Self) void {
        // Clear scrollback
        self.scrollback.clear();
        
        self.clearCurrentLine();
        self.cursor.x = 0;
        self.cursor.y = 0;
        self.viewport_offset = 0;
    }
    
    /// Scroll terminal up
    pub fn scrollUp(self: *Self, lines: usize) void {
        self.viewport_offset += lines;
        if (self.viewport_offset > self.scrollback.count()) {
            self.viewport_offset = self.scrollback.count();
        }
    }
    
    /// Scroll terminal down
    pub fn scrollDown(self: *Self, lines: usize) void {
        if (self.viewport_offset >= lines) {
            self.viewport_offset -= lines;
        } else {
            self.viewport_offset = 0;
        }
    }
    
    /// Get visible lines for rendering
    pub fn getVisibleLines(self: *const Self) struct { lines: []const Line, current: []const u8 } {
        const total_lines = self.scrollback.count();
        
        if (total_lines == 0 or self.viewport_offset >= total_lines) {
            return .{ .lines = &[_]Line{}, .current = self.current_line.items };
        }
        
        // Calculate visible range
        const start = if (self.viewport_offset > 0) total_lines - self.viewport_offset else 0;
        const visible_count = @min(self.rows, total_lines - start);
        
        // Create slice of visible lines
        var visible_lines = self.allocator.alloc(Line, visible_count) catch return .{ .lines = &[_]Line{}, .current = self.current_line.items };
        
        var i: usize = 0;
        while (i < visible_count) : (i += 1) {
            if (self.scrollback.get(start + i)) |line| {
                visible_lines[i] = line;
            }
        }
        
        return .{ .lines = visible_lines, .current = self.current_line.items };
    }
    
    /// Resize terminal
    pub fn resize(self: *Self, columns: usize, rows: usize) void {
        self.columns = columns;
        self.rows = rows;
        
        // Adjust cursor if needed
        if (self.cursor.x >= self.columns) {
            self.cursor.x = if (self.columns > 0) self.columns - 1 else 0;
        }
    }
    
    /// Update terminal state (called each frame)
    pub fn update(self: *Self, dt: f32) void {
        self.cursor.update(dt);
    }
    
    /// Get current working directory
    pub fn getWorkingDirectory(self: *const Self) []const u8 {
        return self.working_directory.items;
    }
    
    /// Set current working directory
    pub fn setWorkingDirectory(self: *Self, path: []const u8) !void {
        self.working_directory.clearRetainingCapacity();
        try self.working_directory.appendSlice(path);
    }
    
    /// Set command executor callback
    pub fn setCommandExecutor(self: *Self, executor: CommandExecutorFn, context: *anyopaque) void {
        self.command_executor = executor;
        self.command_executor_context = context;
    }
};