const colors = @import("../core/colors.zig");
const math = @import("../math/mod.zig");
const styles = @import("styles/mod.zig");

const Color = colors.Color;
const Vec2 = math.Vec2;

/// Text alignment options for text displays
pub const TextAlignment = enum {
    left,
    center,
    right,

    /// Get horizontal offset for alignment
    pub fn getHorizontalOffset(self: TextAlignment, text_width: f32, available_width: f32) f32 {
        return switch (self) {
            .left => 0,
            .center => (available_width - text_width) / 2,
            .right => available_width - text_width,
        };
    }
};

/// Style configuration for text displays
pub const TextDisplayStyle = struct {
    font_size: f32 = styles.FontSizes.normal,
    color: Color = styles.Colors.text_primary,
    background_color: ?Color = null, // Transparent by default
    padding: Vec2 = Vec2.ZERO,
    alignment: TextAlignment = .left,

    /// Preset styles for common use cases
    pub const Presets = struct {
        pub const default = TextDisplayStyle{};

        pub const title = TextDisplayStyle{
            .font_size = styles.FontSizes.title,
            .alignment = .center,
            .padding = Vec2{ .x = 0, .y = styles.Spacing.medium },
        };

        pub const subtitle = TextDisplayStyle{
            .font_size = styles.FontSizes.large,
            .color = styles.Colors.text_secondary,
            .alignment = .center,
            .padding = Vec2{ .x = 0, .y = styles.Spacing.small },
        };

        pub const small = TextDisplayStyle{
            .font_size = styles.FontSizes.small,
            .color = styles.Colors.text_secondary,
        };

        pub const error_text = TextDisplayStyle{
            .font_size = styles.FontSizes.normal,
            .color = styles.Colors.text_error,
        };

        pub const success_text = TextDisplayStyle{
            .font_size = styles.FontSizes.normal,
            .color = styles.Colors.text_success,
        };

        pub const warning_text = TextDisplayStyle{
            .font_size = styles.FontSizes.normal,
            .color = styles.Colors.text_warning,
        };
    };

    /// Calculate text position based on alignment and padding
    pub fn getTextPosition(self: *const TextDisplayStyle, base_position: Vec2, text_width: f32, container_width: f32) Vec2 {
        const horizontal_offset = self.alignment.getHorizontalOffset(text_width, container_width);

        return Vec2{
            .x = base_position.x + self.padding.x + horizontal_offset,
            .y = base_position.y + self.padding.y,
        };
    }

    /// Get the total size needed for a text display with this style
    pub fn getRequiredSize(self: *const TextDisplayStyle, text_width: f32) Vec2 {
        return Vec2{
            .x = text_width + (self.padding.x * 2),
            .y = self.font_size + (self.padding.y * 2),
        };
    }
};

// Tests
test "text alignment horizontal offset" {
    const testing = @import("std").testing;

    const text_width = 100.0;
    const container_width = 200.0;

    try testing.expectEqual(@as(f32, 0), TextAlignment.left.getHorizontalOffset(text_width, container_width));
    try testing.expectEqual(@as(f32, 50), TextAlignment.center.getHorizontalOffset(text_width, container_width));
    try testing.expectEqual(@as(f32, 100), TextAlignment.right.getHorizontalOffset(text_width, container_width));
}

test "text display style presets" {
    const testing = @import("std").testing;

    const title = TextDisplayStyle.Presets.title;
    try testing.expectEqual(@as(f32, 24.0), title.font_size);
    try testing.expectEqual(TextAlignment.center, title.alignment);

    const error_text = TextDisplayStyle.Presets.error_text;
    try testing.expectEqual(@as(u8, 255), error_text.color.r); // Red component should be high
    try testing.expect(error_text.color.g < 150); // Green should be lower than red
}

test "required size calculation" {
    const testing = @import("std").testing;

    const style = TextDisplayStyle{
        .padding = Vec2{ .x = 5, .y = 3 },
        .font_size = 16,
    };

    const text_width = 100.0;
    const required_size = style.getRequiredSize(text_width);

    try testing.expectEqual(@as(f32, 110.0), required_size.x); // 100 + 5*2
    try testing.expectEqual(@as(f32, 22.0), required_size.y); // 16 + 3*2
}
