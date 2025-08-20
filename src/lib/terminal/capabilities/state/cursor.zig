const std = @import("std");
const kernel = @import("../../kernel/mod.zig");

/// Cursor capability - manages cursor position, visibility, and blinking
pub const Cursor = struct {
    pub const dependencies = &[_][]const u8{};

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


    pub fn init() Cursor {
        return Cursor{};
    }

    /// Create a new cursor capability
    pub fn create(allocator: std.mem.Allocator) !*Cursor {
        const self = try allocator.create(Cursor);
        self.* = Cursor.init();
        return self;
    }

    /// Destroy cursor capability
    pub fn destroy(self: *Cursor, allocator: std.mem.Allocator) void {
        self.deinit();
        allocator.destroy(self);
    }


    /// Get required dependencies
    pub fn getDependencies(self: *Cursor) []const []const u8 {
        _ = self;
        return dependencies;
    }

    /// Initialize capability with dependencies
    pub fn initialize(self: *Cursor, deps: []const kernel.TypeSafeCapability, event_bus: *kernel.EventBus) !void {
        _ = deps; // No dependencies for cursor

        self.event_bus = event_bus;

        // Subscribe to state change events from line buffer and other components
        try event_bus.subscribe(.state_change, stateChangeCallback, self);
        try event_bus.subscribe(.input, inputEventCallback, self);
        try event_bus.subscribe(.resize, resizeEventCallback, self);

        self.initialized = true;
        self.active = true;
    }

    /// Cleanup capability resources
    pub fn deinit(self: *Cursor) void {
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
    pub fn isActive(self: *Cursor) bool {
        return self.active;
    }

    /// Update cursor blinking animation
    pub fn update(self: *Cursor, dt: f32) !void {
        if (!self.active) return;

        self.blink_timer += dt;
        if (self.blink_timer >= self.blink_rate) {
            self.blink_timer = 0.0;
            self.visible = !self.visible;
            try self.emitStateChange(.blink_toggled);
        }
    }

    /// Show cursor and reset blink timer
    pub fn show(self: *Cursor) !void {
        if (!self.active) return;

        self.visible = true;
        self.blink_timer = 0.0;
        try self.emitStateChange(.shown);
    }

    /// Hide cursor
    pub fn hide(self: *Cursor) !void {
        if (!self.active) return;

        self.visible = false;
        try self.emitStateChange(.hidden);
    }

    /// Set cursor position
    pub fn setPosition(self: *Cursor, x: usize, y: usize) !void {
        if (!self.active) return;

        self.x = @min(x, self.max_columns - 1);
        self.y = @min(y, self.max_rows - 1);
        try self.show(); // Reset blink on position change
        try self.emitStateChange(.position_changed);
    }

    /// Move cursor by relative amount
    pub fn moveRelative(self: *Cursor, dx: i32, dy: i32) !void {
        if (!self.active) return;

        const new_x: i32 = @as(i32, @intCast(self.x)) + dx;
        const new_y: i32 = @as(i32, @intCast(self.y)) + dy;

        const bounded_x = @max(0, @min(new_x, @as(i32, @intCast(self.max_columns - 1))));
        const bounded_y = @max(0, @min(new_y, @as(i32, @intCast(self.max_rows - 1))));

        try self.setPosition(@intCast(bounded_x), @intCast(bounded_y));
    }

    /// Set terminal dimensions for bounds checking
    pub fn setDimensions(self: *Cursor, columns: usize, rows: usize) !void {
        if (!self.active) return;

        self.max_columns = columns;
        self.max_rows = rows;

        // Ensure cursor is still within bounds
        if (self.x >= columns) self.x = columns - 1;
        if (self.y >= rows) self.y = rows - 1;

        try self.emitStateChange(.dimensions_changed);
    }

    /// Get cursor position
    pub fn getPosition(self: *const Cursor) struct { x: usize, y: usize } {
        return .{ .x = self.x, .y = self.y };
    }

    /// Check if cursor is visible
    pub fn isVisible(self: *const Cursor) bool {
        return self.visible;
    }

    /// Emit state change event
    fn emitStateChange(self: *Cursor, state: kernel.events.CursorState) !void {
        if (self.event_bus) |bus| {
            const event = kernel.Event.init(.state_change, kernel.EventData{
                .state_change = kernel.events.StateChangeData{
                    .component = .cursor,
                    .state = .{ .cursor = state },
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
            if (state_data.component == .line_buffer) {
                switch (state_data.state.line_buffer) {
                    .char_inserted, .char_deleted => {
                        // Cursor position is managed by line buffer, just reset blink
                        try self.show();
                    },
                    .line_executed => {
                        // Move to new line
                        try self.setPosition(0, self.y + 1);
                    },
                    .line_cleared => {
                        try self.setPosition(0, self.y);
                    },
                    else => {}, // Ignore other line buffer states
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
            switch (input_data.key) {
                .special => |special_key| {
                    // Handle cursor movement keys that aren't handled by line buffer
                    switch (special_key) {
                        .page_up => try self.moveRelative(0, -10), // Move up 10 lines
                        .page_down => try self.moveRelative(0, 10), // Move down 10 lines
                        else => {}, // Other cursor movement is handled by line buffer
                    }
                },
                else => {}, // Ignore character and text input
            }
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
