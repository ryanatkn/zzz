const std = @import("std");
const scalar = @import("scalar.zig");

/// Wave generation utilities for animations, effects, and procedural content
pub const WaveGenerator = struct {
    /// Generate sine wave value normalized to 0.0-1.0 range
    pub fn sine(time: f32, frequency: f32) f32 {
        return (std.math.sin(time * frequency) + 1.0) * 0.5;
    }

    /// Generate cosine wave value normalized to 0.0-1.0 range
    pub fn cosine(time: f32, frequency: f32) f32 {
        return (std.math.cos(time * frequency) + 1.0) * 0.5;
    }

    /// Generate pulse wave (oscillating 0.0-1.0)
    pub fn pulse(time: f32, frequency: f32) f32 {
        return sine(time, frequency);
    }

    /// Generate sawtooth wave (linear ramp 0.0-1.0)
    pub fn sawtooth(time: f32, frequency: f32) f32 {
        const cycle_time = time * frequency;
        return @mod(cycle_time, 1.0);
    }

    /// Generate triangle wave (symmetric ramp 0.0-1.0-0.0)
    pub fn triangle(time: f32, frequency: f32) f32 {
        const cycle_time = time * frequency;
        const phase = @mod(cycle_time, 1.0);
        return if (phase < 0.5) phase * 2.0 else 2.0 - phase * 2.0;
    }

    /// Generate square wave (step function 0.0/1.0)
    pub fn square(time: f32, frequency: f32, duty_cycle: f32) f32 {
        const phase = @mod(time * frequency, 1.0);
        return if (phase < scalar.clamp(duty_cycle, 0.0, 1.0)) 1.0 else 0.0;
    }

    /// Generate noise-like oscillation (pseudo-random based on sine)
    pub fn noise(time: f32, frequency: f32, seed: f32) f32 {
        const phase = time * frequency + seed;
        return (std.math.sin(phase * 12.9898) * std.math.sin(phase * 78.233) + 1.0) * 0.5;
    }
};

/// Animation-specific timing functions
pub const AnimationWaves = struct {
    /// Calculate animation pulse from milliseconds (commonly used in UI)
    pub fn calculatePulse(frequency: f32, time_ms: f32) f32 {
        const time_sec = time_ms / 1000.0;
        return WaveGenerator.pulse(time_sec, frequency);
    }

    /// Calculate color cycle animation from milliseconds
    pub fn calculateColorCycle(frequency: f32, time_ms: f32) f32 {
        const time_sec = time_ms / 1000.0;
        return WaveGenerator.sine(time_sec, frequency);
    }

    /// Breathing animation (slower, smooth pulse)
    pub fn breathe(time_ms: f32, cycle_duration_sec: f32) f32 {
        const frequency = 1.0 / cycle_duration_sec;
        return calculatePulse(frequency, time_ms);
    }

    /// Pulsing animation with custom amplitude and baseline
    pub fn pulseWithRange(time_ms: f32, frequency: f32, baseline: f32, amplitude: f32) f32 {
        const pulse = calculatePulse(frequency, time_ms);
        return baseline + pulse * amplitude;
    }

    /// Smooth step animation (ease in/out effect) - delegated to scalar module
    pub fn smoothStep(time_ms: f32, duration_ms: f32) f32 {
        return scalar.smoothstep(0.0, duration_ms, time_ms);
    }
};

/// Wave utilities for procedural content and effects
pub const WaveUtils = struct {
    /// Combine multiple waves with different frequencies and amplitudes
    pub fn combineSines(time: f32, frequencies: []const f32, amplitudes: []const f32) f32 {
        var result: f32 = 0.0;
        var total_amplitude: f32 = 0.0;

        const count = @min(frequencies.len, amplitudes.len);
        for (0..count) |i| {
            result += WaveGenerator.sine(time, frequencies[i]) * amplitudes[i];
            total_amplitude += amplitudes[i];
        }

        return if (total_amplitude > 0.0) result / total_amplitude else 0.0;
    }

    /// Generate perlin-like noise using multiple octaves
    pub fn multiOctaveNoise(time: f32, base_frequency: f32, octaves: u32, persistence: f32, seed: f32) f32 {
        var result: f32 = 0.0;
        var amplitude: f32 = 1.0;
        var frequency: f32 = base_frequency;
        var max_amplitude: f32 = 0.0;

        for (0..octaves) |_| {
            result += WaveGenerator.noise(time, frequency, seed) * amplitude;
            max_amplitude += amplitude;
            amplitude *= persistence;
            frequency *= 2.0;
        }

        return if (max_amplitude > 0.0) result / max_amplitude else 0.0;
    }

    /// Create wave with custom phase offset
    pub fn phaseOffset(time: f32, frequency: f32, phase_offset: f32, wave_fn: fn (f32, f32) f32) f32 {
        return wave_fn(time + phase_offset, frequency);
    }
};

test "wave generation" {
    // Test basic wave functions
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), WaveGenerator.sine(0.0, 1.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), WaveGenerator.cosine(0.0, 1.0), 0.001);

    // Test range is 0.0 to 1.0
    const sine_quarter = WaveGenerator.sine(std.math.pi / 2.0, 1.0);
    try std.testing.expect(sine_quarter > 0.99 and sine_quarter <= 1.0);

    // Test sawtooth ramp
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), WaveGenerator.sawtooth(0.0, 1.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), WaveGenerator.sawtooth(0.5, 1.0), 0.001);
}

test "animation waves" {
    // Test millisecond conversion
    const pulse_1sec = AnimationWaves.calculatePulse(1.0, 1000.0); // 1Hz at 1 second
    try std.testing.expect(pulse_1sec >= 0.0 and pulse_1sec <= 1.0);

    // Test smooth step
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), AnimationWaves.smoothStep(0.0, 1000.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), AnimationWaves.smoothStep(1000.0, 1000.0), 0.001);

    // Test pulse with range
    const pulse_range = AnimationWaves.pulseWithRange(0.0, 1.0, 0.5, 0.3);
    try std.testing.expect(pulse_range >= 0.2 and pulse_range <= 0.8); // baseline ± amplitude
}

test "wave utilities" {
    // Test wave combination
    const frequencies = [_]f32{ 1.0, 2.0 };
    const amplitudes = [_]f32{ 1.0, 0.5 };
    const combined = WaveUtils.combineSines(0.0, &frequencies, &amplitudes);
    try std.testing.expect(combined >= 0.0 and combined <= 1.0);

    // Test multi-octave noise
    const noise = WaveUtils.multiOctaveNoise(0.0, 1.0, 3, 0.5, 42.0);
    try std.testing.expect(noise >= 0.0 and noise <= 1.0);
}
