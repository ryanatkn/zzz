const std = @import("std");
const interpolation = @import("interpolation.zig");

/// Small focused module for Bézier curve mathematics
/// Provides pure mathematical functions for curve evaluation and tessellation
/// Independent of font-specific types - works with any 2D points
/// Generic 2D point for curve calculations
/// Callers can convert their specific point types to/from this
pub const CurvePoint = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) CurvePoint {
        return .{ .x = x, .y = y };
    }
};

/// Configuration for curve tessellation
pub const TessellationConfig = struct {
    /// Fixed tessellation - uniform subdivision
    fixed_steps: u32 = 8,

    /// Adaptive tessellation parameters
    min_segments: u32 = 2,
    max_segments: u32 = 16,
    curvature_threshold: f32 = 2.0,

    /// Use adaptive (true) or fixed (false) tessellation
    use_adaptive: bool = true,
};

pub const DEFAULT_CONFIG = TessellationConfig{};

/// Evaluate a quadratic Bézier curve at parameter t
/// Formula: (1-t)²P₀ + 2(1-t)tP₁ + t²P₂
pub inline fn evaluateQuadraticBezier(start: CurvePoint, control: CurvePoint, end: CurvePoint, t: f32) CurvePoint {
    const t2 = t * t;
    const one_minus_t = 1.0 - t;
    const one_minus_t2 = one_minus_t * one_minus_t;

    return CurvePoint{
        .x = one_minus_t2 * start.x + 2.0 * one_minus_t * t * control.x + t2 * end.x,
        .y = one_minus_t2 * start.y + 2.0 * one_minus_t * t * control.y + t2 * end.y,
    };
}

/// Evaluate a cubic Bézier curve at parameter t
/// Formula: (1-t)³P₀ + 3(1-t)²tP₁ + 3(1-t)t²P₂ + t³P₃
pub inline fn evaluateCubicBezier(p0: CurvePoint, p1: CurvePoint, p2: CurvePoint, p3: CurvePoint, t: f32) CurvePoint {
    const t2 = t * t;
    const t3 = t2 * t;
    const one_minus_t = 1.0 - t;
    const one_minus_t2 = one_minus_t * one_minus_t;
    const one_minus_t3 = one_minus_t2 * one_minus_t;

    return CurvePoint{
        .x = one_minus_t3 * p0.x + 3.0 * one_minus_t2 * t * p1.x + 3.0 * one_minus_t * t2 * p2.x + t3 * p3.x,
        .y = one_minus_t3 * p0.y + 3.0 * one_minus_t2 * t * p1.y + 3.0 * one_minus_t * t2 * p2.y + t3 * p3.y,
    };
}

/// Calculate the distance from a point to a line segment
/// Used for adaptive tessellation and SDF calculations
pub fn distanceToSegment(point: CurvePoint, line_start: CurvePoint, line_end: CurvePoint) f32 {
    const dx = line_end.x - line_start.x;
    const dy = line_end.y - line_start.y;

    // If line segment has zero length, return distance to point
    const length_sq = dx * dx + dy * dy;
    if (length_sq < 0.0001) {
        const px = point.x - line_start.x;
        const py = point.y - line_start.y;
        return @sqrt(px * px + py * py);
    }

    // Calculate projection parameter
    const px = point.x - line_start.x;
    const py = point.y - line_start.y;
    const dot = px * dx + py * dy;
    const t = std.math.clamp(dot / length_sq, 0.0, 1.0);

    // Find closest point on segment
    const closest_x = line_start.x + t * dx;
    const closest_y = line_start.y + t * dy;

    // Return distance to closest point
    const dist_x = point.x - closest_x;
    const dist_y = point.y - closest_y;
    return @sqrt(dist_x * dist_x + dist_y * dist_y);
}

/// Estimate optimal number of segments for a quadratic curve based on curvature
pub fn estimateQuadraticSegments(start: CurvePoint, control: CurvePoint, end: CurvePoint, config: TessellationConfig) u32 {
    if (!config.use_adaptive) {
        return config.fixed_steps;
    }

    // Calculate curve deviation from straight line
    const dx1 = control.x - start.x;
    const dy1 = control.y - start.y;
    const dx2 = end.x - control.x;
    const dy2 = end.y - control.y;

    const line_length_sq = (end.x - start.x) * (end.x - start.x) + (end.y - start.y) * (end.y - start.y);
    const line_length = @sqrt(line_length_sq + 0.001);
    const deviation = @abs(dx1 * dy2 - dy1 * dx2) / line_length;

    const segments = @as(u32, @intFromFloat(deviation / config.curvature_threshold + @as(f32, @floatFromInt(config.min_segments))));
    return @max(config.min_segments, @min(config.max_segments, segments));
}

/// Tessellate a quadratic Bézier curve into line segments
/// Returns array of points along the curve (including endpoints)
pub fn tessellateQuadraticBezier(allocator: std.mem.Allocator, start: CurvePoint, control: CurvePoint, end: CurvePoint, config: TessellationConfig) ![]CurvePoint {
    const num_segments = estimateQuadraticSegments(start, control, end, config);
    var points = try std.ArrayList(CurvePoint).initCapacity(allocator, num_segments + 1);

    // Add start point
    try points.append(start);

    // Add intermediate points
    for (1..num_segments) |i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(num_segments));
        try points.append(evaluateQuadraticBezier(start, control, end, t));
    }

    // Add end point
    try points.append(end);

    return points.toOwnedSlice();
}

/// Calculate the curvature of a quadratic Bézier at parameter t
/// Returns 0 for straight lines, higher values for sharper curves
pub fn quadraticCurvature(start: CurvePoint, control: CurvePoint, end: CurvePoint, t: f32) f32 {
    // First derivative (velocity)
    const dx_dt = 2.0 * (1.0 - t) * (control.x - start.x) + 2.0 * t * (end.x - control.x);
    const dy_dt = 2.0 * (1.0 - t) * (control.y - start.y) + 2.0 * t * (end.y - control.y);

    // Second derivative (acceleration)
    const d2x_dt2 = 2.0 * (end.x - 2.0 * control.x + start.x);
    const d2y_dt2 = 2.0 * (end.y - 2.0 * control.y + start.y);

    // Curvature formula: |v × a| / |v|³
    const cross = dx_dt * d2y_dt2 - dy_dt * d2x_dt2;
    const speed = @sqrt(dx_dt * dx_dt + dy_dt * dy_dt);

    if (speed < 0.0001) return 0.0;
    return @abs(cross) / (speed * speed * speed);
}

/// Check if three points are approximately collinear
/// Useful for optimizing straight segments
pub fn areCollinear(p1: CurvePoint, p2: CurvePoint, p3: CurvePoint, epsilon: f32) bool {
    // Calculate cross product
    const dx1 = p2.x - p1.x;
    const dy1 = p2.y - p1.y;
    const dx2 = p3.x - p1.x;
    const dy2 = p3.y - p1.y;

    const cross = @abs(dx1 * dy2 - dy1 * dx2);
    return cross < epsilon;
}

test "evaluateQuadraticBezier" {
    const testing = std.testing;

    const start = CurvePoint.init(0.0, 0.0);
    const control = CurvePoint.init(50.0, 100.0);
    const end = CurvePoint.init(100.0, 0.0);

    // Test at endpoints
    const p0 = evaluateQuadraticBezier(start, control, end, 0.0);
    try testing.expectApproxEqAbs(@as(f32, 0.0), p0.x, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0.0), p0.y, 0.001);

    const p1 = evaluateQuadraticBezier(start, control, end, 1.0);
    try testing.expectApproxEqAbs(@as(f32, 100.0), p1.x, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 0.0), p1.y, 0.001);

    // Test at midpoint
    const p_mid = evaluateQuadraticBezier(start, control, end, 0.5);
    try testing.expectApproxEqAbs(@as(f32, 50.0), p_mid.x, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 50.0), p_mid.y, 0.001);
}

test "distanceToSegment" {
    const testing = std.testing;

    const line_start = CurvePoint.init(0.0, 0.0);
    const line_end = CurvePoint.init(10.0, 0.0);

    // Point on the line
    const point_on = CurvePoint.init(5.0, 0.0);
    try testing.expectApproxEqAbs(@as(f32, 0.0), distanceToSegment(point_on, line_start, line_end), 0.001);

    // Point perpendicular to line
    const point_perp = CurvePoint.init(5.0, 3.0);
    try testing.expectApproxEqAbs(@as(f32, 3.0), distanceToSegment(point_perp, line_start, line_end), 0.001);
}

test "tessellateQuadraticBezier" {
    const testing = std.testing;
    const allocator = std.testing.allocator;

    const start = CurvePoint.init(0.0, 0.0);
    const control = CurvePoint.init(50.0, 100.0);
    const end = CurvePoint.init(100.0, 0.0);

    const config = TessellationConfig{ .use_adaptive = false, .fixed_steps = 4 };
    const points = try tessellateQuadraticBezier(allocator, start, control, end, config);
    defer allocator.free(points);

    // Should have start + intermediate + end points
    try testing.expectEqual(@as(usize, 5), points.len);

    // First and last points should match input
    try testing.expectApproxEqAbs(@as(f32, 0.0), points[0].x, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 100.0), points[4].x, 0.001);
}

test "areCollinear" {
    const testing = std.testing;

    // Three points in a line
    const p1 = CurvePoint.init(0.0, 0.0);
    const p2 = CurvePoint.init(5.0, 5.0);
    const p3 = CurvePoint.init(10.0, 10.0);

    try testing.expect(areCollinear(p1, p2, p3, 0.1));

    // Three points not in a line
    const p4 = CurvePoint.init(5.0, 6.0); // Slightly off the line
    try testing.expect(!areCollinear(p1, p2, p4, 0.1));
}

// TODO see if these should/can be the only way to do things
// Performance-optimized versions for hot paths that already have compatible types
// These avoid CurvePoint conversions when the caller has Vec2 types

/// High-performance quadratic Bézier evaluation for Vec2 types (used by vector/path.zig)
pub inline fn evaluateQuadraticBezierVec2(start_x: f32, start_y: f32, control_x: f32, control_y: f32, end_x: f32, end_y: f32, t: f32) struct { x: f32, y: f32 } {
    const t2 = t * t;
    const one_minus_t = 1.0 - t;
    const one_minus_t2 = one_minus_t * one_minus_t;

    return .{
        .x = one_minus_t2 * start_x + 2.0 * one_minus_t * t * control_x + t2 * end_x,
        .y = one_minus_t2 * start_y + 2.0 * one_minus_t * t * control_y + t2 * end_y,
    };
}

/// High-performance cubic Bézier evaluation for Vec2 types (used by vector/path.zig)
pub inline fn evaluateCubicBezierVec2(start_x: f32, start_y: f32, control1_x: f32, control1_y: f32, control2_x: f32, control2_y: f32, end_x: f32, end_y: f32, t: f32) struct { x: f32, y: f32 } {
    const t2 = t * t;
    const t3 = t2 * t;
    const one_minus_t = 1.0 - t;
    const one_minus_t2 = one_minus_t * one_minus_t;
    const one_minus_t3 = one_minus_t2 * one_minus_t;

    return .{
        .x = one_minus_t3 * start_x + 3.0 * one_minus_t2 * t * control1_x + 3.0 * one_minus_t * t2 * control2_x + t3 * end_x,
        .y = one_minus_t3 * start_y + 3.0 * one_minus_t2 * t * control1_y + 3.0 * one_minus_t * t2 * control2_y + t3 * end_y,
    };
}
