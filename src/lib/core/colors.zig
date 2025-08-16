const std = @import("std");

/// RGBA color struct compatible with GPU buffers
pub const Color = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

// Core game entity colors
pub const PLAYER_ALIVE = Color{ .r = 0, .g = 70, .b = 200, .a = 255 }; // BLUE
pub const UNIT_DEFAULT = Color{ .r = 100, .g = 100, .b = 100, .a = 255 }; // GRAY (default unit color)
pub const UNIT_AGGRO = Color{ .r = 200, .g = 30, .b = 30, .a = 255 }; // RED (aggro)
pub const UNIT_NON_AGGRO = Color{ .r = 120, .g = 60, .b = 60, .a = 255 }; // DIMMED RED (non-aggro)
pub const OBSTACLE_DEADLY = Color{ .r = 200, .g = 100, .b = 0, .a = 255 }; // ORANGE (deadly)
pub const OBSTACLE_BLOCKING = Color{ .r = 0, .g = 140, .b = 0, .a = 255 }; // GREEN (blocking)
pub const BULLET = Color{ .r = 220, .g = 160, .b = 0, .a = 255 }; // YELLOW
pub const PORTAL = Color{ .r = 120, .g = 30, .b = 160, .a = 255 }; // PURPLE
pub const LIFESTONE_ATTUNED = Color{ .r = 0, .g = 200, .b = 200, .a = 255 }; // CYAN (attuned)
pub const LIFESTONE_UNATTUNED = Color{ .r = 0, .g = 100, .b = 100, .a = 255 }; // CYAN_FADED (unattuned)
pub const DEAD = Color{ .r = 100, .g = 100, .b = 100, .a = 255 }; // GRAY

// Common UI colors
pub const BLACK = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
pub const WHITE = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
pub const TRANSPARENT = Color{ .r = 0, .g = 0, .b = 0, .a = 0 };

// Semantic UI colors
pub const PRIMARY = Color{ .r = 0, .g = 123, .b = 255, .a = 255 }; // Bootstrap blue
pub const SECONDARY = Color{ .r = 108, .g = 117, .b = 125, .a = 255 }; // Bootstrap gray
pub const SUCCESS = Color{ .r = 40, .g = 167, .b = 69, .a = 255 }; // Bootstrap green
pub const DANGER = Color{ .r = 220, .g = 53, .b = 69, .a = 255 }; // Bootstrap red
pub const WARNING = Color{ .r = 255, .g = 193, .b = 7, .a = 255 }; // Bootstrap yellow
pub const INFO = Color{ .r = 23, .g = 162, .b = 184, .a = 255 }; // Bootstrap cyan

// UI background colors
pub const BACKGROUND_DARK = Color{ .r = 30, .g = 30, .b = 30, .a = 180 };
pub const BACKGROUND_LIGHT = Color{ .r = 240, .g = 240, .b = 240, .a = 200 };
pub const OVERLAY = Color{ .r = 0, .g = 0, .b = 0, .a = 128 };

// Border/effect colors
pub const BLUE_BRIGHT = Color{ .r = 100, .g = 150, .b = 255, .a = 255 };
pub const GREEN_BRIGHT = Color{ .r = 80, .g = 220, .b = 80, .a = 255 };
pub const PURPLE_BRIGHT = Color{ .r = 180, .g = 100, .b = 240, .a = 255 };
pub const RED_BRIGHT = Color{ .r = 255, .g = 100, .b = 100, .a = 255 };
pub const YELLOW_BRIGHT = Color{ .r = 255, .g = 220, .b = 80, .a = 255 };
pub const ORANGE_BRIGHT = Color{ .r = 255, .g = 180, .b = 80, .a = 255 };
pub const CYAN = Color{ .r = 0, .g = 200, .b = 200, .a = 255 };

// Color utility functions

/// Create a color with specified alpha transparency
pub fn withAlpha(color: Color, alpha: u8) Color {
    return Color{
        .r = color.r,
        .g = color.g,
        .b = color.b,
        .a = alpha,
    };
}

/// Darken a color by reducing RGB values by percentage (0.0 to 1.0)
pub fn darken(color: Color, factor: f32) Color {
    const clamped_factor = std.math.clamp(factor, 0.0, 1.0);
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
    const clamped_factor = std.math.clamp(factor, 0.0, 1.0);
    return Color{
        .r = @intFromFloat(@as(f32, @floatFromInt(color.r)) + (255.0 - @as(f32, @floatFromInt(color.r))) * clamped_factor),
        .g = @intFromFloat(@as(f32, @floatFromInt(color.g)) + (255.0 - @as(f32, @floatFromInt(color.g))) * clamped_factor),
        .b = @intFromFloat(@as(f32, @floatFromInt(color.b)) + (255.0 - @as(f32, @floatFromInt(color.b))) * clamped_factor),
        .a = color.a,
    };
}

/// Mix two colors with a blend factor (0.0 = first color, 1.0 = second color)
pub fn mix(color1: Color, color2: Color, factor: f32) Color {
    const clamped_factor = std.math.clamp(factor, 0.0, 1.0);
    const inv_factor = 1.0 - clamped_factor;
    return Color{
        .r = @intFromFloat(@as(f32, @floatFromInt(color1.r)) * inv_factor + @as(f32, @floatFromInt(color2.r)) * clamped_factor),
        .g = @intFromFloat(@as(f32, @floatFromInt(color1.g)) * inv_factor + @as(f32, @floatFromInt(color2.g)) * clamped_factor),
        .b = @intFromFloat(@as(f32, @floatFromInt(color1.b)) * inv_factor + @as(f32, @floatFromInt(color2.b)) * clamped_factor),
        .a = @intFromFloat(@as(f32, @floatFromInt(color1.a)) * inv_factor + @as(f32, @floatFromInt(color2.a)) * clamped_factor),
    };
}

/// Convert RGB to HSV for advanced color manipulation
pub const HSV = struct {
    h: f32, // Hue (0-360)
    s: f32, // Saturation (0-1)
    v: f32, // Value (0-1)
    a: f32, // Alpha (0-1)
};

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
    hsv.s = std.math.clamp(hsv.s * saturation_factor, 0.0, 1.0);
    return fromHSV(hsv);
}

/// Adjust brightness/value of a color (0.0 = black, 1.0 = original, >1.0 = brighter)
pub fn adjustBrightness(color: Color, brightness_factor: f32) Color {
    var hsv = toHSV(color);
    hsv.v = std.math.clamp(hsv.v * brightness_factor, 0.0, 1.0);
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

/// Multiply color by another color (useful for tinting)
pub fn multiply(color1: Color, color2: Color) Color {
    return Color{
        .r = @intFromFloat((@as(f32, @floatFromInt(color1.r)) / 255.0) * (@as(f32, @floatFromInt(color2.r)) / 255.0) * 255.0),
        .g = @intFromFloat((@as(f32, @floatFromInt(color1.g)) / 255.0) * (@as(f32, @floatFromInt(color2.g)) / 255.0) * 255.0),
        .b = @intFromFloat((@as(f32, @floatFromInt(color1.b)) / 255.0) * (@as(f32, @floatFromInt(color2.b)) / 255.0) * 255.0),
        .a = @intFromFloat((@as(f32, @floatFromInt(color1.a)) / 255.0) * (@as(f32, @floatFromInt(color2.a)) / 255.0) * 255.0),
    };
}

/// Add two colors with clamping
pub fn add(color1: Color, color2: Color) Color {
    return Color{
        .r = @min(255, @as(u16, color1.r) + @as(u16, color2.r)),
        .g = @min(255, @as(u16, color1.g) + @as(u16, color2.g)),
        .b = @min(255, @as(u16, color1.b) + @as(u16, color2.b)),
        .a = @min(255, @as(u16, color1.a) + @as(u16, color2.a)),
    };
}

/// Subtract color2 from color1 with clamping
pub fn subtract(color1: Color, color2: Color) Color {
    return Color{
        .r = if (color1.r > color2.r) color1.r - color2.r else 0,
        .g = if (color1.g > color2.g) color1.g - color2.g else 0,
        .b = if (color1.b > color2.b) color1.b - color2.b else 0,
        .a = if (color1.a > color2.a) color1.a - color2.a else 0,
    };
}

/// Apply gamma correction
pub fn gamma(color: Color, gamma_value: f32) Color {
    const inv_gamma = 1.0 / gamma_value;
    return Color{
        .r = @intFromFloat(std.math.pow(f32, @as(f32, @floatFromInt(color.r)) / 255.0, inv_gamma) * 255.0),
        .g = @intFromFloat(std.math.pow(f32, @as(f32, @floatFromInt(color.g)) / 255.0, inv_gamma) * 255.0),
        .b = @intFromFloat(std.math.pow(f32, @as(f32, @floatFromInt(color.b)) / 255.0, inv_gamma) * 255.0),
        .a = color.a,
    };
}

/// Invert color (255 - each component)
pub fn invert(color: Color) Color {
    return Color{
        .r = 255 - color.r,
        .g = 255 - color.g,
        .b = 255 - color.b,
        .a = color.a,
    };
}

/// Sepia tone effect
pub fn sepia(color: Color) Color {
    const r = @as(f32, @floatFromInt(color.r));
    const g = @as(f32, @floatFromInt(color.g));
    const b = @as(f32, @floatFromInt(color.b));
    
    return Color{
        .r = @intFromFloat(@min(255.0, (r * 0.393) + (g * 0.769) + (b * 0.189))),
        .g = @intFromFloat(@min(255.0, (r * 0.349) + (g * 0.686) + (b * 0.168))),
        .b = @intFromFloat(@min(255.0, (r * 0.272) + (g * 0.534) + (b * 0.131))),
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

/// Get contrasting color (black or white) based on luminance
pub fn getContrast(color: Color) Color {
    return if (isDark(color)) WHITE else BLACK;
}

/// Blend two colors using alpha blending (color2 over color1)
pub fn alphaBlend(background: Color, foreground: Color) Color {
    const fg_alpha = @as(f32, @floatFromInt(foreground.a)) / 255.0;
    const bg_alpha = @as(f32, @floatFromInt(background.a)) / 255.0;
    const inv_fg_alpha = 1.0 - fg_alpha;
    
    const result_alpha = fg_alpha + bg_alpha * inv_fg_alpha;
    
    if (result_alpha == 0.0) return TRANSPARENT;
    
    return Color{
        .r = @intFromFloat(((@as(f32, @floatFromInt(foreground.r)) * fg_alpha) + 
                          (@as(f32, @floatFromInt(background.r)) * bg_alpha * inv_fg_alpha)) / result_alpha),
        .g = @intFromFloat(((@as(f32, @floatFromInt(foreground.g)) * fg_alpha) + 
                          (@as(f32, @floatFromInt(background.g)) * bg_alpha * inv_fg_alpha)) / result_alpha),
        .b = @intFromFloat(((@as(f32, @floatFromInt(foreground.b)) * fg_alpha) + 
                          (@as(f32, @floatFromInt(background.b)) * bg_alpha * inv_fg_alpha)) / result_alpha),
        .a = @intFromFloat(result_alpha * 255.0),
    };
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

/// Color palette generator
pub const Palette = struct {
    /// Generate analogous colors (adjacent on color wheel)
    pub fn analogous(base_color: Color, count: u8) [6]Color {
        var colors: [6]Color = undefined;
        colors[0] = base_color;
        
        for (1..@min(count, 6)) |i| {
            const hue_shift = @as(f32, @floatFromInt(i)) * 30.0; // 30 degree shifts
            colors[i] = shiftHue(base_color, hue_shift);
        }
        
        return colors;
    }
    
    /// Generate triadic colors (120 degrees apart)
    pub fn triadic(base_color: Color) [3]Color {
        return [3]Color{
            base_color,
            shiftHue(base_color, 120.0),
            shiftHue(base_color, 240.0),
        };
    }
    
    /// Generate complementary pair
    pub fn complementary(base_color: Color) [2]Color {
        return [2]Color{
            base_color,
            complement(base_color),
        };
    }
    
    /// Generate split complementary (base + two colors adjacent to complement)
    pub fn splitComplementary(base_color: Color) [3]Color {
        const comp = complement(base_color);
        return [3]Color{
            base_color,
            shiftHue(comp, -30.0),
            shiftHue(comp, 30.0),
        };
    }
    
    /// Generate monochromatic palette (same hue, different brightness/saturation)
    pub fn monochromatic(base_color: Color, count: u8) [5]Color {
        var colors: [5]Color = undefined;
        colors[0] = base_color;
        
        for (1..@min(count, 5)) |i| {
            const factor = 0.2 + (@as(f32, @floatFromInt(i)) * 0.2); // 0.4, 0.6, 0.8, 1.0
            colors[i] = adjustBrightness(base_color, factor);
        }
        
        return colors;
    }
};

test "color manipulation functions" {
    // Test basic color creation
    const red = Color{ .r = 255, .g = 0, .b = 0, .a = 255 };
    const blue = Color{ .r = 0, .g = 0, .b = 255, .a = 255 };
    
    // Test mix
    const purple = mix(red, blue, 0.5);
    try std.testing.expect(purple.r > 100 and purple.r < 140); // Should be around 127
    try std.testing.expect(purple.b > 100 and purple.b < 140);
    
    // Test complement
    const red_complement = complement(red);
    try std.testing.expect(red_complement.g > 200); // Should be cyan-ish
    try std.testing.expect(red_complement.b > 200);
    
    // Test grayscale
    const gray = toGrayscale(red);
    try std.testing.expect(gray.r == gray.g and gray.g == gray.b);
    
    // Test luminance
    const white_luminance = getLuminance(WHITE);
    const black_luminance = getLuminance(BLACK);
    try std.testing.expect(white_luminance > 0.9);
    try std.testing.expect(black_luminance < 0.1);
    
    // Test isDark/isLight
    try std.testing.expect(isDark(BLACK));
    try std.testing.expect(isLight(WHITE));
    try std.testing.expect(getContrast(BLACK).r == 255); // Should return white
    try std.testing.expect(getContrast(WHITE).r == 0);   // Should return black
}

test "HSV color conversion" {
    const red = Color{ .r = 255, .g = 0, .b = 0, .a = 255 };
    const hsv = toHSV(red);
    const back_to_rgb = fromHSV(hsv);
    
    // Should be close to original (within rounding errors)
    try std.testing.expect(@as(i16, back_to_rgb.r) - @as(i16, red.r) <= 1);
    try std.testing.expect(@as(i16, back_to_rgb.g) - @as(i16, red.g) <= 1);
    try std.testing.expect(@as(i16, back_to_rgb.b) - @as(i16, red.b) <= 1);
}

test "hex color conversion" {
    const red_hex = "FF0000";
    const red = try fromHex(red_hex);
    try std.testing.expect(red.r == 255 and red.g == 0 and red.b == 0);
    
    var allocator = std.testing.allocator;
    const hex_back = try toHex(red, allocator);
    defer allocator.free(hex_back);
    try std.testing.expect(std.mem.eql(u8, hex_back, red_hex));
}

test "color palette generation" {
    const base = Color{ .r = 100, .g = 150, .b = 200, .a = 255 };
    
    // Test triadic
    const triadic_colors = Palette.triadic(base);
    try std.testing.expect(triadic_colors.len == 3);
    try std.testing.expect(triadic_colors[0].r == base.r); // First should be original
    
    // Test complementary
    const comp_colors = Palette.complementary(base);
    try std.testing.expect(comp_colors.len == 2);
    try std.testing.expect(comp_colors[0].r == base.r); // First should be original
}
