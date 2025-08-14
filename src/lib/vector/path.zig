const std = @import("std");
const types = @import("../types.zig");
const maths = @import("../maths.zig");

const Vec2 = types.Vec2;

/// A point on a vector path with control information
pub const PathPoint = struct {
    position: Vec2,
    on_curve: bool,
};

/// A quadratic bezier curve segment
pub const QuadraticCurve = struct {
    start: Vec2,
    control: Vec2,
    end: Vec2,

    /// Evaluate the curve at parameter t (0.0 to 1.0)
    pub fn evaluate(self: QuadraticCurve, t: f32) Vec2 {
        const one_minus_t = 1.0 - t;
        return Vec2{
            .x = one_minus_t * one_minus_t * self.start.x +
                2.0 * one_minus_t * t * self.control.x +
                t * t * self.end.x,
            .y = one_minus_t * one_minus_t * self.start.y +
                2.0 * one_minus_t * t * self.control.y +
                t * t * self.end.y,
        };
    }

    /// Get the derivative (tangent) at parameter t
    pub fn derivative(self: QuadraticCurve, t: f32) Vec2 {
        const one_minus_t = 1.0 - t;
        return Vec2{
            .x = 2.0 * one_minus_t * (self.control.x - self.start.x) +
                2.0 * t * (self.end.x - self.control.x),
            .y = 2.0 * one_minus_t * (self.control.y - self.start.y) +
                2.0 * t * (self.end.y - self.control.y),
        };
    }

    /// Calculate the approximate length of the curve
    pub fn length(self: QuadraticCurve) f32 {
        // Use numerical integration for approximate length
        const steps = 10;
        var total_length: f32 = 0;
        var prev_point = self.start;

        var i: u32 = 1;
        while (i <= steps) : (i += 1) {
            const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(steps));
            const point = self.evaluate(t);
            total_length += maths.vec2_length(maths.vec2_subtract(point, prev_point));
            prev_point = point;
        }

        return total_length;
    }

    /// Get bounding box of the curve
    pub fn boundingBox(self: QuadraticCurve) struct { min: Vec2, max: Vec2 } {
        var min_x = @min(self.start.x, self.end.x);
        var max_x = @max(self.start.x, self.end.x);
        var min_y = @min(self.start.y, self.end.y);
        var max_y = @max(self.start.y, self.end.y);

        // Check extrema of the curve (where derivative = 0)
        // For quadratic: derivative = 2(1-t)(control-start) + 2t(end-control)
        // Setting to 0 and solving for t

        // X extrema
        const dx_start = self.control.x - self.start.x;
        const dx_end = self.end.x - self.control.x;
        if (dx_start != dx_end) {
            const t_x = dx_start / (dx_start - dx_end);
            if (t_x > 0 and t_x < 1) {
                const extrema_x = self.evaluate(t_x).x;
                min_x = @min(min_x, extrema_x);
                max_x = @max(max_x, extrema_x);
            }
        }

        // Y extrema
        const dy_start = self.control.y - self.start.y;
        const dy_end = self.end.y - self.control.y;
        if (dy_start != dy_end) {
            const t_y = dy_start / (dy_start - dy_end);
            if (t_y > 0 and t_y < 1) {
                const extrema_y = self.evaluate(t_y).y;
                min_y = @min(min_y, extrema_y);
                max_y = @max(max_y, extrema_y);
            }
        }

        return .{
            .min = Vec2{ .x = min_x, .y = min_y },
            .max = Vec2{ .x = max_x, .y = max_y },
        };
    }
};

/// A cubic bezier curve segment
pub const CubicCurve = struct {
    start: Vec2,
    control1: Vec2,
    control2: Vec2,
    end: Vec2,

    /// Evaluate the curve at parameter t (0.0 to 1.0)
    pub fn evaluate(self: CubicCurve, t: f32) Vec2 {
        const one_minus_t = 1.0 - t;
        const one_minus_t_sq = one_minus_t * one_minus_t;
        const one_minus_t_cb = one_minus_t_sq * one_minus_t;
        const t_sq = t * t;
        const t_cb = t_sq * t;

        return Vec2{
            .x = one_minus_t_cb * self.start.x +
                3.0 * one_minus_t_sq * t * self.control1.x +
                3.0 * one_minus_t * t_sq * self.control2.x +
                t_cb * self.end.x,
            .y = one_minus_t_cb * self.start.y +
                3.0 * one_minus_t_sq * t * self.control1.y +
                3.0 * one_minus_t * t_sq * self.control2.y +
                t_cb * self.end.y,
        };
    }
};

/// A line segment
pub const LineSegment = struct {
    start: Vec2,
    end: Vec2,

    pub fn evaluate(self: LineSegment, t: f32) Vec2 {
        return maths.vec2_lerp(self.start, self.end, t);
    }

    pub fn length(self: LineSegment) f32 {
        return maths.vec2_length(maths.vec2_subtract(self.end, self.start));
    }
};

/// A path segment (can be line or curve)
pub const PathSegment = union(enum) {
    line: LineSegment,
    quadratic: QuadraticCurve,
    cubic: CubicCurve,

    pub fn evaluate(self: PathSegment, t: f32) Vec2 {
        return switch (self) {
            .line => |line| line.evaluate(t),
            .quadratic => |quad| quad.evaluate(t),
            .cubic => |cubic| cubic.evaluate(t),
        };
    }

    pub fn startPoint(self: PathSegment) Vec2 {
        return switch (self) {
            .line => |line| line.start,
            .quadratic => |quad| quad.start,
            .cubic => |cubic| cubic.start,
        };
    }

    pub fn endPoint(self: PathSegment) Vec2 {
        return switch (self) {
            .line => |line| line.end,
            .quadratic => |quad| quad.end,
            .cubic => |cubic| cubic.end,
        };
    }

    pub fn length(self: PathSegment) f32 {
        return switch (self) {
            .line => |line| line.length(),
            .quadratic => |quad| quad.length(),
            .cubic => |cubic| blk: {
                // Approximate length for cubic curves
                const steps = 20;
                var total_length: f32 = 0;
                var prev_point = cubic.start;

                var i: u32 = 1;
                while (i <= steps) : (i += 1) {
                    const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(steps));
                    const point = cubic.evaluate(t);
                    total_length += maths.vec2_length(maths.vec2_subtract(point, prev_point));
                    prev_point = point;
                }

                break :blk total_length;
            },
        };
    }
};

/// A contour is a closed path made of segments
pub const Contour = struct {
    segments: std.ArrayList(PathSegment),
    closed: bool,

    pub fn init(allocator: std.mem.Allocator) Contour {
        return Contour{
            .segments = std.ArrayList(PathSegment).init(allocator),
            .closed = false,
        };
    }

    pub fn deinit(self: *Contour) void {
        self.segments.deinit();
    }

    pub fn addLine(self: *Contour, end: Vec2) !void {
        const start = if (self.segments.items.len > 0)
            self.segments.items[self.segments.items.len - 1].endPoint()
        else
            Vec2{ .x = 0, .y = 0 };

        try self.segments.append(.{ .line = LineSegment{ .start = start, .end = end } });
    }

    pub fn addQuadratic(self: *Contour, control: Vec2, end: Vec2) !void {
        const start = if (self.segments.items.len > 0)
            self.segments.items[self.segments.items.len - 1].endPoint()
        else
            Vec2{ .x = 0, .y = 0 };

        try self.segments.append(.{ .quadratic = QuadraticCurve{ .start = start, .control = control, .end = end } });
    }

    pub fn addCubic(self: *Contour, control1: Vec2, control2: Vec2, end: Vec2) !void {
        const start = if (self.segments.items.len > 0)
            self.segments.items[self.segments.items.len - 1].endPoint()
        else
            Vec2{ .x = 0, .y = 0 };

        try self.segments.append(.{ .cubic = CubicCurve{ .start = start, .control1 = control1, .control2 = control2, .end = end } });
    }

    pub fn close(self: *Contour) void {
        self.closed = true;
    }

    /// Get bounding box of the entire contour
    pub fn boundingBox(self: *const Contour) ?struct { min: Vec2, max: Vec2 } {
        if (self.segments.items.len == 0) return null;

        var min_x: f32 = std.math.floatMax(f32);
        var min_y: f32 = std.math.floatMax(f32);
        var max_x: f32 = std.math.floatMin(f32);
        var max_y: f32 = std.math.floatMin(f32);

        for (self.segments.items) |segment| {
            switch (segment) {
                .line => |line| {
                    min_x = @min(min_x, @min(line.start.x, line.end.x));
                    max_x = @max(max_x, @max(line.start.x, line.end.x));
                    min_y = @min(min_y, @min(line.start.y, line.end.y));
                    max_y = @max(max_y, @max(line.start.y, line.end.y));
                },
                .quadratic => |quad| {
                    const bbox = quad.boundingBox();
                    min_x = @min(min_x, bbox.min.x);
                    max_x = @max(max_x, bbox.max.x);
                    min_y = @min(min_y, bbox.min.y);
                    max_y = @max(max_y, bbox.max.y);
                },
                .cubic => |cubic| {
                    // Simplified bounding box for cubic (just control points)
                    const points = [_]Vec2{ cubic.start, cubic.control1, cubic.control2, cubic.end };
                    for (points) |point| {
                        min_x = @min(min_x, point.x);
                        max_x = @max(max_x, point.x);
                        min_y = @min(min_y, point.y);
                        max_y = @max(max_y, point.y);
                    }
                },
            }
        }

        return .{
            .min = Vec2{ .x = min_x, .y = min_y },
            .max = Vec2{ .x = max_x, .y = max_y },
        };
    }
};

/// A complete vector path containing multiple contours
pub const VectorPath = struct {
    contours: std.ArrayList(Contour),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) VectorPath {
        return VectorPath{
            .contours = std.ArrayList(Contour).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *VectorPath) void {
        for (self.contours.items) |*contour| {
            contour.deinit();
        }
        self.contours.deinit();
    }

    pub fn addContour(self: *VectorPath) !*Contour {
        try self.contours.append(Contour.init(self.allocator));
        return &self.contours.items[self.contours.items.len - 1];
    }

    /// Get bounding box of the entire path
    pub fn boundingBox(self: *const VectorPath) ?struct { min: Vec2, max: Vec2 } {
        if (self.contours.items.len == 0) return null;

        var min_x: f32 = std.math.floatMax(f32);
        var min_y: f32 = std.math.floatMax(f32);
        var max_x: f32 = std.math.floatMin(f32);
        var max_y: f32 = std.math.floatMin(f32);

        for (self.contours.items) |*contour| {
            if (contour.boundingBox()) |bbox| {
                min_x = @min(min_x, bbox.min.x);
                max_x = @max(max_x, bbox.max.x);
                min_y = @min(min_y, bbox.min.y);
                max_y = @max(max_y, bbox.max.y);
            }
        }

        if (min_x == std.math.floatMax(f32)) return null;

        return .{
            .min = Vec2{ .x = min_x, .y = min_y },
            .max = Vec2{ .x = max_x, .y = max_y },
        };
    }

    /// Transform the entire path by a scale and translation
    pub fn transform(self: *VectorPath, scale: f32, offset: Vec2) void {
        for (self.contours.items) |*contour| {
            for (contour.segments.items) |*segment| {
                switch (segment.*) {
                    .line => |*line| {
                        line.start = maths.vec2_add(maths.vec2_multiply(line.start, scale), offset);
                        line.end = maths.vec2_add(maths.vec2_multiply(line.end, scale), offset);
                    },
                    .quadratic => |*quad| {
                        quad.start = maths.vec2_add(maths.vec2_multiply(quad.start, scale), offset);
                        quad.control = maths.vec2_add(maths.vec2_multiply(quad.control, scale), offset);
                        quad.end = maths.vec2_add(maths.vec2_multiply(quad.end, scale), offset);
                    },
                    .cubic => |*cubic| {
                        cubic.start = maths.vec2_add(maths.vec2_multiply(cubic.start, scale), offset);
                        cubic.control1 = maths.vec2_add(maths.vec2_multiply(cubic.control1, scale), offset);
                        cubic.control2 = maths.vec2_add(maths.vec2_multiply(cubic.control2, scale), offset);
                        cubic.end = maths.vec2_add(maths.vec2_multiply(cubic.end, scale), offset);
                    },
                }
            }
        }
    }
};

/// Path builder for convenient path construction
pub const PathBuilder = struct {
    path: VectorPath,
    current_contour: ?*Contour,
    current_position: Vec2,

    pub fn init(allocator: std.mem.Allocator) PathBuilder {
        return PathBuilder{
            .path = VectorPath.init(allocator),
            .current_contour = null,
            .current_position = Vec2{ .x = 0, .y = 0 },
        };
    }

    pub fn deinit(self: *PathBuilder) void {
        self.path.deinit();
    }

    pub fn moveTo(self: *PathBuilder, position: Vec2) !void {
        self.current_contour = try self.path.addContour();
        self.current_position = position;
    }

    pub fn lineTo(self: *PathBuilder, position: Vec2) !void {
        if (self.current_contour) |contour| {
            try contour.addLine(position);
            self.current_position = position;
        }
    }

    pub fn quadraticTo(self: *PathBuilder, control: Vec2, end: Vec2) !void {
        if (self.current_contour) |contour| {
            try contour.addQuadratic(control, end);
            self.current_position = end;
        }
    }

    pub fn cubicTo(self: *PathBuilder, control1: Vec2, control2: Vec2, end: Vec2) !void {
        if (self.current_contour) |contour| {
            try contour.addCubic(control1, control2, end);
            self.current_position = end;
        }
    }

    pub fn closePath(self: *PathBuilder) void {
        if (self.current_contour) |contour| {
            contour.close();
        }
        self.current_contour = null;
    }

    pub fn finalize(self: *PathBuilder) VectorPath {
        const result = self.path;
        self.path = VectorPath.init(self.path.allocator);
        self.current_contour = null;
        return result;
    }
};

/// Utility functions for working with TTF point arrays
pub const TTFUtils = struct {
    /// Convert TTF coordinate arrays to path segments
    pub fn createContourFromTTF(
        allocator: std.mem.Allocator,
        x_coords: []const f32,
        y_coords: []const f32,
        on_curve: []const bool,
        start_index: u32,
        end_index: u32,
    ) !Contour {
        var contour = Contour.init(allocator);
        errdefer contour.deinit();

        if (start_index >= end_index) return contour;

        var prev_x = x_coords[start_index];
        var prev_y = y_coords[start_index];
        var prev_on_curve = on_curve[start_index];

        var point_index = start_index + 1;
        while (point_index <= end_index) : (point_index += 1) {
            const x = x_coords[point_index];
            const y = y_coords[point_index];
            const is_on_curve = on_curve[point_index];

            if (prev_on_curve and is_on_curve) {
                // Line segment
                try contour.addLine(Vec2{ .x = x, .y = y });
            } else if (!prev_on_curve and is_on_curve) {
                // Previous point was control point, this is end point
                try contour.addQuadratic(Vec2{ .x = prev_x, .y = prev_y }, Vec2{ .x = x, .y = y });
            } else if (!prev_on_curve and !is_on_curve) {
                // Two consecutive control points - create implicit on-curve point
                const mid_x = (prev_x + x) * 0.5;
                const mid_y = (prev_y + y) * 0.5;

                try contour.addQuadratic(Vec2{ .x = prev_x, .y = prev_y }, Vec2{ .x = mid_x, .y = mid_y });

                prev_x = mid_x;
                prev_y = mid_y;
                prev_on_curve = true;
                continue;
            }

            prev_x = x;
            prev_y = y;
            prev_on_curve = is_on_curve;
        }

        contour.close();
        return contour;
    }
};
