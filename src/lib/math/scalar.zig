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
}