const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const reactive = @import("../reactive/mod.zig");
const styles = @import("styles/mod.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const Rectangle = math.Rectangle;

/// Base component properties that all UI components share
pub const ComponentProps = struct {
    // Layout properties - reactive to screen size changes
    position: reactive.Signal(Vec2),
    size: reactive.Signal(Vec2),

    // Visual properties - reactive to theme changes
    background_color: reactive.Signal(Color),
    border_color: reactive.Signal(Color),

    // State properties
    visible: reactive.Signal(bool),
    enabled: reactive.Signal(bool),
    hovered: reactive.Signal(bool),

    // Event handlers (optional)
    on_click: ?*const fn (Vec2) void = null,
    on_hover: ?*const fn (bool) void = null,

    pub fn init(allocator: std.mem.Allocator, initial_position: Vec2, initial_size: Vec2) !ComponentProps {
        return ComponentProps{
            .position = try reactive.signal(allocator, Vec2, initial_position),
            .size = try reactive.signal(allocator, Vec2, initial_size),
            .background_color = try reactive.signal(allocator, Color, styles.Colors.bg_secondary),
            .border_color = try reactive.signal(allocator, Color, styles.Colors.border_primary),
            .visible = try reactive.signal(allocator, bool, true),
            .enabled = try reactive.signal(allocator, bool, true),
            .hovered = try reactive.signal(allocator, bool, false),
        };
    }

    pub fn deinit(self: *ComponentProps) void {
        self.position.deinit();
        self.size.deinit();
        self.background_color.deinit();
        self.border_color.deinit();
        self.visible.deinit();
        self.enabled.deinit();
        self.hovered.deinit();
    }

    /// Get current bounds as a Rectangle (reactive - registers dependencies)
    pub fn getBounds(self: *ComponentProps) Rectangle {
        return Rectangle{
            .position = self.position.get(),
            .size = self.size.get(),
        };
    }

    /// Get current bounds as a Rectangle (non-reactive - no dependencies)
    pub fn getBoundsConst(self: *const ComponentProps) Rectangle {
        return Rectangle{
            .position = self.position.peek(),
            .size = self.size.peek(),
        };
    }

    /// Check if point is within component bounds
    pub fn containsPoint(self: *const ComponentProps, point: Vec2) bool {
        const bounds = self.getBoundsConst();
        return point.x >= bounds.position.x and
            point.x <= bounds.position.x + bounds.size.x and
            point.y >= bounds.position.y and
            point.y <= bounds.position.y + bounds.size.y;
    }
};

/// Base component interface that all UI components implement
pub const Component = struct {
    const Self = @This();

    pub const VTable = struct {
        init: *const fn (self: *Component, allocator: std.mem.Allocator, props: ComponentProps) anyerror!void,
        deinit: *const fn (self: *Component, allocator: std.mem.Allocator) void,
        update: *const fn (self: *Component, dt: f32) void,
        render: *const fn (self: *const Component, renderer: anytype) anyerror!void,
        handle_event: *const fn (self: *Component, event: anytype) bool,
        destroy: *const fn (self: *Component, allocator: std.mem.Allocator) void,
    };

    vtable: VTable,
    props: ComponentProps,

    // Component hierarchy
    children: std.ArrayList(*Component),
    parent: ?*Component = null,

    pub fn init(self: *Component, allocator: std.mem.Allocator, props: ComponentProps) !void {
        self.props = props;
        self.children = std.ArrayList(*Component).init(allocator);
        try self.vtable.init(self, allocator, props);
    }

    pub fn deinit(self: *Component, allocator: std.mem.Allocator) void {
        // Cleanup children first
        for (self.children.items) |child| {
            child.deinit(allocator);
        }
        self.children.deinit();

        // Cleanup props
        self.props.deinit();

        // Component-specific cleanup
        self.vtable.deinit(self, allocator);
    }

    pub fn update(self: *Component, dt: f32) void {
        if (!self.props.visible.get()) return;

        // Update this component
        self.vtable.update(self, dt);

        // Update children
        for (self.children.items) |child| {
            child.update(dt);
        }
    }

    pub fn render(self: *const Component, renderer: anytype) !void {
        if (!self.props.visible.get()) return;

        // Render this component
        try self.vtable.render(self, renderer);

        // Render children
        for (self.children.items) |child| {
            try child.render(renderer);
        }
    }

    pub fn handleEvent(self: *Component, event: anytype) bool {
        if (!self.props.enabled.get() or !self.props.visible.get()) return false;

        // Try children first (reverse order for proper z-order)
        var i = self.children.items.len;
        while (i > 0) {
            i -= 1;
            if (self.children.items[i].handleEvent(event)) {
                return true; // Event was consumed by child
            }
        }

        // Handle event in this component
        return self.vtable.handle_event(self, event);
    }

    pub fn addChild(self: *Component, child: *Component) !void {
        try self.children.append(child);
        child.parent = self;
    }

    pub fn removeChild(self: *Component, child: *Component) void {
        for (self.children.items, 0..) |item, index| {
            if (item == child) {
                _ = self.children.swapRemove(index);
                child.parent = null;
                break;
            }
        }
    }

    pub fn destroy(self: *Component, allocator: std.mem.Allocator) void {
        self.vtable.destroy(self, allocator);
    }
};

/// Screen-relative units for responsive design
pub const ScreenUnits = struct {
    screen_width: *reactive.Signal(f32),
    screen_height: *reactive.Signal(f32),

    pub fn init(screen_width_signal: *reactive.Signal(f32), screen_height_signal: *reactive.Signal(f32)) ScreenUnits {
        return ScreenUnits{
            .screen_width = screen_width_signal,
            .screen_height = screen_height_signal,
        };
    }

    /// Convert viewport width percentage to pixels (e.g., 0.5 = 50% of screen width)
    pub fn vw(self: *const ScreenUnits, percentage: f32) f32 {
        return self.screen_width.get() * percentage;
    }

    /// Convert viewport height percentage to pixels (e.g., 0.5 = 50% of screen height)
    pub fn vh(self: *const ScreenUnits, percentage: f32) f32 {
        return self.screen_height.get() * percentage;
    }

    /// Convert viewport minimum percentage to pixels (min of vw and vh)
    pub fn vmin(self: *const ScreenUnits, percentage: f32) f32 {
        return @min(self.vw(percentage), self.vh(percentage));
    }

    /// Convert viewport maximum percentage to pixels (max of vw and vh)
    pub fn vmax(self: *const ScreenUnits, percentage: f32) f32 {
        return @max(self.vw(percentage), self.vh(percentage));
    }

    /// Center position for given size
    pub fn center(self: *const ScreenUnits, size: Vec2) Vec2 {
        return Vec2{
            .x = (self.screen_width.get() - size.x) / 2.0,
            .y = (self.screen_height.get() - size.y) / 2.0,
        };
    }

    /// Position relative to screen edges (0.0 = left/top, 1.0 = right/bottom)
    pub fn relativePosition(self: *const ScreenUnits, x_ratio: f32, y_ratio: f32) Vec2 {
        return Vec2{
            .x = self.screen_width.get() * x_ratio,
            .y = self.screen_height.get() * y_ratio,
        };
    }
};

// Tests
test "component basic functionality" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize reactive system
    try reactive.init(allocator);
    defer reactive.deinit(allocator);

    // Create component props
    var props = try ComponentProps.init(allocator, Vec2{ .x = 10, .y = 20 }, Vec2{ .x = 100, .y = 50 });
    defer props.deinit();

    // Test bounds calculation
    const bounds = props.getBounds();
    try std.testing.expect(bounds.position.x == 10);
    try std.testing.expect(bounds.position.y == 20);
    try std.testing.expect(bounds.size.x == 100);
    try std.testing.expect(bounds.size.y == 50);

    // Test point containment
    try std.testing.expect(props.containsPoint(Vec2{ .x = 50, .y = 30 }));
    try std.testing.expect(!props.containsPoint(Vec2{ .x = 5, .y = 30 }));
}

test "screen units responsive calculations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try reactive.init(allocator);
    defer reactive.deinit(allocator);

    var screen_width = try reactive.signal(allocator, f32, 1920);
    defer screen_width.deinit();

    var screen_height = try reactive.signal(allocator, f32, 1080);
    defer screen_height.deinit();

    const units = ScreenUnits.init(&screen_width, &screen_height);

    // Test viewport calculations
    try std.testing.expect(units.vw(0.5) == 960); // 50% of width
    try std.testing.expect(units.vh(0.5) == 540); // 50% of height

    // Test centering
    const center_pos = units.center(Vec2{ .x = 200, .y = 100 });
    try std.testing.expect(center_pos.x == 860); // (1920 - 200) / 2
    try std.testing.expect(center_pos.y == 490); // (1080 - 100) / 2
}
