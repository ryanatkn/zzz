/// Unified UI Style System
/// Provides consistent styling across all UI components
pub const base_style = @import("base_style.zig");
pub const text_style = @import("text_style.zig");
pub const button_style = @import("button_style.zig");
pub const presets = @import("presets.zig");

// Re-export commonly used types
pub const Colors = base_style.Colors;
pub const FontSizes = base_style.FontSizes;
pub const Spacing = base_style.Spacing;
pub const BorderWidths = base_style.BorderWidths;

pub const TextStyle = text_style.TextStyle;
pub const TextAlignment = text_style.TextAlignment;

pub const ButtonStyle = button_style.ButtonStyle;
pub const ButtonState = button_style.ButtonState;

pub const Text = presets.Text;
pub const Button = button_style.Presets;
pub const ColorCombos = presets.ColorCombos;
