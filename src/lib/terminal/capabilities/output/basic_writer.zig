const std = @import("std");
const kernel = @import("../../kernel/mod.zig");
const core = @import("../../core.zig");
const colors = @import("../../../core/colors.zig");

/// Basic writer capability - handles text output to terminal scrollback
pub const BasicWriter = struct {
    pub const dependencies = &[_][]const u8{};

    active: bool = false,
    initialized: bool = false,

    // Event bus for emitting events and subscribing to output events
    event_bus: ?*kernel.EventBus = null,
    allocator: std.mem.Allocator,

    // Terminal state
    scrollback: core.RingBuffer(core.Line, 1000),
    current_color: colors.Color = colors.ANSI_BRIGHT_WHITE,
    current_bold: bool = false,

    // Terminal dimensions for line wrapping
    terminal_width: usize = 80,
    wrap_lines: bool = true, // Enable line wrapping by default

    // Arena allocator for line management
    arena: std.heap.ArenaAllocator,
    // Current line being built (accumulates characters until newline)
    current_line: ?core.Line = null,

    pub fn init(allocator: std.mem.Allocator) BasicWriter {
        return BasicWriter{
            .active = false,
            .initialized = false,
            .event_bus = null,
            .allocator = allocator,
            .scrollback = core.RingBuffer(core.Line, 1000).init(),
            .current_color = colors.ANSI_BRIGHT_WHITE,
            .current_bold = false,
            .terminal_width = 80,
            .wrap_lines = true,
            .arena = std.heap.ArenaAllocator.init(allocator),
            .current_line = null,
        };
    }

    /// Create a new basic writer capability
    pub fn create(allocator: std.mem.Allocator) !*BasicWriter {
        const self = try allocator.create(BasicWriter);
        self.* = BasicWriter.init(allocator);
        return self;
    }

    /// Destroy basic writer capability
    pub fn destroy(self: *BasicWriter, allocator: std.mem.Allocator) void {
        self.deinit();
        allocator.destroy(self);
    }

    /// Get required dependencies
    pub fn getDependencies(self: *BasicWriter) []const []const u8 {
        _ = self;
        return dependencies;
    }

    /// Initialize capability with dependencies
    pub fn initialize(self: *BasicWriter, deps: []const kernel.TypeSafeCapability, event_bus: *kernel.EventBus) !void {
        _ = deps; // No dependencies for basic writer

        self.event_bus = event_bus;

        // Subscribe to output and resize events
        try event_bus.subscribe(.output, outputEventCallback, self);
        try event_bus.subscribe(.resize, resizeEventCallback, self);

        self.initialized = true;
        self.active = true;
    }

    /// Cleanup capability resources
    pub fn deinit(self: *BasicWriter) void {
        // Unsubscribe from events
        if (self.event_bus) |bus| {
            bus.unsubscribe(.output, outputEventCallback, self);
            bus.unsubscribe(.resize, resizeEventCallback, self);
        }

        // Clean up arena
        self.arena.deinit();

        self.active = false;
        self.initialized = false;
        self.event_bus = null;
    }

    /// Check if capability is active
    pub fn isActive(self: *BasicWriter) bool {
        return self.active;
    }

    /// Write text to the terminal scrollback
    pub fn write(self: *BasicWriter, text: []const u8) !void {
        if (!self.active) return;

        for (text) |ch| {
            try self.writeChar(ch);
        }

        // Emit state change event
        if (self.event_bus) |bus| {
            const event = kernel.Event.init(.state_change, kernel.EventData{
                .state_change = kernel.events.StateChangeData{
                    .component = .basic_writer,
                    .state = .{ .basic_writer = .text_written },
                },
            });
            try bus.emit(event);
        }
    }

    /// Write a single character to the terminal
    fn writeChar(self: *BasicWriter, ch: u8) !void {
        switch (ch) {
            '\n' => try self.newline(),
            '\r' => {}, // Ignore carriage return for now
            '\t' => {
                // Convert tab to spaces
                const spaces = 4;
                var i: usize = 0;
                while (i < spaces) : (i += 1) {
                    try self.writeChar(' ');
                }
            },
            else => {
                // Just add the character - we don't manage cursor position here
                // That's handled by the line buffer capability
                // For now, we create a simple line with the character
                try self.addCharToCurrentOutput(ch);
            },
        }
    }

    /// Add character to current output
    fn addCharToCurrentOutput(self: *BasicWriter, ch: u8) !void {
        // Initialize current line if it doesn't exist (start of new line)
        if (self.current_line == null) {
            self.current_line = core.Line.init(self.arena.allocator());
            // This is a new line, so push it to scrollback
            self.scrollback.push(self.current_line.?);
        }

        // Check if adding this character would exceed terminal width
        const current_length = self.current_line.?.length();
        if (self.wrap_lines and current_length >= self.terminal_width) {
            // Auto-wrap: start a new line
            try self.forceNewline();

            // Initialize new current line for the wrapped character
            if (self.current_line == null) {
                self.current_line = core.Line.init(self.arena.allocator());
                self.scrollback.push(self.current_line.?);
            }
        }

        // Add character to current line
        try self.current_line.?.appendChar(ch, self.current_color, self.current_bold);

        // Update the last line in scrollback with our updated current line
        // (since current_line is the same object we pushed, we can replace it)
        _ = self.scrollback.replaceLast(self.current_line.?);
    }

    /// Move to new line
    fn newline(self: *BasicWriter) !void {
        // Finalize current line if it exists
        if (self.current_line != null) {
            // Current line should already be in scrollback, just reset our reference
            self.current_line = null;
        } else {
            // No current line, add empty line to scrollback
            const empty_line = core.Line.init(self.arena.allocator());
            self.scrollback.push(empty_line);
        }

        // Next character will start a new line
        self.current_line = null;
    }

    /// Force a new line without adding empty line to scrollback (for wrapping)
    fn forceNewline(self: *BasicWriter) !void {
        // Simply finalize current line and reset reference
        // The current line is already in scrollback, no need to add empty line
        self.current_line = null;
    }

    /// Get scrollback for rendering
    pub fn getScrollback(self: *const BasicWriter) *const core.RingBuffer(core.Line, 1000) {
        return &self.scrollback;
    }

    /// Clear all output
    pub fn clear(self: *BasicWriter) !void {
        if (!self.active) return;

        self.scrollback.clear();
        self.current_line = null;

        // Emit state change event
        if (self.event_bus) |bus| {
            const event = kernel.Event.init(.state_change, kernel.EventData{
                .state_change = kernel.events.StateChangeData{
                    .component = .basic_writer,
                    .state = .{ .basic_writer = .cleared },
                },
            });
            try bus.emit(event);
        }
    }

    /// Configure line wrapping behavior
    pub fn setLineWrapping(self: *BasicWriter, enabled: bool) void {
        self.wrap_lines = enabled;
    }

    /// Get current line wrapping setting
    pub fn isLineWrappingEnabled(self: *const BasicWriter) bool {
        return self.wrap_lines;
    }

    /// Get current terminal width setting
    pub fn getTerminalWidth(self: *const BasicWriter) usize {
        return self.terminal_width;
    }
};

/// Event callback for handling resize events
fn resizeEventCallback(event: kernel.Event, context: ?*anyopaque) !void {
    const self: *BasicWriter = @ptrCast(@alignCast(context.?));

    switch (event.data) {
        .resize => |resize_data| {
            // Update terminal width for line wrapping
            self.terminal_width = resize_data.new_columns;
        },
        else => {}, // Ignore other event types
    }
}

/// Event callback for handling output events
fn outputEventCallback(event: kernel.Event, context: ?*anyopaque) !void {
    const self: *BasicWriter = @ptrCast(@alignCast(context.?));

    switch (event.data) {
        .output => |output_data| {
            try self.write(output_data.text);
        },
        else => {}, // Ignore other event types
    }
}
