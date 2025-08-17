const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const reactive = @import("../reactive/mod.zig");
const component = @import("component.zig");
const text = @import("text.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const Component = component.Component;
const ComponentProps = component.ComponentProps;
const Text = text.Text;
const TextStyle = text.TextStyle;

/// Button states for visual feedback
pub const ButtonState = enum {
    normal,
    hovered,
    pressed,
    disabled,
};

/// Button styling configuration
pub const ButtonStyle = struct {
    // Background colors for different states
    normal_color: Color = Color{ .r = 60, .g = 60, .b = 60, .a = 255 },
    hover_color: Color = Color{ .r = 80, .g = 80, .b = 80, .a = 255 },
    pressed_color: Color = Color{ .r = 40, .g = 40, .b = 40, .a = 255 },
    disabled_color: Color = Color{ .r = 30, .g = 30, .b = 30, .a = 255 },

    // Border colors
    border_normal: Color = Color{ .r = 120, .g = 120, .b = 120, .a = 255 },
    border_hover: Color = Color{ .r = 160, .g = 160, .b = 160, .a = 255 },
    border_pressed: Color = Color{ .r = 100, .g = 100, .b = 100, .a = 255 },
    border_disabled: Color = Color{ .r = 60, .g = 60, .b = 60, .a = 255 },

    // Border width
    border_width: f32 = 1.0,

    // Corner radius for rounded buttons
    corner_radius: f32 = 4.0,

    // Padding inside the button
    padding: Vec2 = Vec2{ .x = 16, .y = 8 },

    pub fn getBackgroundColor(self: *const ButtonStyle, state: ButtonState) Color {
        return switch (state) {
            .normal => self.normal_color,
            .hovered => self.hover_color,
            .pressed => self.pressed_color,
            .disabled => self.disabled_color,
        };
    }

    pub fn getBorderColor(self: *const ButtonStyle, state: ButtonState) Color {
        return switch (state) {
            .normal => self.border_normal,
            .hovered => self.border_hover,
            .pressed => self.border_pressed,
            .disabled => self.border_disabled,
        };
    }
};

/// Interactive button component with text label
pub const Button = struct {
    base: Component,

    // Button properties (reactive)
    label: reactive.Signal([]const u8),
    button_style: reactive.Signal(ButtonStyle),
    text_style: reactive.Signal(TextStyle),
    state: reactive.Signal(ButtonState),

    // Child text component
    text_component: ?*Component = null,

    // Event handlers
    on_click: ?*const fn () void = null,
    on_hover_start: ?*const fn () void = null,
    on_hover_end: ?*const fn () void = null,

    // Internal state tracking
    is_pressed: bool = false,

    const Self = @This();

    pub fn init(self: *Component, allocator: std.mem.Allocator, props: ComponentProps) !void {
        const button: *Button = @fieldParentPtr("base", self);

        // Initialize button-specific signals
        button.label = try reactive.signal(allocator, []const u8, "Button");
        button.button_style = try reactive.signal(allocator, ButtonStyle, ButtonStyle{});
        button.text_style = try reactive.signal(allocator, TextStyle, TextStyle{
            .font_size = 14.0,
            .color = Color{ .r = 255, .g = 255, .b = 255, .a = 255 }, // White text
            // .align = .center, // TODO: Add align field to TextStyle if needed
        });
        button.state = try reactive.signal(allocator, ButtonState, .normal);

        // Create child text component for the label
        const initial_label = button.label.get();
        const initial_text_style = button.text_style.get();
        const button_bounds = props.getBounds();
        const text_position = Vec2{
            .x = button_bounds.position.x + button.button_style.get().padding.x,
            .y = button_bounds.position.y + button.button_style.get().padding.y,
        };

        button.text_component = try text.createText(allocator, initial_label, text_position, initial_text_style);
        try self.addChild(button.text_component.?);

        // Set up reactive effects to update child text when label or style changes
        const UpdateTextContext = struct {
            button_ptr: *Button,

            fn updateText(context: @This()) void {
                if (context.button_ptr.text_component) |text_comp| {
                    const text_impl: *Text = @fieldParentPtr("base", text_comp);
                    text_impl.setText(context.button_ptr.label.get());
                    text_impl.setStyle(context.button_ptr.text_style.get());

                    // Update text position to center it in the button
                    context.button_ptr.centerText();
                }
            }
        };

        const update_context = UpdateTextContext{ .button_ptr = button };
        _ = try reactive.createEffect(allocator, update_context.updateText);

        // Set up reactive effect to update visual state
        const UpdateStateContext = struct {
            button_ptr: *Button,

            fn updateVisuals(context: @This()) void {
                const current_state = context.button_ptr.state.get();
                const style = context.button_ptr.button_style.get();

                // Update component background and border colors
                context.button_ptr.base.props.background_color.set(style.getBackgroundColor(current_state));
                context.button_ptr.base.props.border_color.set(style.getBorderColor(current_state));

                // Update hover state in base component
                context.button_ptr.base.props.hovered.set(current_state == .hovered);
                context.button_ptr.base.props.enabled.set(current_state != .disabled);
            }
        };

        const state_context = UpdateStateContext{ .button_ptr = button };
        _ = try reactive.createEffect(allocator, state_context.updateVisuals);
    }

    pub fn deinit(self: *Component, allocator: std.mem.Allocator) void {
        const button: *Button = @fieldParentPtr("base", self);

        // Cleanup button-specific signals
        button.label.deinit();
        button.button_style.deinit();
        button.text_style.deinit();
        button.state.deinit();

        // Child text component will be cleaned up by base Component.deinit()
    }

    pub fn update(self: *Component, dt: f32) void {
        _ = dt;
        const button: *Button = @fieldParentPtr("base", self);

        // Update button state based on interaction
        button.updateInteractionState();
    }

    pub fn render(self: *const Component, renderer: anytype) !void {
        const button: *const Button = @fieldParentPtr("base", self);

        if (!self.props.visible.get()) return;

        const bounds = self.props.getBounds();
        const style = button.button_style.get();
        const current_state = button.state.get();

        // Render button background
        const bg_color = style.getBackgroundColor(current_state);
        if (@hasDecl(@TypeOf(renderer), "drawRoundedRect")) {
            try renderer.drawRoundedRect(bounds, bg_color, style.corner_radius);
        } else if (@hasDecl(@TypeOf(renderer), "drawRect")) {
            try renderer.drawRect(bounds, bg_color);
        }

        // Render button border
        if (style.border_width > 0) {
            const border_color = style.getBorderColor(current_state);
            if (@hasDecl(@TypeOf(renderer), "drawRoundedRectBorder")) {
                try renderer.drawRoundedRectBorder(bounds, border_color, style.border_width, style.corner_radius);
            } else if (@hasDecl(@TypeOf(renderer), "drawRectBorder")) {
                try renderer.drawRectBorder(bounds, border_color, style.border_width);
            }
        }

        // Child text component will render itself via base Component.render()
    }

    pub fn handleEvent(self: *Component, event: anytype) bool {
        const button: *Button = @fieldParentPtr("base", self);

        if (!self.props.enabled.get() or !self.props.visible.get()) return false;

        // Handle mouse events (assuming event has mouse_x, mouse_y, mouse_pressed, etc.)
        if (@hasField(@TypeOf(event), "mouse_x") and @hasField(@TypeOf(event), "mouse_y")) {
            const mouse_pos = Vec2{ .x = event.mouse_x, .y = event.mouse_y };
            const is_over = self.props.containsPoint(mouse_pos);

            if (is_over) {
                // Mouse is over button
                if (@hasField(@TypeOf(event), "mouse_pressed") and event.mouse_pressed and !button.is_pressed) {
                    // Mouse press started
                    button.is_pressed = true;
                    button.state.set(.pressed);
                    return true;
                } else if (@hasField(@TypeOf(event), "mouse_released") and event.mouse_released and button.is_pressed) {
                    // Mouse released over button - trigger click
                    button.is_pressed = false;
                    button.state.set(.hovered);

                    if (button.on_click) |click_handler| {
                        click_handler();
                    }
                    return true;
                } else if (!button.is_pressed and button.state.get() != .hovered) {
                    // Just hovering
                    button.state.set(.hovered);
                    if (button.on_hover_start) |hover_handler| {
                        hover_handler();
                    }
                }
            } else {
                // Mouse is not over button
                if (button.state.get() == .hovered or button.state.get() == .pressed) {
                    button.state.set(.normal);
                    button.is_pressed = false;
                    if (button.on_hover_end) |hover_end_handler| {
                        hover_end_handler();
                    }
                }
            }
        }

        return false;
    }

    pub fn destroy(self: *Component, allocator: std.mem.Allocator) void {
        const button: *Button = @fieldParentPtr("base", self);
        allocator.destroy(button);
    }

    /// Update interaction state based on current conditions
    fn updateInteractionState(self: *Button) void {
        if (!self.base.props.enabled.get()) {
            self.state.set(.disabled);
            return;
        }

        // State is updated by event handling
    }

    /// Center the text within the button
    fn centerText(self: *Button) void {
        if (self.text_component) |text_comp| {
            const button_bounds = self.base.props.getBounds();
            const style = self.button_style.get();
            const text_impl: *Text = @fieldParentPtr("base", text_comp);
            const text_size = text_impl.getMeasuredSize();

            // Center the text within the button
            const centered_pos = Vec2{
                .x = button_bounds.position.x + (button_bounds.size.x - text_size.x) / 2,
                .y = button_bounds.position.y + (button_bounds.size.y - text_size.y) / 2,
            };

            text_comp.props.position.set(centered_pos);
        }
    }

    /// Set the button label text
    pub fn setLabel(self: *Button, new_label: []const u8) void {
        self.label.set(new_label);
    }

    /// Set button style
    pub fn setButtonStyle(self: *Button, new_style: ButtonStyle) void {
        self.button_style.set(new_style);
    }

    /// Set text style
    pub fn setTextStyle(self: *Button, new_style: TextStyle) void {
        self.text_style.set(new_style);
    }

    /// Set click handler
    pub fn setOnClick(self: *Button, click_handler: *const fn () void) void {
        self.on_click = click_handler;
    }

    /// Set hover handlers
    pub fn setOnHover(self: *Button, hover_start: ?*const fn () void, hover_end: ?*const fn () void) void {
        self.on_hover_start = hover_start;
        self.on_hover_end = hover_end;
    }

    /// Enable or disable the button
    pub fn setEnabled(self: *Button, enabled: bool) void {
        self.base.props.enabled.set(enabled);
        if (!enabled) {
            self.state.set(.disabled);
            self.is_pressed = false;
        } else if (self.state.get() == .disabled) {
            self.state.set(.normal);
        }
    }
};

/// Create a new button component
pub fn createButton(allocator: std.mem.Allocator, label: []const u8, position: Vec2, size: Vec2, style: ButtonStyle, click_handler: ?*const fn () void) !*Component {
    const button = try allocator.create(Button);

    var props = try ComponentProps.init(allocator, position, size);

    button.* = Button{
        .base = Component{
            .vtable = Component.VTable{
                .init = Button.init,
                .deinit = Button.deinit,
                .update = Button.update,
                .render = Button.render,
                .handle_event = Button.handleEvent,
                .destroy = Button.destroy,
            },
            .props = props,
            .children = std.ArrayList(*Component).init(allocator),
            .parent = null,
        },
        .label = undefined, // Will be initialized in init()
        .button_style = undefined,
        .text_style = undefined,
        .state = undefined,
        .on_click = click_handler,
    };

    try button.base.init(allocator, props);

    // Set initial label and style
    button.setLabel(label);
    button.setButtonStyle(style);

    return &button.base;
}

/// Create a simple button with default styling
pub fn createSimpleButton(allocator: std.mem.Allocator, label: []const u8, position: Vec2, click_handler: ?*const fn () void) !*Component {
    // Calculate size based on text length
    const estimated_width = @as(f32, @floatFromInt(label.len)) * 8.0 + 32.0; // Rough estimate + padding
    const size = Vec2{ .x = estimated_width, .y = 36.0 };

    return try createButton(allocator, label, position, size, ButtonStyle{}, click_handler);
}

// Tests
test "button creation and basic operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try reactive.init(allocator);
    defer reactive.deinit(allocator);

    var clicked = false;
    const TestClickHandler = struct {
        fn onClick() void {
            clicked = true;
        }
    };

    var button = try createSimpleButton(allocator, "Test Button", Vec2{ .x = 10, .y = 20 }, TestClickHandler.onClick);
    defer button.destroy(allocator);

    const button_impl: *Button = @fieldParentPtr("base", button);

    // Test initial state
    try std.testing.expect(std.mem.eql(u8, button_impl.label.get(), "Test Button"));
    try std.testing.expect(button_impl.state.get() == .normal);

    // Test label change
    button_impl.setLabel("New Label");
    try std.testing.expect(std.mem.eql(u8, button_impl.label.get(), "New Label"));

    // Test enable/disable
    button_impl.setEnabled(false);
    try std.testing.expect(button_impl.state.get() == .disabled);

    button_impl.setEnabled(true);
    try std.testing.expect(button_impl.state.get() == .normal);
}

test "button style color handling" {
    const style = ButtonStyle{};

    // Test different state colors
    try std.testing.expect(style.getBackgroundColor(.normal).r == 60);
    try std.testing.expect(style.getBackgroundColor(.hovered).r == 80);
    try std.testing.expect(style.getBackgroundColor(.pressed).r == 40);
    try std.testing.expect(style.getBackgroundColor(.disabled).r == 30);

    // Ensure no bright yellow colors
    const hover_color = style.getBackgroundColor(.hovered);
    try std.testing.expect(!(hover_color.r == 255 and hover_color.g == 255 and hover_color.b == 0));
}
