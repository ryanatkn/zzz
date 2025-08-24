const std = @import("std");
const scalar = @import("../math/scalar.zig");

/// RGBA color struct compatible with GPU buffers - float-first design
pub const Color = extern struct {
    r: f32, // 0.0 to 1.0
    g: f32, // 0.0 to 1.0
    b: f32, // 0.0 to 1.0
    a: f32, // 0.0 to 1.0

    /// Direct float constructor (0.0-1.0 range)
    pub fn fromFloat(r: f32, g: f32, b: f32, a: f32) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    /// Normalized float constructor (RGB with alpha=1.0)
    pub fn fromNormalized(r: f32, g: f32, b: f32) Color {
        return .{ .r = r, .g = g, .b = b, .a = 1.0 };
    }

    /// Create a color from hex string (e.g., "FF0000" for red)
    pub fn fromHex(hex: []const u8) !Color {
        if (hex.len != 6) return error.InvalidHexLength;
        const r = std.fmt.parseInt(u8, hex[0..2], 16) catch return error.InvalidHexFormat;
        const g = std.fmt.parseInt(u8, hex[2..4], 16) catch return error.InvalidHexFormat;
        const b = std.fmt.parseInt(u8, hex[4..6], 16) catch return error.InvalidHexFormat;
        return fromNormalized(
            @as(f32, @floatFromInt(r)) / 255.0,
            @as(f32, @floatFromInt(g)) / 255.0,
            @as(f32, @floatFromInt(b)) / 255.0,
        );
    }

    /// Convert to u8 array for SDL APIs that require it
    pub fn toU8Array(self: Color) [4]u8 {
        return .{
            @intFromFloat(self.r * 255.0),
            @intFromFloat(self.g * 255.0),
            @intFromFloat(self.b * 255.0),
            @intFromFloat(self.a * 255.0),
        };
    }

    /// Convert to float array for GPU uniforms (now zero-cost)
    pub inline fn toFloatArray(self: Color) [4]f32 {
        return .{ self.r, self.g, self.b, self.a };
    }
};

// Game colors moved to respective game modules (e.g., hex/colors.zig)

// Common UI colors
pub const BLACK = Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 };
pub const WHITE = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };

// Frequently used gray scales
pub const DARK_GRAY_15 = Color{ .r = 0.059, .g = 0.071, .b = 0.098, .a = 1.0 }; // (15, 18, 25)
pub const DARK_GRAY_25 = Color{ .r = 0.098, .g = 0.098, .b = 0.098, .a = 1.0 }; // (25, 25, 25)
pub const DARK_GRAY_30 = Color{ .r = 0.118, .g = 0.118, .b = 0.118, .a = 1.0 }; // (30, 30, 30)
pub const DARK_GRAY_40 = Color{ .r = 0.157, .g = 0.157, .b = 0.157, .a = 1.0 }; // (40, 40, 40)
pub const DARK_GRAY_50 = Color{ .r = 0.196, .g = 0.196, .b = 0.196, .a = 1.0 }; // (50, 50, 50)
pub const GRAY_60 = Color{ .r = 0.235, .g = 0.235, .b = 0.235, .a = 1.0 }; // (60, 60, 60)
pub const GRAY_80 = Color{ .r = 0.314, .g = 0.314, .b = 0.314, .a = 1.0 }; // (80, 80, 80)
pub const GRAY_100 = Color{ .r = 0.392, .g = 0.392, .b = 0.392, .a = 1.0 }; // (100, 100, 100)
pub const LIGHT_GRAY_180 = Color{ .r = 0.706, .g = 0.745, .b = 0.784, .a = 1.0 }; // (180, 190, 200)
pub const LIGHT_GRAY_200 = Color{ .r = 0.784, .g = 0.784, .b = 0.784, .a = 1.0 }; // (200, 200, 200)
pub const LIGHT_GRAY_220 = Color{ .r = 0.784, .g = 0.784, .b = 0.863, .a = 1.0 }; // (200, 200, 220)
pub const LIGHT_GRAY_230 = Color{ .r = 0.902, .g = 0.902, .b = 0.902, .a = 1.0 }; // (230, 230, 230)
pub const WHITE_255 = WHITE; // Full white alias

// Navigation and UI colors
pub const NAV_BACKGROUND = Color{ .r = 0.078, .g = 0.098, .b = 0.137, .a = 1.0 }; // (20, 25, 35)
pub const NAV_BORDER = Color{ .r = 0.157, .g = 0.176, .b = 0.216, .a = 1.0 }; // (40, 45, 55)
pub const ADDRESS_BAR_BG = Color{ .r = 0.059, .g = 0.071, .b = 0.098, .a = 1.0 }; // (15, 18, 25)

// Button colors
pub const BUTTON_NORMAL = Color{ .r = 0.235, .g = 0.275, .b = 0.353, .a = 1.0 }; // (60, 70, 90)
pub const BUTTON_BORDER = Color{ .r = 0.314, .g = 0.353, .b = 0.431, .a = 1.0 }; // (80, 90, 110)
pub const BUTTON_DISABLED = Color{ .r = 0.118, .g = 0.137, .b = 0.176, .a = 0.502 }; // (30, 35, 45, 128)
pub const BUTTON_HOVER = Color{ .r = 0.235, .g = 0.314, .b = 0.471, .a = 1.0 }; // (60, 80, 120)

// Link colors
pub const LINK_NORMAL = Color{ .r = 0.157, .g = 0.196, .b = 0.314, .a = 1.0 }; // (40, 50, 80)
pub const LINK_HOVERED = Color{ .r = 0.235, .g = 0.314, .b = 0.471, .a = 1.0 }; // (60, 80, 120)

// Focus and selection colors
pub const FOCUS_BORDER = Color{ .r = 0.392, .g = 0.588, .b = 0.784, .a = 1.0 }; // (100, 150, 200)

// Shared accent colors (single source of truth)
pub const GOLD = Color{ .r = 1.0, .g = 0.843, .b = 0.0, .a = 1.0 }; // (255, 215, 0)
pub const GOLD_DARK = Color{ .r = 0.784, .g = 0.588, .b = 0.039, .a = 1.0 }; // Darker gold for animations
pub const ORANGE = Color{ .r = 1.0, .g = 0.549, .b = 0.0, .a = 1.0 }; // Orange for file types, syntax
pub const PURPLE = Color{ .r = 0.471, .g = 0.118, .b = 0.627, .a = 1.0 }; // Purple for accents
pub const CYAN = Color{ .r = 0.0, .g = 0.784, .b = 0.784, .a = 1.0 }; // Cyan for accents

// Discrete color palettes with consistent hues (numbered by intensity percentage)
// TODO: optimize - Add complete discrete color families: CYAN_20/40/60/80, YELLOW_GREEN_20/40/60/80, etc.
// TODO: optimize - Add comptime color validation to ensure hue consistency within families
// Blue variants (hue ~0.608, varying saturation/value)
pub const BLUE_20 = Color{ .r = 0.051, .g = 0.145, .b = 0.320, .a = 1.0 };
pub const BLUE_40 = Color{ .r = 0.053, .g = 0.188, .b = 0.440, .a = 1.0 };
pub const BLUE_60 = Color{ .r = 0.045, .g = 0.225, .b = 0.560, .a = 1.0 };
pub const BLUE_80 = Color{ .r = 0.135, .g = 0.403, .b = 0.900, .a = 1.0 };
pub const BLUE_100 = Color{ .r = 0.300, .g = 0.545, .b = 1.000, .a = 1.0 };

// Purple variants (hue ~0.782, varying saturation/value)
pub const PURPLE_20 = Color{ .r = 0.245, .g = 0.077, .b = 0.320, .a = 1.0 };
pub const PURPLE_40 = Color{ .r = 0.329, .g = 0.079, .b = 0.440, .a = 1.0 };
pub const PURPLE_60 = Color{ .r = 0.408, .g = 0.067, .b = 0.560, .a = 1.0 };
pub const PURPLE_80 = Color{ .r = 0.651, .g = 0.090, .b = 0.900, .a = 1.0 };
pub const PURPLE_100 = Color{ .r = 0.754, .g = 0.200, .b = 1.000, .a = 1.0 };

// Alpha variants for overlays
pub const OVERLAY_20 = Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.2 };
pub const OVERLAY_40 = Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.4 };
pub const OVERLAY_60 = Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.6 };
pub const OVERLAY_80 = Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.8 };

// Semi-transparent versions
pub const DARK_OVERLAY = Color{ .r = 0.039, .g = 0.039, .b = 0.059, .a = 0.471 }; // (10, 10, 15, 120)
pub const SELECTION_BLUE = Color{ .r = 0.235, .g = 0.392, .b = 0.627, .a = 0.502 }; // (60, 100, 160, 128)
pub const COOLDOWN_OVERLAY = Color{ .r = 0.235, .g = 0.235, .b = 0.235, .a = 0.588 }; // (60, 60, 60, 150)
pub const TRANSPARENT = Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 };

// ANSI Terminal Colors (exact terminal compatibility)
pub const ANSI_BLACK = Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 }; // (0, 0, 0)
pub const ANSI_RED = Color{ .r = 0.804, .g = 0.192, .b = 0.192, .a = 1.0 }; // (205, 49, 49)
pub const ANSI_GREEN = Color{ .r = 0.051, .g = 0.737, .b = 0.475, .a = 1.0 }; // (13, 188, 121)
pub const ANSI_YELLOW = Color{ .r = 0.898, .g = 0.898, .b = 0.063, .a = 1.0 }; // (229, 229, 16)
pub const ANSI_BLUE = Color{ .r = 0.141, .g = 0.447, .b = 0.784, .a = 1.0 }; // (36, 114, 200)
pub const ANSI_MAGENTA = Color{ .r = 0.737, .g = 0.247, .b = 0.737, .a = 1.0 }; // (188, 63, 188)
pub const ANSI_CYAN = Color{ .r = 0.067, .g = 0.659, .b = 0.804, .a = 1.0 }; // (17, 168, 205)
pub const ANSI_WHITE = Color{ .r = 0.898, .g = 0.898, .b = 0.898, .a = 1.0 }; // (229, 229, 229)
pub const ANSI_BRIGHT_BLACK = Color{ .r = 0.400, .g = 0.400, .b = 0.400, .a = 1.0 }; // (102, 102, 102)
pub const ANSI_BRIGHT_RED = Color{ .r = 0.945, .g = 0.298, .b = 0.298, .a = 1.0 }; // (241, 76, 76)
pub const ANSI_BRIGHT_GREEN = Color{ .r = 0.137, .g = 0.820, .b = 0.545, .a = 1.0 }; // (35, 209, 139)
pub const ANSI_BRIGHT_YELLOW = Color{ .r = 0.961, .g = 0.961, .b = 0.263, .a = 1.0 }; // (245, 245, 67)
pub const ANSI_BRIGHT_BLUE = Color{ .r = 0.231, .g = 0.557, .b = 0.918, .a = 1.0 }; // (59, 142, 234)
pub const ANSI_BRIGHT_MAGENTA = Color{ .r = 0.839, .g = 0.439, .b = 0.839, .a = 1.0 }; // (214, 112, 214)
pub const ANSI_BRIGHT_CYAN = Color{ .r = 0.161, .g = 0.722, .b = 0.859, .a = 1.0 }; // (41, 184, 219)
pub const ANSI_BRIGHT_WHITE = WHITE; // (255, 255, 255)

// Semantic and UI colors moved to ui/styles/base_style.zig or game-specific modules

// Color utility functions are in src/lib/math/color.zig (ColorMath, ColorAdvanced)
// This module contains only the core Color type and basic constants

// HSV conversion and advanced color functions moved to math/color.zig

// All color manipulation functions moved to math/color.zig

test "core color constants" {
    // Test basic color constants are available
    try std.testing.expect(BLACK.r == 0.0 and BLACK.g == 0.0 and BLACK.b == 0.0 and BLACK.a == 1.0);
    try std.testing.expect(WHITE.r == 1.0 and WHITE.g == 1.0 and WHITE.b == 1.0 and WHITE.a == 1.0);
    try std.testing.expect(TRANSPARENT.a == 0.0);
}

test "Color constructors" {
    // Test fromNormalized
    const red = Color.fromNormalized(1.0, 0.0, 0.0);
    try std.testing.expect(red.r == 1.0 and red.g == 0.0 and red.b == 0.0 and red.a == 1.0);

    // Test fromFloat
    const float_white = Color.fromFloat(1.0, 1.0, 1.0, 1.0);
    try std.testing.expect(float_white.r == 1.0 and float_white.g == 1.0 and float_white.b == 1.0 and float_white.a == 1.0);

    const half_gray = Color.fromFloat(0.5, 0.5, 0.5, 0.5);
    try std.testing.expect(half_gray.r == 0.5 and half_gray.g == 0.5 and half_gray.b == 0.5 and half_gray.a == 0.5);

    // Test fromHex
    const red_from_hex = try Color.fromHex("FF0000");
    try std.testing.expect(red_from_hex.r == 1.0 and red_from_hex.g == 0.0 and red_from_hex.b == 0.0 and red_from_hex.a == 1.0);
}

test "Color conversion methods" {
    const test_color = Color.fromFloat(100.0 / 255.0, 150.0 / 255.0, 200.0 / 255.0, 1.0);

    // Test toU8Array
    const u8_array = test_color.toU8Array();
    try std.testing.expect(u8_array[0] == 100 and u8_array[1] == 150 and u8_array[2] == 200 and u8_array[3] == 255);

    // Test toFloatArray (zero-cost)
    const float_array = test_color.toFloatArray();
    const epsilon = 0.01; // Small tolerance for floating point comparison
    try std.testing.expect(@abs(float_array[0] - (100.0 / 255.0)) < epsilon);
    try std.testing.expect(@abs(float_array[1] - (150.0 / 255.0)) < epsilon);
    try std.testing.expect(@abs(float_array[2] - (200.0 / 255.0)) < epsilon);
    try std.testing.expect(@abs(float_array[3] - 1.0) < epsilon);
}
