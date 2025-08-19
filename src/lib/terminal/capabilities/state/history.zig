const std = @import("std");
const kernel = @import("../../kernel/mod.zig");

/// Command history capability - manages command history with navigation
pub const History = struct {
    pub const name = "history";
    pub const capability_type = "state";
    pub const dependencies = &[_][]const u8{};
    
    active: bool = false,
    initialized: bool = false,
    
    // Event bus for subscribing to command events
    event_bus: ?*kernel.EventBus = null,
    allocator: std.mem.Allocator,
    
    // History state using fixed-size ring buffer
    command_history: HistoryBuffer,
    history_index: ?usize = null,
    max_history: usize = 100,
    
    const Self = @This();
    const HistoryBuffer = kernel.RingBuffer([]u8, 100);
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .active = false,
            .initialized = false,
            .event_bus = null,
            .allocator = allocator,
            .command_history = HistoryBuffer.init(),
            .history_index = null,
        };
    }
    
    /// Create a new history capability
    pub fn create(allocator: std.mem.Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = Self.init(allocator);
        return self;
    }
    
    /// Destroy history capability
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
    pub fn initialize(self: *Self, deps: []const kernel.ICapability, event_bus: *kernel.EventBus) !void {
        _ = deps; // No dependencies
        
        self.event_bus = event_bus;
        
        // Subscribe to command execution events to track history
        try event_bus.subscribe(.command_execute, commandExecuteCallback, self);
        
        // Subscribe to input events for history navigation
        try event_bus.subscribe(.input, inputEventCallback, self);
        
        self.initialized = true;
        self.active = true;
    }
    
    /// Cleanup capability resources
    pub fn deinit(self: *Self) void {
        // Unsubscribe from events
        if (self.event_bus) |bus| {
            bus.unsubscribe(.command_execute, commandExecuteCallback, self);
            bus.unsubscribe(.input, inputEventCallback, self);
        }
        
        // Free all stored commands
        var i: usize = 0;
        while (i < self.command_history.count()) : (i += 1) {
            if (self.command_history.get(i)) |cmd| {
                self.allocator.free(cmd);
            }
        }
        
        self.active = false;
        self.initialized = false;
        self.event_bus = null;
    }
    
    /// Add command to history
    pub fn addCommand(self: *Self, command: []const u8) !void {
        // Don't add empty commands or duplicates of the last command
        if (command.len == 0) return;
        
        // Check if it's the same as the last command
        if (self.command_history.count() > 0) {
            const last_index = self.command_history.count() - 1;
            if (self.command_history.get(last_index)) |last_cmd| {
                if (std.mem.eql(u8, last_cmd, command)) {
                    return; // Skip duplicate
                }
            }
        }
        
        // Allocate and copy the command
        const cmd_copy = try self.allocator.dupe(u8, command);
        
        // If buffer is full, free the oldest command
        if (self.command_history.isFull()) {
            if (self.command_history.get(0)) |old_cmd| {
                self.allocator.free(old_cmd);
            }
        }
        
        // Add to history
        self.command_history.push(cmd_copy);
        
        // Reset history navigation index
        self.history_index = null;
        
        // Emit state change event
        if (self.event_bus) |bus| {
            const state_event = kernel.Event.init(.state_change, .{
                .state_change = .{
                    .component = .line_buffer,
                    .state = .{ .line_buffer = .history_loaded },
                },
            });
            try bus.emit(state_event);
        }
    }
    
    /// Navigate history (direction: -1 for up, 1 for down)
    pub fn navigate(self: *Self, direction: i32) ?[]const u8 {
        const count = self.command_history.count();
        if (count == 0) return null;
        
        if (self.history_index) |*index| {
            // Already navigating history
            if (direction < 0) {
                // Going up (older)
                if (index.* > 0) {
                    index.* -= 1;
                }
            } else {
                // Going down (newer)
                if (index.* < count - 1) {
                    index.* += 1;
                } else {
                    // Reached the end, return to current input
                    self.history_index = null;
                    return null;
                }
            }
        } else {
            // Starting history navigation
            if (direction < 0 and count > 0) {
                self.history_index = count - 1;
            } else {
                return null;
            }
        }
        
        // Return the command at current index
        if (self.history_index) |index| {
            return self.command_history.get(index);
        }
        
        return null;
    }
    
    /// Get current history position
    pub fn getCurrentCommand(self: *const Self) ?[]const u8 {
        if (self.history_index) |index| {
            return self.command_history.get(index);
        }
        return null;
    }
    
    /// Get history count
    pub fn getCount(self: *const Self) usize {
        return self.command_history.count();
    }
    
    /// Clear all history
    pub fn clear(self: *Self) void {
        // Free all commands
        var i: usize = 0;
        while (i < self.command_history.count()) : (i += 1) {
            if (self.command_history.get(i)) |cmd| {
                self.allocator.free(cmd);
            }
        }
        
        self.command_history.clear();
        self.history_index = null;
    }
};

/// Callback for command execution events
fn commandExecuteCallback(event: kernel.Event, context: ?*anyopaque) !void {
    const self: *History = @ptrCast(@alignCast(context.?));
    
    switch (event.data) {
        .command_execute => |data| {
            try self.addCommand(data.command);
        },
        else => {},
    }
}

/// Callback for input events (history navigation)
fn inputEventCallback(event: kernel.Event, context: ?*anyopaque) !void {
    const self: *History = @ptrCast(@alignCast(context.?));
    
    switch (event.data) {
        .input => |data| {
            switch (data.key) {
                .special => |special| {
                    switch (special) {
                        .up_arrow => {
                            if (self.navigate(-1)) |cmd| {
                                // Emit event to load this command into line buffer
                                if (self.event_bus) |bus| {
                                    const output_event = kernel.Event.init(.output, .{
                                        .output = .{
                                            .text = cmd,
                                            .target = "line_buffer",
                                        },
                                    });
                                    try bus.emit(output_event);
                                }
                            }
                        },
                        .down_arrow => {
                            if (self.navigate(1)) |cmd| {
                                // Emit event to load this command
                                if (self.event_bus) |bus| {
                                    const output_event = kernel.Event.init(.output, .{
                                        .output = .{
                                            .text = cmd,
                                            .target = "line_buffer",
                                        },
                                    });
                                    try bus.emit(output_event);
                                }
                            }
                        },
                        else => {},
                    }
                },
                else => {},
            }
        },
        else => {},
    }
}

// Tests
test "History capability basic operations" {
    const allocator = std.testing.allocator;
    var history = History.init(allocator);
    defer history.deinit();
    
    // Add commands
    try history.addCommand("ls");
    try history.addCommand("pwd");
    try history.addCommand("echo hello");
    
    try std.testing.expectEqual(@as(usize, 3), history.getCount());
    
    // Navigate up through history
    try std.testing.expectEqualStrings("echo hello", history.navigate(-1).?);
    try std.testing.expectEqualStrings("pwd", history.navigate(-1).?);
    try std.testing.expectEqualStrings("ls", history.navigate(-1).?);
    
    // Navigate down
    try std.testing.expectEqualStrings("pwd", history.navigate(1).?);
    try std.testing.expectEqualStrings("echo hello", history.navigate(1).?);
    try std.testing.expectEqual(@as(?[]const u8, null), history.navigate(1));
}

test "History capability duplicate prevention" {
    const allocator = std.testing.allocator;
    var history = History.init(allocator);
    defer history.deinit();
    
    try history.addCommand("ls");
    try history.addCommand("ls"); // Should be ignored
    try history.addCommand("pwd");
    try history.addCommand("pwd"); // Should be ignored
    
    try std.testing.expectEqual(@as(usize, 2), history.getCount());
}