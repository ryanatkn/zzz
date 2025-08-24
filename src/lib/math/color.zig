const std = @import("std");
const scalar = @import("scalar.zig");

// Import Color from core/colors.zig for use in color math functions
const core_colors = @import("../core/colors.zig");
const Color = core_colors.Color;

/// Consolidated color mathematics utilities
pub const ColorMath = struct {
    /// Linear interpolation between two colors
    pub fn lerp(color1: Color, color2: Color, t: f32) Color {
        const clamped_t = scalar.clamp(t, 0.0, 1.0);

        return Color{
            .r = color1.r + (color2.r - color1.r) * clamped_t,
            .g = color1.g + (color2.g - color1.g) * clamped_t,
            .b = color1.b + (color2.b - color1.b) * clamped_t,
            .a = color1.a + (color2.a - color1.a) * clamped_t,
        };
    }

    /// Darken a color by reducing RGB values by percentage (0.0 to 1.0)
    pub fn darken(color: Color, factor: f32) Color {
        const clamped_factor = scalar.clamp(factor, 0.0, 1.0);
        const multiplier = 1.0 - clamped_factor;
        return Color{
            .r = color.r * multiplier,
            .g = color.g * multiplier,
            .b = color.b * multiplier,
            .a = color.a,
        };
    }

    /// Lighten a color by increasing RGB values by percentage (0.0 to 1.0)
    pub fn lighten(color: Color, factor: f32) Color {
        const clamped_factor = scalar.clamp(factor, 0.0, 1.0);
        return Color{
            .r = color.r + (1.0 - color.r) * clamped_factor,
            .g = color.g + (1.0 - color.g) * clamped_factor,
            .b = color.b + (1.0 - color.b) * clamped_factor,
            .a = color.a,
        };
    }

    /// Create a color with specified alpha transparency (0.0-1.0)
    pub fn withAlpha(color: Color, alpha: f32) Color {
        return Color{
            .r = color.r,
            .g = color.g,
            .b = color.b,
            .a = scalar.clamp(alpha, 0.0, 1.0),
        };
    }

    /// Apply intensity multiplier to a color (0.0 to 1.0)
    pub fn applyIntensity(color: Color, intensity: f32) Color {
        const clamped = scalar.clamp(intensity, 0.0, 1.0);
        return Color{
            .r = color.r * clamped,
            .g = color.g * clamped,
            .b = color.b * clamped,
            .a = color.a,
        };
    }
};

/// HSV color space for advanced color manipulation
pub const HSV = struct {
    h: f32, // Hue (0-360)
    s: f32, // Saturation (0-1)
    v: f32, // Value (0-1)
    a: f32, // Alpha (0-1)
};

/// Advanced color manipulation functions
pub const ColorAdvanced = struct {
    /// Convert Color to HSV color space
    pub fn toHSV(color: Color) HSV {
        const r = color.r;
        const g = color.g;
        const b = color.b;
        const a = color.a;

        const max_val = @max(@max(r, g), b);
        const min_val = @min(@min(r, g), b);
        const delta = max_val - min_val;

        var h: f32 = 0.0;
        if (delta != 0.0) {
            if (max_val == r) {
                h = 60.0 * (((g - b) / delta) + if (g < b) @as(f32, 6.0) else 0.0);
            } else if (max_val == g) {
                h = 60.0 * (((b - r) / delta) + 2.0);
            } else {
                h = 60.0 * (((r - g) / delta) + 4.0);
            }
        }

        const s = if (max_val == 0.0) 0.0 else delta / max_val;
        const v = max_val;

        return HSV{ .h = h, .s = s, .v = v, .a = a };
    }

    /// Convert HSV back to Color
    pub fn fromHSV(hsv: HSV) Color {
        const c = hsv.v * hsv.s;
        const x = c * (1.0 - @abs(@mod(hsv.h / 60.0, 2.0) - 1.0));
        const m = hsv.v - c;

        var r: f32 = 0.0;
        var g: f32 = 0.0;
        var b: f32 = 0.0;

        if (hsv.h >= 0.0 and hsv.h < 60.0) {
            r = c;
            g = x;
            b = 0.0;
        } else if (hsv.h >= 60.0 and hsv.h < 120.0) {
            r = x;
            g = c;
            b = 0.0;
        } else if (hsv.h >= 120.0 and hsv.h < 180.0) {
            r = 0.0;
            g = c;
            b = x;
        } else if (hsv.h >= 180.0 and hsv.h < 240.0) {
            r = 0.0;
            g = x;
            b = c;
        } else if (hsv.h >= 240.0 and hsv.h < 300.0) {
            r = x;
            g = 0.0;
            b = c;
        } else if (hsv.h >= 300.0 and hsv.h < 360.0) {
            r = c;
            g = 0.0;
            b = x;
        }

        return Color{
            .r = r + m,
            .g = g + m,
            .b = b + m,
            .a = hsv.a,
        };
    }

    /// Adjust saturation of a color (0.0 = grayscale, 1.0 = original, >1.0 = oversaturated)
    pub fn adjustSaturation(color: Color, saturation_factor: f32) Color {
        var hsv = toHSV(color);
        hsv.s = scalar.clamp(hsv.s * saturation_factor, 0.0, 1.0);
        return fromHSV(hsv);
    }

    /// Adjust brightness/value of a color (0.0 = black, 1.0 = original, >1.0 = brighter)
    pub fn adjustBrightness(color: Color, brightness_factor: f32) Color {
        var hsv = toHSV(color);
        hsv.v = scalar.clamp(hsv.v * brightness_factor, 0.0, 1.0);
        return fromHSV(hsv);
    }

    /// Shift hue of a color by degrees (-360 to 360)
    pub fn shiftHue(color: Color, hue_shift: f32) Color {
        var hsv = toHSV(color);
        hsv.h = @mod(hsv.h + hue_shift, 360.0);
        if (hsv.h < 0.0) hsv.h += 360.0;
        return fromHSV(hsv);
    }

    /// Get complementary color (opposite on color wheel)
    pub fn complement(color: Color) Color {
        return shiftHue(color, 180.0);
    }

    /// Get grayscale version of color using luminance weights
    pub fn toGrayscale(color: Color) Color {
        // Standard luminance formula
        const luminance = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
        return Color{
            .r = luminance,
            .g = luminance,
            .b = luminance,
            .a = color.a,
        };
    }

    /// Get luminance value (0.0 to 1.0)
    pub fn getLuminance(color: Color) f32 {
        return 0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
    }

    /// Check if color is considered dark (luminance < 0.5)
    pub fn isDark(color: Color) bool {
        return getLuminance(color) < 0.5;
    }

    /// Check if color is considered light (luminance >= 0.5)
    pub fn isLight(color: Color) bool {
        return getLuminance(color) >= 0.5;
    }
};

test "color math" {
    const red = Color.fromNormalized(1.0, 0.0, 0.0);
    const blue = Color.fromNormalized(0.0, 0.0, 1.0);

    // Test lerp
    const purple = ColorMath.lerp(red, blue, 0.5);
    const epsilon = 0.01;
    try std.testing.expect(@abs(purple.r - 0.5) < epsilon); // Should be 0.5 (halfway between 1.0 and 0.0)
    try std.testing.expect(@abs(purple.b - 0.5) < epsilon);

    // Test darken
    const dark_red = ColorMath.darken(red, 0.5);
    try std.testing.expect(@abs(dark_red.r - 0.5) < epsilon); // Should be 0.5 (50% of 1.0)
    try std.testing.expect(dark_red.a == 1.0); // Alpha preserved

    // Test lighten
    const light_red = ColorMath.lighten(red, 0.5);
    try std.testing.expect(light_red.r == 1.0); // Already at max
    try std.testing.expect(light_red.g >= 0.5); // Green should increase

    // Test withAlpha
    const transparent_red = ColorMath.withAlpha(red, 0.5);
    try std.testing.expect(transparent_red.a == 0.5);

    // Test intensity
    const dim_red = ColorMath.applyIntensity(red, 0.5);
    try std.testing.expect(@abs(dim_red.r - 0.5) < epsilon);
}

test "HSV color conversion" {
    const red = Color.fromNormalized(1.0, 0.0, 0.0);
    const hsv = ColorAdvanced.toHSV(red);
    const back_to_rgb = ColorAdvanced.fromHSV(hsv);

    // Should be close to original (within rounding errors)
    const epsilon = 0.01;
    try std.testing.expect(@abs(back_to_rgb.r - red.r) <= epsilon);
    try std.testing.expect(@abs(back_to_rgb.g - red.g) <= epsilon);
    try std.testing.expect(@abs(back_to_rgb.b - red.b) <= epsilon);
}

test "advanced color functions" {
    const red = Color.fromNormalized(1.0, 0.0, 0.0);

    // Test complement
    const red_complement = ColorAdvanced.complement(red);
    try std.testing.expect(red_complement.g > 0.7); // Should be cyan-ish (> 0.7 in 0.0-1.0 range)
    try std.testing.expect(red_complement.b > 0.7);

    // Test grayscale
    const gray = ColorAdvanced.toGrayscale(red);
    try std.testing.expect(gray.r == gray.g and gray.g == gray.b);

    // Test luminance
    const core_colors_test = @import("../core/colors.zig");
    const white_luminance = ColorAdvanced.getLuminance(core_colors_test.WHITE);
    const black_luminance = ColorAdvanced.getLuminance(core_colors_test.BLACK);
    try std.testing.expect(white_luminance > 0.9);
    try std.testing.expect(black_luminance < 0.1);

    // Test isDark/isLight
    try std.testing.expect(ColorAdvanced.isDark(core_colors_test.BLACK));
    try std.testing.expect(ColorAdvanced.isLight(core_colors_test.WHITE));
}
