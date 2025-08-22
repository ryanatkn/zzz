const std = @import("std");
const scalar = @import("../math/scalar.zig");

/// RGBA color struct compatible with GPU buffers
pub const Color = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

// Game colors moved to respective game modules (e.g., hex/colors.zig)

// Common UI colors
pub const BLACK = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
pub const WHITE = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
pub const TRANSPARENT = Color{ .r = 0, .g = 0, .b = 0, .a = 0 };

// Semantic and UI colors moved to ui/styles/base_style.zig or game-specific modules

// Color utility functions are in src/lib/math/color.zig (ColorMath, ColorAdvanced)
// This module contains only the core Color type and basic constants

// HSV conversion and advanced color functions moved to math/color.zig

// All color manipulation functions moved to math/color.zig

test "core color constants" {
    // Test basic color constants are available
    try std.testing.expect(BLACK.r == 0 and BLACK.g == 0 and BLACK.b == 0 and BLACK.a == 255);
    try std.testing.expect(WHITE.r == 255 and WHITE.g == 255 and WHITE.b == 255 and WHITE.a == 255);
    try std.testing.expect(TRANSPARENT.a == 0);
}
