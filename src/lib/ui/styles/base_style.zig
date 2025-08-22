/// Base style constants and common patterns for UI components
/// Provides standardized colors, fonts, and spacing values
const Color = @import("../../core/colors.zig").Color;

/// Common color palette used across UI components
pub const Colors = struct {
    /// Text colors
    pub const text_primary = Color{ .r = 255, .g = 255, .b = 255, .a = 255 }; // White
    pub const text_secondary = Color{ .r = 200, .g = 200, .b = 200, .a = 255 }; // Light gray
    pub const text_disabled = Color{ .r = 128, .g = 128, .b = 128, .a = 255 }; // Gray
    pub const text_error = Color{ .r = 255, .g = 100, .b = 100, .a = 255 }; // Light red
    pub const text_success = Color{ .r = 100, .g = 255, .b = 100, .a = 255 }; // Light green
    pub const text_warning = Color{ .r = 255, .g = 200, .b = 100, .a = 255 }; // Light orange

    /// Background colors
    pub const bg_primary = Color{ .r = 40, .g = 40, .b = 40, .a = 255 }; // Dark gray
    pub const bg_secondary = Color{ .r = 60, .g = 60, .b = 60, .a = 255 }; // Medium gray
    pub const bg_hover = Color{ .r = 80, .g = 80, .b = 80, .a = 255 }; // Light gray
    pub const bg_pressed = Color{ .r = 30, .g = 30, .b = 30, .a = 255 }; // Very dark gray
    pub const bg_disabled = Color{ .r = 25, .g = 25, .b = 25, .a = 255 }; // Almost black

    /// Border colors
    pub const border_primary = Color{ .r = 120, .g = 120, .b = 120, .a = 255 }; // Medium gray
    pub const border_hover = Color{ .r = 160, .g = 160, .b = 160, .a = 255 }; // Light gray
    pub const border_focus = Color{ .r = 70, .g = 130, .b = 180, .a = 255 }; // Blue
    pub const border_disabled = Color{ .r = 60, .g = 60, .b = 60, .a = 255 }; // Dark gray

    /// Special colors
    pub const selection = Color{ .r = 60, .g = 100, .b = 160, .a = 128 }; // Semi-transparent blue
    pub const transparent = Color{ .r = 0, .g = 0, .b = 0, .a = 0 }; // Fully transparent

    /// Terminal colors
    pub const terminal_black = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
    pub const terminal_bg_focus = Color{ .r = 30, .g = 35, .b = 40, .a = 255 }; // Custom dark blue for terminal focus
    pub const terminal_bg_unfocus = Color{ .r = 15, .g = 20, .b = 25, .a = 255 }; // Custom darker blue for terminal

    /// File type colors for file tree/explorer components
    pub const file_folder = Color{ .r = 100, .g = 149, .b = 237, .a = 255 }; // Blue
    pub const file_zig = Color{ .r = 255, .g = 140, .b = 0, .a = 255 }; // Orange
    pub const file_markdown = Color{ .r = 50, .g = 205, .b = 50, .a = 255 }; // Green
    pub const file_shader = Color{ .r = 255, .g = 20, .b = 147, .a = 255 }; // Pink
    pub const file_config = Color{ .r = 255, .g = 215, .b = 0, .a = 255 }; // Gold
    pub const file_text = Color{ .r = 169, .g = 169, .b = 169, .a = 255 }; // Gray
    pub const file_unknown = Color{ .r = 128, .g = 128, .b = 128, .a = 255 }; // Dark Gray

    /// Component specific colors
    pub const scrollbar_thumb = Color{ .r = 100, .g = 100, .b = 100, .a = 255 }; // Medium gray scrollbar
    pub const input_focus = Color{ .r = 100, .g = 150, .b = 200, .a = 255 }; // Blue input focus
    pub const input_unfocus = Color{ .r = 80, .g = 80, .b = 80, .a = 255 }; // Gray input unfocus
};

/// Standard font sizes used across components
pub const FontSizes = struct {
    pub const small: f32 = 12.0;
    pub const normal: f32 = 14.0;
    pub const medium: f32 = 16.0;
    pub const large: f32 = 18.0;
    pub const title: f32 = 24.0;
    pub const header: f32 = 32.0;
};

/// Standard spacing values
pub const Spacing = struct {
    pub const tiny: f32 = 2.0;
    pub const small: f32 = 4.0;
    pub const medium: f32 = 8.0;
    pub const large: f32 = 12.0;
    pub const xlarge: f32 = 16.0;
};

/// Standard border widths
pub const BorderWidths = struct {
    pub const thin: f32 = 1.0;
    pub const medium: f32 = 2.0;
    pub const thick: f32 = 3.0;
};
