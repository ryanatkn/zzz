//! Modern UI system for Zzz Game Engine
//! Reactive, component-based UI inspired by modern web frameworks
//! 
//! Features:
//! - Reactive components that automatically update when data changes
//! - Flexbox-like layout system for responsive design
//! - Unified text rendering (fixes yellow text flashing)
//! - Screen-relative units for multi-resolution support
//! - Event handling with proper propagation
//! - Type-safe styling and theming
//!
//! Usage:
//! ```zig
//! const ui = @import("lib/ui.zig");
//! 
//! // Create a layout container
//! var layout = try ui.createLayout(allocator, props);
//! layout_impl.setDirection(.row);
//! layout_impl.setJustifyContent(.center);
//! 
//! // Add a button
//! var button = try ui.createSimpleButton(allocator, "Click me", position, handleClick);
//! try layout.addChild(button);
//! 
//! // Add text
//! var title = try ui.createTitle(allocator, "Welcome", position, 24.0);
//! try layout.addChild(title);
//! ```

pub const component = @import("ui/component.zig");
pub const layout = @import("ui/layout.zig");
pub const text = @import("ui/text.zig");
pub const button = @import("ui/button.zig");

// Re-export commonly used types
pub const Component = component.Component;
pub const ComponentProps = component.ComponentProps;
pub const LayoutConstraints = component.LayoutConstraints;
pub const ScreenUnits = component.ScreenUnits;

pub const Layout = layout.Layout;
pub const LayoutDirection = layout.LayoutDirection;
pub const JustifyContent = layout.JustifyContent;
pub const AlignItems = layout.AlignItems;

pub const Text = text.Text;
pub const TextStyle = text.TextStyle;
pub const TextAlign = text.TextAlign;

pub const Button = button.Button;
pub const ButtonStyle = button.ButtonStyle;
pub const ButtonState = button.ButtonState;

// Re-export creation functions
pub const createLayout = layout.createLayout;
pub const createText = text.createText;
pub const createLabel = text.createLabel;
pub const createTitle = text.createTitle;
pub const createButton = button.createButton;
pub const createSimpleButton = button.createSimpleButton;

// Convenience functions for common UI patterns

/// Create a centered container with padding
pub fn createCenteredContainer(
    allocator: std.mem.Allocator,
    screen_units: *const ScreenUnits,
    padding: f32
) !*Component {
    const size = types.Vec2{
        .x = screen_units.vw(0.8), // 80% of screen width
        .y = screen_units.vh(0.8), // 80% of screen height
    };
    const position = screen_units.center(size);
    
    var props = try ComponentProps.init(allocator, position, size);
    var container = try createLayout(allocator, props);
    
    const container_impl: *Layout = @fieldParentPtr("base", container);
    container_impl.setDirection(.column);
    container_impl.setJustifyContent(.flex_start);
    container_impl.setAlignItems(.stretch);
    container_impl.setPadding(padding);
    
    return container;
}

/// Create a horizontal button row
pub fn createButtonRow(
    allocator: std.mem.Allocator,
    position: types.Vec2,
    size: types.Vec2,
    gap: f32
) !*Component {
    var props = try ComponentProps.init(allocator, position, size);
    var row = try createLayout(allocator, props);
    
    const row_impl: *Layout = @fieldParentPtr("base", row);
    row_impl.setDirection(.row);
    row_impl.setJustifyContent(.space_evenly);
    row_impl.setAlignItems(.center);
    row_impl.setGap(gap);
    
    return row;
}

/// Create a vertical text column
pub fn createTextColumn(
    allocator: std.mem.Allocator,
    position: types.Vec2,
    size: types.Vec2,
    gap: f32
) !*Component {
    var props = try ComponentProps.init(allocator, position, size);
    var column = try createLayout(allocator, props);
    
    const column_impl: *Layout = @fieldParentPtr("base", column);
    column_impl.setDirection(.column);
    column_impl.setJustifyContent(.flex_start);
    column_impl.setAlignItems(.flex_start);
    column_impl.setGap(gap);
    
    return column;
}

/// Create a navigation menu with consistent styling
pub fn createNavMenu(
    allocator: std.mem.Allocator,
    screen_units: *const ScreenUnits,
    buttons: []const struct { label: []const u8, handler: *const fn () void }
) !*Component {
    const menu_height = 60.0;
    const position = types.Vec2{ .x = 0, .y = screen_units.screen_height.get() - menu_height };
    const size = types.Vec2{ .x = screen_units.screen_width.get(), .y = menu_height };
    
    var menu = try createButtonRow(allocator, position, size, 20.0);
    
    // Create buttons for the menu
    for (buttons) |button_def| {
        const nav_button = try createSimpleButton(allocator, button_def.label, types.Vec2{ .x = 0, .y = 0 }, button_def.handler);
        try menu.addChild(nav_button);
    }
    
    return menu;
}

/// Theme system for consistent styling across the application
pub const Theme = struct {
    // Colors
    background: types.Color = types.Color{ .r = 30, .g = 30, .b = 30, .a = 255 },
    surface: types.Color = types.Color{ .r = 50, .g = 50, .b = 50, .a = 255 },
    primary: types.Color = types.Color{ .r = 100, .g = 150, .b = 255, .a = 255 },
    secondary: types.Color = types.Color{ .r = 150, .g = 100, .b = 255, .a = 255 },
    text: types.Color = types.Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
    text_secondary: types.Color = types.Color{ .r = 200, .g = 200, .b = 200, .a = 255 },
    
    // Typography
    font_size_small: f32 = 12.0,
    font_size_normal: f32 = 14.0,
    font_size_large: f32 = 18.0,
    font_size_title: f32 = 24.0,
    font_size_heading: f32 = 32.0,
    
    // Spacing
    spacing_small: f32 = 4.0,
    spacing_normal: f32 = 8.0,
    spacing_large: f32 = 16.0,
    spacing_xl: f32 = 24.0,
    
    // Button styles
    button_height: f32 = 36.0,
    button_padding: types.Vec2 = types.Vec2{ .x = 16, .y = 8 },
    button_radius: f32 = 4.0,
    
    pub fn getTextStyle(self: *const Theme, size_category: enum { small, normal, large, title, heading }) TextStyle {
        const font_size = switch (size_category) {
            .small => self.font_size_small,
            .normal => self.font_size_normal,
            .large => self.font_size_large,
            .title => self.font_size_title,
            .heading => self.font_size_heading,
        };
        
        return TextStyle{
            .font_size = font_size,
            .color = self.text,
            .align = .left,
        };
    }
    
    pub fn getButtonStyle(self: *const Theme) ButtonStyle {
        return ButtonStyle{
            .normal_color = self.surface,
            .hover_color = types.Color{ .r = self.surface.r + 20, .g = self.surface.g + 20, .b = self.surface.b + 20, .a = 255 },
            .pressed_color = types.Color{ .r = self.surface.r - 10, .g = self.surface.g - 10, .b = self.surface.b - 10, .a = 255 },
            .disabled_color = types.Color{ .r = self.surface.r - 20, .g = self.surface.g - 20, .b = self.surface.b - 20, .a = 255 },
            .border_normal = types.Color{ .r = 120, .g = 120, .b = 120, .a = 255 },
            .border_hover = self.primary,
            .border_pressed = types.Color{ .r = self.primary.r - 50, .g = self.primary.g - 50, .b = self.primary.b - 50, .a = 255 },
            .border_disabled = types.Color{ .r = 60, .g = 60, .b = 60, .a = 255 },
            .border_width = 1.0,
            .corner_radius = self.button_radius,
            .padding = self.button_padding,
        };
    }
};

// Default theme instance
pub const default_theme = Theme{};

// Import types for convenience
const types = @import("../core/types.zig");
const reactive = @import("../reactive.zig");

// Tests
const std = @import("std");

test "UI system integration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try reactive.init(allocator);
    defer reactive.deinit(allocator);
    
    // Create screen units
    var screen_width = try reactive.signal(allocator, f32, 1920);
    defer screen_width.deinit();
    
    var screen_height = try reactive.signal(allocator, f32, 1080);
    defer screen_height.deinit();
    
    const screen_units = ScreenUnits.init(&screen_width, &screen_height);
    
    // Create a centered container
    var container = try createCenteredContainer(allocator, &screen_units, 16.0);
    defer container.destroy(allocator);
    
    // Add a title
    var title = try createTitle(allocator, "Test Title", types.Vec2{ .x = 0, .y = 0 }, 24.0);
    try container.addChild(title);
    
    // Add a button
    const TestHandler = struct {
        fn onClick() void {}
    };
    var button = try createSimpleButton(allocator, "Test Button", types.Vec2{ .x = 0, .y = 0 }, TestHandler.onClick);
    try container.addChild(button);
    
    // Verify structure
    try std.testing.expect(container.children.items.len == 2);
}

test "theme system" {
    const theme = default_theme;
    
    // Test text styles
    const title_style = theme.getTextStyle(.title);
    try std.testing.expect(title_style.font_size == theme.font_size_title);
    try std.testing.expect(std.mem.eql(u8, std.mem.asBytes(&title_style.color), std.mem.asBytes(&theme.text)));
    
    // Test button style
    const button_style = theme.getButtonStyle();
    try std.testing.expect(std.mem.eql(u8, std.mem.asBytes(&button_style.normal_color), std.mem.asBytes(&theme.surface)));
    try std.testing.expect(button_style.corner_radius == theme.button_radius);
    
    // Verify no bright yellow colors in theme
    try std.testing.expect(!(theme.primary.r == 255 and theme.primary.g == 255 and theme.primary.b == 0));
    try std.testing.expect(!(button_style.hover_color.r == 255 and button_style.hover_color.g == 255 and button_style.hover_color.b == 0));
}