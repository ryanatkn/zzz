const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const reactive = @import("../reactive/mod.zig");
const styles = @import("styles/mod.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;
const Color = colors.Color;

// Input field content padding (replaces hardcoded magic numbers)
const INPUT_PADDING = 4.0;

/// Base UI component with retained mode optimizations
pub const UIComponent = struct {
    bounds: reactive.Signal(Rectangle),
    visible: reactive.Signal(bool),
    dirty: reactive.Signal(bool), // Tracks if component needs re-rendering

    /// Initialize base component
    pub fn init(allocator: std.mem.Allocator, initial_bounds: Rectangle) !UIComponent {
        return UIComponent{
            .bounds = try reactive.signal(allocator, Rectangle, initial_bounds),
            .visible = try reactive.signal(allocator, bool, true),
            .dirty = try reactive.signal(allocator, bool, true),
        };
    }

    /// Cleanup component
    pub fn deinit(self: *UIComponent) void {
        self.bounds.deinit();
        self.visible.deinit();
        self.dirty.deinit();
    }

    /// Set bounds and mark as dirty
    pub fn setBounds(self: *UIComponent, bounds: Rectangle) void {
        self.bounds.set(bounds);
        self.markDirty();
    }

    /// Set visibility
    pub fn setVisible(self: *UIComponent, visible: bool) void {
        self.visible.set(visible);
        if (visible) self.markDirty();
    }

    /// Mark component as needing re-render
    pub fn markDirty(self: *UIComponent) void {
        self.dirty.set(true);
    }

    /// Clear dirty flag after rendering
    pub fn clearDirty(self: *UIComponent) void {
        self.dirty.set(false);
    }

    /// Check if component is visible and needs rendering
    pub fn shouldRender(self: *const UIComponent) bool {
        return self.visible.peek() and self.dirty.peek();
    }

    /// Get current bounds
    pub fn getBounds(self: *const UIComponent) Rectangle {
        return self.bounds.peek();
    }

    /// Check if point is inside component bounds
    pub fn containsPoint(self: *const UIComponent, point: Vec2) bool {
        const bounds = self.bounds.peek();
        return point.x >= bounds.position.x and
            point.x <= bounds.position.x + bounds.size.x and
            point.y >= bounds.position.y and
            point.y <= bounds.position.y + bounds.size.y;
    }
};

/// Panel component with background and border
pub const Panel = struct {
    base: UIComponent,
    background_color: reactive.Signal(Color),
    border_color: reactive.Signal(Color),
    border_width: reactive.Signal(f32),
    padding: reactive.Signal(f32),

    /// Initialize panel
    pub fn init(allocator: std.mem.Allocator, bounds: Rectangle, config: PanelConfig) !Panel {
        return Panel{
            .base = try UIComponent.init(allocator, bounds),
            .background_color = try reactive.signal(allocator, Color, config.background_color),
            .border_color = try reactive.signal(allocator, Color, config.border_color),
            .border_width = try reactive.signal(allocator, f32, config.border_width),
            .padding = try reactive.signal(allocator, f32, config.padding),
        };
    }

    /// Cleanup panel
    pub fn deinit(self: *Panel) void {
        self.background_color.deinit();
        self.border_color.deinit();
        self.border_width.deinit();
        self.padding.deinit();
        self.base.deinit();
    }

    /// Get content area (bounds minus padding)
    pub fn getContentArea(self: *const Panel) Rectangle {
        const bounds = self.base.getBounds();
        const pad = self.padding.peek();
        return Rectangle{
            .position = Vec2{ .x = bounds.position.x + pad, .y = bounds.position.y + pad },
            .size = Vec2{ .x = bounds.size.x - (pad * 2), .y = bounds.size.y - (pad * 2) },
        };
    }

    /// Render panel (to be called by renderer)
    pub fn render(self: *Panel, renderer: anytype) void {
        if (!self.base.shouldRender()) return;

        const bounds = self.base.getBounds();
        const bg_color = self.background_color.get();
        const border_color = self.border_color.get();
        const border_width = self.border_width.get();

        // Draw background
        if (@hasDecl(@TypeOf(renderer), "drawRect")) {
            renderer.drawRect(bounds, bg_color);
        }

        // Draw border if enabled
        if (border_width > 0) {
            drawBorder(renderer, bounds, border_color, border_width);
        }

        self.base.clearDirty();
    }

    /// Draw border around rectangle
    fn drawBorder(renderer: anytype, rect: Rectangle, color: Color, width: f32) void {
        if (@hasDecl(@TypeOf(renderer), "drawRect")) {
            // Top border
            renderer.drawRect(Rectangle{
                .position = rect.position,
                .size = Vec2{ .x = rect.size.x, .y = width },
            }, color);
            // Bottom border
            renderer.drawRect(Rectangle{
                .position = Vec2{ .x = rect.position.x, .y = rect.position.y + rect.size.y - width },
                .size = Vec2{ .x = rect.size.x, .y = width },
            }, color);
            // Left border
            renderer.drawRect(Rectangle{
                .position = rect.position,
                .size = Vec2{ .x = width, .y = rect.size.y },
            }, color);
            // Right border
            renderer.drawRect(Rectangle{
                .position = Vec2{ .x = rect.position.x + rect.size.x - width, .y = rect.position.y },
                .size = Vec2{ .x = width, .y = rect.size.y },
            }, color);
        }
    }
};

/// Configuration for panel styling
pub const PanelConfig = struct {
    background_color: Color = colors.DARK_GRAY_40,
    border_color: Color = colors.GRAY_80,
    border_width: f32 = 1.0,
    padding: f32 = 8.0,
};

/// Text input field component
pub const InputField = struct {
    base: UIComponent,
    text: reactive.Signal([]const u8),
    focused: reactive.Signal(bool),
    cursor_position: reactive.Signal(usize),
    font_size: reactive.Signal(f32),
    text_color: reactive.Signal(Color),
    background_color: reactive.Signal(Color),

    // Memory management
    allocator: std.mem.Allocator,
    owned_text: ?[]u8 = null, // Track allocated text to free it later

    /// Initialize input field
    pub fn init(allocator: std.mem.Allocator, bounds: Rectangle, config: InputFieldConfig) !InputField {
        return InputField{
            .base = try UIComponent.init(allocator, bounds),
            .text = try reactive.signal(allocator, []const u8, config.initial_text),
            .focused = try reactive.signal(allocator, bool, false),
            .cursor_position = try reactive.signal(allocator, usize, 0),
            .font_size = try reactive.signal(allocator, f32, config.font_size),
            .text_color = try reactive.signal(allocator, Color, config.text_color),
            .background_color = try reactive.signal(allocator, Color, config.background_color),
            .allocator = allocator,
        };
    }

    /// Cleanup input field
    pub fn deinit(self: *InputField) void {
        // Free owned text if it exists
        if (self.owned_text) |text| {
            self.allocator.free(text);
        }

        self.text.deinit();
        self.focused.deinit();
        self.cursor_position.deinit();
        self.font_size.deinit();
        self.text_color.deinit();
        self.background_color.deinit();
        self.base.deinit();
    }

    /// Set focus state
    pub fn setFocus(self: *InputField, focused: bool) void {
        self.focused.set(focused);
        self.base.markDirty();
    }

    /// Set text content (takes ownership if it's allocated)
    pub fn setText(self: *InputField, text: []const u8) void {
        // Free previous owned text
        if (self.owned_text) |old_text| {
            self.allocator.free(old_text);
            self.owned_text = null;
        }

        self.text.set(text);
        self.cursor_position.set(@min(self.cursor_position.peek(), text.len));
        self.base.markDirty();
    }

    /// Set text content from owned string (takes ownership)
    pub fn setOwnedText(self: *InputField, owned_text: []u8) void {
        // Free previous owned text
        if (self.owned_text) |old_text| {
            self.allocator.free(old_text);
        }

        self.owned_text = owned_text;
        self.text.set(owned_text);
        self.cursor_position.set(@min(self.cursor_position.peek(), owned_text.len));
        self.base.markDirty();
    }

    /// Handle character input
    pub fn handleChar(self: *InputField, ch: u8) !void {
        if (!self.focused.get()) return;

        const current_text = self.text.peek();
        const cursor_pos = self.cursor_position.peek();

        // Create new string with character inserted
        var new_text = try self.allocator.alloc(u8, current_text.len + 1);
        @memcpy(new_text[0..cursor_pos], current_text[0..cursor_pos]);
        new_text[cursor_pos] = ch;
        @memcpy(new_text[cursor_pos + 1 ..], current_text[cursor_pos..]);

        self.setOwnedText(new_text);
        self.cursor_position.set(cursor_pos + 1);
    }

    /// Handle backspace
    pub fn handleBackspace(self: *InputField) !void {
        if (!self.focused.get()) return;

        const current_text = self.text.peek();
        const cursor_pos = self.cursor_position.peek();

        if (cursor_pos == 0) return;

        // Create new string with character removed
        var new_text = try self.allocator.alloc(u8, current_text.len - 1);
        @memcpy(new_text[0 .. cursor_pos - 1], current_text[0 .. cursor_pos - 1]);
        @memcpy(new_text[cursor_pos - 1 ..], current_text[cursor_pos..]);

        self.setOwnedText(new_text);
        self.cursor_position.set(cursor_pos - 1);
    }

    /// Render input field
    pub fn render(self: *InputField, renderer: anytype) void {
        if (!self.base.shouldRender()) return;

        const bounds = self.base.getBounds();
        const text = self.text.get();
        const is_focused = self.focused.get();
        const bg_color = self.background_color.get();
        const text_color = self.text_color.get();
        const font_size = self.font_size.get();

        // Draw background
        if (@hasDecl(@TypeOf(renderer), "drawRect")) {
            renderer.drawRect(bounds, bg_color);
        }

        // Draw border (focused = thicker)
        const border_color = if (is_focused)
            colors.FOCUS_BORDER
        else
            colors.GRAY_80;
        const border_width: f32 = if (is_focused) 2.0 else 1.0;

        Panel.drawBorder(renderer, bounds, border_color, border_width);

        // Draw text
        if (text.len > 0) {
            if (@hasDecl(@TypeOf(renderer), "drawText")) {
                renderer.drawText(text, bounds.position.x + INPUT_PADDING, bounds.position.y + INPUT_PADDING, font_size, text_color);
            }
        }

        // Draw cursor if focused
        if (is_focused) {
            const cursor_pos = self.cursor_position.get();
            const char_width = font_size * 0.6; // Estimate character width
            const cursor_x = bounds.position.x + INPUT_PADDING + @as(f32, @floatFromInt(cursor_pos)) * char_width;

            if (@hasDecl(@TypeOf(renderer), "drawRect")) {
                renderer.drawRect(Rectangle{
                    .position = Vec2{ .x = cursor_x, .y = bounds.position.y + INPUT_PADDING },
                    .size = Vec2{ .x = 1, .y = font_size },
                }, text_color);
            }
        }

        self.base.clearDirty();
    }
};

/// Configuration for input field styling
pub const InputFieldConfig = struct {
    initial_text: []const u8 = "",
    font_size: f32 = styles.FontSizes.normal,
    text_color: Color = colors.WHITE,
    background_color: Color = colors.DARK_GRAY_30,
};

/// Button component with hover/press states
pub const Button = struct {
    base: UIComponent,
    text: reactive.Signal([]const u8),
    hovered: reactive.Signal(bool),
    pressed: reactive.Signal(bool),
    enabled: reactive.Signal(bool),
    font_size: reactive.Signal(f32),

    // Style colors
    normal_color: Color,
    hover_color: Color,
    pressed_color: Color,
    disabled_color: Color,
    text_color: Color,

    /// Initialize button
    pub fn init(allocator: std.mem.Allocator, bounds: Rectangle, text: []const u8, config: ButtonConfig) !Button {
        return Button{
            .base = try UIComponent.init(allocator, bounds),
            .text = try reactive.signal(allocator, []const u8, text),
            .hovered = try reactive.signal(allocator, bool, false),
            .pressed = try reactive.signal(allocator, bool, false),
            .enabled = try reactive.signal(allocator, bool, true),
            .font_size = try reactive.signal(allocator, f32, config.font_size),
            .normal_color = config.normal_color,
            .hover_color = config.hover_color,
            .pressed_color = config.pressed_color,
            .disabled_color = config.disabled_color,
            .text_color = config.text_color,
        };
    }

    /// Cleanup button
    pub fn deinit(self: *Button) void {
        self.text.deinit();
        self.hovered.deinit();
        self.pressed.deinit();
        self.enabled.deinit();
        self.font_size.deinit();
        self.base.deinit();
    }

    /// Handle mouse hover
    pub fn setHovered(self: *Button, hovered: bool) void {
        if (self.hovered.get() != hovered) {
            self.hovered.set(hovered);
            self.base.markDirty();
        }
    }

    /// Handle mouse press/release
    pub fn setPressed(self: *Button, pressed: bool) void {
        if (self.pressed.get() != pressed) {
            self.pressed.set(pressed);
            self.base.markDirty();
        }
    }

    /// Set enabled state
    pub fn setEnabled(self: *Button, enabled: bool) void {
        if (self.enabled.get() != enabled) {
            self.enabled.set(enabled);
            self.base.markDirty();
        }
    }

    /// Handle click (returns true if button was clicked)
    pub fn handleClick(self: *Button, point: Vec2) bool {
        if (!self.enabled.get()) return false;
        if (!self.base.containsPoint(point)) return false;

        // Simple click handling - could be enhanced with proper mouse events
        return true;
    }

    /// Render button
    pub fn render(self: *Button, renderer: anytype) void {
        if (!self.base.shouldRender()) return;

        const bounds = self.base.getBounds();
        const text = self.text.get();
        const font_size = self.font_size.get();

        // Determine button color based on state
        const bg_color = if (!self.enabled.get()) self.disabled_color else if (self.pressed.get()) self.pressed_color else if (self.hovered.get()) self.hover_color else self.normal_color;

        // Draw background
        if (@hasDecl(@TypeOf(renderer), "drawRect")) {
            renderer.drawRect(bounds, bg_color);
        }

        // Draw border
        Panel.drawBorder(renderer, bounds, colors.GRAY_100, 1.0);

        // Draw text (centered)
        if (text.len > 0) {
            if (@hasDecl(@TypeOf(renderer), "drawText")) {
                const text_width = @as(f32, @floatFromInt(text.len)) * font_size * 0.6; // Estimate
                const text_x = bounds.position.x + (bounds.size.x - text_width) / 2;
                const text_y = bounds.position.y + (bounds.size.y - font_size) / 2;

                renderer.drawText(text, text_x, text_y, font_size, self.text_color);
            }
        }

        self.base.clearDirty();
    }
};

/// Configuration for button styling
pub const ButtonConfig = struct {
    font_size: f32 = styles.FontSizes.normal,
    normal_color: Color = colors.GRAY_60,
    hover_color: Color = colors.GRAY_80,
    pressed_color: Color = colors.DARK_GRAY_40,
    disabled_color: Color = colors.DARK_GRAY_30,
    text_color: Color = colors.WHITE,
};

// Tests
test "UIComponent basic functionality" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const bounds = Rectangle.sizedWH(100, 50);
    var component = try UIComponent.init(allocator, bounds);
    defer component.deinit();

    // Test initial state
    try testing.expect(component.visible.get());
    try testing.expect(component.dirty.get());
    try testing.expect(component.shouldRender());

    // Test point containment
    try testing.expect(component.containsPoint(Vec2{ .x = 50, .y = 25 }));
    try testing.expect(!component.containsPoint(Vec2{ .x = 150, .y = 25 }));
}

test "Panel rendering preparation" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const bounds = Rectangle.sizedWH(100, 50);
    var panel = try Panel.init(allocator, bounds, PanelConfig{});
    defer panel.deinit();

    // Test content area calculation
    const content_area = panel.getContentArea();
    try testing.expect(content_area.position.x == 8.0); // padding
    try testing.expect(content_area.position.y == 8.0); // padding
    try testing.expect(content_area.size.x == 84.0); // 100 - 16 (padding * 2)
    try testing.expect(content_area.size.y == 34.0); // 50 - 16 (padding * 2)
}
