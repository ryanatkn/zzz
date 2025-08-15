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
