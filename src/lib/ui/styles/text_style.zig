/// Unified text styling system
/// Consolidates text styling patterns from across the UI system
const Vec2 = @import("../../math/mod.zig").Vec2;
const Color = @import("../../core/colors.zig").Color;
const BaseStyle = @import("base_style.zig");

/// Text alignment options
pub const TextAlignment = enum {
    left,
    center,
    right,
};

/// Unified text style structure
pub const TextStyle = struct {
    font_size: f32 = BaseStyle.FontSizes.normal,
    color: Color = BaseStyle.Colors.text_primary,
    background_color: ?Color = null,
    padding: Vec2 = Vec2{ .x = 0, .y = 0 },
    alignment: TextAlignment = .left,

    /// Get display color based on interaction state
    pub fn getDisplayColor(self: *const TextStyle, hovered: bool, enabled: bool) Color {
        if (!enabled) {
            return BaseStyle.Colors.text_disabled;
        }
        if (hovered) {
            // Slightly brighter version of the base color
            return Color{
                .r = @min(255, @as(u16, self.color.r) + 30),
                .g = @min(255, @as(u16, self.color.g) + 30),
                .b = @min(255, @as(u16, self.color.b) + 30),
                .a = self.color.a,
            };
        }
        return self.color;
    }
};

/// Common text style presets
pub const Presets = struct {
    pub const default = TextStyle{};

    pub const title = TextStyle{
        .font_size = BaseStyle.FontSizes.title,
        .color = BaseStyle.Colors.text_primary,
        .alignment = .center,
    };

    pub const subtitle = TextStyle{
        .font_size = BaseStyle.FontSizes.large,
        .color = BaseStyle.Colors.text_secondary,
        .alignment = .center,
    };

    pub const small = TextStyle{
        .font_size = BaseStyle.FontSizes.small,
        .color = BaseStyle.Colors.text_secondary,
    };

    pub const error_text = TextStyle{
        .font_size = BaseStyle.FontSizes.normal,
        .color = BaseStyle.Colors.text_error,
    };

    pub const success = TextStyle{
        .font_size = BaseStyle.FontSizes.normal,
        .color = BaseStyle.Colors.text_success,
    };

    pub const warning = TextStyle{
        .font_size = BaseStyle.FontSizes.normal,
        .color = BaseStyle.Colors.text_warning,
    };

    pub const button = TextStyle{
        .font_size = BaseStyle.FontSizes.normal,
        .color = BaseStyle.Colors.text_primary,
        .alignment = .center,
    };
};

// Tests
const std = @import("std");

test "text style presets" {
    const testing = std.testing;

    // Test that presets have expected properties
    try testing.expect(Presets.title.font_size == BaseStyle.FontSizes.title);
    try testing.expect(Presets.title.alignment == .center);

    try testing.expect(Presets.small.font_size == BaseStyle.FontSizes.small);
    try testing.expect(Presets.error_text.color.r == BaseStyle.Colors.text_error.r);
}

test "text style display colors" {
    const testing = std.testing;

    const style = Presets.default;

    // Test disabled state
    const disabled_color = style.getDisplayColor(false, false);
    try testing.expect(disabled_color.r == BaseStyle.Colors.text_disabled.r);

    // Test normal state
    const normal_color = style.getDisplayColor(false, true);
    try testing.expect(normal_color.r == style.color.r);

    // Test hovered state (should be brighter)
    const hovered_color = style.getDisplayColor(true, true);
    try testing.expect(hovered_color.r >= style.color.r);
}
