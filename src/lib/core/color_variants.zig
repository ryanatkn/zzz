const std = @import("std");
const colors = @import("colors.zig");
const color_math = @import("../math/color.zig");
const Color = colors.Color;

/// Base color palette - 11 distinct colors for maximum visual variety
pub const BaseColor = enum(u8) {
    red,
    green,
    blue,
    brown,
    orange,
    yellow,
    purple,
    cyan,
    pink,
    teal,
    indigo,

    /// Get the base color (variant 5 - middle brightness)
    pub fn getBaseColor(self: BaseColor) Color {
        return self.getVariant(5);
    }

    /// Get a specific variant (0-10, where 0 is darkest, 10 is brightest)
    pub fn getVariant(self: BaseColor, variant: u8) Color {
        const clamped_variant = @min(variant, 10);
        return COLOR_PALETTES[@intFromEnum(self)][clamped_variant];
    }

    /// Get the full palette for this color (all 11 variants)
    pub fn getPalette(self: BaseColor) [11]Color {
        return COLOR_PALETTES[@intFromEnum(self)];
    }
};

/// Color variant combining base color and intensity level
pub const ColorVariant = struct {
    base: BaseColor,
    variant: u8, // 0-10, where 0 is darkest, 10 is brightest

    /// Convert to actual Color
    pub fn toColor(self: ColorVariant) Color {
        return self.base.getVariant(self.variant);
    }

    /// Create a standard (middle brightness) variant
    pub fn standard(base: BaseColor) ColorVariant {
        return .{ .base = base, .variant = 5 };
    }

    /// Create a dark variant
    pub fn dark(base: BaseColor) ColorVariant {
        return .{ .base = base, .variant = 2 };
    }

    /// Create a bright variant
    pub fn bright(base: BaseColor) ColorVariant {
        return .{ .base = base, .variant = 8 };
    }
};

// Compile-time helper to generate color variants using precomputed HSV→RGB conversion
fn generateVariants(comptime base_h: f32, comptime base_s: f32, comptime _: f32) [11]Color {
    comptime {
        var variants: [11]Color = undefined;

        // Generate 11 variants from dark to bright at compile time
        for (0..11) |i| {
            const t = @as(f32, @floatFromInt(i)) / 10.0;

            // Value progression: 0.3 (dark) to 0.9 (bright) with curve
            const value = 0.3 + (t * t * 0.6);

            // Saturation modifier for visual balance
            const sat_modifier = 1.0 - (@abs(t - 0.5) * 0.3);
            const saturation = base_s * sat_modifier;

            // Inline HSV→RGB conversion for compile-time evaluation
            variants[i] = hsvToColorComptime(base_h, saturation, value);
        }

        return variants;
    }
}

// Compile-time HSV to RGB conversion (no runtime overhead)
fn hsvToColorComptime(comptime h: f32, comptime s: f32, comptime v: f32) Color {
    comptime {
        const c = v * s;
        const x = c * (1.0 - @abs(@mod(h / 60.0, 2.0) - 1.0));
        const m = v - c;

        var r: f32 = 0.0;
        var g: f32 = 0.0;
        var b: f32 = 0.0;

        if (h >= 0.0 and h < 60.0) {
            r = c;
            g = x;
            b = 0.0;
        } else if (h >= 60.0 and h < 120.0) {
            r = x;
            g = c;
            b = 0.0;
        } else if (h >= 120.0 and h < 180.0) {
            r = 0.0;
            g = c;
            b = x;
        } else if (h >= 180.0 and h < 240.0) {
            r = 0.0;
            g = x;
            b = c;
        } else if (h >= 240.0 and h < 300.0) {
            r = x;
            g = 0.0;
            b = c;
        } else if (h >= 300.0 and h < 360.0) {
            r = c;
            g = 0.0;
            b = x;
        }

        return Color{
            .r = r + m,
            .g = g + m,
            .b = b + m,
            .a = 1.0,
        };
    }
}

// Pre-computed color palettes for each base color
// Each has 11 variants from dark (0) to bright (10)
// Base colors are calibrated to be fairly dark at level 5 (middle)
// Aligned to cache line for optimal performance
const COLOR_PALETTES align(64) = [_][11]Color{
    // Red (0° hue)
    generateVariants(0, 0.85, 0.65),

    // Green (120° hue - forest green, darker and less saturated)
    generateVariants(120, 0.65, 0.50),

    // Blue (210° hue - slightly cyan-shifted for richness)
    generateVariants(210, 0.80, 0.65),

    // Brown (30° hue with low saturation)
    generateVariants(30, 0.65, 0.55),

    // Orange (30° hue with high saturation and moderate brightness)
    generateVariants(30, 0.92, 0.72),

    // Yellow (60° hue)
    generateVariants(60, 0.80, 0.70),

    // Purple (270° hue)
    generateVariants(270, 0.70, 0.65),

    // Cyan (180° hue)
    generateVariants(180, 0.75, 0.65),

    // Pink (330° hue - magenta-ish)
    generateVariants(330, 0.65, 0.60),

    // Teal (165° hue - blue-green, not yellowish)
    generateVariants(165, 0.70, 0.60),

    // Indigo (240° hue - deep blue-purple)
    generateVariants(240, 0.75, 0.55),
};

// NOTE: Game-specific mappings (FactionRelation, Disposition, EnergyLevel) should be defined in game modules
// This library provides the generic color variant system only

// Precomputed commonly used colors (zero runtime cost)
pub const COMMON = struct {
    // Hostile variations - direct Color constants (no variant lookup needed)
    pub const HOSTILE_CALM = COLOR_PALETTES[@intFromEnum(BaseColor.red)][3];
    pub const HOSTILE_NORMAL = COLOR_PALETTES[@intFromEnum(BaseColor.red)][5];
    pub const HOSTILE_AGGRESSIVE = COLOR_PALETTES[@intFromEnum(BaseColor.red)][8];

    // Neutral variations
    pub const NEUTRAL_PASSIVE = COLOR_PALETTES[@intFromEnum(BaseColor.brown)][2];
    pub const NEUTRAL_NORMAL = COLOR_PALETTES[@intFromEnum(BaseColor.brown)][5];
    pub const NEUTRAL_FEARFUL = COLOR_PALETTES[@intFromEnum(BaseColor.brown)][8];

    // Friendly variations
    pub const FRIENDLY_CALM = COLOR_PALETTES[@intFromEnum(BaseColor.blue)][3];
    pub const FRIENDLY_NORMAL = COLOR_PALETTES[@intFromEnum(BaseColor.blue)][5];
    pub const FRIENDLY_EXCITED = COLOR_PALETTES[@intFromEnum(BaseColor.blue)][8];

    // Additional performance shortcuts for hot paths
    pub const DEFAULT_UNIT = NEUTRAL_NORMAL;
    pub const PLAYER_COLOR = COLOR_PALETTES[@intFromEnum(BaseColor.blue)][5];
    pub const PROJECTILE_COLOR = COLOR_PALETTES[@intFromEnum(BaseColor.yellow)][7];
};

// SIMD operations for batch color processing (Anti-Pattern #5 fix)
pub const ColorVec4 = @Vector(4, u8);

// Packed struct for efficient memory layout (Anti-Pattern #1 fix - cache-friendly)
pub const PackedColorData = packed struct {
    base_color: u4, // 11 base colors fit in 4 bits (0-15 range, we use 0-10)
    variant: u4, // 11 variants fit in 4 bits (0-15 range, we use 0-10)

    pub inline fn toColor(self: PackedColorData) Color {
        // Bounds check to ensure safety
        const safe_base = @min(self.base_color, 10);
        const safe_variant = @min(self.variant, 10);
        return COLOR_PALETTES[safe_base][safe_variant];
    }

    pub inline fn fromColorVariant(base: BaseColor, variant: u8) PackedColorData {
        // Ensure values fit in 4 bits and are within valid ranges
        const base_idx = @as(u4, @intFromEnum(base));
        std.debug.assert(base_idx <= 10); // Ensure base color is valid

        return .{
            .base_color = @min(base_idx, 10),
            .variant = @as(u4, @min(variant, 10)),
        };
    }
};

/// Process multiple colors at once using SIMD
pub inline fn applyBrightnessToColors(colors_array: []Color, brightness_factor: f32) void {
    const clamped_factor = @max(0.0, brightness_factor); // Allow values > 1.0 for brightening

    // Process each color's RGBA components with SIMD
    for (colors_array) |*color| {
        // Load color components into vector
        const vec = @Vector(4, f32){
            color.r,
            color.g,
            color.b,
            color.a,
        };

        // SIMD multiply and clamp
        const result = vec * @as(@Vector(4, f32), @splat(clamped_factor));

        // Store back with saturation
        color.r = @min(1.0, result[0]);
        color.g = @min(1.0, result[1]);
        color.b = @min(1.0, result[2]);
        color.a = @min(1.0, result[3]);
    }
}

/// Batch convert multiple entities to colors with specific variants
pub inline fn batchGetColors(base_colors: []const BaseColor, variants: []const u8, out_colors: []Color) void {
    std.debug.assert(base_colors.len == variants.len);
    std.debug.assert(base_colors.len == out_colors.len);

    for (base_colors, variants, out_colors) |base, variant, *out| {
        out.* = base.getVariant(variant);
    }
}

test "color variant generation" {
    // Test that we can get variants
    const red_dark = BaseColor.red.getVariant(0);
    const red_mid = BaseColor.red.getVariant(5);
    const red_bright = BaseColor.red.getVariant(10);

    // Dark should be darker than mid
    try std.testing.expect(color_math.ColorAdvanced.getLuminance(red_dark) < color_math.ColorAdvanced.getLuminance(red_mid));
    // Mid should be darker than bright
    try std.testing.expect(color_math.ColorAdvanced.getLuminance(red_mid) < color_math.ColorAdvanced.getLuminance(red_bright));

    // Test ColorVariant struct
    const fearful_neutral = ColorVariant{ .base = .brown, .variant = 8 };
    const color = fearful_neutral.toColor();
    try std.testing.expect(color.r > 0 or color.g > 0 or color.b > 0); // Not black
}

test "all base colors have valid palettes" {
    // Ensure all 11 base colors have proper palettes
    inline for (std.meta.fields(BaseColor)) |field| {
        const base_color = @as(BaseColor, @enumFromInt(field.value));
        const palette = base_color.getPalette();

        // Check we have 11 variants
        try std.testing.expect(palette.len == 11);

        // Check progression from dark to light
        const dark_lum = color_math.ColorAdvanced.getLuminance(palette[0]);
        const bright_lum = color_math.ColorAdvanced.getLuminance(palette[10]);
        try std.testing.expect(dark_lum < bright_lum);
    }
}

test "variant selection" {
    // Test variant levels
    const base = BaseColor.red;

    // Test lowered energy (variant 3)
    const lowered_color = base.getVariant(3);
    try std.testing.expectEqual(COLOR_PALETTES[@intFromEnum(base)][3], lowered_color);

    // Test normal energy (variant 5)
    const normal_color = base.getVariant(5);
    try std.testing.expectEqual(COLOR_PALETTES[@intFromEnum(base)][5], normal_color);

    // Test raised energy (variant 8)
    const raised_color = base.getVariant(8);
    try std.testing.expectEqual(COLOR_PALETTES[@intFromEnum(base)][8], raised_color);
}

test "SIMD brightness operations" {
    var test_colors = [_]Color{
        Color.fromFloat(100.0 / 255.0, 150.0 / 255.0, 200.0 / 255.0, 1.0),
        Color.fromFloat(50.0 / 255.0, 75.0 / 255.0, 100.0 / 255.0, 1.0),
    };

    // Apply 50% brightness
    applyBrightnessToColors(&test_colors, 0.5);

    // Check results are approximately half (in float 0.0-1.0 range)
    const epsilon = 0.01;
    try std.testing.expect(@abs(test_colors[0].r - (100.0 / 255.0 * 0.5)) < epsilon);
    try std.testing.expect(@abs(test_colors[0].g - (150.0 / 255.0 * 0.5)) < epsilon);
    try std.testing.expect(@abs(test_colors[0].b - (200.0 / 255.0 * 0.5)) < epsilon);

    // Test clamping at max
    test_colors[0] = Color.fromFloat(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0, 1.0);
    applyBrightnessToColors(&test_colors, 2.0); // Should clamp to 1.0

    // After clamping, should be 1.0 (max float value)
    const epsilon2 = 0.01;
    try std.testing.expect(@abs(test_colors[0].r - 1.0) < epsilon2);
    try std.testing.expect(@abs(test_colors[0].g - 1.0) < epsilon2);
    try std.testing.expect(@abs(test_colors[0].b - 1.0) < epsilon2);
}

test "packed color data" {
    // Test packing and unpacking
    const original = ColorVariant{ .base = .blue, .variant = 7 };
    const packed_data = PackedColorData.fromColorVariant(original.base, original.variant);
    const unpacked = packed_data.toColor();

    // Should match the direct lookup
    const expected = BaseColor.blue.getVariant(7);
    try std.testing.expectEqual(expected, unpacked);

    // Test bounds safety
    const overflow_packed = PackedColorData{ .base_color = 15, .variant = 15 };
    const safe_color = overflow_packed.toColor();
    // Should safely clamp to valid ranges
    try std.testing.expectEqual(COLOR_PALETTES[10][10], safe_color);
}
