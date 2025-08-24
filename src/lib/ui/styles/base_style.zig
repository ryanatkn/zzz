/// Base style constants and common patterns for UI components
/// Provides standardized colors, fonts, and spacing values
const core_colors = @import("../../core/colors.zig");
const Color = core_colors.Color;

/// Common color palette used across UI components
pub const Colors = struct {
    /// Text colors
    pub const text_primary = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 }; // White
    pub const text_secondary = Color{ .r = 0.784, .g = 0.784, .b = 0.784, .a = 1.0 }; // Light gray
    pub const text_disabled = Color{ .r = 0.502, .g = 0.502, .b = 0.502, .a = 1.0 }; // Gray
    pub const text_error = Color{ .r = 1.0, .g = 0.392, .b = 0.392, .a = 1.0 }; // Light red
    pub const text_success = Color{ .r = 0.392, .g = 1.0, .b = 0.392, .a = 1.0 }; // Light green
    pub const text_warning = Color{ .r = 1.0, .g = 0.784, .b = 0.392, .a = 1.0 }; // Light orange

    /// Background colors
    pub const bg_primary = Color{ .r = 0.157, .g = 0.157, .b = 0.157, .a = 1.0 }; // Dark gray
    pub const bg_secondary = Color{ .r = 0.235, .g = 0.235, .b = 0.235, .a = 1.0 }; // Medium gray
    pub const bg_hover = Color{ .r = 0.314, .g = 0.314, .b = 0.314, .a = 1.0 }; // Light gray
    pub const bg_pressed = Color{ .r = 0.118, .g = 0.118, .b = 0.118, .a = 1.0 }; // Very dark gray
    pub const bg_disabled = Color{ .r = 0.098, .g = 0.098, .b = 0.098, .a = 1.0 }; // Almost black

    /// Border colors
    pub const border_primary = Color{ .r = 0.471, .g = 0.471, .b = 0.471, .a = 1.0 }; // Medium gray
    pub const border_hover = Color{ .r = 0.627, .g = 0.627, .b = 0.627, .a = 1.0 }; // Light gray
    pub const border_focus = Color{ .r = 0.275, .g = 0.510, .b = 0.706, .a = 1.0 }; // Blue
    pub const border_disabled = Color{ .r = 0.235, .g = 0.235, .b = 0.235, .a = 1.0 }; // Dark gray

    /// Special colors
    pub const selection = Color{ .r = 0.235, .g = 0.392, .b = 0.627, .a = 0.502 }; // Semi-transparent blue
    pub const transparent = Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 }; // Fully transparent

    /// Terminal colors
    pub const terminal_black = Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 };
    pub const terminal_bg_focus = Color{ .r = 0.118, .g = 0.137, .b = 0.157, .a = 1.0 }; // Custom dark blue for terminal focus
    pub const terminal_bg_unfocus = Color{ .r = 0.059, .g = 0.078, .b = 0.098, .a = 1.0 }; // Custom darker blue for terminal

    /// File type colors for file tree/explorer components
    pub const file_folder = Color{ .r = 0.392, .g = 0.584, .b = 0.929, .a = 1.0 }; // Specific blue for folders
    pub const file_zig = core_colors.ORANGE; // Use shared orange
    pub const file_markdown = Color{ .r = 0.196, .g = 0.804, .b = 0.196, .a = 1.0 }; // Specific green for markdown
    pub const file_shader = Color{ .r = 1.0, .g = 0.078, .b = 0.576, .a = 1.0 }; // Specific pink for shaders
    pub const file_config = core_colors.GOLD; // Use shared gold
    pub const file_text = Color{ .r = 0.663, .g = 0.663, .b = 0.663, .a = 1.0 }; // Gray
    pub const file_unknown = Color{ .r = 0.502, .g = 0.502, .b = 0.502, .a = 1.0 }; // Dark Gray

    /// Component specific colors
    pub const scrollbar_thumb = Color{ .r = 0.392, .g = 0.392, .b = 0.392, .a = 1.0 }; // Medium gray scrollbar
    pub const input_focus = Color{ .r = 0.392, .g = 0.588, .b = 0.784, .a = 1.0 }; // Blue input focus
    pub const input_unfocus = Color{ .r = 0.314, .g = 0.314, .b = 0.314, .a = 1.0 }; // Gray input unfocus
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
