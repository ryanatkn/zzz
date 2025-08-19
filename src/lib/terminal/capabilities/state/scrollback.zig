const std = @import("std");
const kernel = @import("../../kernel/mod.zig");

/// Line structure for scrollback buffer
pub const Line = struct {
    text: []u8,
    length: usize,
    timestamp: i64,
    
    pub fn init(allocator: std.mem.Allocator, text: []const u8) !Line {
        const text_copy = try allocator.dupe(u8, text);
        return Line{
            .text = text_copy,
            .length = text.len,
            .timestamp = std.time.milliTimestamp(),
        };
    }
    
    pub fn deinit(self: *Line, allocator: std.mem.Allocator) void {
        allocator.free(self.text);
    }
};

/// Scrollback capability - manages terminal scrollback buffer
pub const Scrollback = struct {
    pub const name = "scrollback";
    pub const capability_type = "state";
    pub const dependencies = &[_][]const u8{};
    
    active: bool = false,
    initialized: bool = false,
    
    // Event bus for subscribing to output events
    event_bus: ?*kernel.EventBus = null,
    allocator: std.mem.Allocator,
    
    // Scrollback state
    buffer: ScrollbackBuffer,
    viewport_offset: usize = 0,  // 0 = bottom (newest), increases going up
    max_lines: usize = 1000,
    
    // Search state (for future enhancement)
    search_term: ?[]u8 = null,
    search_results: std.ArrayList(usize),
    
    const Self = @This();
    const ScrollbackBuffer = kernel.RingBuffer(Line, 1000);
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .active = false,
            .initialized = false,
            .event_bus = null,
            .allocator = allocator,
            .buffer = ScrollbackBuffer.init(),
            .viewport_offset = 0,
            .search_results = std.ArrayList(usize).init(allocator),
        };
    }
    
    /// Create a new scrollback capability
    pub fn create(allocator: std.mem.Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = Self.init(allocator);
        return self;
    }
    
    /// Destroy scrollback capability
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
    
    /// Initialize capability with event bus
    pub fn initialize(self: *Self, deps: []const kernel.ICapability, event_bus: *kernel.EventBus) !void {
        _ = deps; // No dependencies
        
        self.event_bus = event_bus;
        
        // Subscribe to output events to capture scrollback
        try event_bus.subscribe(.output, outputEventCallback, self);
        
        // Subscribe to state change events for clearing
        try event_bus.subscribe(.state_change, stateChangeCallback, self);
        
        self.initialized = true;
        self.active = true;
    }
    
    /// Cleanup capability resources
    pub fn deinit(self: *Self) void {
        // Unsubscribe from events
        if (self.event_bus) |bus| {
            bus.unsubscribe(.output, outputEventCallback, self);
            bus.unsubscribe(.state_change, stateChangeCallback, self);
        }
        
        // Free all stored lines
        var i: usize = 0;
        while (i < self.buffer.count()) : (i += 1) {
            if (self.buffer.getMutable(i)) |line| {
                line.deinit(self.allocator);
            }
        }
        
        // Free search term if any
        if (self.search_term) |term| {
            self.allocator.free(term);
        }
        
        self.search_results.deinit();
        
        self.active = false;
        self.initialized = false;
        self.event_bus = null;
    }
    
    /// Add a line to scrollback
    pub fn addLine(self: *Self, text: []const u8) !void {
        // If buffer is full, free the oldest line
        if (self.buffer.isFull()) {
            if (self.buffer.getMutable(0)) |old_line| {
                old_line.deinit(self.allocator);
            }
        }
        
        // Create and add new line
        const line = try Line.init(self.allocator, text);
        self.buffer.push(line);
        
        // Reset viewport to bottom when new content arrives
        if (self.viewport_offset > 0) {
            self.viewport_offset = 0;
            
            // Emit viewport change event
            if (self.event_bus) |bus| {
                const state_event = kernel.Event.init(.state_change, .{
                    .state_change = .{
                        .component = .basic_writer,
                        .state = .{ .basic_writer = .text_written },
                    },
                });
                try bus.emit(state_event);
            }
        }
    }
    
    /// Scroll up by specified number of lines
    pub fn scrollUp(self: *Self, lines: usize) void {
        const max_offset = if (self.buffer.count() > 0) self.buffer.count() - 1 else 0;
        self.viewport_offset = @min(self.viewport_offset + lines, max_offset);
    }
    
    /// Scroll down by specified number of lines
    pub fn scrollDown(self: *Self, lines: usize) void {
        if (self.viewport_offset >= lines) {
            self.viewport_offset -= lines;
        } else {
            self.viewport_offset = 0;
        }
    }
    
    /// Scroll to top of buffer
    pub fn scrollToTop(self: *Self) void {
        self.viewport_offset = if (self.buffer.count() > 0) self.buffer.count() - 1 else 0;
    }
    
    /// Scroll to bottom of buffer
    pub fn scrollToBottom(self: *Self) void {
        self.viewport_offset = 0;
    }
    
    /// Get visible lines for rendering (returns iterator-like structure)
    pub fn getVisibleLines(self: *const Self, max_rows: usize) VisibleLinesIterator {
        return VisibleLinesIterator.init(&self.buffer, self.viewport_offset, max_rows);
    }
    
    /// Clear all scrollback
    pub fn clear(self: *Self) void {
        // Free all lines
        var i: usize = 0;
        while (i < self.buffer.count()) : (i += 1) {
            if (self.buffer.getMutable(i)) |line| {
                line.deinit(self.allocator);
            }
        }
        
        self.buffer.clear();
        self.viewport_offset = 0;
        self.search_results.clearRetainingCapacity();
    }
    
    /// Get line at specific index
    pub fn getLine(self: *const Self, index: usize) ?Line {
        return self.buffer.get(index);
    }
    
    /// Get total line count
    pub fn getLineCount(self: *const Self) usize {
        return self.buffer.count();
    }
    
    /// Check if at bottom of scrollback
    pub fn isAtBottom(self: *const Self) bool {
        return self.viewport_offset == 0;
    }
};

/// Iterator for visible lines
pub const VisibleLinesIterator = struct {
    buffer: *const kernel.RingBuffer(Line, 1000),
    viewport_offset: usize,
    max_rows: usize,
    current: usize = 0,
    
    pub fn init(buffer: *const kernel.RingBuffer(Line, 1000), viewport_offset: usize, max_rows: usize) VisibleLinesIterator {
        return VisibleLinesIterator{
            .buffer = buffer,
            .viewport_offset = viewport_offset,
            .max_rows = max_rows,
        };
    }
    
    pub fn next(self: *VisibleLinesIterator) ?Line {
        const total_lines = self.buffer.count();
        if (total_lines == 0 or self.current >= self.max_rows) return null;
        
        // Calculate which line to return based on viewport offset
        // viewport_offset = 0 means show the newest lines (bottom)
        // viewport_offset > 0 means scrolled up by that many lines
        const bottom_index = if (total_lines > 0) total_lines - 1 else 0;
        const start_index = if (bottom_index >= self.viewport_offset) 
            bottom_index - self.viewport_offset 
        else 
            0;
        
        // Calculate the actual line index for this iteration
        const line_index = if (start_index >= self.max_rows - 1)
            start_index - (self.max_rows - 1) + self.current
        else if (self.current <= start_index)
            self.current
        else
            return null;
        
        if (line_index >= total_lines) return null;
        
        self.current += 1;
        return self.buffer.get(line_index);
    }
    
    pub fn reset(self: *VisibleLinesIterator) void {
        self.current = 0;
    }
};

/// Callback for output events
fn outputEventCallback(event: kernel.Event, context: ?*anyopaque) !void {
    const self: *Scrollback = @ptrCast(@alignCast(context.?));
    
    switch (event.data) {
        .output => |data| {
            // Only capture output not targeted at specific components
            if (data.target == null) {
                try self.addLine(data.text);
            }
        },
        else => {},
    }
}

/// Callback for state change events
fn stateChangeCallback(event: kernel.Event, context: ?*anyopaque) !void {
    const self: *Scrollback = @ptrCast(@alignCast(context.?));
    
    switch (event.data) {
        .state_change => |data| {
            switch (data.state) {
                .basic_writer => |writer_state| {
                    if (writer_state == .cleared) {
                        self.clear();
                    }
                },
                else => {},
            }
        },
        else => {},
    }
}

// Tests
test "Scrollback capability basic operations" {
    const allocator = std.testing.allocator;
    var scrollback = Scrollback.init(allocator);
    defer scrollback.deinit();
    
    // Add some lines
    try scrollback.addLine("Line 1");
    try scrollback.addLine("Line 2");
    try scrollback.addLine("Line 3");
    
    try std.testing.expectEqual(@as(usize, 3), scrollback.getLineCount());
    
    // Check lines
    const line1 = scrollback.getLine(0).?;
    try std.testing.expectEqualStrings("Line 1", line1.text);
    
    const line2 = scrollback.getLine(1).?;
    try std.testing.expectEqualStrings("Line 2", line2.text);
}

test "Scrollback viewport scrolling" {
    const allocator = std.testing.allocator;
    var scrollback = Scrollback.init(allocator);
    defer scrollback.deinit();
    
    // Add lines
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        var buf: [32]u8 = undefined;
        const text = try std.fmt.bufPrint(&buf, "Line {d}", .{i});
        try scrollback.addLine(text);
    }
    
    // Initially at bottom
    try std.testing.expect(scrollback.isAtBottom());
    
    // Scroll up
    scrollback.scrollUp(5);
    try std.testing.expectEqual(@as(usize, 5), scrollback.viewport_offset);
    try std.testing.expect(!scrollback.isAtBottom());
    
    // Scroll to top
    scrollback.scrollToTop();
    try std.testing.expectEqual(@as(usize, 9), scrollback.viewport_offset);
    
    // Scroll to bottom
    scrollback.scrollToBottom();
    try std.testing.expect(scrollback.isAtBottom());
}