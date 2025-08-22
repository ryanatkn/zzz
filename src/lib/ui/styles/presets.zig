/// Common UI style presets
/// Ready-to-use style configurations for common UI patterns
const TextStyle = @import("text_style.zig").TextStyle;
const BaseStyle = @import("base_style.zig");

/// Ready-to-use text style presets
pub const Text = struct {
    pub const title = TextStyle{
        .font_size = BaseStyle.FontSizes.title,
        .color = BaseStyle.Colors.text_primary,
        .alignment = .center,
    };

    pub const header = TextStyle{
        .font_size = BaseStyle.FontSizes.header,
        .color = BaseStyle.Colors.text_primary,
        .alignment = .center,
    };

    pub const subtitle = TextStyle{
        .font_size = BaseStyle.FontSizes.large,
        .color = BaseStyle.Colors.text_secondary,
        .alignment = .center,
    };

    pub const body = TextStyle{
        .font_size = BaseStyle.FontSizes.normal,
        .color = BaseStyle.Colors.text_primary,
        .alignment = .left,
    };

    pub const small_text = TextStyle{
        .font_size = BaseStyle.FontSizes.small,
        .color = BaseStyle.Colors.text_secondary,
        .alignment = .left,
    };

    pub const error_message = TextStyle{
        .font_size = BaseStyle.FontSizes.normal,
        .color = BaseStyle.Colors.text_error,
        .alignment = .left,
    };

    pub const success_message = TextStyle{
        .font_size = BaseStyle.FontSizes.normal,
        .color = BaseStyle.Colors.text_success,
        .alignment = .left,
    };

    pub const warning_message = TextStyle{
        .font_size = BaseStyle.FontSizes.normal,
        .color = BaseStyle.Colors.text_warning,
        .alignment = .left,
    };

    pub const button_text = TextStyle{
        .font_size = BaseStyle.FontSizes.normal,
        .color = BaseStyle.Colors.text_primary,
        .alignment = .center,
    };

    pub const menu_item = TextStyle{
        .font_size = BaseStyle.FontSizes.medium,
        .color = BaseStyle.Colors.text_secondary,
        .alignment = .left,
    };

    pub const menu_item_hovered = TextStyle{
        .font_size = BaseStyle.FontSizes.medium,
        .color = BaseStyle.Colors.text_primary,
        .alignment = .left,
    };
};

/// Common color combinations for quick use
pub const ColorCombos = struct {
    pub const dark_theme = struct {
        pub const background = BaseStyle.Colors.bg_primary;
        pub const text = BaseStyle.Colors.text_primary;
        pub const border = BaseStyle.Colors.border_primary;
    };

    pub const button_normal = struct {
        pub const background = BaseStyle.Colors.bg_secondary;
        pub const text = BaseStyle.Colors.text_primary;
        pub const border = BaseStyle.Colors.border_primary;
    };

    pub const button_hover = struct {
        pub const background = BaseStyle.Colors.bg_hover;
        pub const text = BaseStyle.Colors.text_primary;
        pub const border = BaseStyle.Colors.border_hover;
    };

    pub const button_pressed = struct {
        pub const background = BaseStyle.Colors.bg_pressed;
        pub const text = BaseStyle.Colors.text_primary;
        pub const border = BaseStyle.Colors.border_primary;
    };

    pub const input_field = struct {
        pub const background = BaseStyle.Colors.bg_primary;
        pub const text = BaseStyle.Colors.text_primary;
        pub const border = BaseStyle.Colors.border_primary;
        pub const placeholder = BaseStyle.Colors.text_disabled;
        pub const selection = BaseStyle.Colors.selection;
    };
};
