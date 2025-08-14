const std = @import("std");

const types = @import("types.zig");

const Vec2 = types.Vec2;

// Scalar math utilities
pub fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

// Vec2 math functions with consistent vec2_ prefix (idiomatic C-style naming)
pub fn vec2_length(v: Vec2) f32 {
    return @sqrt(v.x * v.x + v.y * v.y);
}

pub fn vec2_lengthSquared(v: Vec2) f32 {
    return v.x * v.x + v.y * v.y;
}

pub fn vec2_normalize(v: Vec2) Vec2 {
    const len = vec2_length(v);
    if (len > 0) {
        return Vec2{ .x = v.x / len, .y = v.y / len };
    }
    return Vec2{ .x = 0, .y = 0 };
}

pub fn vec2_add(a: Vec2, b: Vec2) Vec2 {
    return Vec2{ .x = a.x + b.x, .y = a.y + b.y };
}

pub fn vec2_subtract(a: Vec2, b: Vec2) Vec2 {
    return Vec2{ .x = a.x - b.x, .y = a.y - b.y };
}

pub fn vec2_multiply(v: Vec2, scalar: f32) Vec2 {
    return Vec2{ .x = v.x * scalar, .y = v.y * scalar };
}

pub fn vec2_divide(v: Vec2, scalar: f32) Vec2 {
    return Vec2{ .x = v.x / scalar, .y = v.y / scalar };
}

pub fn vec2_dot(a: Vec2, b: Vec2) f32 {
    return a.x * b.x + a.y * b.y;
}

pub fn vec2_lerp(a: Vec2, b: Vec2, t: f32) Vec2 {
    return Vec2{
        .x = lerp(a.x, b.x, t),
        .y = lerp(a.y, b.y, t),
    };
}

pub fn vec2_direction(from: Vec2, to: Vec2) Vec2 {
    return vec2_normalize(vec2_subtract(to, from));
}

pub fn vec2_isZero(v: Vec2) bool {
    return v.x == 0.0 and v.y == 0.0;
}

pub fn vec2_isEqual(a: Vec2, b: Vec2, tolerance: f32) bool {
    const diff = vec2_subtract(a, b);
    return vec2_lengthSquared(diff) <= tolerance * tolerance;
}

pub fn vec2_clamp(v: Vec2, min: Vec2, max: Vec2) Vec2 {
    return Vec2{
        .x = std.math.clamp(v.x, min.x, max.x),
        .y = std.math.clamp(v.y, min.y, max.y),
    };
}

pub fn vec2_angleTo(from: Vec2, to: Vec2) f32 {
    const diff = vec2_subtract(to, from);
    return std.math.atan2(diff.y, diff.x);
}

pub fn vec2_rotate(v: Vec2, angle: f32) Vec2 {
    const cos_a = @cos(angle);
    const sin_a = @sin(angle);
    return Vec2{
        .x = v.x * cos_a - v.y * sin_a,
        .y = v.x * sin_a + v.y * cos_a,
    };
}

pub fn vec2_reflect(v: Vec2, normal: Vec2) Vec2 {
    const normal_normalized = vec2_normalize(normal);
    const dot_product = vec2_dot(v, normal_normalized);
    return vec2_subtract(v, vec2_multiply(normal_normalized, 2.0 * dot_product));
}

pub fn vec2_project(a: Vec2, b: Vec2) Vec2 {
    const b_normalized = vec2_normalize(b);
    const dot_product = vec2_dot(a, b_normalized);
    return vec2_multiply(b_normalized, dot_product);
}

pub fn vec2_perpendicular(v: Vec2) Vec2 {
    return Vec2{ .x = -v.y, .y = v.x };
}

pub fn vec2_moveTowards(from: Vec2, to: Vec2, max_distance: f32) Vec2 {
    const diff = vec2_subtract(to, from);
    const dist = vec2_length(diff);
    if (dist <= max_distance) {
        return to;
    }
    return vec2_add(from, vec2_multiply(vec2_normalize(diff), max_distance));
}

pub fn vec2_smoothDamp(current: Vec2, target: Vec2, smooth_time: f32, delta_time: f32) Vec2 {
    const omega = 2.0 / smooth_time;
    const x = omega * delta_time;
    const exp = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x);
    const change = vec2_subtract(current, target);
    return vec2_add(target, vec2_multiply(change, exp));
}

// Distance functions (used so frequently they deserve concise names)
pub fn distance(a: Vec2, b: Vec2) f32 {
    return vec2_length(vec2_subtract(a, b));
}

pub fn distanceSquared(a: Vec2, b: Vec2) f32 {
    return vec2_lengthSquared(vec2_subtract(a, b));
}

// Boundary and containment checks
pub fn vec2_isWithinCircle(point: Vec2, center: Vec2, radius: f32) bool {
    return distanceSquared(point, center) <= radius * radius;
}

pub fn vec2_isWithinRect(point: Vec2, rect_pos: Vec2, rect_size: Vec2) bool {
    return point.x >= rect_pos.x and point.x <= rect_pos.x + rect_size.x and
        point.y >= rect_pos.y and point.y <= rect_pos.y + rect_size.y;
}

pub fn vec2_clampToCircle(point: Vec2, center: Vec2, radius: f32) Vec2 {
    const dir = vec2_subtract(point, center);
    const dist = vec2_length(dir);
    if (dist <= radius) {
        return point;
    }
    return vec2_add(center, vec2_multiply(vec2_normalize(dir), radius));
}

pub fn vec2_clampToRect(point: Vec2, rect_pos: Vec2, rect_size: Vec2) Vec2 {
    return Vec2{
        .x = std.math.clamp(point.x, rect_pos.x, rect_pos.x + rect_size.x),
        .y = std.math.clamp(point.y, rect_pos.y, rect_pos.y + rect_size.y),
    };
}

// Coordinate system transformations
pub fn vec2_worldToScreen(world_pos: Vec2, camera_pos: Vec2, camera_scale: f32, screen_center: Vec2) Vec2 {
    const relative_pos = vec2_subtract(world_pos, camera_pos);
    const scaled_pos = vec2_multiply(relative_pos, camera_scale);
    return vec2_add(screen_center, scaled_pos);
}

pub fn vec2_screenToWorld(screen_pos: Vec2, camera_pos: Vec2, camera_scale: f32, screen_center: Vec2) Vec2 {
    const relative_pos = vec2_subtract(screen_pos, screen_center);
    const unscaled_pos = vec2_divide(relative_pos, camera_scale);
    return vec2_add(camera_pos, unscaled_pos);
}
