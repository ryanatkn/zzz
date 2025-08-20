const std = @import("std");
const kernel = @import("../../kernel/mod.zig");

/// Cell represents a single character in the screen buffer
pub const Cell = struct {
    char: u8 = ' ',
    fg_color: u32 = 0xFFFFFF, // Default white
    bg_color: u32 = 0x000000, // Default black
    bold: bool = false,
    underline: bool = false,

    pub fn clear(self: *Cell) void {
        self.char = ' ';
        self.fg_color = 0xFFFFFF;
        self.bg_color = 0x000000;
        self.bold = false;
        self.underline = false;
    }
};

/// Screen buffer capability - manages full screen buffer for alternate screen mode
pub const ScreenBuffer = struct {
    pub const name = "screen_buffer";
    pub const capability_type = "state";
    pub const dependencies = &[_][]const u8{};

    active: bool = false,
    initialized: bool = false,

    // Event bus for emitting screen state changes
    event_bus: ?*kernel.EventBus = null,
    allocator: std.mem.Allocator,

    // Screen dimensions
    columns: usize = 80,
    rows: usize = 24,

    // Primary and alternate buffers
    primary_buffer: []Cell,
    alternate_buffer: []Cell,
    current_buffer: []Cell,
    using_alternate: bool = false,

    // Saved cursor positions for each buffer
    primary_cursor: struct { x: usize = 0, y: usize = 0 } = .{},
    alternate_cursor: struct { x: usize = 0, y: usize = 0 } = .{},

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        const buffer_size = 80 * 24;
        const primary = try allocator.alloc(Cell, buffer_size);
        const alternate = try allocator.alloc(Cell, buffer_size);

        // Initialize buffers with blank cells
        for (primary) |*cell| {
            cell.clear();
        }
        for (alternate) |*cell| {
            cell.clear();
        }

        return Self{
            .active = false,
            .initialized = false,
            .event_bus = null,
            .allocator = allocator,
            .primary_buffer = primary,
            .alternate_buffer = alternate,
            .current_buffer = primary,
        };
    }

    /// Create a new screen buffer capability
    pub fn create(allocator: std.mem.Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = try Self.init(allocator);
        return self;
    }

    /// Destroy screen buffer capability
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

    /// Check if capability is active
    pub fn isActive(self: *Self) bool {
        return self.active;
    }

    /// Initialize capability with event bus
    pub fn initialize(self: *Self, deps: []const kernel.TypeSafeCapability, event_bus: *kernel.EventBus) !void {
        _ = deps; // No dependencies

        self.event_bus = event_bus;

        // Subscribe to output events to update screen buffer
        try event_bus.subscribe(.output, outputEventCallback, self);

        // Subscribe to resize events
        try event_bus.subscribe(.resize, resizeEventCallback, self);

        self.initialized = true;
        self.active = true;
    }

    /// Cleanup capability resources
    pub fn deinit(self: *Self) void {
        // Unsubscribe from events
        if (self.event_bus) |bus| {
            bus.unsubscribe(.output, outputEventCallback, self);
            bus.unsubscribe(.resize, resizeEventCallback, self);
        }

        self.allocator.free(self.primary_buffer);
        self.allocator.free(self.alternate_buffer);

        self.active = false;
        self.initialized = false;
        self.event_bus = null;
    }

    /// Switch to alternate screen buffer
    pub fn switchToAlternate(self: *Self) void {
        if (!self.using_alternate) {
            // Save current cursor position
            self.primary_cursor.x = 0; // Would get from cursor capability
            self.primary_cursor.y = 0;

            // Switch to alternate buffer
            self.current_buffer = self.alternate_buffer;
            self.using_alternate = true;

            // Clear alternate buffer on switch
            self.clearScreen();

            // Restore alternate cursor position
            // Would emit cursor position event here
        }
    }

    /// Switch back to primary screen buffer
    pub fn switchToPrimary(self: *Self) void {
        if (self.using_alternate) {
            // Save alternate cursor position
            self.alternate_cursor.x = 0; // Would get from cursor capability
            self.alternate_cursor.y = 0;

            // Switch to primary buffer
            self.current_buffer = self.primary_buffer;
            self.using_alternate = false;

            // Restore primary cursor position
            // Would emit cursor position event here
        }
    }

    /// Write a character at specific position
    pub fn writeChar(self: *Self, x: usize, y: usize, char: u8, fg: u32, bg: u32, bold: bool) void {
        if (x >= self.columns or y >= self.rows) return;

        const index = y * self.columns + x;
        if (index >= self.current_buffer.len) return;

        self.current_buffer[index] = Cell{
            .char = char,
            .fg_color = fg,
            .bg_color = bg,
            .bold = bold,
            .underline = false,
        };
    }

    /// Clear entire screen
    pub fn clearScreen(self: *Self) void {
        for (self.current_buffer) |*cell| {
            cell.clear();
        }
    }

    /// Clear from cursor to end of screen
    pub fn clearToEnd(self: *Self, start_x: usize, start_y: usize) void {
        const start_index = start_y * self.columns + start_x;
        if (start_index >= self.current_buffer.len) return;

        for (self.current_buffer[start_index..]) |*cell| {
            cell.clear();
        }
    }

    /// Clear from cursor to beginning of screen
    pub fn clearToBeginning(self: *Self, end_x: usize, end_y: usize) void {
        const end_index = end_y * self.columns + end_x;
        if (end_index >= self.current_buffer.len) return;

        for (self.current_buffer[0..end_index]) |*cell| {
            cell.clear();
        }
    }

    /// Clear line at specified row
    pub fn clearLine(self: *Self, row: usize) void {
        if (row >= self.rows) return;

        const start_index = row * self.columns;
        const end_index = @min(start_index + self.columns, self.current_buffer.len);

        for (self.current_buffer[start_index..end_index]) |*cell| {
            cell.clear();
        }
    }

    /// Get cell at position
    pub fn getCell(self: *const Self, x: usize, y: usize) ?Cell {
        if (x >= self.columns or y >= self.rows) return null;

        const index = y * self.columns + x;
        if (index >= self.current_buffer.len) return null;

        return self.current_buffer[index];
    }

    /// Resize screen buffer
    pub fn resize(self: *Self, new_columns: usize, new_rows: usize) !void {
        const new_size = new_columns * new_rows;

        // Allocate new buffers
        const new_primary = try self.allocator.alloc(Cell, new_size);
        const new_alternate = try self.allocator.alloc(Cell, new_size);

        // Initialize new buffers
        for (new_primary) |*cell| {
            cell.clear();
        }
        for (new_alternate) |*cell| {
            cell.clear();
        }

        // Copy old content (as much as fits)
        const copy_rows = @min(self.rows, new_rows);
        const copy_cols = @min(self.columns, new_columns);

        var y: usize = 0;
        while (y < copy_rows) : (y += 1) {
            var x: usize = 0;
            while (x < copy_cols) : (x += 1) {
                const old_index = y * self.columns + x;
                const new_index = y * new_columns + x;

                if (old_index < self.primary_buffer.len and new_index < new_primary.len) {
                    new_primary[new_index] = self.primary_buffer[old_index];
                }
                if (old_index < self.alternate_buffer.len and new_index < new_alternate.len) {
                    new_alternate[new_index] = self.alternate_buffer[old_index];
                }
            }
        }

        // Free old buffers
        self.allocator.free(self.primary_buffer);
        self.allocator.free(self.alternate_buffer);

        // Update to new buffers
        self.primary_buffer = new_primary;
        self.alternate_buffer = new_alternate;
        self.current_buffer = if (self.using_alternate) new_alternate else new_primary;
        self.columns = new_columns;
        self.rows = new_rows;
    }
};

/// Callback for output events
fn outputEventCallback(event: kernel.Event, context: ?*anyopaque) !void {
    const self: *ScreenBuffer = @ptrCast(@alignCast(context.?));
    _ = self;
    _ = event;
    // Would update screen buffer based on output text
    // This is simplified - real implementation would parse and render text
}

/// Callback for resize events
fn resizeEventCallback(event: kernel.Event, context: ?*anyopaque) !void {
    const self: *ScreenBuffer = @ptrCast(@alignCast(context.?));

    switch (event.data) {
        .resize => |data| {
            try self.resize(data.new_columns, data.new_rows);
        },
        else => {},
    }
}

// Tests
test "ScreenBuffer capability basic operations" {
    const allocator = std.testing.allocator;
    var buffer = try ScreenBuffer.init(allocator);
    defer buffer.deinit();

    // Write some characters
    buffer.writeChar(0, 0, 'H', 0xFFFFFF, 0x000000, false);
    buffer.writeChar(1, 0, 'i', 0xFFFFFF, 0x000000, false);

    // Check cells
    const cell1 = buffer.getCell(0, 0).?;
    try std.testing.expectEqual(@as(u8, 'H'), cell1.char);

    const cell2 = buffer.getCell(1, 0).?;
    try std.testing.expectEqual(@as(u8, 'i'), cell2.char);

    // Clear screen
    buffer.clearScreen();
    const cleared = buffer.getCell(0, 0).?;
    try std.testing.expectEqual(@as(u8, ' '), cleared.char);
}

test "ScreenBuffer alternate screen switching" {
    const allocator = std.testing.allocator;
    var buffer = try ScreenBuffer.init(allocator);
    defer buffer.deinit();

    // Write to primary buffer
    buffer.writeChar(0, 0, 'P', 0xFFFFFF, 0x000000, false);

    // Switch to alternate
    buffer.switchToAlternate();
    try std.testing.expect(buffer.using_alternate);

    // Write to alternate buffer
    buffer.writeChar(0, 0, 'A', 0xFFFFFF, 0x000000, false);

    // Check alternate has 'A'
    const alt_cell = buffer.getCell(0, 0).?;
    try std.testing.expectEqual(@as(u8, 'A'), alt_cell.char);

    // Switch back to primary
    buffer.switchToPrimary();
    try std.testing.expect(!buffer.using_alternate);

    // Check primary still has 'P'
    const prim_cell = buffer.getCell(0, 0).?;
    try std.testing.expectEqual(@as(u8, 'P'), prim_cell.char);
}
