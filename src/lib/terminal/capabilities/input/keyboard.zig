const std = @import("std");
const kernel = @import("../../kernel/mod.zig");

/// Keyboard input capability - handles raw keyboard events and emits structured input events
pub const KeyboardInput = struct {
    pub const name = "keyboard_input";
    pub const capability_type = "input";
    pub const dependencies = &[_][]const u8{};

    active: bool = false,
    initialized: bool = false,

    // Event bus for emitting events
    event_bus: ?*kernel.EventBus = null,

    /// Create a new keyboard input capability
    pub fn create(allocator: std.mem.Allocator) !*KeyboardInput {
        const self = try allocator.create(KeyboardInput);
        self.* = KeyboardInput{};
        return self;
    }

    /// Destroy keyboard input capability
    pub fn destroy(self: *KeyboardInput, allocator: std.mem.Allocator) void {
        self.deinit();
        allocator.destroy(self);
    }

    /// Get capability name
    pub fn getName(self: *KeyboardInput) []const u8 {
        _ = self;
        return name;
    }

    /// Get capability type
    pub fn getType(self: *KeyboardInput) []const u8 {
        _ = self;
        return capability_type;
    }

    /// Get required dependencies
    pub fn getDependencies(self: *KeyboardInput) []const []const u8 {
        _ = self;
        return dependencies;
    }

    /// Initialize capability with dependencies
    pub fn initialize(self: *KeyboardInput, deps: []const kernel.TypeSafeCapability, event_bus: *kernel.EventBus) !void {
        _ = deps; // No dependencies for keyboard input

        self.event_bus = event_bus;
        self.initialized = true;
        self.active = true;
    }

    /// Cleanup capability resources
    pub fn deinit(self: *KeyboardInput) void {
        self.active = false;
        self.initialized = false;
        self.event_bus = null;
    }

    /// Check if capability is active
    pub fn isActive(self: *KeyboardInput) bool {
        return self.active;
    }

    /// Handle a keyboard key press and emit appropriate events
    pub fn handleKey(self: *KeyboardInput, key: kernel.Key) !void {
        if (!self.active or self.event_bus == null) {
            return;
        }

        // Convert kernel.Key to our KeyInput enum
        const key_input: kernel.events.KeyInput = switch (key) {
            .char => |ch| .{ .char = ch },
            .backspace => .{ .special = .backspace },
            .delete => .{ .special = .delete },
            .enter => .{ .special = .enter },
            .tab => .{ .special = .tab },
            .escape => .{ .special = .escape },
            .up_arrow => .{ .special = .up_arrow },
            .down_arrow => .{ .special = .down_arrow },
            .left_arrow => .{ .special = .left_arrow },
            .right_arrow => .{ .special = .right_arrow },
            .home => .{ .special = .home },
            .end => .{ .special = .end },
            .page_up => .{ .special = .page_up },
            .page_down => .{ .special = .page_down },
            .ctrl_c => .{ .special = .ctrl_c },
            .ctrl_l => .{ .special = .ctrl_l },
            .ctrl_d => .{ .special = .ctrl_d },
            .ctrl_z => .{ .special = .ctrl_z },
        };

        // Emit structured input event with enum-based key
        const event = kernel.Event.init(.input, kernel.EventData{
            .input = kernel.events.InputEventData{
                .input_type = .keyboard,
                .key = key_input,
            },
        });

        try self.event_bus.?.emit(event);
    }
};
