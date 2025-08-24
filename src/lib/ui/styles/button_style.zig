/// Unified button styling system
/// Consolidates button styling patterns from button.zig and simple_button.zig
const Vec2 = @import("../../math/mod.zig").Vec2;
const Color = @import("../../core/colors.zig").Color;
const BaseStyle = @import("base_style.zig");

/// Button states for visual feedback
pub const ButtonState = enum {
    normal,
    hovered,
    pressed,
    disabled,
};

/// Unified button style structure
pub const ButtonStyle = struct {
    // Background colors for different states
    normal_color: Color = BaseStyle.Colors.bg_secondary,
    hover_color: Color = BaseStyle.Colors.bg_hover,
    pressed_color: Color = BaseStyle.Colors.bg_pressed,
    disabled_color: Color = BaseStyle.Colors.bg_disabled,

    // Border colors
    border_normal: Color = BaseStyle.Colors.border_primary,
    border_hover: Color = BaseStyle.Colors.border_hover,
    border_pressed: Color = BaseStyle.Colors.border_primary,
    border_disabled: Color = BaseStyle.Colors.border_disabled,

    // Visual properties
    border_width: f32 = BaseStyle.BorderWidths.thin,
    corner_radius: f32 = 4.0,
    padding: Vec2 = Vec2{ .x = BaseStyle.Spacing.large, .y = BaseStyle.Spacing.medium },

    // Text properties
    text_color: Color = BaseStyle.Colors.text_primary,
    font_size: f32 = BaseStyle.FontSizes.normal,

    /// Get background color for a given state
    pub fn getBackgroundColor(self: *const ButtonStyle, state: ButtonState) Color {
        return switch (state) {
            .normal => self.normal_color,
            .hovered => self.hover_color,
            .pressed => self.pressed_color,
            .disabled => self.disabled_color,
        };
    }

    /// Get border color for a given state
    pub fn getBorderColor(self: *const ButtonStyle, state: ButtonState) Color {
        return switch (state) {
            .normal => self.border_normal,
            .hovered => self.border_hover,
            .pressed => self.border_pressed,
            .disabled => self.border_disabled,
        };
    }
};

/// Common button style presets
pub const Presets = struct {
    pub const default = ButtonStyle{};

    pub const primary = ButtonStyle{
        .normal_color = BaseStyle.Colors.border_focus, // Blue
        .hover_color = BaseStyle.Colors.input_focus, // Lighter blue
        .pressed_color = BaseStyle.Colors.border_focus, // Same blue (rely on visual feedback)
    };

    pub const secondary = ButtonStyle{
        .normal_color = BaseStyle.Colors.bg_primary,
        .border_normal = BaseStyle.Colors.border_primary,
        .border_hover = BaseStyle.Colors.border_hover,
    };

    pub const danger = ButtonStyle{
        .normal_color = BaseStyle.Colors.text_error, // Light red
        .hover_color = BaseStyle.Colors.text_error, // Same red (use border for feedback)
        .pressed_color = BaseStyle.Colors.text_error, // Same red (use shadow for feedback)
    };

    pub const large = ButtonStyle{
        .font_size = BaseStyle.FontSizes.large,
        .padding = Vec2{ .x = BaseStyle.Spacing.xlarge, .y = BaseStyle.Spacing.large },
    };

    pub const small = ButtonStyle{
        .font_size = BaseStyle.FontSizes.small,
        .padding = Vec2{ .x = BaseStyle.Spacing.medium, .y = BaseStyle.Spacing.small },
    };
};

// Tests
const std = @import("std");

test "button style state colors" {
    const testing = std.testing;

    const style = ButtonStyle{};

    // Test normal state
    const normal_color = style.getBackgroundColor(.normal);
    try testing.expect(normal_color.r == BaseStyle.Colors.bg_secondary.r);

    // Test hover state (should be different/brighter)
    const hover_color = style.getBackgroundColor(.hovered);
    try testing.expect(hover_color.r != normal_color.r);

    // Test border colors
    const border_color = style.getBorderColor(.normal);
    try testing.expect(border_color.r == BaseStyle.Colors.border_primary.r);
}

test "button style presets" {
    const testing = std.testing;

    // Test that presets have different properties
    const default_style = Presets.default;
    const primary_style = Presets.primary;

    try testing.expect(default_style.normal_color.r != primary_style.normal_color.r);
    try testing.expect(Presets.large.font_size > Presets.small.font_size);
}
