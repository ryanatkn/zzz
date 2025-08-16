const std = @import("std");
const math = std.math;
const Vec2 = @import("vec2.zig").Vec2;
const colors = @import("../core/colors.zig");
const easing = @import("easing.zig");

const Color = colors.Color;

/// Linear interpolation between two Vec2 points
pub fn lerpVec2(a: Vec2, b: Vec2, t: f32) Vec2 {
    return Vec2{
        .x = a.x + (b.x - a.x) * t,
        .y = a.y + (b.y - a.y) * t,
    };
}

/// Interpolate between two colors
pub fn lerpColor(a: Color, b: Color, t: f32) Color {
    const clamped_t = @max(0.0, @min(1.0, t));
    
    return Color{
        .r = @intFromFloat(@as(f32, @floatFromInt(a.r)) + (@as(f32, @floatFromInt(b.r)) - @as(f32, @floatFromInt(a.r))) * clamped_t),
        .g = @intFromFloat(@as(f32, @floatFromInt(a.g)) + (@as(f32, @floatFromInt(b.g)) - @as(f32, @floatFromInt(a.g))) * clamped_t),
        .b = @intFromFloat(@as(f32, @floatFromInt(a.b)) + (@as(f32, @floatFromInt(b.b)) - @as(f32, @floatFromInt(a.b))) * clamped_t),
        .a = @intFromFloat(@as(f32, @floatFromInt(a.a)) + (@as(f32, @floatFromInt(b.a)) - @as(f32, @floatFromInt(a.a))) * clamped_t),
    };
}

/// Interpolate between colors using floating point RGB values
pub fn lerpColorF32(a: struct { r: f32, g: f32, b: f32 }, b: struct { r: f32, g: f32, b: f32 }, t: f32) struct { r: f32, g: f32, b: f32 } {
    const clamped_t = @max(0.0, @min(1.0, t));
    
    return .{
        .r = a.r + (b.r - a.r) * clamped_t,
        .g = a.g + (b.g - a.g) * clamped_t,
        .b = a.b + (b.b - a.b) * clamped_t,
    };
}

/// Smoothstep interpolation between two values
pub fn smoothstep(a: f32, b: f32, t: f32) f32 {
    const clamped_t = @max(0.0, @min(1.0, t));
    const smooth_t = clamped_t * clamped_t * (3.0 - 2.0 * clamped_t);
    return a + (b - a) * smooth_t;
}

/// Smootherstep interpolation (more gradual than smoothstep)
pub fn smootherstep(a: f32, b: f32, t: f32) f32 {
    const clamped_t = @max(0.0, @min(1.0, t));
    const smooth_t = clamped_t * clamped_t * clamped_t * (clamped_t * (clamped_t * 6.0 - 15.0) + 10.0);
    return a + (b - a) * smooth_t;
}

/// Inverse interpolation - find t value for a given value between a and b
pub fn inverseLerp(a: f32, b: f32, value: f32) f32 {
    if (@abs(b - a) < std.math.floatEps(f32)) return 0.0;
    return (value - a) / (b - a);
}

/// Bezier interpolation for 3 control points (quadratic)
pub fn bezierQuadratic(p0: f32, p1: f32, p2: f32, t: f32) f32 {
    const clamped_t = @max(0.0, @min(1.0, t));
    const inv_t = 1.0 - clamped_t;
    return inv_t * inv_t * p0 + 2.0 * inv_t * clamped_t * p1 + clamped_t * clamped_t * p2;
}

/// Bezier interpolation for 4 control points (cubic)
pub fn bezierCubic(p0: f32, p1: f32, p2: f32, p3: f32, t: f32) f32 {
    const clamped_t = @max(0.0, @min(1.0, t));
    const inv_t = 1.0 - clamped_t;
    const inv_t2 = inv_t * inv_t;
    const inv_t3 = inv_t2 * inv_t;
    const t2 = clamped_t * clamped_t;
    const t3 = t2 * clamped_t;
    
    return inv_t3 * p0 + 3.0 * inv_t2 * clamped_t * p1 + 3.0 * inv_t * t2 * p2 + t3 * p3;
}

/// Bezier interpolation for Vec2 points (quadratic)
pub fn bezierQuadraticVec2(p0: Vec2, p1: Vec2, p2: Vec2, t: f32) Vec2 {
    return Vec2{
        .x = bezierQuadratic(p0.x, p1.x, p2.x, t),
        .y = bezierQuadratic(p0.y, p1.y, p2.y, t),
    };
}

/// Bezier interpolation for Vec2 points (cubic)
pub fn bezierCubicVec2(p0: Vec2, p1: Vec2, p2: Vec2, p3: Vec2, t: f32) Vec2 {
    return Vec2{
        .x = bezierCubic(p0.x, p1.x, p2.x, p3.x, t),
        .y = bezierCubic(p0.y, p1.y, p2.y, p3.y, t),
    };
}

/// Catmull-Rom spline interpolation (smooth curve through points)
pub fn catmullRom(p0: f32, p1: f32, p2: f32, p3: f32, t: f32) f32 {
    const clamped_t = @max(0.0, @min(1.0, t));
    const t2 = clamped_t * clamped_t;
    const t3 = t2 * clamped_t;
    
    return 0.5 * (
        2.0 * p1 +
        (-p0 + p2) * clamped_t +
        (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
        (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
    );
}

/// Hermite interpolation with tangents
pub fn hermite(p0: f32, p1: f32, t0: f32, t1: f32, t: f32) f32 {
    const clamped_t = @max(0.0, @min(1.0, t));
    const t2 = clamped_t * clamped_t;
    const t3 = t2 * clamped_t;
    
    const h00 = 2.0 * t3 - 3.0 * t2 + 1.0;
    const h10 = t3 - 2.0 * t2 + clamped_t;
    const h01 = -2.0 * t3 + 3.0 * t2;
    const h11 = t3 - t2;
    
    return h00 * p0 + h10 * t0 + h01 * p1 + h11 * t1;
}

/// Multi-step interpolation with easing
pub fn easedLerp(a: f32, b: f32, t: f32, easing_fn: easing.EasingFunction) f32 {
    const eased_t = easing_fn(t);
    return a + (b - a) * eased_t;
}

/// Multi-step Vec2 interpolation with easing
pub fn easedLerpVec2(a: Vec2, b: Vec2, t: f32, easing_fn: easing.EasingFunction) Vec2 {
    const eased_t = easing_fn(t);
    return lerpVec2(a, b, eased_t);
}

/// Multi-step color interpolation with easing
pub fn easedLerpColor(a: Color, b: Color, t: f32, easing_fn: easing.EasingFunction) Color {
    const eased_t = easing_fn(t);
    return lerpColor(a, b, eased_t);
}

/// Bounce interpolation (spring effect)
pub fn bounceInterp(a: f32, b: f32, t: f32, bounce_strength: f32) f32 {
    const clamped_t = @max(0.0, @min(1.0, t));
    const bounce = math.sin(clamped_t * math.pi * bounce_strength) * (1.0 - clamped_t);
    const base_lerp = a + (b - a) * clamped_t;
    return base_lerp + bounce * (b - a) * 0.1;
}

/// Oscillate between two values
pub fn oscillate(a: f32, b: f32, t: f32, frequency: f32) f32 {
    const wave = math.sin(t * frequency * 2.0 * math.pi);
    return a + (b - a) * (wave + 1.0) * 0.5;
}

/// Ping-pong interpolation (goes from a to b, then back to a)
pub fn pingPong(a: f32, b: f32, t: f32) f32 {
    const ping_t = 1.0 - @abs(2.0 * @mod(t, 1.0) - 1.0);
    return a + (b - a) * ping_t;
}

/// Stepped interpolation (discretize t into steps)
pub fn steppedLerp(a: f32, b: f32, t: f32, steps: u32) f32 {
    if (steps == 0) return a;
    const step_t = @floor(t * @as(f32, @floatFromInt(steps))) / @as(f32, @floatFromInt(steps));
    return a + (b - a) * step_t;
}

test "interpolation functions" {
    // Test basic lerp
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), lerpVec2(Vec2{.x = 0.0, .y = 0.0}, Vec2{.x = 10.0, .y = 10.0}, 0.5).x, 0.001);
    
    // Test color interpolation
    const red = Color{.r = 255, .g = 0, .b = 0, .a = 255};
    const blue = Color{.r = 0, .g = 0, .b = 255, .a = 255};
    const purple = lerpColor(red, blue, 0.5);
    try std.testing.expect(purple.r == 127 or purple.r == 128); // Allow for rounding
    try std.testing.expect(purple.b == 127 or purple.b == 128);
    
    // Test smoothstep
    const smooth_mid = smoothstep(0.0, 10.0, 0.5);
    try std.testing.expect(smooth_mid > 4.0 and smooth_mid < 6.0); // Should be around 5 but smoother
    
    // Test inverse lerp
    const t = inverseLerp(0.0, 10.0, 3.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), t, 0.001);
    
    // Test ping pong
    const ping1 = pingPong(0.0, 10.0, 0.25); // Should be at 5.0 (going up)
    const ping2 = pingPong(0.0, 10.0, 0.75); // Should be at 5.0 (going down)
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), ping1, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), ping2, 0.001);
}

test "bezier interpolation" {
    // Test quadratic bezier - at t=0.5, should be weighted towards p1
    const bezier_result = bezierQuadratic(0.0, 10.0, 0.0, 0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), bezier_result, 0.001);
    
    // Test cubic bezier endpoints
    const cubic_start = bezierCubic(0.0, 3.0, 7.0, 10.0, 0.0);
    const cubic_end = bezierCubic(0.0, 3.0, 7.0, 10.0, 1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), cubic_start, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), cubic_end, 0.001);
}

test "eased interpolation" {
    // Test eased lerp with linear (should be same as regular lerp)
    const linear_result = easedLerp(0.0, 10.0, 0.5, easing.Easing.linear);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), linear_result, 0.001);
    
    // Test that ease-in gives different result than linear
    const ease_in_result = easedLerp(0.0, 10.0, 0.5, easing.Easing.quadraticEaseIn);
    try std.testing.expect(ease_in_result < 5.0); // Should be less than halfway due to ease-in
}