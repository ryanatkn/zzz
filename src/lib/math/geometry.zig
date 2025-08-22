const std = @import("std");
const Vec2 = @import("vec2.zig").Vec2;
const scalar = @import("scalar.zig");

/// Geometric calculation utilities for spatial operations
pub const GeometryUtils = struct {
    /// Calculate squared distance between two points (avoids expensive sqrt)
    pub fn distanceSquared(a: Vec2, b: Vec2) f32 {
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        return dx * dx + dy * dy;
    }

    /// Calculate actual distance between two points
    pub fn distance(a: Vec2, b: Vec2) f32 {
        return @sqrt(distanceSquared(a, b));
    }

    /// Calculate centroid (center point) of an array of points
    pub fn centroid(points: []const Vec2) Vec2 {
        if (points.len == 0) return Vec2{ .x = 0.0, .y = 0.0 };

        var sum = Vec2{ .x = 0.0, .y = 0.0 };
        for (points) |point| {
            sum = sum.add(point);
        }

        const count = @as(f32, @floatFromInt(points.len));
        return Vec2{ .x = sum.x / count, .y = sum.y / count };
    }

    /// Calculate area of a triangle given three vertices
    pub fn triangleArea(a: Vec2, b: Vec2, c: Vec2) f32 {
        // Using cross product formula: |AB × AC| / 2
        const ab = b.sub(a);
        const ac = c.sub(a);
        return @abs(ab.x * ac.y - ab.y * ac.x) * 0.5;
    }

    /// Calculate area of a polygon using shoelace formula
    pub fn polygonArea(vertices: []const Vec2) f32 {
        if (vertices.len < 3) return 0.0;

        var area: f32 = 0.0;
        for (0..vertices.len) |i| {
            const j = (i + 1) % vertices.len;
            area += vertices[i].x * vertices[j].y;
            area -= vertices[j].x * vertices[i].y;
        }

        return @abs(area) * 0.5;
    }

    /// Calculate perimeter of a polygon
    pub fn polygonPerimeter(vertices: []const Vec2) f32 {
        if (vertices.len < 2) return 0.0;

        var perimeter: f32 = 0.0;
        for (0..vertices.len) |i| {
            const j = (i + 1) % vertices.len;
            perimeter += distance(vertices[i], vertices[j]);
        }

        return perimeter;
    }

    /// Check if point is inside triangle using barycentric coordinates
    pub fn pointInTriangle(point: Vec2, a: Vec2, b: Vec2, c: Vec2) bool {
        const v0 = c.sub(a);
        const v1 = b.sub(a);
        const v2 = point.sub(a);

        const dot00 = v0.dot(v0);
        const dot01 = v0.dot(v1);
        const dot02 = v0.dot(v2);
        const dot11 = v1.dot(v1);
        const dot12 = v1.dot(v2);

        const inv_denom = 1.0 / (dot00 * dot11 - dot01 * dot01);
        const u = (dot11 * dot02 - dot01 * dot12) * inv_denom;
        const v = (dot00 * dot12 - dot01 * dot02) * inv_denom;

        return (u >= 0.0) and (v >= 0.0) and (u + v <= 1.0);
    }

    /// Find closest point on line segment to given point
    pub fn closestPointOnLineSegment(point: Vec2, line_start: Vec2, line_end: Vec2) Vec2 {
        const line_vec = line_end.sub(line_start);
        const point_vec = point.sub(line_start);

        const line_len_sq = line_vec.lengthSquared();
        if (line_len_sq == 0.0) return line_start; // Degenerate line

        const t = scalar.clamp(point_vec.dot(line_vec) / line_len_sq, 0.0, 1.0);
        return line_start.add(line_vec.scale(t));
    }

    /// Calculate angle between three points (B is the vertex)
    pub fn angleBetweenPoints(a: Vec2, b: Vec2, c: Vec2) f32 {
        const ba = a.sub(b);
        const bc = c.sub(b);

        const dot_product = ba.dot(bc);
        const magnitudes = ba.length() * bc.length();

        if (magnitudes == 0.0) return 0.0;

        const cos_angle = scalar.clamp(dot_product / magnitudes, -1.0, 1.0);
        return std.math.acos(cos_angle);
    }

    /// Check if two line segments intersect
    pub fn lineSegmentsIntersect(a1: Vec2, a2: Vec2, b1: Vec2, b2: Vec2) bool {
        const orientation = struct {
            fn orient(p: Vec2, q: Vec2, r: Vec2) i32 {
                const val = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y);
                if (@abs(val) < std.math.floatEps(f32)) return 0; // Colinear
                return if (val > 0) 1 else 2; // Clockwise or counterclockwise
            }

            fn onSegment(p: Vec2, q: Vec2, r: Vec2) bool {
                return q.x <= @max(p.x, r.x) and q.x >= @min(p.x, r.x) and
                    q.y <= @max(p.y, r.y) and q.y >= @min(p.y, r.y);
            }
        };

        const o1 = orientation.orient(a1, a2, b1);
        const o2 = orientation.orient(a1, a2, b2);
        const o3 = orientation.orient(b1, b2, a1);
        const o4 = orientation.orient(b1, b2, a2);

        // General case
        if (o1 != o2 and o3 != o4) return true;

        // Special cases (colinear points)
        if (o1 == 0 and orientation.onSegment(a1, b1, a2)) return true;
        if (o2 == 0 and orientation.onSegment(a1, b2, a2)) return true;
        if (o3 == 0 and orientation.onSegment(b1, a1, b2)) return true;
        if (o4 == 0 and orientation.onSegment(b1, a2, b2)) return true;

        return false;
    }
};

test "geometry calculations" {
    // Test distance
    const a = Vec2{ .x = 0.0, .y = 0.0 };
    const b = Vec2{ .x = 3.0, .y = 4.0 };
    try std.testing.expectApproxEqAbs(@as(f32, 25.0), GeometryUtils.distanceSquared(a, b), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), GeometryUtils.distance(a, b), 0.001);

    // Test centroid
    const points = [_]Vec2{ Vec2{ .x = 0.0, .y = 0.0 }, Vec2{ .x = 2.0, .y = 0.0 }, Vec2{ .x = 1.0, .y = 2.0 } };
    const center = GeometryUtils.centroid(&points);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), center.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0 / 3.0), center.y, 0.001);

    // Test triangle area
    const p1 = Vec2{ .x = 0.0, .y = 0.0 };
    const p2 = Vec2{ .x = 1.0, .y = 0.0 };
    const p3 = Vec2{ .x = 0.0, .y = 1.0 };
    const area = GeometryUtils.triangleArea(p1, p2, p3);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), area, 0.001);
}

test "point in triangle" {
    const a = Vec2{ .x = 0.0, .y = 0.0 };
    const b = Vec2{ .x = 1.0, .y = 0.0 };
    const c = Vec2{ .x = 0.5, .y = 1.0 };

    // Point inside triangle
    const inside = Vec2{ .x = 0.5, .y = 0.3 };
    try std.testing.expect(GeometryUtils.pointInTriangle(inside, a, b, c));

    // Point outside triangle
    const outside = Vec2{ .x = 1.0, .y = 1.0 };
    try std.testing.expect(!GeometryUtils.pointInTriangle(outside, a, b, c));
}

test "line segment intersection" {
    // Intersecting segments
    const a1 = Vec2{ .x = 0.0, .y = 0.0 };
    const a2 = Vec2{ .x = 1.0, .y = 1.0 };
    const b1 = Vec2{ .x = 0.0, .y = 1.0 };
    const b2 = Vec2{ .x = 1.0, .y = 0.0 };

    try std.testing.expect(GeometryUtils.lineSegmentsIntersect(a1, a2, b1, b2));

    // Non-intersecting segments
    const c1 = Vec2{ .x = 0.0, .y = 0.0 };
    const c2 = Vec2{ .x = 1.0, .y = 0.0 };
    const d1 = Vec2{ .x = 0.0, .y = 1.0 };
    const d2 = Vec2{ .x = 1.0, .y = 1.0 };

    try std.testing.expect(!GeometryUtils.lineSegmentsIntersect(c1, c2, d1, d2));
}
