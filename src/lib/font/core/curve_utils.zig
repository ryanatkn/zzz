// Shared curve tessellation utilities for font rendering strategies
// Provides unified Bézier curve handling for vertex, bitmap, and SDF rendering

const std = @import("std");
const interpolation = @import("../../math/interpolation.zig");
const curves = @import("../../math/curves.zig");
const core_types = @import("types.zig");

const Point = core_types.Point;
const Contour = core_types.Contour;

/// Configuration for curve tessellation quality
pub const TessellationConfig = struct {
    // Fixed tessellation - simple uniform subdivision
    fixed_steps: u32 = 8,

    // Adaptive tessellation - based on curve curvature
    min_segments: u32 = 2,
    max_segments: u32 = 16,
    curvature_threshold: f32 = 2.0,

    // Whether to use adaptive or fixed tessellation
    use_adaptive: bool = true,
};

/// Default tessellation configuration
pub const DEFAULT_CONFIG = TessellationConfig{};

/// Tessellate a contour, converting Bézier curves to line segments
/// This function unifies the tessellation logic used by both rasterizer and triangulator
pub fn tessellateContour(allocator: std.mem.Allocator, contour: Contour, config: TessellationConfig) ![]Point {
    var tessellated = std.ArrayList(Point).init(allocator);
    defer tessellated.deinit();

    if (contour.points.len < 2) {
        return tessellated.toOwnedSlice();
    }

    var i: usize = 0;
    while (i < contour.points.len) {
        const current = contour.points[i];
        const next_i = (i + 1) % contour.points.len;
        const next = contour.points[next_i];

        try tessellated.append(current);

        // If current point is on-curve and next is off-curve, we have a curve segment
        if (current.on_curve and !next.on_curve) {
            // Look for the end point of the curve
            const end_i = (i + 2) % contour.points.len;
            var end_point = contour.points[end_i];

            // If end point is also off-curve, create implied on-curve point
            if (!end_point.on_curve and i + 2 < contour.points.len) {
                const next_next = contour.points[end_i];
                end_point = Point{
                    .x = (next.x + next_next.x) / 2.0,
                    .y = (next.y + next_next.y) / 2.0,
                    .on_curve = true,
                };
            } else if (!end_point.on_curve) {
                // Wrap around - use first point
                end_point = contour.points[0];
            }

            // Tessellate the quadratic Bézier curve
            if (config.use_adaptive) {
                try interpolateBezierCurveAdaptive(current, next, end_point, &tessellated, config);
            } else {
                try interpolateBezierCurveFixed(current, next, end_point, &tessellated, config.fixed_steps);
            }

            // Skip the control point and move to end point
            i = end_i;
        } else {
            i += 1;
        }
    }

    return tessellated.toOwnedSlice();
}

/// Fixed subdivision of quadratic Bézier curve
/// Uses consistent number of segments - good for predictable tessellation
pub fn interpolateBezierCurveFixed(start: Point, control: Point, end: Point, output: *std.ArrayList(Point), steps: u32) !void {
    // Convert to generic curve points
    const curve_start = curves.CurvePoint.init(start.x, start.y);
    const curve_control = curves.CurvePoint.init(control.x, control.y);
    const curve_end = curves.CurvePoint.init(end.x, end.y);

    // Generate points along the curve (skip t=0 since start point is already added)
    var step: u32 = 1;
    while (step <= steps) : (step += 1) {
        const t = @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(steps));
        const curve_point = curves.evaluateQuadraticBezier(curve_start, curve_control, curve_end, t);
        const point = Point{
            .x = curve_point.x,
            .y = curve_point.y,
            .on_curve = true,
        };
        try output.append(point);
    }
}

/// Adaptive subdivision of quadratic Bézier curve
/// Uses curve curvature to determine number of segments - better quality for varying curves
pub fn interpolateBezierCurveAdaptive(start: Point, control: Point, end: Point, output: *std.ArrayList(Point), config: TessellationConfig) !void {
    // Convert to generic curve points
    const curve_start = curves.CurvePoint.init(start.x, start.y);
    const curve_control = curves.CurvePoint.init(control.x, control.y);
    const curve_end = curves.CurvePoint.init(end.x, end.y);

    // Use centralized curve configuration
    const curve_config = curves.TessellationConfig{
        .fixed_steps = config.fixed_steps,
        .min_segments = config.min_segments,
        .max_segments = config.max_segments,
        .curvature_threshold = config.curvature_threshold,
        .use_adaptive = config.use_adaptive,
    };

    // Estimate segments using centralized algorithm
    const num_segments = curves.estimateQuadraticSegments(curve_start, curve_control, curve_end, curve_config);

    // Generate points along the curve using centralized evaluation
    for (1..num_segments) |i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(num_segments));
        const curve_point = curves.evaluateQuadraticBezier(curve_start, curve_control, curve_end, t);

        try output.append(Point{
            .x = curve_point.x,
            .y = curve_point.y,
            .on_curve = true, // All interpolated points are on the curve
        });
    }
}

/// Unified curve interpolation interface
/// Automatically chooses between adaptive and fixed based on configuration
pub fn interpolateContour(allocator: std.mem.Allocator, contour: Contour, config: TessellationConfig) ![]Point {
    return tessellateContour(allocator, contour, config);
}

/// Estimate the number of segments needed for a curve with given curvature
pub fn estimateSegments(start: Point, control: Point, end: Point, config: TessellationConfig) u32 {
    // Convert to generic curve points
    const curve_start = curves.CurvePoint.init(start.x, start.y);
    const curve_control = curves.CurvePoint.init(control.x, control.y);
    const curve_end = curves.CurvePoint.init(end.x, end.y);

    // Use centralized curve configuration
    const curve_config = curves.TessellationConfig{
        .fixed_steps = config.fixed_steps,
        .min_segments = config.min_segments,
        .max_segments = config.max_segments,
        .curvature_threshold = config.curvature_threshold,
        .use_adaptive = config.use_adaptive,
    };

    // Use centralized estimation algorithm
    return curves.estimateQuadraticSegments(curve_start, curve_control, curve_end, curve_config);
}

test "tessellateContour basic functionality" {
    var allocator = std.testing.allocator;

    // Create a simple contour with a quadratic curve
    const points = [_]Point{
        Point.init(0.0, 0.0, true), // start
        Point.init(50.0, 100.0, false), // control
        Point.init(100.0, 0.0, true), // end
    };

    const contour = Contour{
        .points = @constCast(&points),
        .closed = true,
    };

    const config = TessellationConfig{ .use_adaptive = false, .fixed_steps = 4 };
    const tessellated = try tessellateContour(allocator, contour, config);
    defer allocator.free(tessellated);

    // Should have original points + tessellated curve points
    try std.testing.expect(tessellated.len > 3);

    // First point should be the start point
    try std.testing.expectEqual(@as(f32, 0.0), tessellated[0].x);
    try std.testing.expectEqual(@as(f32, 0.0), tessellated[0].y);
}

test "interpolateBezierCurveFixed" {
    const allocator = std.testing.allocator;
    var output = std.ArrayList(Point).init(allocator);
    defer output.deinit();

    const start = Point.init(0.0, 0.0, true);
    const control = Point.init(50.0, 100.0, false);
    const end = Point.init(100.0, 0.0, true);

    try interpolateBezierCurveFixed(start, control, end, &output, 4);

    // Should have 4 interpolated points
    try std.testing.expectEqual(@as(usize, 4), output.items.len);

    // All points should be on curve
    for (output.items) |point| {
        try std.testing.expectEqual(true, point.on_curve);
    }
}

test "estimateSegments" {
    const start = Point.init(0.0, 0.0, true);
    const control = Point.init(50.0, 100.0, false); // Sharp curve
    const end = Point.init(100.0, 0.0, true);

    const config = TessellationConfig{};
    const segments = estimateSegments(start, control, end, config);

    // Should require multiple segments for this curve
    try std.testing.expect(segments >= config.min_segments);
    try std.testing.expect(segments <= config.max_segments);
}
