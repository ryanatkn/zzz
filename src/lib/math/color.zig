const std = @import("std");
const scalar = @import("scalar.zig");

// Re-use the core Color type from colors.zig to avoid duplication
const core_colors = @import("../core/colors.zig");
pub const Color = core_colors.Color;

/// F32 RGB color for calculations
pub const ColorF32 = struct {
    r: f32,
    g: f32,
    b: f32,
};

/// Color pair for border animations and gradients
pub const ColorPair = struct {
    dark: ColorF32,
    bright: ColorF32,
};

/// Consolidated color mathematics utilities
pub const ColorMath = struct {
    /// Linear interpolation between two colors
    pub fn lerp(color1: Color, color2: Color, t: f32) Color {
        const clamped_t = scalar.clamp(t, 0.0, 1.0);

        return Color{
            .r = @intFromFloat(@as(f32, @floatFromInt(color1.r)) + (@as(f32, @floatFromInt(color2.r)) - @as(f32, @floatFromInt(color1.r))) * clamped_t),
            .g = @intFromFloat(@as(f32, @floatFromInt(color1.g)) + (@as(f32, @floatFromInt(color2.g)) - @as(f32, @floatFromInt(color1.g))) * clamped_t),
            .b = @intFromFloat(@as(f32, @floatFromInt(color1.b)) + (@as(f32, @floatFromInt(color2.b)) - @as(f32, @floatFromInt(color1.b))) * clamped_t),
            .a = @intFromFloat(@as(f32, @floatFromInt(color1.a)) + (@as(f32, @floatFromInt(color2.a)) - @as(f32, @floatFromInt(color1.a))) * clamped_t),
        };
    }

    /// Darken a color by reducing RGB values by percentage (0.0 to 1.0)
    pub fn darken(color: Color, factor: f32) Color {
        const clamped_factor = scalar.clamp(factor, 0.0, 1.0);
        const multiplier = 1.0 - clamped_factor;
        return Color{
            .r = @intFromFloat(@as(f32, @floatFromInt(color.r)) * multiplier),
            .g = @intFromFloat(@as(f32, @floatFromInt(color.g)) * multiplier),
            .b = @intFromFloat(@as(f32, @floatFromInt(color.b)) * multiplier),
            .a = color.a,
        };
    }

    /// Lighten a color by increasing RGB values by percentage (0.0 to 1.0)
    pub fn lighten(color: Color, factor: f32) Color {
        const clamped_factor = scalar.clamp(factor, 0.0, 1.0);
        return Color{
            .r = @intFromFloat(@as(f32, @floatFromInt(color.r)) + (255.0 - @as(f32, @floatFromInt(color.r))) * clamped_factor),
            .g = @intFromFloat(@as(f32, @floatFromInt(color.g)) + (255.0 - @as(f32, @floatFromInt(color.g))) * clamped_factor),
            .b = @intFromFloat(@as(f32, @floatFromInt(color.b)) + (255.0 - @as(f32, @floatFromInt(color.b))) * clamped_factor),
            .a = color.a,
        };
    }

    /// Create a color with specified alpha transparency
    pub fn withAlpha(color: Color, alpha: u8) Color {
        return Color{
            .r = color.r,
            .g = color.g,
            .b = color.b,
            .a = alpha,
        };
    }

    /// Apply intensity multiplier to a color (0.0 to 1.0)
    pub fn applyIntensity(color: Color, intensity: f32) Color {
        const clamped = scalar.clamp(intensity, 0.0, 1.0);
        return Color{
            .r = @intFromFloat(@as(f32, @floatFromInt(color.r)) * clamped),
            .g = @intFromFloat(@as(f32, @floatFromInt(color.g)) * clamped),
            .b = @intFromFloat(@as(f32, @floatFromInt(color.b)) * clamped),
            .a = color.a,
        };
    }

    /// Interpolate between F32 color pairs (for UI animations)
    pub fn lerpColorF32(a: ColorF32, b: ColorF32, t: f32) ColorF32 {
        const clamped_t = scalar.clamp(t, 0.0, 1.0);
        return ColorF32{
            .r = a.r + (b.r - a.r) * clamped_t,
            .g = a.g + (b.g - a.g) * clamped_t,
            .b = a.b + (b.b - a.b) * clamped_t,
        };
    }

    /// Convert F32 color to byte color with intensity
    pub fn f32ToColor(color_f32: ColorF32, intensity: f32) Color {
        const clamped_intensity = scalar.clamp(intensity, 0.0, 1.0);
        return Color{
            .r = @intFromFloat(color_f32.r * clamped_intensity),
            .g = @intFromFloat(color_f32.g * clamped_intensity),
            .b = @intFromFloat(color_f32.b * clamped_intensity),
            .a = 255,
        };
    }

    /// Convert Color to F32 representation
    pub fn colorToF32(color: Color) ColorF32 {
        return ColorF32{
            .r = @as(f32, @floatFromInt(color.r)),
            .g = @as(f32, @floatFromInt(color.g)),
            .b = @as(f32, @floatFromInt(color.b)),
        };
    }

    /// Interpolate between color pair with automatic timing
    pub fn interpolateColorPair(color_pair: ColorPair, t: f32, intensity: f32) Color {
        const lerped = lerpColorF32(color_pair.dark, color_pair.bright, t);
        return f32ToColor(lerped, intensity);
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
        const r = @as(f32, @floatFromInt(color.r)) / 255.0;
        const g = @as(f32, @floatFromInt(color.g)) / 255.0;
        const b = @as(f32, @floatFromInt(color.b)) / 255.0;
        const a = @as(f32, @floatFromInt(color.a)) / 255.0;

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
            .r = @intFromFloat((r + m) * 255.0),
            .g = @intFromFloat((g + m) * 255.0),
            .b = @intFromFloat((b + m) * 255.0),
            .a = @intFromFloat(hsv.a * 255.0),
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
        const luminance = 0.299 * @as(f32, @floatFromInt(color.r)) +
            0.587 * @as(f32, @floatFromInt(color.g)) +
            0.114 * @as(f32, @floatFromInt(color.b));
        const gray_value = @as(u8, @intFromFloat(luminance));
        return Color{
            .r = gray_value,
            .g = gray_value,
            .b = gray_value,
            .a = color.a,
        };
    }

    /// Get luminance value (0.0 to 1.0)
    pub fn getLuminance(color: Color) f32 {
        return (0.299 * @as(f32, @floatFromInt(color.r)) +
            0.587 * @as(f32, @floatFromInt(color.g)) +
            0.114 * @as(f32, @floatFromInt(color.b))) / 255.0;
    }

    /// Check if color is considered dark (luminance < 0.5)
    pub fn isDark(color: Color) bool {
        return getLuminance(color) < 0.5;
    }

    /// Check if color is considered light (luminance >= 0.5)
    pub fn isLight(color: Color) bool {
        return getLuminance(color) >= 0.5;
    }

    /// Create a color from hex string (e.g., "FF0000" for red)
    pub fn fromHex(hex: []const u8) !Color {
        if (hex.len != 6) return error.InvalidHexLength;

        const r = std.fmt.parseInt(u8, hex[0..2], 16) catch return error.InvalidHexFormat;
        const g = std.fmt.parseInt(u8, hex[2..4], 16) catch return error.InvalidHexFormat;
        const b = std.fmt.parseInt(u8, hex[4..6], 16) catch return error.InvalidHexFormat;

        return Color{ .r = r, .g = g, .b = b, .a = 255 };
    }

    /// Convert color to hex string (without alpha)
    pub fn toHex(color: Color, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "{X:0>2}{X:0>2}{X:0>2}", .{ color.r, color.g, color.b });
    }
};

/// Semantic color builders for common hardcoded patterns
/// Eliminates `Color{ .r = X, .g = Y, .b = Z }` constructions
pub const ColorBuilder = struct {
    /// Create a color from RGB values with full opacity
    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return Color{ .r = r, .g = g, .b = b, .a = 255 };
    }

    /// Create a color from RGBA values
    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
        return Color{ .r = r, .g = g, .b = b, .a = a };
    }

    /// Create a grayscale color with full opacity
    pub fn gray(value: u8) Color {
        return Color{ .r = value, .g = value, .b = value, .a = 255 };
    }

    /// Create a grayscale color with alpha
    pub fn grayAlpha(value: u8, alpha: u8) Color {
        return Color{ .r = value, .g = value, .b = value, .a = alpha };
    }

    /// Create a color from normalized float values (0.0 to 1.0)
    pub fn fromNormalized(r_norm: f32, g_norm: f32, b_norm: f32) Color {
        return Color{
            .r = @intFromFloat(scalar.clamp(r_norm, 0.0, 1.0) * 255.0),
            .g = @intFromFloat(scalar.clamp(g_norm, 0.0, 1.0) * 255.0),
            .b = @intFromFloat(scalar.clamp(b_norm, 0.0, 1.0) * 255.0),
            .a = 255,
        };
    }

    /// Create a color from normalized float values with alpha
    pub fn fromNormalizedAlpha(r_norm: f32, g_norm: f32, b_norm: f32, a_norm: f32) Color {
        return Color{
            .r = @intFromFloat(scalar.clamp(r_norm, 0.0, 1.0) * 255.0),
            .g = @intFromFloat(scalar.clamp(g_norm, 0.0, 1.0) * 255.0),
            .b = @intFromFloat(scalar.clamp(b_norm, 0.0, 1.0) * 255.0),
            .a = @intFromFloat(scalar.clamp(a_norm, 0.0, 1.0) * 255.0),
        };
    }
};

test "color math" {
    const red = Color{ .r = 255, .g = 0, .b = 0, .a = 255 };
    const blue = Color{ .r = 0, .g = 0, .b = 255, .a = 255 };

    // Test lerp
    const purple = ColorMath.lerp(red, blue, 0.5);
    try std.testing.expect(purple.r >= 127 and purple.r <= 128); // Allow for rounding
    try std.testing.expect(purple.b >= 127 and purple.b <= 128);

    // Test darken
    const dark_red = ColorMath.darken(red, 0.5);
    try std.testing.expect(dark_red.r == 127 or dark_red.r == 128);
    try std.testing.expect(dark_red.a == 255); // Alpha preserved

    // Test lighten
    const light_red = ColorMath.lighten(red, 0.5);
    try std.testing.expect(light_red.r == 255); // Already at max
    try std.testing.expect(light_red.g >= 127); // Green should increase

    // Test withAlpha
    const transparent_red = ColorMath.withAlpha(red, 128);
    try std.testing.expect(transparent_red.a == 128);

    // Test intensity
    const dim_red = ColorMath.applyIntensity(red, 0.5);
    try std.testing.expect(dim_red.r >= 127 and dim_red.r <= 128);
}

test "F32 color operations" {
    const color_pair = ColorPair{
        .dark = ColorF32{ .r = 200.0, .g = 150.0, .b = 10.0 },
        .bright = ColorF32{ .r = 255.0, .g = 240.0, .b = 0.0 },
    };

    // Test F32 lerp
    const mid = ColorMath.lerpColorF32(color_pair.dark, color_pair.bright, 0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 227.5), mid.r, 0.1); // (200 + 255) / 2

    // Test color pair interpolation
    const result = ColorMath.interpolateColorPair(color_pair, 0.5, 0.8);
    try std.testing.expect(result.a == 255);
}

test "HSV color conversion" {
    const red = Color{ .r = 255, .g = 0, .b = 0, .a = 255 };
    const hsv = ColorAdvanced.toHSV(red);
    const back_to_rgb = ColorAdvanced.fromHSV(hsv);

    // Should be close to original (within rounding errors)
    try std.testing.expect(@as(i16, back_to_rgb.r) - @as(i16, red.r) <= 1);
    try std.testing.expect(@as(i16, back_to_rgb.g) - @as(i16, red.g) <= 1);
    try std.testing.expect(@as(i16, back_to_rgb.b) - @as(i16, red.b) <= 1);
}

test "advanced color functions" {
    const red = Color{ .r = 255, .g = 0, .b = 0, .a = 255 };

    // Test complement
    const red_complement = ColorAdvanced.complement(red);
    try std.testing.expect(red_complement.g > 200); // Should be cyan-ish
    try std.testing.expect(red_complement.b > 200);

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

test "hex color conversion" {
    const red_hex = "FF0000";
    const red = try ColorAdvanced.fromHex(red_hex);
    try std.testing.expect(red.r == 255 and red.g == 0 and red.b == 0);

    var allocator = std.testing.allocator;
    const hex_back = try ColorAdvanced.toHex(red, allocator);
    defer allocator.free(hex_back);
    try std.testing.expect(std.mem.eql(u8, hex_back, red_hex));
}

test "color builder semantic constructors" {
    // Test RGB constructor
    const red = ColorBuilder.rgb(255, 0, 0);
    try std.testing.expect(red.r == 255 and red.g == 0 and red.b == 0 and red.a == 255);

    // Test RGBA constructor
    const transparent_blue = ColorBuilder.rgba(0, 0, 255, 128);
    try std.testing.expect(transparent_blue.b == 255 and transparent_blue.a == 128);

    // Test grayscale constructor
    const gray = ColorBuilder.gray(128);
    try std.testing.expect(gray.r == 128 and gray.g == 128 and gray.b == 128 and gray.a == 255);

    // Test grayscale with alpha
    const transparent_gray = ColorBuilder.grayAlpha(64, 200);
    try std.testing.expect(transparent_gray.r == 64 and transparent_gray.a == 200);

    // Test normalized constructor
    const norm_color = ColorBuilder.fromNormalized(1.0, 0.5, 0.0);
    try std.testing.expect(norm_color.r == 255);
    try std.testing.expect(norm_color.g >= 127 and norm_color.g <= 128); // Allow for rounding
    try std.testing.expect(norm_color.b == 0);
    try std.testing.expect(norm_color.a == 255);

    // Test normalized with alpha
    const norm_alpha = ColorBuilder.fromNormalizedAlpha(0.8, 0.6, 0.4, 0.5);
    try std.testing.expect(norm_alpha.r >= 203 and norm_alpha.r <= 204); // 0.8 * 255
    try std.testing.expect(norm_alpha.g >= 152 and norm_alpha.g <= 153); // 0.6 * 255
    try std.testing.expect(norm_alpha.b >= 101 and norm_alpha.b <= 102); // 0.4 * 255
    try std.testing.expect(norm_alpha.a >= 127 and norm_alpha.a <= 128); // 0.5 * 255
}
