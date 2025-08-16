const std = @import("std");
const math = std.math;
const colors = @import("../core/colors.zig");
const easing = @import("../math/easing.zig");

const Color = colors.Color;

/// Configuration for animated border rendering
pub const BorderConfig = struct {
    max_layers: usize = 8,
    screen_width: f32 = 1920.0,
    screen_height: f32 = 1080.0,
    visibility_threshold: f32 = 0.5,
};

/// Color pair for border animations
pub const BorderColorPair = struct {
    dark: struct { r: f32, g: f32, b: f32 },
    bright: struct { r: f32, g: f32, b: f32 },
};

/// Pre-defined color pairs for common border themes
pub const ColorPairs = struct {
    pub const GOLD_YELLOW = BorderColorPair{
        .dark = .{ .r = 200.0, .g = 150.0, .b = 10.0 },
        .bright = .{ .r = 255.0, .g = 240.0, .b = 0.0 },
    };

    pub const RED = BorderColorPair{
        .dark = .{ .r = 180.0, .g = 40.0, .b = 40.0 },
        .bright = .{ .r = 255.0, .g = 30.0, .b = 30.0 },
    };

    pub const GREEN = BorderColorPair{
        .dark = .{ .r = 20.0, .g = 160.0, .b = 20.0 },
        .bright = .{ .r = 50.0, .g = 220.0, .b = 80.0 },
    };

    pub const BLUE = BorderColorPair{
        .dark = .{ .r = 0.0, .g = 60.0, .b = 120.0 },
        .bright = .{ .r = 0.0, .g = 100.0, .b = 200.0 },
    };

    pub const PURPLE = BorderColorPair{
        .dark = .{ .r = 120.0, .g = 40.0, .b = 120.0 },
        .bright = .{ .r = 200.0, .g = 80.0, .b = 200.0 },
    };
};

/// Animation timing functions for borders
pub const BorderAnimation = struct {
    /// Calculate animation pulse using sine wave
    pub fn calculatePulse(frequency: f32, time_ms: f32) f32 {
        const time_sec = time_ms / 1000.0;
        return (math.sin(time_sec * frequency) + 1.0) * 0.5;
    }

    /// Calculate color cycle animation
    pub fn calculateColorCycle(frequency: f32, time_ms: f32) f32 {
        const time_sec = time_ms / 1000.0;
        return (math.sin(time_sec * frequency) + 1.0) * 0.5;
    }

    /// Interpolate between two colors using a factor t (0.0 to 1.0)
    pub fn interpolateColor(color_pair: BorderColorPair, t: f32, intensity: f32) Color {
        const clamped_t = @max(0.0, @min(1.0, t));
        const clamped_intensity = @max(0.0, @min(1.0, intensity));
        
        return Color{
            .r = @intFromFloat((color_pair.dark.r + (color_pair.bright.r - color_pair.dark.r) * clamped_t) * clamped_intensity),
            .g = @intFromFloat((color_pair.dark.g + (color_pair.bright.g - color_pair.dark.g) * clamped_t) * clamped_intensity),
            .b = @intFromFloat((color_pair.dark.b + (color_pair.bright.b - color_pair.dark.b) * clamped_t) * clamped_intensity),
            .a = 255,
        };
    }

    /// Create animated color from color pair with automatic timing
    pub fn getAnimatedColor(color_pair: BorderColorPair, pulse_freq: f32, color_freq: f32, time_ms: f32) Color {
        const pulse = calculatePulse(pulse_freq, time_ms);
        const hue_cycle = calculateColorCycle(color_freq, time_ms);
        const intensity = 0.7 + pulse * 0.3; // Base intensity + pulse variation
        
        return interpolateColor(color_pair, hue_cycle, intensity);
    }
};

/// Border specification for rendering
pub const BorderSpec = struct {
    base_width: f32,
    base_color: Color,
    color_pair: ?BorderColorPair = null,
    pulse_freq: ?f32 = null,
    pulse_amplitude: f32 = 0.0,
    color_freq: f32 = 4.0, // Default color cycling frequency

    /// Get current animated width
    pub fn getCurrentWidth(self: *const BorderSpec, time_ms: f32) f32 {
        if (self.pulse_freq) |freq| {
            const pulse = BorderAnimation.calculatePulse(freq, time_ms);
            return self.base_width + pulse * self.pulse_amplitude;
        }
        return self.base_width;
    }

    /// Get maximum possible width (base + amplitude)
    pub fn getMaxWidth(self: *const BorderSpec) f32 {
        return self.base_width + self.pulse_amplitude;
    }

    /// Get current animated color
    pub fn getCurrentColor(self: *const BorderSpec, time_ms: f32) Color {
        if (self.color_pair) |color_pair| {
            const effective_pulse_freq = self.pulse_freq orelse 4.0;
            return BorderAnimation.getAnimatedColor(color_pair, effective_pulse_freq, self.color_freq, time_ms);
        }
        return self.base_color;
    }

    /// Create static border spec
    pub fn static(width: f32, color: Color) BorderSpec {
        return BorderSpec{
            .base_width = width,
            .base_color = color,
        };
    }

    /// Create animated border spec
    pub fn animated(base_width: f32, color_pair: BorderColorPair, pulse_freq: f32, pulse_amplitude: f32) BorderSpec {
        const base_color = Color{
            .r = @intFromFloat(color_pair.dark.r),
            .g = @intFromFloat(color_pair.dark.g),
            .b = @intFromFloat(color_pair.dark.b),
            .a = 255,
        };
        
        return BorderSpec{
            .base_width = base_width,
            .base_color = base_color,
            .color_pair = color_pair,
            .pulse_freq = pulse_freq,
            .pulse_amplitude = pulse_amplitude,
        };
    }
};

/// Border rectangle for rendering
pub const BorderRect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

/// Border stack for managing multiple layered borders
pub fn BorderStack(comptime max_layers: usize) type {
    return struct {
        const Self = @This();
        
        specs: [max_layers]BorderSpec = undefined,
        count: usize = 0,
        config: BorderConfig,

        pub fn init(config: BorderConfig) Self {
            return Self{
                .config = config,
            };
        }

        pub fn clear(self: *Self) void {
            self.count = 0;
        }

        /// Add a border to the stack
        pub fn push(self: *Self, border_spec: BorderSpec) void {
            if (self.count < max_layers) {
                self.specs[self.count] = border_spec;
                self.count += 1;
            }
        }

        /// Add a static border
        pub fn pushStatic(self: *Self, width: f32, color: Color) void {
            self.push(BorderSpec.static(width, color));
        }

        /// Add an animated border
        pub fn pushAnimated(self: *Self, base_width: f32, color_pair: BorderColorPair, pulse_freq: f32, pulse_amplitude: f32) void {
            self.push(BorderSpec.animated(base_width, color_pair, pulse_freq, pulse_amplitude));
        }

        /// Calculate border rectangles for a given width and offset
        pub fn calculateBorderRects(self: *const Self, width: f32, offset: f32) [4]BorderRect {
            const inner_x = offset;
            const inner_y = offset;
            const inner_width = self.config.screen_width - (offset * 2);
            const inner_height = self.config.screen_height - (offset * 2);

            return [4]BorderRect{
                // Top
                BorderRect{ .x = inner_x, .y = inner_y, .w = inner_width, .h = width },
                // Bottom
                BorderRect{ .x = inner_x, .y = inner_y + inner_height - width, .w = inner_width, .h = width },
                // Left
                BorderRect{ .x = inner_x, .y = inner_y + width, .w = width, .h = inner_height - (width * 2) },
                // Right
                BorderRect{ .x = inner_x + inner_width - width, .y = inner_y + width, .w = width, .h = inner_height - (width * 2) },
            };
        }

        /// Render all borders using a callback function
        pub fn render(self: *const Self, time_ms: f32, drawBorderFn: fn(Color, f32, f32) void) void {
            var current_offset: f32 = 0;

            for (0..self.count) |i| {
                const spec = &self.specs[i];
                const current_width = spec.getCurrentWidth(time_ms);
                const current_color = spec.getCurrentColor(time_ms);

                if (current_width > self.config.visibility_threshold) {
                    drawBorderFn(current_color, current_width, current_offset);
                    current_offset += current_width;
                }
            }
        }

        /// Get total maximum width of all borders
        pub fn getMaxTotalWidth(self: *const Self) f32 {
            var total: f32 = 0;
            for (0..self.count) |i| {
                total += self.specs[i].getMaxWidth();
            }
            return total;
        }
    };
}

// Re-export easing functions for convenience
pub const Easing = easing.Easing;

/// Iris wipe effect for dramatic transitions
pub const IrisWipe = struct {
    colors: []const Color,
    band_width: f32,
    duration: f32,
    easing_fn: easing.EasingFunction = Easing.quarticEaseOut,

    /// Calculate iris wipe borders for current time
    pub fn getBorders(self: *const IrisWipe, elapsed_time: f32, border_stack: anytype) void {
        if (elapsed_time >= self.duration) return;

        const progress = elapsed_time / self.duration;
        const eased_progress = self.easing_fn(progress);
        const shrink_factor = 1.0 - eased_progress;

        for (self.colors) |color| {
            const current_width = self.band_width * shrink_factor;
            if (current_width > border_stack.config.visibility_threshold) {
                border_stack.pushStatic(current_width, color);
            }
        }
    }
};

test "border animation" {
    // Test pulse calculation
    const pulse = BorderAnimation.calculatePulse(1.0, 1000.0); // 1Hz at 1 second
    try std.testing.expect(pulse >= 0.0 and pulse <= 1.0);

    // Test color interpolation
    const color_pair = ColorPairs.RED;
    const color = BorderAnimation.interpolateColor(color_pair, 0.5, 1.0);
    try std.testing.expect(color.a == 255);
}

test "border stack" {
    const config = BorderConfig{};
    var stack = BorderStack(4).init(config);
    
    // Test adding borders
    stack.pushStatic(10.0, colors.WHITE);
    stack.pushAnimated(5.0, ColorPairs.GOLD_YELLOW, 1.0, 2.0);
    
    try std.testing.expect(stack.count == 2);
    
    // Test max width calculation
    const max_width = stack.getMaxTotalWidth();
    try std.testing.expect(max_width == 17.0); // 10 + (5 + 2)
}

test "easing functions" {
    // Test edge cases
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), Easing.quarticEaseOut(0.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), Easing.quarticEaseOut(1.0), 0.001);
    
    // Test smooth progression
    const mid = Easing.sineEaseInOut(0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), mid, 0.001);
}