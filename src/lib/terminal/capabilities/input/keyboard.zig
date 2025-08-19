const std = @import("std");
const kernel = @import("../../kernel/mod.zig");

/// Keyboard input capability - handles raw keyboard events and emits structured input events
pub const KeyboardInput = struct {
    name: []const u8 = "keyboard_input",
    capability_type: []const u8 = "input",
    dependencies: []const []const u8 = &[_][]const u8{},
    
    active: bool = false,
    initialized: bool = false,
    
    // Event bus for emitting events
    event_bus: ?*kernel.EventBus = null,

    const Self = @This();

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
        _ = dependencies; // No dependencies for keyboard input
        
        self.event_bus = event_bus;
        self.initialized = true;
        self.active = true;
    }

    /// Cleanup capability resources
    pub fn deinit(self: *Self) void {
        self.active = false;
        self.initialized = false;
        self.event_bus = null;
    }

    /// Check if capability is active
    pub fn isActive(self: *Self) bool {
        return self.active;
    }

    /// Handle a keyboard key press and emit appropriate events
    pub fn handleKey(self: *Self, key: kernel.Key) !void {
        if (!self.active or self.event_bus == null) return;

        switch (key) {
            .char => |ch| {
                // Emit character input event
                const event = kernel.Event.init(.input, kernel.EventData{
                    .input = kernel.events.InputEventData{
                        .input_type = .keyboard,
                        .data = &[_]u8{ch},
                    },
                });
                try self.event_bus.?.emit(event);
            },
            .backspace => {
                const event = kernel.Event.init(.input, kernel.EventData{
                    .input = kernel.events.InputEventData{
                        .input_type = .keyboard,
                        .data = "BACKSPACE",
                    },
                });
                try self.event_bus.?.emit(event);
            },
            .delete => {
                const event = kernel.Event.init(.input, kernel.EventData{
                    .input = kernel.events.InputEventData{
                        .input_type = .keyboard,
                        .data = "DELETE",
                    },
                });
                try self.event_bus.?.emit(event);
            },
            .enter => {
                const event = kernel.Event.init(.input, kernel.EventData{
                    .input = kernel.events.InputEventData{
                        .input_type = .keyboard,
                        .data = "ENTER",
                    },
                });
                try self.event_bus.?.emit(event);
            },
            .tab => {
                const event = kernel.Event.init(.input, kernel.EventData{
                    .input = kernel.events.InputEventData{
                        .input_type = .keyboard,
                        .data = "TAB",
                    },
                });
                try self.event_bus.?.emit(event);
            },
            .up_arrow => {
                const event = kernel.Event.init(.input, kernel.EventData{
                    .input = kernel.events.InputEventData{
                        .input_type = .keyboard,
                        .data = "UP_ARROW",
                    },
                });
                try self.event_bus.?.emit(event);
            },
            .down_arrow => {
                const event = kernel.Event.init(.input, kernel.EventData{
                    .input = kernel.events.InputEventData{
                        .input_type = .keyboard,
                        .data = "DOWN_ARROW",
                    },
                });
                try self.event_bus.?.emit(event);
            },
            .left_arrow => {
                const event = kernel.Event.init(.input, kernel.EventData{
                    .input = kernel.events.InputEventData{
                        .input_type = .keyboard,
                        .data = "LEFT_ARROW",
                    },
                });
                try self.event_bus.?.emit(event);
            },
            .right_arrow => {
                const event = kernel.Event.init(.input, kernel.EventData{
                    .input = kernel.events.InputEventData{
                        .input_type = .keyboard,
                        .data = "RIGHT_ARROW",
                    },
                });
                try self.event_bus.?.emit(event);
            },
            .home => {
                const event = kernel.Event.init(.input, kernel.EventData{
                    .input = kernel.events.InputEventData{
                        .input_type = .keyboard,
                        .data = "HOME",
                    },
                });
                try self.event_bus.?.emit(event);
            },
            .end => {
                const event = kernel.Event.init(.input, kernel.EventData{
                    .input = kernel.events.InputEventData{
                        .input_type = .keyboard,
                        .data = "END",
                    },
                });
                try self.event_bus.?.emit(event);
            },
            .page_up => {
                const event = kernel.Event.init(.input, kernel.EventData{
                    .input = kernel.events.InputEventData{
                        .input_type = .keyboard,
                        .data = "PAGE_UP",
                    },
                });
                try self.event_bus.?.emit(event);
            },
            .page_down => {
                const event = kernel.Event.init(.input, kernel.EventData{
                    .input = kernel.events.InputEventData{
                        .input_type = .keyboard,
                        .data = "PAGE_DOWN",
                    },
                });
                try self.event_bus.?.emit(event);
            },
            .ctrl_c => {
                const event = kernel.Event.init(.input, kernel.EventData{
                    .input = kernel.events.InputEventData{
                        .input_type = .keyboard,
                        .data = "CTRL_C",
                    },
                });
                try self.event_bus.?.emit(event);
            },
            .ctrl_l => {
                const event = kernel.Event.init(.input, kernel.EventData{
                    .input = kernel.events.InputEventData{
                        .input_type = .keyboard,
                        .data = "CTRL_L",
                    },
                });
                try self.event_bus.?.emit(event);
            },
            else => {
                // Unknown key - emit generic input event
                const event = kernel.Event.init(.input, kernel.EventData{
                    .input = kernel.events.InputEventData{
                        .input_type = .keyboard,
                        .data = "UNKNOWN",
                    },
                });
                try self.event_bus.?.emit(event);
            },
        }
    }
};