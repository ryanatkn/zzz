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
