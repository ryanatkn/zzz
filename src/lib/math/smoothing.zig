const std = @import("std");
const scalar = @import("scalar.zig");
const Vec2 = @import("vec2.zig").Vec2;

/// Smoothing and filtering utilities for numerical stabilization
pub const SmoothingUtils = struct {
    /// Simple exponential moving average for scalar values
    pub fn exponentialSmooth(current_value: f32, new_value: f32, smoothing_factor: f32) f32 {
        const alpha = scalar.clamp(smoothing_factor, 0.0, 1.0);
        return current_value * (1.0 - alpha) + new_value * alpha;
    }

    /// Exponential smoothing for Vec2 values
    pub fn exponentialSmoothVec2(current: Vec2, new_value: Vec2, smoothing_factor: f32) Vec2 {
        return Vec2{
            .x = exponentialSmooth(current.x, new_value.x, smoothing_factor),
            .y = exponentialSmooth(current.y, new_value.y, smoothing_factor),
        };
    }

    /// Running average with fixed window size
    pub fn RunningAverage(comptime T: type, comptime window_size: usize) type {
        return struct {
            const Self = @This();

            values: [window_size]T,
            index: usize = 0,
            count: usize = 0,
            sum: T = switch (T) {
                f32 => 0.0,
                Vec2 => Vec2.zero(),
                else => @compileError("Unsupported type for RunningAverage"),
            },

            pub fn init() Self {
                return Self{
                    .values = std.mem.zeroes([window_size]T),
                };
            }

            pub fn addValue(self: *Self, value: T) void {
                if (self.count < window_size) {
                    self.sum = switch (T) {
                        f32 => self.sum + value,
                        Vec2 => self.sum.add(value),
                        else => unreachable,
                    };
                    self.count += 1;
                } else {
                    const old_value = self.values[self.index];
                    self.sum = switch (T) {
                        f32 => self.sum - old_value + value,
                        Vec2 => self.sum.sub(old_value).add(value),
                        else => unreachable,
                    };
                }

                self.values[self.index] = value;
                self.index = (self.index + 1) % window_size;
            }

            pub fn getAverage(self: *const Self) T {
                if (self.count == 0) {
                    return switch (T) {
                        f32 => 0.0,
                        Vec2 => Vec2.zero(),
                        else => unreachable,
                    };
                }

                const count_f32 = @as(f32, @floatFromInt(self.count));
                return switch (T) {
                    f32 => self.sum / count_f32,
                    Vec2 => Vec2{ .x = self.sum.x / count_f32, .y = self.sum.y / count_f32 },
                    else => unreachable,
                };
            }

            pub fn isFull(self: *const Self) bool {
                return self.count >= window_size;
            }
        };
    }

    /// Low-pass filter for reducing noise
    pub fn lowPassFilter(current_value: f32, new_value: f32, cutoff_frequency: f32, delta_time: f32) f32 {
        if (delta_time <= 0.0) return current_value;

        const rc = 1.0 / (2.0 * std.math.pi * cutoff_frequency);
        const alpha = delta_time / (rc + delta_time);
        return current_value + alpha * (new_value - current_value);
    }

    /// Low-pass filter for Vec2 values
    pub fn lowPassFilterVec2(current: Vec2, new_value: Vec2, cutoff_frequency: f32, delta_time: f32) Vec2 {
        return Vec2{
            .x = lowPassFilter(current.x, new_value.x, cutoff_frequency, delta_time),
            .y = lowPassFilter(current.y, new_value.y, cutoff_frequency, delta_time),
        };
    }

    /// Simple moving median filter (useful for outlier rejection)
    pub fn MedianFilter(comptime window_size: usize) type {
        return struct {
            const Self = @This();

            values: [window_size]f32,
            index: usize = 0,
            count: usize = 0,

            pub fn init() Self {
                return Self{
                    .values = std.mem.zeroes([window_size]f32),
                };
            }

            pub fn addValue(self: *Self, value: f32) void {
                self.values[self.index] = value;
                self.index = (self.index + 1) % window_size;
                if (self.count < window_size) {
                    self.count += 1;
                }
            }

            pub fn getMedian(self: *const Self) f32 {
                if (self.count == 0) return 0.0;

                var sorted_values: [window_size]f32 = undefined;
                for (0..self.count) |i| {
                    sorted_values[i] = self.values[i];
                }

                // Simple insertion sort for small arrays
                for (1..self.count) |i| {
                    const key = sorted_values[i];
                    var j = i;
                    while (j > 0 and sorted_values[j - 1] > key) {
                        sorted_values[j] = sorted_values[j - 1];
                        j -= 1;
                    }
                    sorted_values[j] = key;
                }

                const mid = self.count / 2;
                if (self.count % 2 == 0) {
                    return (sorted_values[mid - 1] + sorted_values[mid]) * 0.5;
                } else {
                    return sorted_values[mid];
                }
            }
        };
    }

    /// Smooth step function (ease-in/ease-out) - delegated to scalar module
    pub fn smoothStep(edge0: f32, edge1: f32, x: f32) f32 {
        return scalar.smoothstep(edge0, edge1, x);
    }

    /// Smoother step function (more gradual than smoothStep)
    pub fn smootherStep(edge0: f32, edge1: f32, x: f32) f32 {
        const t = scalar.clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
        return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
    }

    /// Simple velocity-based smoothing for position tracking
    pub fn velocitySmooth(current_pos: Vec2, target_pos: Vec2, current_velocity: *Vec2, max_speed: f32, smoothing: f32, delta_time: f32) Vec2 {
        const to_target = target_pos.sub(current_pos);
        const desired_velocity = to_target.scale(smoothing);

        // Clamp to max speed
        const desired_speed = desired_velocity.length();
        const clamped_velocity = if (desired_speed > max_speed)
            desired_velocity.scale(max_speed / desired_speed)
        else
            desired_velocity;

        // Smooth the velocity change
        current_velocity.* = exponentialSmoothVec2(current_velocity.*, clamped_velocity, 0.1);

        return current_pos.add(current_velocity.scale(delta_time));
    }
};

test "exponential smoothing" {
    // Test scalar smoothing
    const current: f32 = 0.0;
    const new_value: f32 = 1.0;
    const smoothed = SmoothingUtils.exponentialSmooth(current, new_value, 0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), smoothed, 0.001);

    // Test Vec2 smoothing
    const current_vec = Vec2{ .x = 0.0, .y = 0.0 };
    const new_vec = Vec2{ .x = 2.0, .y = 4.0 };
    const smoothed_vec = SmoothingUtils.exponentialSmoothVec2(current_vec, new_vec, 0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), smoothed_vec.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), smoothed_vec.y, 0.001);
}

test "running average" {
    var avg = SmoothingUtils.RunningAverage(f32, 3).init();

    avg.addValue(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), avg.getAverage(), 0.001);

    avg.addValue(2.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), avg.getAverage(), 0.001);

    avg.addValue(3.0);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), avg.getAverage(), 0.001);

    // Should now start replacing oldest values
    avg.addValue(6.0);
    try std.testing.expectApproxEqAbs(@as(f32, 3.667), avg.getAverage(), 0.01); // (2+3+6)/3
}

test "median filter" {
    var filter = SmoothingUtils.MedianFilter(5).init();

    filter.addValue(1.0);
    filter.addValue(5.0);
    filter.addValue(3.0);
    filter.addValue(7.0);
    filter.addValue(2.0);

    const median = filter.getMedian();
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), median, 0.001);
}

test "smooth step functions" {
    // Test smoothStep
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), SmoothingUtils.smoothStep(0.0, 1.0, 0.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), SmoothingUtils.smoothStep(0.0, 1.0, 1.0), 0.001);

    const mid = SmoothingUtils.smoothStep(0.0, 1.0, 0.5);
    try std.testing.expect(mid > 0.4 and mid < 0.6); // Should be smooth, not linear

    // Test smootherStep
    const smoother_mid = SmoothingUtils.smootherStep(0.0, 1.0, 0.5);
    try std.testing.expect(smoother_mid > 0.4 and smoother_mid < 0.6);
}
