const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const reactive = @import("../reactive/mod.zig");
const base_component = @import("base_component.zig");
const text_display = @import("text_display.zig");
const styles = @import("styles/mod.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const ComponentProps = base_component.ComponentProps;
const Component = base_component.Component;
const TextDisplay = text_display.TextDisplay;

// Re-export unified button styling
pub const ButtonState = styles.ButtonState;
pub const ButtonStyle = styles.ButtonStyle;

/// Button component data
pub const ButtonData = struct {
    text: reactive.Signal([]const u8),
    state: reactive.Signal(ButtonState),
    style: ButtonStyle,

    // Event handlers
    on_click: ?*const fn () void = null,
    on_hover_start: ?*const fn () void = null,
    on_hover_end: ?*const fn () void = null,

    // Internal tracking
    is_pressed: bool = false,
    mouse_inside: bool = false,

    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, text: []const u8, style: ButtonStyle) !Self {
        return Self{
            .text = try reactive.signal(allocator, []const u8, text),
            .state = try reactive.signal(allocator, ButtonState, .normal),
            .style = style,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.text.deinit();
        self.state.deinit();
    }

    /// Set button text
    pub fn setText(self: *Self, new_text: []const u8) void {
        self.text.set(new_text);
    }

    /// Get button text (reactive)
    pub fn getText(self: *Self) []const u8 {
        return self.text.get();
    }

    /// Peek at button text (non-reactive)
    pub fn peekText(self: *const Self) []const u8 {
        return self.text.peek();
    }

    /// Set click handler
    pub fn setOnClick(self: *Self, handler: *const fn () void) void {
        self.on_click = handler;
    }

    /// Set hover handlers
    pub fn setOnHover(self: *Self, hover_start: ?*const fn () void, hover_end: ?*const fn () void) void {
        self.on_hover_start = hover_start;
        self.on_hover_end = hover_end;
    }

    /// Update button state based on interactions
    pub fn updateState(self: *Self, mouse_pos: Vec2, mouse_pressed: bool, mouse_released: bool, button_bounds: Vec2, button_size: Vec2) void {
        const mouse_in_bounds = mouse_pos.x >= button_bounds.x and
            mouse_pos.x <= button_bounds.x + button_size.x and
            mouse_pos.y >= button_bounds.y and
            mouse_pos.y <= button_bounds.y + button_size.y;

        // Handle mouse enter/leave
        if (mouse_in_bounds != self.mouse_inside) {
            self.mouse_inside = mouse_in_bounds;
            if (mouse_in_bounds and self.on_hover_start) |handler| {
                handler();
            } else if (!mouse_in_bounds and self.on_hover_end) |handler| {
                handler();
            }
        }

        // Update state based on interaction
        if (!mouse_in_bounds) {
            self.state.set(.normal);
            self.is_pressed = false;
        } else {
            if (mouse_pressed and !self.is_pressed) {
                self.is_pressed = true;
                self.state.set(.pressed);
            } else if (mouse_released and self.is_pressed) {
                self.is_pressed = false;
                self.state.set(.hovered);

                // Trigger click event
                if (self.on_click) |handler| {
                    handler();
                }
            } else if (!self.is_pressed) {
                self.state.set(.hovered);
            }
        }
    }

    /// Get estimated button size based on text
    pub fn getEstimatedSize(self: *const Self) Vec2 {
        const text_content = self.text.peek();
        const text_width = @as(f32, @floatFromInt(text_content.len)) * self.style.font_size * 0.6;
        return Vec2{
            .x = text_width + (self.style.padding.x * 2),
            .y = self.style.font_size + (self.style.padding.y * 2),
        };
    }
};

/// Type alias for complete button component
pub const SimpleButton = Component(ButtonData);

/// Render function for button
pub fn renderButton(button_ref: *const anyopaque, renderer: anytype, props: *const ComponentProps) !void {
    const button: *const SimpleButton = @ptrCast(@alignCast(button_ref));

    if (!button.shouldRender()) return;

    const button_data = button.getDataConst();
    const position = props.peekPosition();
    const size = button_data.getEstimatedSize();
    const current_state = button_data.state.peek();

    // Get colors based on state
    const bg_color = button_data.style.getBackgroundColor(current_state);
    const border_color = button_data.style.getBorderColor(current_state);

    // Draw button background
    if (@hasDecl(@TypeOf(renderer), "drawRoundedRect")) {
        try renderer.drawRoundedRect(math.Rectangle.init(position, size), bg_color, button_data.style.corner_radius);
    } else if (@hasDecl(@TypeOf(renderer), "drawRect")) {
        try renderer.drawRect(math.Rectangle.init(position, size), bg_color);
    }

    // Draw border
    if (button_data.style.border_width > 0) {
        if (@hasDecl(@TypeOf(renderer), "drawRoundedRectBorder")) {
            try renderer.drawRoundedRectBorder(math.Rectangle.init(position, size), border_color, button_data.style.border_width, button_data.style.corner_radius);
        }
    }

    // Draw text (centered)
    const text = button_data.text.peek();
    if (text.len > 0) {
        if (@hasDecl(@TypeOf(renderer), "drawText")) {
            const text_width = @as(f32, @floatFromInt(text.len)) * button_data.style.font_size * 0.6;
            const text_pos = Vec2{
                .x = position.x + (size.x - text_width) / 2,
                .y = position.y + (size.y - button_data.style.font_size) / 2,
            };

            try renderer.drawText(text, text_pos.x, text_pos.y, button_data.style.font_size, button_data.style.text_color);
        }
    }
}

/// Handle events for button
pub fn handleButtonEvent(button_ref: *anyopaque, event: anytype, props: *ComponentProps) bool {
    const button: *SimpleButton = @ptrCast(@alignCast(button_ref));

    if (!button.getPropsConst().isActive()) return false;

    const button_data = button.getData();

    // Handle mouse events
    if (@hasField(@TypeOf(event), "mouse_x") and @hasField(@TypeOf(event), "mouse_y")) {
        const mouse_pos = Vec2{ .x = event.mouse_x, .y = event.mouse_y };
        const mouse_pressed = @hasField(@TypeOf(event), "mouse_pressed") and event.mouse_pressed;
        const mouse_released = @hasField(@TypeOf(event), "mouse_released") and event.mouse_released;

        const position = props.peekPosition();
        const size = button_data.getEstimatedSize();

        button_data.updateState(mouse_pos, mouse_pressed, mouse_released, position, size);
        return true;
    }

    return false;
}

/// Create a simple button
pub fn createButton(allocator: std.mem.Allocator, text: []const u8, position: Vec2, style: ButtonStyle, click_handler: ?*const fn () void) !SimpleButton {
    var button_data = try ButtonData.init(allocator, text, style);

    if (click_handler) |handler| {
        button_data.setOnClick(handler);
    }

    return SimpleButton.init(allocator, position, button_data);
}

/// Create a button with default styling
pub fn createDefaultButton(allocator: std.mem.Allocator, text: []const u8, position: Vec2, click_handler: ?*const fn () void) !SimpleButton {
    return createButton(allocator, text, position, ButtonStyle{}, click_handler);
}

// Tests
test "simple button creation" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const reactive_mod = @import("../reactive/mod.zig");
    try reactive_mod.init(allocator);
    defer reactive_mod.deinit(allocator);

    const TestClick = struct {
        fn onClick() void {}
    };

    var button = try createDefaultButton(allocator, "Test Button", Vec2{ .x = 10, .y = 20 }, TestClick.onClick);
    defer button.deinit();

    // Test initial state
    try testing.expect(std.mem.eql(u8, button.getData().peekText(), "Test Button"));
    try testing.expectEqual(Vec2{ .x = 10, .y = 20 }, button.peekPosition());
    try testing.expect(button.shouldRender());

    // Test text change
    button.getData().setText("New Text");
    try testing.expect(std.mem.eql(u8, button.getData().peekText(), "New Text"));

    // Test size estimation
    const estimated_size = button.getDataConst().getEstimatedSize();
    try testing.expect(estimated_size.x > 0);
    try testing.expect(estimated_size.y > 0);
}
