const std = @import("std");
const kernel = @import("../../kernel/mod.zig");

/// Cursor capability - manages cursor position, visibility, and blinking
pub const Cursor = struct {
    name: []const u8 = "cursor",
    capability_type: []const u8 = "state",
    dependencies: []const []const u8 = &[_][]const u8{},
    
    active: bool = false,
    initialized: bool = false,
    
    // Event bus for emitting events and subscribing to state changes
    event_bus: ?*kernel.EventBus = null,
    
    // Cursor state
    x: usize = 0,
    y: usize = 0,
    visible: bool = true,
    blink_timer: f32 = 0.0,
    blink_rate: f32 = 0.5, // seconds
    
    // Terminal dimensions for bounds checking
    max_columns: usize = 80,
    max_rows: usize = 24,

    const Self = @This();

    pub fn init() Self {
        return Self{};
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
        _ = dependencies; // No dependencies for cursor
        
        self.event_bus = event_bus;
        
        // Subscribe to state change events from line buffer and other components
        try event_bus.subscribe(.state_change, stateChangeCallback, self);
        try event_bus.subscribe(.input, inputEventCallback, self);
        try event_bus.subscribe(.resize, resizeEventCallback, self);
        
        self.initialized = true;
        self.active = true;
    }

    /// Cleanup capability resources
    pub fn deinit(self: *Self) void {
        // Unsubscribe from events
        if (self.event_bus) |bus| {
            bus.unsubscribe(.state_change, stateChangeCallback, self);
            bus.unsubscribe(.input, inputEventCallback, self);
            bus.unsubscribe(.resize, resizeEventCallback, self);
        }
        
        self.active = false;
        self.initialized = false;
        self.event_bus = null;
    }

    /// Check if capability is active
    pub fn isActive(self: *Self) bool {
        return self.active;
    }

    /// Update cursor blinking animation
    pub fn update(self: *Self, dt: f32) !void {
        if (!self.active) return;
        
        self.blink_timer += dt;
        if (self.blink_timer >= self.blink_rate) {
            self.blink_timer = 0.0;
            self.visible = !self.visible;
            try self.emitStateChange("blink_toggled");
        }
    }

    /// Show cursor and reset blink timer
    pub fn show(self: *Self) !void {
        if (!self.active) return;
        
        self.visible = true;
        self.blink_timer = 0.0;
        try self.emitStateChange("shown");
    }

    /// Hide cursor
    pub fn hide(self: *Self) !void {
        if (!self.active) return;
        
        self.visible = false;
        try self.emitStateChange("hidden");
    }

    /// Set cursor position
    pub fn setPosition(self: *Self, x: usize, y: usize) !void {
        if (!self.active) return;
        
        self.x = @min(x, self.max_columns - 1);
        self.y = @min(y, self.max_rows - 1);
        try self.show(); // Reset blink on position change
        try self.emitStateChange("position_changed");
    }

    /// Move cursor by relative amount
    pub fn moveRelative(self: *Self, dx: i32, dy: i32) !void {
        if (!self.active) return;
        
        const new_x: i32 = @as(i32, @intCast(self.x)) + dx;
        const new_y: i32 = @as(i32, @intCast(self.y)) + dy;
        
        const bounded_x = @max(0, @min(new_x, @as(i32, @intCast(self.max_columns - 1))));
        const bounded_y = @max(0, @min(new_y, @as(i32, @intCast(self.max_rows - 1))));
        
        try self.setPosition(@intCast(bounded_x), @intCast(bounded_y));
    }

    /// Set terminal dimensions for bounds checking
    pub fn setDimensions(self: *Self, columns: usize, rows: usize) !void {
        if (!self.active) return;
        
        self.max_columns = columns;
        self.max_rows = rows;
        
        // Ensure cursor is still within bounds
        if (self.x >= columns) self.x = columns - 1;
        if (self.y >= rows) self.y = rows - 1;
        
        try self.emitStateChange("dimensions_changed");
    }

    /// Get cursor position
    pub fn getPosition(self: *const Self) struct { x: usize, y: usize } {
        return .{ .x = self.x, .y = self.y };
    }

    /// Check if cursor is visible
    pub fn isVisible(self: *const Self) bool {
        return self.visible;
    }

    /// Emit state change event
    fn emitStateChange(self: *Self, change_type: []const u8) !void {
        if (self.event_bus) |bus| {
            const event = kernel.Event.init(.state_change, kernel.EventData{
                .state_change = kernel.events.StateChangeData{
                    .component = "cursor",
                    .old_state = null,
                    .new_state = change_type,
                },
            });
            try bus.emit(event);
        }
    }
};

/// Event callback for handling state change events from other components
fn stateChangeCallback(event: kernel.Event, context: ?*anyopaque) !void {
    const self: *Cursor = @ptrCast(@alignCast(context.?));
    
    switch (event.data) {
        .state_change => |state_data| {
            // React to line buffer changes that might affect cursor position
            if (std.mem.eql(u8, state_data.component, "line_buffer")) {
                if (std.mem.eql(u8, state_data.new_state, "char_inserted")) {
                    // Cursor position is managed by line buffer, just reset blink
                    try self.show();
                } else if (std.mem.eql(u8, state_data.new_state, "char_deleted")) {
                    try self.show();
                } else if (std.mem.eql(u8, state_data.new_state, "line_executed")) {
                    // Move to new line
                    try self.setPosition(0, self.y + 1);
                } else if (std.mem.eql(u8, state_data.new_state, "line_cleared")) {
                    try self.setPosition(0, self.y);
                }
            }
        },
        else => {}, // Ignore other event types
    }
}

/// Event callback for handling input events that directly affect cursor
fn inputEventCallback(event: kernel.Event, context: ?*anyopaque) !void {
    const self: *Cursor = @ptrCast(@alignCast(context.?));
    
    switch (event.data) {
        .input => |input_data| {
            const key_name = input_data.data;
            // Handle cursor movement keys that aren't handled by line buffer
            if (std.mem.eql(u8, key_name, "PAGE_UP")) {
                try self.moveRelative(0, -10); // Move up 10 lines
            } else if (std.mem.eql(u8, key_name, "PAGE_DOWN")) {
                try self.moveRelative(0, 10); // Move down 10 lines
            }
            // Other cursor movement is handled by line buffer
        },
        else => {}, // Ignore other event types
    }
}

/// Event callback for handling terminal resize events
fn resizeEventCallback(event: kernel.Event, context: ?*anyopaque) !void {
    const self: *Cursor = @ptrCast(@alignCast(context.?));
    
    switch (event.data) {
        .resize => |resize_data| {
            try self.setDimensions(resize_data.new_columns, resize_data.new_rows);
        },
        else => {}, // Ignore other event types
    }
}