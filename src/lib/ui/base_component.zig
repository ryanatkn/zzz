const std = @import("std");
const math = @import("../math/mod.zig");
const reactive = @import("../reactive/mod.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;

/// Base properties shared by all UI components
pub const ComponentProps = struct {
    position: reactive.Signal(Vec2),
    visible: reactive.Signal(bool),
    enabled: reactive.Signal(bool),

    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, position: Vec2) !Self {
        return Self{
            .position = try reactive.signal(allocator, Vec2, position),
            .visible = try reactive.signal(allocator, bool, true),
            .enabled = try reactive.signal(allocator, bool, true),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.position.deinit();
        self.visible.deinit();
        self.enabled.deinit();
    }

    /// Set position (reactive)
    pub fn setPosition(self: *Self, position: Vec2) void {
        self.position.set(position);
    }

    /// Get position (reactive - tracks dependency)
    pub fn getPosition(self: *Self) Vec2 {
        return self.position.get();
    }

    /// Peek at position without reactive tracking
    pub fn peekPosition(self: *const Self) Vec2 {
        return self.position.peek();
    }

    /// Set visibility (reactive)
    pub fn setVisible(self: *Self, visible: bool) void {
        self.visible.set(visible);
    }

    /// Check if visible (reactive - tracks dependency)
    pub fn isVisible(self: *Self) bool {
        return self.visible.get();
    }

    /// Peek at visibility without reactive tracking
    pub fn peekVisible(self: *const Self) bool {
        return self.visible.peek();
    }

    /// Set enabled state (reactive)
    pub fn setEnabled(self: *Self, enabled: bool) void {
        self.enabled.set(enabled);
    }

    /// Check if enabled (reactive - tracks dependency)
    pub fn isEnabled(self: *Self) bool {
        return self.enabled.get();
    }

    /// Peek at enabled state without reactive tracking
    pub fn peekEnabled(self: *const Self) bool {
        return self.enabled.peek();
    }

    /// Check if component should participate in rendering/interaction
    pub fn isActive(self: *const Self) bool {
        return self.peekVisible() and self.peekEnabled();
    }

    /// Check if component is interactive (enabled and visible)
    pub fn isInteractive(self: *Self) bool {
        return self.isVisible() and self.isEnabled();
    }
};

/// Base interface for all UI components
pub const ComponentInterface = struct {
    /// Initialize the component
    init_fn: *const fn (self: *anyopaque, allocator: std.mem.Allocator, props: *ComponentProps) anyerror!void,

    /// Cleanup the component
    deinit_fn: *const fn (self: *anyopaque, allocator: std.mem.Allocator) void,

    /// Render the component (const version for read-only rendering)
    render_fn: *const fn (self: *const anyopaque, renderer: anytype, props: *const ComponentProps) anyerror!void,

    /// Handle events (mutable version for state changes)
    handle_event_fn: ?*const fn (self: *anyopaque, event: anytype, props: *ComponentProps) bool = null,

    /// Update component (for animation, etc.)
    update_fn: ?*const fn (self: *anyopaque, dt: f32, props: *ComponentProps) void = null,
};

/// Generic component wrapper that provides common functionality
pub fn Component(comptime T: type) type {
    return struct {
        props: ComponentProps,
        data: T,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, position: Vec2, data: T) !Self {
            return Self{
                .props = try ComponentProps.init(allocator, position),
                .data = data,
            };
        }

        pub fn deinit(self: *Self) void {
            self.props.deinit();
        }

        /// Get mutable reference to component data
        pub fn getData(self: *Self) *T {
            return &self.data;
        }

        /// Get const reference to component data
        pub fn getDataConst(self: *const Self) *const T {
            return &self.data;
        }

        /// Get mutable reference to props
        pub fn getProps(self: *Self) *ComponentProps {
            return &self.props;
        }

        /// Get const reference to props
        pub fn getPropsConst(self: *const Self) *const ComponentProps {
            return &self.props;
        }

        /// Forward position operations to props
        pub fn setPosition(self: *Self, position: Vec2) void {
            self.props.setPosition(position);
        }

        pub fn getPosition(self: *Self) Vec2 {
            return self.props.getPosition();
        }

        pub fn peekPosition(self: *const Self) Vec2 {
            return self.props.peekPosition();
        }

        /// Forward visibility operations to props
        pub fn setVisible(self: *Self, visible: bool) void {
            self.props.setVisible(visible);
        }

        pub fn isVisible(self: *Self) bool {
            return self.props.isVisible();
        }

        pub fn peekVisible(self: *const Self) bool {
            return self.props.peekVisible();
        }

        /// Forward enabled operations to props
        pub fn setEnabled(self: *Self, enabled: bool) void {
            self.props.setEnabled(enabled);
        }

        pub fn isEnabled(self: *Self) bool {
            return self.props.isEnabled();
        }

        pub fn peekEnabled(self: *const Self) bool {
            return self.props.peekEnabled();
        }

        /// Check if component should be rendered
        pub fn shouldRender(self: *const Self) bool {
            return self.props.isActive();
        }
    };
}

// Tests
test "component props basic functionality" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const reactive_mod = @import("../reactive/mod.zig");
    try reactive_mod.init(allocator);
    defer reactive_mod.deinit(allocator);

    var props = try ComponentProps.init(allocator, Vec2{ .x = 10, .y = 20 });
    defer props.deinit();

    // Test initial state
    try testing.expectEqual(Vec2{ .x = 10, .y = 20 }, props.peekPosition());
    try testing.expect(props.peekVisible());
    try testing.expect(props.peekEnabled());
    try testing.expect(props.isActive());

    // Test position change
    props.setPosition(Vec2{ .x = 30, .y = 40 });
    try testing.expectEqual(Vec2{ .x = 30, .y = 40 }, props.peekPosition());

    // Test visibility toggle
    props.setVisible(false);
    try testing.expect(!props.peekVisible());
    try testing.expect(!props.isActive()); // Should be inactive when invisible

    // Test enabled toggle
    props.setVisible(true);
    props.setEnabled(false);
    try testing.expect(!props.peekEnabled());
    try testing.expect(!props.isActive()); // Should be inactive when disabled
}

test "generic component wrapper" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const reactive_mod = @import("../reactive/mod.zig");
    try reactive_mod.init(allocator);
    defer reactive_mod.deinit(allocator);

    // Test with simple data
    const TestData = struct {
        value: i32,
    };

    const TestComponent = Component(TestData);
    var component = try TestComponent.init(allocator, Vec2{ .x = 5, .y = 15 }, TestData{ .value = 42 });
    defer component.deinit();

    // Test data access
    try testing.expectEqual(@as(i32, 42), component.getDataConst().value);

    component.getData().value = 100;
    try testing.expectEqual(@as(i32, 100), component.getDataConst().value);

    // Test props forwarding
    try testing.expectEqual(Vec2{ .x = 5, .y = 15 }, component.peekPosition());

    component.setVisible(false);
    try testing.expect(!component.shouldRender());

    component.setVisible(true);
    try testing.expect(component.shouldRender());
}
