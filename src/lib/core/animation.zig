const std = @import("std");
const math = @import("../math/mod.zig");
const c = @import("../../platform/sdl.zig");
const Color = @import("../core/colors.zig").Color;

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
        return millisecondsToSeconds(c.sdl.SDL_GetTicks());
    }
};

/// Animation wave functions - delegated to math.waves for consistency
/// TODO: Consider removing this wrapper and using math.WaveGenerator directly
pub const Waves = struct {
    /// Sine wave oscillation between 0.0 and 1.0
    pub fn sine(time: f32, frequency: f32) f32 {
        return math.WaveGenerator.sine(time, frequency);
    }

    /// Cosine wave oscillation between 0.0 and 1.0
    pub fn cosine(time: f32, frequency: f32) f32 {
        return math.WaveGenerator.cosine(time, frequency);
    }

    /// Triangle wave that goes 0->1->0 linearly
    pub fn triangle(time: f32, frequency: f32) f32 {
        return math.WaveGenerator.triangle(time, frequency);
    }

    /// Sawtooth wave that goes 0->1 linearly then jumps back to 0
    pub fn sawtooth(time: f32, frequency: f32) f32 {
        return math.WaveGenerator.sawtooth(time, frequency);
    }

    /// Square wave alternating between 0.0 and 1.0
    pub fn square(time: f32, frequency: f32) f32 {
        return math.WaveGenerator.square(time, frequency, 0.5);
    }

    /// Pulse wave with configurable duty cycle (0.0-1.0)
    pub fn pulse(time: f32, frequency: f32, duty_cycle: f32) f32 {
        return math.WaveGenerator.square(time, frequency, duty_cycle);
    }
};

/// Easing functions for smooth animations
/// Re-exported from math module for convenience
pub const Easing = math.easing.Easing;

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

    /// Apply intensity multiplier to a color - delegated to math.ColorMath
    pub fn applyIntensity(color: Color, intensity: f32) Color {
        return math.ColorMath.applyIntensity(color, intensity);
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

    // Test quadratic ease in
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), Easing.quadraticEaseIn(0.0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), Easing.quadraticEaseIn(0.5), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), Easing.quadraticEaseIn(1.0), 0.01);
}

test "Sequence functionality" {
    // Test ping-pong
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), Sequence.pingPong(0.0, 1.0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), Sequence.pingPong(0.5, 1.0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), Sequence.pingPong(1.0, 1.0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), Sequence.pingPong(1.5, 1.0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), Sequence.pingPong(2.0, 1.0), 0.01);
}
