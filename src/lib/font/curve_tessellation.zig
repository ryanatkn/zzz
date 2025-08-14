const std = @import("std");
const types = @import("../types.zig");
const maths = @import("../maths.zig");
const vector_path = @import("../vector/path.zig");

const Vec2 = types.Vec2;
const QuadraticCurve = vector_path.QuadraticCurve;
const CubicCurve = vector_path.CubicCurve;

/// Configuration for tessellation quality vs performance
pub const TessellationConfig = struct {
    /// Maximum number of segments per curve (prevents infinite subdivision)
    max_segments: u32 = 64,

    /// Minimum number of segments per curve (ensures minimum quality)
    min_segments: u32 = 2,

    /// Maximum distance from true curve (in pixels) for adaptive tessellation
    tolerance: f32 = 0.5,

    /// Angle threshold for adaptive tessellation (in radians)
    angle_tolerance: f32 = 0.1,

    /// Whether to use adaptive tessellation or fixed step size
    adaptive: bool = true,
};

/// A line segment resulting from tessellation
pub const TessellatedSegment = struct {
    start: Vec2,
    end: Vec2,

    /// Parameter range this segment covers on the original curve
    t_start: f32,
    t_end: f32,
};

/// Result of tessellating a curve
pub const TessellationResult = struct {
    segments: std.ArrayList(TessellatedSegment),

    pub fn deinit(self: *TessellationResult) void {
        self.segments.deinit();
    }
};

/// Tessellate a quadratic bezier curve into line segments
pub fn tessellateQuadratic(
    allocator: std.mem.Allocator,
    curve: QuadraticCurve,
    config: TessellationConfig,
) !TessellationResult {
    var result = TessellationResult{
        .segments = std.ArrayList(TessellatedSegment).init(allocator),
    };

    if (config.adaptive) {
        try tessellateQuadraticAdaptive(curve, &result.segments, config, 0.0, 1.0, 0);
    } else {
        try tessellateQuadraticFixed(curve, &result.segments, config);
    }

    return result;
}

/// Tessellate a cubic bezier curve into line segments
pub fn tessellrateCubic(
    allocator: std.mem.Allocator,
    curve: CubicCurve,
    config: TessellationConfig,
) !TessellationResult {
    var result = TessellationResult{
        .segments = std.ArrayList(TessellatedSegment).init(allocator),
    };

    if (config.adaptive) {
        try tessellrateCubicAdaptive(curve, &result.segments, config, 0.0, 1.0, 0);
    } else {
        try tessellrateCubicFixed(curve, &result.segments, config);
    }

    return result;
}

/// Fixed step tessellation for quadratic curves
fn tessellateQuadraticFixed(
    curve: QuadraticCurve,
    segments: *std.ArrayList(TessellatedSegment),
    config: TessellationConfig,
) !void {
    const num_segments = calculateFixedSegments(curve.length(), config);
    const step = 1.0 / @as(f32, @floatFromInt(num_segments));

    var t: f32 = 0;
    while (t < 1.0 - step * 0.5) {
        const next_t = @min(t + step, 1.0);

        try segments.append(TessellatedSegment{
            .start = curve.evaluate(t),
            .end = curve.evaluate(next_t),
            .t_start = t,
            .t_end = next_t,
        });

        t = next_t;
    }
}

/// Fixed step tessellation for cubic curves
fn tessellrateCubicFixed(
    curve: CubicCurve,
    segments: *std.ArrayList(TessellatedSegment),
    config: TessellationConfig,
) !void {
    const num_segments = calculateFixedSegments(curve.length(), config);
    const step = 1.0 / @as(f32, @floatFromInt(num_segments));

    var t: f32 = 0;
    while (t < 1.0 - step * 0.5) {
        const next_t = @min(t + step, 1.0);

        try segments.append(TessellatedSegment{
            .start = curve.evaluate(t),
            .end = curve.evaluate(next_t),
            .t_start = t,
            .t_end = next_t,
        });

        t = next_t;
    }
}

/// Calculate number of segments for fixed tessellation based on curve length
/// Enhanced with better adaptive segment calculation
fn calculateFixedSegments(curve_length: f32, config: TessellationConfig) u32 {
    // Use tolerance-based calculation for better quality
    // More segments for tighter tolerance
    const segments_per_unit = 1.0 / @max(0.1, config.tolerance);
    const segments_from_length = @as(u32, @intFromFloat(@ceil(curve_length * segments_per_unit / 2.0)));

    // For very short curves, ensure minimum quality
    const min_for_length = if (curve_length < 2.0) 4 else config.min_segments;

    return @min(@max(segments_from_length, min_for_length), config.max_segments);
}

/// Adaptive tessellation for quadratic curves using recursive subdivision
fn tessellateQuadraticAdaptive(
    curve: QuadraticCurve,
    segments: *std.ArrayList(TessellatedSegment),
    config: TessellationConfig,
    t_start: f32,
    t_end: f32,
    depth: u32,
) !void {
    // Prevent infinite recursion
    if (depth > 10 or segments.items.len >= config.max_segments) {
        try segments.append(TessellatedSegment{
            .start = curve.evaluate(t_start),
            .end = curve.evaluate(t_end),
            .t_start = t_start,
            .t_end = t_end,
        });
        return;
    }

    const start_point = curve.evaluate(t_start);
    const end_point = curve.evaluate(t_end);
    const mid_t = (t_start + t_end) * 0.5;
    const mid_point = curve.evaluate(mid_t);

    // Check if the curve segment is flat enough
    if (isFlatEnough(start_point, mid_point, end_point, config.tolerance)) {
        try segments.append(TessellatedSegment{
            .start = start_point,
            .end = end_point,
            .t_start = t_start,
            .t_end = t_end,
        });
    } else {
        // Subdivide the curve
        try tessellateQuadraticAdaptive(curve, segments, config, t_start, mid_t, depth + 1);
        try tessellateQuadraticAdaptive(curve, segments, config, mid_t, t_end, depth + 1);
    }
}

/// Adaptive tessellation for cubic curves using recursive subdivision
fn tessellrateCubicAdaptive(
    curve: CubicCurve,
    segments: *std.ArrayList(TessellatedSegment),
    config: TessellationConfig,
    t_start: f32,
    t_end: f32,
    depth: u32,
) !void {
    // Prevent infinite recursion
    if (depth > 10 or segments.items.len >= config.max_segments) {
        try segments.append(TessellatedSegment{
            .start = curve.evaluate(t_start),
            .end = curve.evaluate(t_end),
            .t_start = t_start,
            .t_end = t_end,
        });
        return;
    }

    const start_point = curve.evaluate(t_start);
    const end_point = curve.evaluate(t_end);
    const mid_t = (t_start + t_end) * 0.5;
    const mid_point = curve.evaluate(mid_t);

    // Check if the curve segment is flat enough
    if (isFlatEnough(start_point, mid_point, end_point, config.tolerance)) {
        try segments.append(TessellatedSegment{
            .start = start_point,
            .end = end_point,
            .t_start = t_start,
            .t_end = t_end,
        });
    } else {
        // Subdivide the curve
        try tessellrateCubicAdaptive(curve, segments, config, t_start, mid_t, depth + 1);
        try tessellrateCubicAdaptive(curve, segments, config, mid_t, t_end, depth + 1);
    }
}

/// Check if a curve segment is flat enough to be approximated by a line
/// Enhanced with FreeType-inspired deviation calculation
fn isFlatEnough(start: Vec2, mid: Vec2, end: Vec2, tolerance: f32) bool {
    // Calculate the distance from the midpoint to the line connecting start and end
    const line_vec = maths.vec2_subtract(end, start);
    const line_length_sq = maths.vec2_lengthSquared(line_vec);

    if (line_length_sq < 0.001) {
        // Degenerate case: start and end are very close
        return true;
    }

    // Use perpendicular distance calculation for better accuracy
    // This is more numerically stable than projection
    const dx = end.x - start.x;
    const dy = end.y - start.y;
    const line_length = @sqrt(line_length_sq);

    // Calculate perpendicular distance from mid to line
    // Using the formula: |ax + by + c| / sqrt(a^2 + b^2)
    const distance = @abs(dy * mid.x - dx * mid.y + end.x * start.y - end.y * start.x) / line_length;

    // For curves, also check the parametric deviation
    // This ensures we don't miss sharp turns
    const param_mid = maths.vec2_multiply(maths.vec2_add(start, end), 0.5);
    const param_deviation = maths.vec2_length(maths.vec2_subtract(mid, param_mid));

    return distance <= tolerance and param_deviation <= tolerance * 2.0;
}

/// Check if the angle change is small enough (for angle-based tessellation)
fn angleChangeSmall(p1: Vec2, p2: Vec2, p3: Vec2, angle_tolerance: f32) bool {
    const v1 = maths.vec2_normalize(maths.vec2_subtract(p2, p1));
    const v2 = maths.vec2_normalize(maths.vec2_subtract(p3, p2));

    // Calculate the angle between the vectors using dot product
    const dot = maths.vec2_dot(v1, v2);
    const angle = std.math.acos(@max(-1.0, @min(1.0, dot)));

    return angle <= angle_tolerance;
}

/// Edge structure for scanline rendering
pub const Edge = struct {
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
    winding: i32,
};

/// Convert tessellated segments to edges for scanline rendering
pub fn segmentsToEdges(
    allocator: std.mem.Allocator,
    segments: []const TessellatedSegment,
) !std.ArrayList(Edge) {
    var edges = std.ArrayList(Edge).init(allocator);

    for (segments) |segment| {
        // Skip horizontal edges (they don't contribute to filling)
        if (@abs(segment.start.y - segment.end.y) > 0.001) {
            try edges.append(Edge{
                .x0 = segment.start.x,
                .y0 = segment.start.y,
                .x1 = segment.end.x,
                .y1 = segment.end.y,
                .winding = if (segment.start.y < segment.end.y) 1 else -1,
            });
        }
    }

    return edges;
}

/// Tessellation quality presets
pub const QualityPresets = struct {
    /// Fast tessellation for real-time rendering
    pub const fast = TessellationConfig{
        .max_segments = 16,
        .min_segments = 2,
        .tolerance = 1.0,
        .angle_tolerance = 0.2,
        .adaptive = true,
    };

    /// Balanced quality and performance
    pub const medium = TessellationConfig{
        .max_segments = 32,
        .min_segments = 3,
        .tolerance = 0.5,
        .angle_tolerance = 0.1,
        .adaptive = true,
    };

    /// High quality tessellation for final output
    pub const high = TessellationConfig{
        .max_segments = 64,
        .min_segments = 4,
        .tolerance = 0.25,
        .angle_tolerance = 0.05,
        .adaptive = true,
    };

    /// Maximum quality for print/vector output
    pub const ultra = TessellationConfig{
        .max_segments = 128,
        .min_segments = 8,
        .tolerance = 0.1,
        .angle_tolerance = 0.025,
        .adaptive = true,
    };
};

/// Get recommended tessellation config based on scale
/// Enhanced algorithm inspired by FreeType's adaptive tessellation
pub fn recommendConfigForScale(scale: f32) TessellationConfig {
    // For very small scales (< 12pt), we need MORE segments, not fewer
    // This counter-intuitive approach ensures smooth curves at small sizes
    if (scale < 0.3) {
        // Tiny fonts need maximum quality to avoid artifacts
        return TessellationConfig{
            .max_segments = 256,
            .min_segments = 16,
            .tolerance = 0.05, // Very tight tolerance
            .angle_tolerance = 0.01,
            .adaptive = true,
        };
    } else if (scale < 0.5) {
        // Small fonts still need high quality
        return TessellationConfig{
            .max_segments = 128,
            .min_segments = 8,
            .tolerance = 0.1,
            .angle_tolerance = 0.02,
            .adaptive = true,
        };
    } else if (scale < 1.0) {
        return QualityPresets.high;
    } else if (scale < 2.0) {
        return QualityPresets.ultra;
    } else {
        // Large fonts can use slightly lower quality
        return QualityPresets.high;
    }
}

/// Tessellate an entire contour from a vector path
pub fn tessellateContour(
    allocator: std.mem.Allocator,
    contour: *const vector_path.Contour,
    config: TessellationConfig,
) !std.ArrayList(TessellatedSegment) {
    var all_segments = std.ArrayList(TessellatedSegment).init(allocator);

    for (contour.segments.items) |segment| {
        switch (segment) {
            .line => |line| {
                // Lines don't need tessellation
                try all_segments.append(TessellatedSegment{
                    .start = line.start,
                    .end = line.end,
                    .t_start = 0.0,
                    .t_end = 1.0,
                });
            },
            .quadratic => |quad| {
                var result = try tessellateQuadratic(allocator, quad, config);
                defer result.deinit();

                try all_segments.appendSlice(result.segments.items);
            },
            .cubic => |cubic| {
                var result = try tessellrateCubic(allocator, cubic, config);
                defer result.deinit();

                try all_segments.appendSlice(result.segments.items);
            },
        }
    }

    return all_segments;
}

/// Utility for creating edges from a path suitable for font rasterization
pub fn pathToEdges(
    allocator: std.mem.Allocator,
    path: *const vector_path.VectorPath,
    config: TessellationConfig,
) !std.ArrayList(Edge) {
    var all_edges = std.ArrayList(Edge).init(allocator);

    for (path.contours.items) |*contour| {
        var segments = try tessellateContour(allocator, contour, config);
        defer segments.deinit();

        var edges = try segmentsToEdges(allocator, segments.items);
        defer edges.deinit();

        try all_edges.appendSlice(edges.items);
    }

    return all_edges;
}
