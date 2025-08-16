const std = @import("std");

/// Linear interpolation between two scalar values
pub fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

/// Clamp value to range
pub fn clamp(value: f32, min_val: f32, max_val: f32) f32 {
    return std.math.clamp(value, min_val, max_val);
}

/// Check if two values are approximately equal
pub fn equals(a: f32, b: f32, tolerance: f32) bool {
    return @abs(a - b) <= tolerance;
}

/// Smooth damp a value towards target
pub fn smoothDamp(current: f32, target: f32, smooth_time: f32, delta_time: f32) f32 {
    const omega = 2.0 / smooth_time;
    const x = omega * delta_time;
    const exp = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x);
    const change = current - target;
    return target + change * exp;
}

/// Move value towards target by max distance
pub fn moveTowards(current: f32, target: f32, max_distance: f32) f32 {
    const diff = target - current;
    if (@abs(diff) <= max_distance) {
        return target;
    }
    return current + std.math.sign(diff) * max_distance;
}

/// Wrap angle to [-π, π] range
pub fn wrapAngle(angle: f32) f32 {
    const two_pi = 2.0 * std.math.pi;
    var wrapped = @mod(angle + std.math.pi, two_pi);
    if (wrapped < 0) wrapped += two_pi;
    return wrapped - std.math.pi;
}

/// Calculate shortest angular distance between two angles
pub fn angleDifference(from: f32, to: f32) f32 {
    return wrapAngle(to - from);
}

/// Lerp between angles (shortest path)
pub fn lerpAngle(from: f32, to: f32, t: f32) f32 {
    return from + angleDifference(from, to) * t;
}

/// Step function: returns 0.0 if x < edge, otherwise 1.0
pub fn step(edge: f32, x: f32) f32 {
    return if (x < edge) 0.0 else 1.0;
}

/// Smooth step function (S-curve between 0 and 1)
pub fn smoothstep(edge0: f32, edge1: f32, x: f32) f32 {
    const t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

/// Saturate (clamp to 0-1 range)
pub fn saturate(x: f32) f32 {
    return clamp(x, 0.0, 1.0);
}

/// Mix/blend two values by factor
pub fn mix(a: f32, b: f32, factor: f32) f32 {
    return lerp(a, b, factor);
}

/// Sign function: -1 for negative, 0 for zero, 1 for positive
pub fn sign(x: f32) f32 {
    if (x > 0.0) return 1.0;
    if (x < 0.0) return -1.0;
    return 0.0;
}

/// Remap value from one range to another
pub fn remap(value: f32, from_min: f32, from_max: f32, to_min: f32, to_max: f32) f32 {
    const t = (value - from_min) / (from_max - from_min);
    return lerp(to_min, to_max, t);
}

/// Safe division that returns 0 if denominator is 0
pub fn safeDivide(numerator: f32, denominator: f32) f32 {
    return if (@abs(denominator) < std.math.floatEps(f32)) 0.0 else numerator / denominator;
}

/// Convert float to int with bounds checking
pub fn floatToIntSafe(value: f32, comptime T: type) T {
    const max_val = @as(f32, @floatFromInt(std.math.maxInt(T)));
    const min_val = @as(f32, @floatFromInt(std.math.minInt(T)));
    const clamped = clamp(value, min_val, max_val);
    return @intFromFloat(clamped);
}

/// Convert degrees to radians
pub fn degreesToRadians(degrees: f32) f32 {
    return degrees * std.math.pi / 180.0;
}

/// Convert radians to degrees
pub fn radiansToDegrees(radians: f32) f32 {
    return radians * 180.0 / std.math.pi;
}

test "scalar math operations" {
    // Test lerp
    try std.testing.expect(equals(lerp(0.0, 10.0, 0.5), 5.0, 0.001));

    // Test clamp
    try std.testing.expect(clamp(-5.0, 0.0, 10.0) == 0.0);
    try std.testing.expect(clamp(15.0, 0.0, 10.0) == 10.0);
    try std.testing.expect(clamp(5.0, 0.0, 10.0) == 5.0);

    // Test equals
    try std.testing.expect(equals(1.0, 1.001, 0.01));
    try std.testing.expect(!equals(1.0, 1.1, 0.01));
    
    // Test step
    try std.testing.expect(step(0.5, 0.3) == 0.0);
    try std.testing.expect(step(0.5, 0.7) == 1.0);
    try std.testing.expect(step(0.5, 0.5) == 1.0);
    
    // Test saturate
    try std.testing.expect(saturate(-0.5) == 0.0);
    try std.testing.expect(saturate(0.5) == 0.5);
    try std.testing.expect(saturate(1.5) == 1.0);
    
    // Test smoothstep
    try std.testing.expect(smoothstep(0.0, 1.0, 0.0) == 0.0);
    try std.testing.expect(smoothstep(0.0, 1.0, 1.0) == 1.0);
    try std.testing.expect(equals(smoothstep(0.0, 1.0, 0.5), 0.5, 0.001));
    
    // Test remap
    try std.testing.expect(equals(remap(5.0, 0.0, 10.0, 0.0, 100.0), 50.0, 0.001));
    
    // Test angle conversions
    try std.testing.expect(equals(degreesToRadians(180.0), std.math.pi, 0.001));
    try std.testing.expect(equals(radiansToDegrees(std.math.pi), 180.0, 0.001));
}
