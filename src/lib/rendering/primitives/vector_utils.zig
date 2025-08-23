// Vector graphics utility functions for creating common shapes
// Moved from vector/gpu_renderer.zig for better organization

const std = @import("std");
const math = @import("../../math/mod.zig");
const vector_path = @import("../../vector/path.zig");

const Vec2 = math.Vec2;
const VectorPath = vector_path.VectorPath;

/// Utility functions for creating vector graphics shapes
pub const VectorUtils = struct {
    /// Create a circle path
    pub fn createCircle(allocator: std.mem.Allocator, center: Vec2, radius: f32, segments: u32) !VectorPath {
        var path = VectorPath.init(allocator);
        var contour = try vector_path.Contour.init(allocator);

        const angle_step = 2.0 * std.math.pi / @as(f32, @floatFromInt(segments));

        for (0..segments) |i| {
            const angle = @as(f32, @floatFromInt(i)) * angle_step;
            const point = vector_path.PathPoint{
                .position = Vec2{
                    .x = center.x + radius * @cos(angle),
                    .y = center.y + radius * @sin(angle),
                },
                .on_curve = true,
            };
            try contour.points.append(point);
        }

        try path.contours.append(contour);
        return path;
    }

    /// Create a rectangle path
    pub fn createRectangle(allocator: std.mem.Allocator, pos: Vec2, size: Vec2) !VectorPath {
        var path = VectorPath.init(allocator);
        var contour = try vector_path.Contour.init(allocator);

        const points = [_]Vec2{
            pos,
            Vec2{ .x = pos.x + size.x, .y = pos.y },
            Vec2{ .x = pos.x + size.x, .y = pos.y + size.y },
            Vec2{ .x = pos.x, .y = pos.y + size.y },
        };

        for (points) |point_pos| {
            const point = vector_path.PathPoint{
                .position = point_pos,
                .on_curve = true,
            };
            try contour.points.append(point);
        }

        try path.contours.append(contour);
        return path;
    }
};
