/// Reusable focus border component for IDE panels and focusable elements
const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const reactive = @import("../reactive/mod.zig");
const component = @import("component.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;
const Color = colors.Color;
const Component = component.Component;
const ComponentProps = component.ComponentProps;

pub const BorderStyle = enum {
    solid,
    dashed,
    dotted,
};

pub const FocusableBorder = struct {
    base: Component,

    // Reactive properties
    is_focused: reactive.Signal(bool),
    border_width: reactive.Signal(f32),
    focus_color: reactive.Signal(Color),
    normal_color: reactive.Signal(Color),
    border_style: reactive.Signal(BorderStyle),

    const Self = @This();

    pub fn init(self: *Component, allocator: std.mem.Allocator, props: ComponentProps) !void {
        _ = props;
        const border: *FocusableBorder = @fieldParentPtr("base", self);

        // Initialize reactive signals with sensible defaults
        border.is_focused = try reactive.signal(allocator, bool, false);
        border.border_width = try reactive.signal(allocator, f32, 2.0);
        border.focus_color = try reactive.signal(allocator, Color, Color{ .r = 70, .g = 130, .b = 180, .a = 255 }); // Selection blue
        border.normal_color = try reactive.signal(allocator, Color, Color{ .r = 60, .g = 65, .b = 75, .a = 255 }); // Subtle gray
        border.border_style = try reactive.signal(allocator, BorderStyle, .solid);
    }

    pub fn deinit(self: *Component, allocator: std.mem.Allocator) void {
        _ = allocator;
        const border: *FocusableBorder = @fieldParentPtr("base", self);

        border.is_focused.deinit();
        border.border_width.deinit();
        border.focus_color.deinit();
        border.normal_color.deinit();
        border.border_style.deinit();
    }

    pub fn update(self: *Component, dt: f32) void {
        _ = self;
        _ = dt;
        // No update logic needed for static border
    }

    /// Render the border around the given bounds
    pub fn render(self: *const Component, renderer: anytype) !void {
        const border: *const FocusableBorder = @fieldParentPtr("base", self);

        if (!self.props.visible.get()) return;

        const bounds = self.props.getBounds();
        const focused = border.is_focused.get();
        const width = border.border_width.get();
        const color = if (focused) border.focus_color.get() else border.normal_color.get();

        // Only render if we have a visible border
        if (width > 0 and color.a > 0) {
            try self.renderBorderRects(renderer, bounds, width, color);
        }
    }

    /// Render border as separate rectangles (top, bottom, left, right)
    fn renderBorderRects(self: *const Component, renderer: anytype, bounds: Rectangle, width: f32, color: Color) !void {
        _ = self;

        if (@hasDecl(@TypeOf(renderer), "drawRect")) {
            // Top border
            try renderer.drawRect(Vec2{ .x = bounds.position.x - width, .y = bounds.position.y - width }, Vec2{ .x = bounds.size.x + 2 * width, .y = width }, color);

            // Bottom border
            try renderer.drawRect(Vec2{ .x = bounds.position.x - width, .y = bounds.position.y + bounds.size.y }, Vec2{ .x = bounds.size.x + 2 * width, .y = width }, color);

            // Left border
            try renderer.drawRect(Vec2{ .x = bounds.position.x - width, .y = bounds.position.y }, Vec2{ .x = width, .y = bounds.size.y }, color);

            // Right border
            try renderer.drawRect(Vec2{ .x = bounds.position.x + bounds.size.x, .y = bounds.position.y }, Vec2{ .x = width, .y = bounds.size.y }, color);
        }
    }

    pub fn handleEvent(self: *Component, event: anytype) bool {
        _ = self;
        _ = event;
        return false; // Border doesn't handle events
    }

    pub fn destroy(self: *Component, allocator: std.mem.Allocator) void {
        const border: *FocusableBorder = @fieldParentPtr("base", self);
        allocator.destroy(border);
    }

    /// Set focus state
    pub fn setFocus(self: *FocusableBorder, focused: bool) void {
        self.is_focused.set(focused);
    }

    /// Get current focus state
    pub fn isFocused(self: *const FocusableBorder) bool {
        return self.is_focused.get();
    }

    /// Set border width
    pub fn setBorderWidth(self: *FocusableBorder, width: f32) void {
        self.border_width.set(width);
    }

    /// Set focus color
    pub fn setFocusColor(self: *FocusableBorder, color: Color) void {
        self.focus_color.set(color);
    }

    /// Set normal (unfocused) color
    pub fn setNormalColor(self: *FocusableBorder, color: Color) void {
        self.normal_color.set(color);
    }
};

/// Create a focusable border component
pub fn createFocusableBorder(allocator: std.mem.Allocator, bounds: Rectangle) !*FocusableBorder {
    const border = try allocator.create(FocusableBorder);

    const props = ComponentProps{
        .bounds = try reactive.signal(allocator, Rectangle, bounds),
        .visible = try reactive.signal(allocator, bool, true),
        .background_color = try reactive.signal(allocator, Color, Color{ .r = 0, .g = 0, .b = 0, .a = 0 }), // Transparent
    };

    border.* = FocusableBorder{
        .base = Component{
            .props = props,
            .vtable = Component.VTable{
                .init = FocusableBorder.init,
                .deinit = FocusableBorder.deinit,
                .update = FocusableBorder.update,
                .render = FocusableBorder.render,
                .handleEvent = FocusableBorder.handleEvent,
                .destroy = FocusableBorder.destroy,
            },
        },
        .is_focused = undefined, // Will be initialized in init()
        .border_width = undefined,
        .focus_color = undefined,
        .normal_color = undefined,
        .border_style = undefined,
    };

    try border.base.vtable.init(&border.base, allocator, props);
    return border;
}
