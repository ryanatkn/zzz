const std = @import("std");
const math = @import("../math/mod.zig");

/// Time utilities for animation systems
pub const Time = struct {
    /// Convert SDL performance counter to seconds
    pub fn ticksToSeconds(ticks: u64, frequency: u64) f32 {
        return @as(f32, @floatFromInt(ticks)) / @as(f32, @floatFromInt(frequency));
    }

    /// Convert SDL_GetTicks() milliseconds to seconds
    pub fn millisecondsToSeconds(ms: u32) f32 {
        return @as(f32, @floatFromInt(ms)) / 1000.0;
    }

    /// Get current time in seconds using SDL_GetTicks
    pub fn getCurrentSeconds() f32 {
        const c = @import("../../platform/sdl.zig");
        return millisecondsToSeconds(c.sdl.SDL_GetTicks());
    }
};

/// Animation wave functions
pub const Waves = struct {
    /// Sine wave oscillation between 0.0 and 1.0
    pub fn sine(time: f32, frequency: f32) f32 {
        return (math.sin(time * frequency) + 1.0) * 0.5;
    }

    /// Cosine wave oscillation between 0.0 and 1.0
    pub fn cosine(time: f32, frequency: f32) f32 {
        return (math.cos(time * frequency) + 1.0) * 0.5;
    }

    /// Triangle wave that goes 0->1->0 linearly
    pub fn triangle(time: f32, frequency: f32) f32 {
        const period = 1.0 / frequency;
        const t = @mod(time, period) / period; // 0 to 1
        return if (t < 0.5) t * 2.0 else 2.0 - (t * 2.0);
    }

    /// Sawtooth wave that goes 0->1 linearly then jumps back to 0
    pub fn sawtooth(time: f32, frequency: f32) f32 {
        const period = 1.0 / frequency;
        return @mod(time, period) / period;
    }

    /// Square wave alternating between 0.0 and 1.0
    pub fn square(time: f32, frequency: f32) f32 {
        return if (sine(time, frequency) >= 0.5) 1.0 else 0.0;
    }

    /// Pulse wave with configurable duty cycle (0.0-1.0)
    pub fn pulse(time: f32, frequency: f32, duty_cycle: f32) f32 {
        const t = @mod(time * frequency, 1.0);
        return if (t < duty_cycle) 1.0 else 0.0;
    }
};

/// Easing functions for smooth animations
pub const Easing = struct {
    /// Linear interpolation (no easing)
    pub fn linear(t: f32) f32 {
        return math.clamp(t, 0.0, 1.0);
    }

    /// Smooth step function (ease in and out)
    pub fn smoothstep(t: f32) f32 {
        const clamped = math.clamp(t, 0.0, 1.0);
        return clamped * clamped * (3.0 - 2.0 * clamped);
    }

    /// Smoother step function (even smoother than smoothstep)
    pub fn smootherstep(t: f32) f32 {
        const clamped = math.clamp(t, 0.0, 1.0);
        return clamped * clamped * clamped * (clamped * (clamped * 6.0 - 15.0) + 10.0);
    }

    /// Ease in quadratic
    pub fn easeInQuad(t: f32) f32 {
        const clamped = math.clamp(t, 0.0, 1.0);
        return clamped * clamped;
    }

    /// Ease out quadratic
    pub fn easeOutQuad(t: f32) f32 {
        const clamped = math.clamp(t, 0.0, 1.0);
        return 1.0 - (1.0 - clamped) * (1.0 - clamped);
    }

    /// Ease in-out quadratic
    pub fn easeInOutQuad(t: f32) f32 {
        const clamped = math.clamp(t, 0.0, 1.0);
        return if (clamped < 0.5)
            2.0 * clamped * clamped
        else
            1.0 - 2.0 * (1.0 - clamped) * (1.0 - clamped);
    }

    /// Elastic ease out (bouncy effect)
    pub fn easeOutElastic(t: f32) f32 {
        const clamped = math.clamp(t, 0.0, 1.0);
        if (clamped == 0.0 or clamped == 1.0) return clamped;

        const c4 = (2.0 * std.math.pi) / 3.0;
        return std.math.pow(f32, 2.0, -10.0 * clamped) * math.sin((clamped * 10.0 - 0.75) * c4) + 1.0;
    }

    /// Bounce ease out
    pub fn easeOutBounce(t: f32) f32 {
        const clamped = math.clamp(t, 0.0, 1.0);
        const n1 = 7.5625;
        const d1 = 2.75;

        if (clamped < 1.0 / d1) {
            return n1 * clamped * clamped;
        } else if (clamped < 2.0 / d1) {
            const t2 = clamped - 1.5 / d1;
            return n1 * t2 * t2 + 0.75;
        } else if (clamped < 2.5 / d1) {
            const t2 = clamped - 2.25 / d1;
            return n1 * t2 * t2 + 0.9375;
        } else {
            const t2 = clamped - 2.625 / d1;
            return n1 * t2 * t2 + 0.984375;
        }
    }
};

/// Animation sequencing utilities
pub const Sequence = struct {
    /// Ping-pong between 0.0 and 1.0 based on time and duration
    pub fn pingPong(time: f32, duration: f32) f32 {
        const cycle_time = @mod(time, duration * 2.0);
        return if (cycle_time < duration)
            cycle_time / duration
        else
            1.0 - (cycle_time - duration) / duration;
    }

    /// Loop a value from 0.0 to 1.0 over the given duration
    pub fn loop(time: f32, duration: f32) f32 {
        return @mod(time, duration) / duration;
    }

    /// One-shot animation that plays once then stays at 1.0
    pub fn oneShot(time: f32, duration: f32) f32 {
        return math.clamp(time / duration, 0.0, 1.0);
    }
};

/// Color animation helpers
pub const ColorAnimation = struct {
    const Color = @import("../core/colors.zig").Color;

    /// Interpolate between two colors with given factor (0.0-1.0)
    pub fn lerp(color1: Color, color2: Color, factor: f32) Color {
        const t = math.clamp(factor, 0.0, 1.0);
        return Color{
            .r = @intFromFloat(@as(f32, @floatFromInt(color1.r)) * (1.0 - t) + @as(f32, @floatFromInt(color2.r)) * t),
            .g = @intFromFloat(@as(f32, @floatFromInt(color1.g)) * (1.0 - t) + @as(f32, @floatFromInt(color2.g)) * t),
            .b = @intFromFloat(@as(f32, @floatFromInt(color1.b)) * (1.0 - t) + @as(f32, @floatFromInt(color2.b)) * t),
            .a = @intFromFloat(@as(f32, @floatFromInt(color1.a)) * (1.0 - t) + @as(f32, @floatFromInt(color2.a)) * t),
        };
    }

    /// Apply intensity multiplier to a color
    pub fn applyIntensity(color: Color, intensity: f32) Color {
        const clamped = math.clamp(intensity, 0.0, 1.0);
        return Color{
            .r = @intFromFloat(@as(f32, @floatFromInt(color.r)) * clamped),
            .g = @intFromFloat(@as(f32, @floatFromInt(color.g)) * clamped),
            .b = @intFromFloat(@as(f32, @floatFromInt(color.b)) * clamped),
            .a = color.a, // Keep alpha unchanged
        };
    }
};

test "Waves functionality" {
    // Test sine wave at key points
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), Waves.sine(0.0, 1.0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), Waves.sine(std.math.pi / 2.0, 1.0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), Waves.sine(std.math.pi, 1.0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), Waves.sine(3.0 * std.math.pi / 2.0, 1.0), 0.01);
}

test "Easing functionality" {
    // Test linear
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), Easing.linear(0.0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), Easing.linear(0.5), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), Easing.linear(1.0), 0.01);

    // Test smoothstep
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), Easing.smoothstep(0.0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), Easing.smoothstep(0.5), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), Easing.smoothstep(1.0), 0.01);
}

test "Sequence functionality" {
    // Test ping-pong
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), Sequence.pingPong(0.0, 1.0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), Sequence.pingPong(0.5, 1.0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), Sequence.pingPong(1.0, 1.0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), Sequence.pingPong(1.5, 1.0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), Sequence.pingPong(2.0, 1.0), 0.01);
}
