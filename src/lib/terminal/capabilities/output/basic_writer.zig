const std = @import("std");
const kernel = @import("../../kernel/mod.zig");
const core = @import("../../core.zig");
const colors = @import("../../../core/colors.zig");

/// Basic writer capability - handles text output to terminal scrollback
pub const BasicWriter = struct {
    pub const name = "basic_writer";
    pub const capability_type = "output";
    pub const dependencies = &[_][]const u8{};

    active: bool = false,
    initialized: bool = false,

    // Event bus for emitting events and subscribing to output events
    event_bus: ?*kernel.EventBus = null,
    allocator: std.mem.Allocator,

    // Terminal state
    scrollback: core.RingBuffer(core.Line, 1000),
    current_color: colors.Color = colors.Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
    current_bold: bool = false,

    // Arena allocator for line management
    arena: std.heap.ArenaAllocator,
    // Current line being built (accumulates characters until newline)
    current_line: ?core.Line = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .active = false,
            .initialized = false,
            .event_bus = null,
            .allocator = allocator,
            .scrollback = core.RingBuffer(core.Line, 1000).init(),
            .current_color = colors.Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
            .current_bold = false,
            .arena = std.heap.ArenaAllocator.init(allocator),
            .current_line = null,
        };
    }

    /// Create a new basic writer capability
    pub fn create(allocator: std.mem.Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = Self.init(allocator);
        return self;
    }

    /// Destroy basic writer capability
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
        _ = deps; // No dependencies for basic writer

        self.event_bus = event_bus;

        // Subscribe to output events
        try event_bus.subscribe(.output, outputEventCallback, self);

        self.initialized = true;
        self.active = true;
    }

    /// Cleanup capability resources
    pub fn deinit(self: *Self) void {
        // Unsubscribe from events
        if (self.event_bus) |bus| {
            bus.unsubscribe(.output, outputEventCallback, self);
        }

        // Clean up arena
        self.arena.deinit();

        self.active = false;
        self.initialized = false;
        self.event_bus = null;
    }

    /// Check if capability is active
    pub fn isActive(self: *Self) bool {
        return self.active;
    }

    /// Write text to the terminal scrollback
    pub fn write(self: *Self, text: []const u8) !void {
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
    fn writeChar(self: *Self, ch: u8) !void {
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
    fn addCharToCurrentOutput(self: *Self, ch: u8) !void {
        // Initialize current line if it doesn't exist (start of new line)
        if (self.current_line == null) {
            self.current_line = core.Line.init(self.arena.allocator());
            // This is a new line, so push it to scrollback
            self.scrollback.push(self.current_line.?);
        }

        // Add character to current line
        try self.current_line.?.appendChar(ch, self.current_color, self.current_bold);

        // Update the last line in scrollback with our updated current line
        // (since current_line is the same object we pushed, we can replace it)
        _ = self.scrollback.replaceLast(self.current_line.?);
    }

    /// Move to new line
    fn newline(self: *Self) !void {
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

    /// Get scrollback for rendering
    pub fn getScrollback(self: *const Self) *const core.RingBuffer(core.Line, 1000) {
        return &self.scrollback;
    }

    /// Clear all output
    pub fn clear(self: *Self) !void {
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
};

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
