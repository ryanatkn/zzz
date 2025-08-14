const std = @import("std");

/// Centralized font configuration and definitions
/// Consolidates font sizing, family definitions, and font selection
/// This solves the issue where different UI components had hardcoded font sizes
/// that didn't work well together (e.g., 48pt FPS text vs 16pt button text)
pub const FontConfig = struct {
    /// Base font size that other sizes are derived from
    /// Users can adjust this for their preference/display
    base_size: f32 = 16.0, // Changed to match original button size

    /// Scaling factors for different UI elements (relative to base_size)
    /// Test various font sizes with bitmap rendering (SDF disabled)
    button_text: f32 = 1.0, // 16pt - test standard button text
    header_text: f32 = 1.5, // 24pt - test larger headers
    navigation_text: f32 = 0.875, // 14pt - test smaller navigation
    fps_counter: f32 = 1.25, // 20pt - test readable performance metrics
    debug_text: f32 = 0.75, // 12pt - test smallest readable text

    /// Calculate actual font size for buttons
    pub fn buttonFontSize(self: FontConfig) f32 {
        return self.base_size * self.button_text;
    }

    /// Calculate actual font size for headers
    pub fn headerFontSize(self: FontConfig) f32 {
        return self.base_size * self.header_text;
    }

    /// Calculate actual font size for navigation
    pub fn navigationFontSize(self: FontConfig) f32 {
        return self.base_size * self.navigation_text;
    }

    /// Calculate actual font size for FPS counter
    pub fn fpsFontSize(self: FontConfig) f32 {
        return self.base_size * self.fps_counter;
    }

    /// Calculate actual font size for debug text
    pub fn debugFontSize(self: FontConfig) f32 {
        return self.base_size * self.debug_text;
    }

    /// Calculate button height based on font size
    /// Ensures text fits comfortably with padding
    pub fn buttonHeight(self: FontConfig) f32 {
        const font_size = self.buttonFontSize();
        // Height = font size * line height multiplier + vertical padding
        // Increased multiplier for 48pt text debugging
        return font_size * 1.8 + self.buttonPadding() * 2;
    }

    /// Calculate button padding based on font size
    pub fn buttonPadding(self: FontConfig) f32 {
        return self.base_size * 0.4;
    }

    /// Estimate character width for a given font size
    /// This is approximate - actual width varies by font and character
    pub fn estimateCharWidth(_: FontConfig, font_size: f32) f32 {
        // Approximate: character width is about 0.6x the font size for proportional fonts
        return font_size * 0.6;
    }

    /// Get character width for button text
    pub fn buttonCharWidth(self: FontConfig) f32 {
        return self.estimateCharWidth(self.buttonFontSize());
    }

    /// Get character width for header text
    pub fn headerCharWidth(self: FontConfig) f32 {
        return self.estimateCharWidth(self.headerFontSize());
    }

    /// Get character width for navigation text
    pub fn navigationCharWidth(self: FontConfig) f32 {
        return self.estimateCharWidth(self.navigationFontSize());
    }
};

/// Preset configurations for different use cases
pub const FontPresets = struct {
    /// Small preset - good for high-density displays
    pub const small = FontConfig{
        .base_size = 12.0,
    };

    /// Medium preset - balanced default (matches original design)
    pub const medium = FontConfig{
        .base_size = 16.0,
    };

    /// Large preset - better readability
    pub const large = FontConfig{
        .base_size = 20.0,
    };

    /// Extra large preset - accessibility
    pub const extra_large = FontConfig{
        .base_size = 24.0,
    };
};

/// Global font configuration instance
/// This should be initialized at startup and used throughout the application
pub var global_config: FontConfig = FontPresets.medium;

/// Set the global font configuration
pub fn setGlobalConfig(config: FontConfig) void {
    global_config = config;
}

/// Get the current global font configuration
pub fn getGlobalConfig() FontConfig {
    return global_config;
}

/// Set the global configuration from a preset
pub fn setPreset(preset: enum { small, medium, large, extra_large }) void {
    global_config = switch (preset) {
        .small => FontPresets.small,
        .medium => FontPresets.medium,
        .large => FontPresets.large,
        .extra_large => FontPresets.extra_large,
    };
}

// ============================================================================
// Font Family and Variant Definitions (merged from fonts.zig)
// ============================================================================

/// Font categories for semantic font selection
pub const FontCategory = enum {
    mono, // Monospace fonts for code
    sans, // Sans-serif for UI
    serif_display, // Serif for titles/headers
    serif_text, // Serif for body text
};

pub const FontVariant = struct {
    path: []const u8,
    weight: i32, // 100-900 (100=Thin, 400=Regular, 700=Bold, 900=Black)
    italic: bool,
    condensed: enum { normal, semi, condensed, extra } = .normal,
    optical_size: ?i32 = null, // For fonts with optical size variants
};

pub const FontFamily = struct {
    name: []const u8,
    category: FontCategory,
    variants: []const FontVariant,
};

/// Available font families with all their variants
pub const available_fonts = [_]FontFamily{
    .{
        .name = "DM Mono",
        .category = .mono,
        .variants = &[_]FontVariant{
            .{ .path = "static/fonts/DM_Mono/DMMono-Light.ttf", .weight = 300, .italic = false },
            .{ .path = "static/fonts/DM_Mono/DMMono-LightItalic.ttf", .weight = 300, .italic = true },
            .{ .path = "static/fonts/DM_Mono/DMMono-Regular.ttf", .weight = 400, .italic = false },
            .{ .path = "static/fonts/DM_Mono/DMMono-Italic.ttf", .weight = 400, .italic = true },
            .{ .path = "static/fonts/DM_Mono/DMMono-Medium.ttf", .weight = 500, .italic = false },
            .{ .path = "static/fonts/DM_Mono/DMMono-MediumItalic.ttf", .weight = 500, .italic = true },
        },
    },
    .{
        .name = "DM Sans",
        .category = .sans,
        .variants = &[_]FontVariant{
            .{ .path = "static/fonts/DM_Sans/static/DMSans-Thin.ttf", .weight = 100, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-ThinItalic.ttf", .weight = 100, .italic = true },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-ExtraLight.ttf", .weight = 200, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-ExtraLightItalic.ttf", .weight = 200, .italic = true },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-Light.ttf", .weight = 300, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-Regular.ttf", .weight = 400, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-Medium.ttf", .weight = 500, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-SemiBold.ttf", .weight = 600, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-Bold.ttf", .weight = 700, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-ExtraBold.ttf", .weight = 800, .italic = false },
            .{ .path = "static/fonts/DM_Sans/static/DMSans-Black.ttf", .weight = 900, .italic = false },
        },
    },
    .{
        .name = "DM Serif Display",
        .category = .serif_display,
        .variants = &[_]FontVariant{
            .{ .path = "static/fonts/DM_Serif_Display/DMSerifDisplay-Regular.ttf", .weight = 400, .italic = false },
            .{ .path = "static/fonts/DM_Serif_Display/DMSerifDisplay-Italic.ttf", .weight = 400, .italic = true },
        },
    },
    .{
        .name = "DM Serif Text",
        .category = .serif_text,
        .variants = &[_]FontVariant{
            .{ .path = "static/fonts/DM_Serif_Text/DMSerifText-Regular.ttf", .weight = 400, .italic = false },
            .{ .path = "static/fonts/DM_Serif_Text/DMSerifText-Italic.ttf", .weight = 400, .italic = true },
        },
    },
};

/// User configurable font settings
pub const FontSettings = struct {
    mono_family: []const u8 = "DM Mono",
    mono_weight: i32 = 400,
    mono_italic: bool = false,

    sans_family: []const u8 = "DM Sans",
    sans_weight: i32 = 400,
    sans_italic: bool = false,

    serif_display_family: []const u8 = "DM Serif Display",
    serif_display_weight: i32 = 400,
    serif_display_italic: bool = false,

    serif_text_family: []const u8 = "DM Serif Text",
    serif_text_weight: i32 = 400,
    serif_text_italic: bool = false,

    default_size: f32 = 16.0,
    ui_size: f32 = 14.0,
    code_size: f32 = 13.0,
    heading_size: f32 = 24.0,
    body_size: f32 = 16.0,
};

/// Find a font family by name
pub fn findFontFamily(name: []const u8) ?*const FontFamily {
    for (&available_fonts) |*family| {
        if (std.mem.eql(u8, family.name, name)) {
            return family;
        }
    }
    return null;
}

/// Find a specific font variant
pub fn findFontVariant(family_name: []const u8, weight: i32, italic: bool) ?*const FontVariant {
    const family = findFontFamily(family_name) orelse return null;

    for (family.variants) |*variant| {
        if (variant.weight == weight and variant.italic == italic) {
            return variant;
        }
    }

    // Fallback to regular weight if exact match not found
    for (family.variants) |*variant| {
        if (variant.weight == 400 and variant.italic == italic) {
            return variant;
        }
    }

    // Ultimate fallback to first variant
    if (family.variants.len > 0) {
        return &family.variants[0];
    }

    return null;
}
