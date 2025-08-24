const std = @import("std");

/// Small focused module for signed distance field mathematics
/// Provides pure SDF calculation algorithms independent of font or graphics systems
/// Used by both font rasterization and text rendering systems
/// Generic 2D point for distance calculations
pub const Point2D = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) Point2D {
        return .{ .x = x, .y = y };
    }

    pub fn distance(self: Point2D, other: Point2D) f32 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        return @sqrt(dx * dx + dy * dy);
    }
};

/// Configuration for SDF generation
pub const SDFConfig = struct {
    /// Resolution of the SDF texture (typically 64x64 or 128x128)
    texture_size: u32 = 64,

    /// Range of the distance field in texture units
    range: f32 = 4.0,

    /// Whether to use high-precision calculation
    high_precision: bool = true,

    /// Number of samples for anti-aliasing (0 = no AA, 4+ recommended)
    sample_count: u32 = 8,

    /// Whether to generate multi-channel SDF (MSDF)
    multi_channel: bool = false,

    /// Scale factor for oversampling
    oversample: u32 = 1,
};

/// Calculate the shortest distance from a point to a line segment
/// This is the fundamental operation for SDF generation
pub fn distanceToSegment(point: Point2D, segment_start: Point2D, segment_end: Point2D) f32 {
    const dx = segment_end.x - segment_start.x;
    const dy = segment_end.y - segment_start.y;

    // If segment has zero length, return distance to start point
    const length_squared = dx * dx + dy * dy;
    if (length_squared < 0.001) {
        return point.distance(segment_start);
    }

    // Calculate projection parameter (where on the segment is closest to point)
    const px = point.x - segment_start.x;
    const py = point.y - segment_start.y;
    const dot_product = px * dx + py * dy;
    const t = std.math.clamp(dot_product / length_squared, 0.0, 1.0);

    // Find closest point on segment
    const closest = Point2D{
        .x = segment_start.x + t * dx,
        .y = segment_start.y + t * dy,
    };

    return point.distance(closest);
}

/// Test if a point is inside a polygon using ray casting algorithm
/// Returns true if point is inside, false if outside
/// Works with both clockwise and counter-clockwise winding
pub fn isPointInsidePolygon(point: Point2D, polygon: []const Point2D) bool {
    if (polygon.len < 3) return false;

    var intersections: u32 = 0;

    // Cast ray from point to the right and count intersections
    for (0..polygon.len) |i| {
        const p1 = polygon[i];
        const p2 = polygon[(i + 1) % polygon.len];

        // Check if ray intersects with this edge
        if ((p1.y > point.y) != (p2.y > point.y)) {
            // Calculate x-coordinate of intersection
            const x_intersect = (p2.x - p1.x) * (point.y - p1.y) / (p2.y - p1.y) + p1.x;

            // If intersection is to the right of our point, count it
            if (point.x < x_intersect) {
                intersections += 1;
            }
        }
    }

    // Odd number of intersections means inside
    return (intersections % 2) == 1;
}

/// Calculate the unsigned distance from a point to a polygon (always positive)
/// Returns the shortest distance to any edge of the polygon
pub fn distanceToPolygon(point: Point2D, polygon: []const Point2D) f32 {
    if (polygon.len == 0) return std.math.floatMax(f32);
    if (polygon.len == 1) return point.distance(polygon[0]);

    var min_distance: f32 = std.math.floatMax(f32);

    // Check distance to each edge
    for (0..polygon.len) |i| {
        const p1 = polygon[i];
        const p2 = polygon[(i + 1) % polygon.len];
        const segment_distance = distanceToSegment(point, p1, p2);
        min_distance = @min(min_distance, segment_distance);
    }

    return min_distance;
}

/// Calculate the signed distance from a point to a polygon
/// Returns negative if inside, positive if outside
/// Requires that polygon vertices are provided in consistent winding order
pub fn signedDistanceToPolygon(point: Point2D, polygon: []const Point2D) f32 {
    const unsigned_distance = distanceToPolygon(point, polygon);
    const inside = isPointInsidePolygon(point, polygon);

    return if (inside) -unsigned_distance else unsigned_distance;
}

/// Calculate signed distance considering multiple contours (for fonts with holes)
/// outer_contours: main shape contours (positive distance outside)
/// inner_contours: hole contours (negative distance inside holes, even if inside main shape)
pub fn signedDistanceToContours(point: Point2D, outer_contours: []const []const Point2D, inner_contours: []const []const Point2D) f32 {
    var min_distance: f32 = std.math.floatMax(f32);
    var inside_outer = false;
    var inside_inner = false;

    // Check all outer contours
    for (outer_contours) |contour| {
        const distance = distanceToPolygon(point, contour);
        min_distance = @min(min_distance, distance);

        if (isPointInsidePolygon(point, contour)) {
            inside_outer = true;
        }
    }

    // Check all inner contours (holes)
    for (inner_contours) |contour| {
        const distance = distanceToPolygon(point, contour);
        min_distance = @min(min_distance, distance);

        if (isPointInsidePolygon(point, contour)) {
            inside_inner = true;
        }
    }

    // Inside outer but not inside any hole = inside shape
    const inside_shape = inside_outer and !inside_inner;

    return if (inside_shape) -min_distance else min_distance;
}

/// Convert distance value to texture byte value for SDF storage
/// Maps distance range [-max_distance, max_distance] to [0, 255]
pub fn distanceToTextureByte(distance: f32, max_distance: f32) u8 {
    const normalized = distance / max_distance;
    const clamped = std.math.clamp(normalized, -1.0, 1.0);
    return @as(u8, @intFromFloat((clamped + 1.0) * 127.5));
}

/// Convert texture byte back to distance value
/// Maps [0, 255] back to [-max_distance, max_distance]
pub fn textureByteToDistance(byte: u8, max_distance: f32) f32 {
    const normalized = (@as(f32, @floatFromInt(byte)) / 127.5) - 1.0;
    return normalized * max_distance;
}

/// Calculate winding number for a point relative to a polygon
/// Alternative to ray casting that handles edge cases better
/// Returns positive for counter-clockwise winding, negative for clockwise
pub fn calculateWindingNumber(point: Point2D, polygon: []const Point2D) i32 {
    if (polygon.len < 3) return 0;

    var winding: i32 = 0;

    for (0..polygon.len) |i| {
        const p1 = polygon[i];
        const p2 = polygon[(i + 1) % polygon.len];

        if (p1.y <= point.y) {
            if (p2.y > point.y) { // Upward crossing
                if (isLeftOfEdge(point, p1, p2)) {
                    winding += 1;
                }
            }
        } else {
            if (p2.y <= point.y) { // Downward crossing
                if (!isLeftOfEdge(point, p1, p2)) {
                    winding -= 1;
                }
            }
        }
    }

    return winding;
}

/// Test if a point is to the left of a directed line segment
fn isLeftOfEdge(point: Point2D, line_start: Point2D, line_end: Point2D) bool {
    const cross = (line_end.x - line_start.x) * (point.y - line_start.y) -
        (point.x - line_start.x) * (line_end.y - line_start.y);
    return cross > 0.0;
}

test "distanceToSegment basic cases" {
    const testing = std.testing;

    // Point on horizontal line segment
    const segment_start = Point2D.init(0.0, 0.0);
    const segment_end = Point2D.init(10.0, 0.0);

    // Point on the segment
    const point_on = Point2D.init(5.0, 0.0);
    try testing.expectApproxEqAbs(@as(f32, 0.0), distanceToSegment(point_on, segment_start, segment_end), 0.001);

    // Point perpendicular to segment
    const point_perp = Point2D.init(5.0, 3.0);
    try testing.expectApproxEqAbs(@as(f32, 3.0), distanceToSegment(point_perp, segment_start, segment_end), 0.001);

    // Point beyond segment end
    const point_beyond = Point2D.init(15.0, 0.0);
    try testing.expectApproxEqAbs(@as(f32, 5.0), distanceToSegment(point_beyond, segment_start, segment_end), 0.001);
}

test "isPointInsidePolygon rectangle" {
    const testing = std.testing;

    // Rectangle from (0,0) to (10,10)
    const rectangle = [_]Point2D{
        Point2D.init(0.0, 0.0),
        Point2D.init(10.0, 0.0),
        Point2D.init(10.0, 10.0),
        Point2D.init(0.0, 10.0),
    };

    // Point inside
    const inside_point = Point2D.init(5.0, 5.0);
    try testing.expect(isPointInsidePolygon(inside_point, &rectangle));

    // Point outside
    const outside_point = Point2D.init(15.0, 5.0);
    try testing.expect(!isPointInsidePolygon(outside_point, &rectangle));

    // Point on edge (should be considered outside for most uses)
    const edge_point = Point2D.init(0.0, 5.0);
    try testing.expect(!isPointInsidePolygon(edge_point, &rectangle));
}

test "signedDistanceToPolygon" {
    const testing = std.testing;

    // Unit square centered at origin
    const square = [_]Point2D{
        Point2D.init(-1.0, -1.0),
        Point2D.init(1.0, -1.0),
        Point2D.init(1.0, 1.0),
        Point2D.init(-1.0, 1.0),
    };

    // Point inside should have negative distance
    const inside_point = Point2D.init(0.0, 0.0);
    const inside_distance = signedDistanceToPolygon(inside_point, &square);
    try testing.expect(inside_distance < 0.0);

    // Point outside should have positive distance
    const outside_point = Point2D.init(2.0, 0.0);
    const outside_distance = signedDistanceToPolygon(outside_point, &square);
    try testing.expect(outside_distance > 0.0);
    try testing.expectApproxEqAbs(@as(f32, 1.0), outside_distance, 0.001);
}

test "distanceToTextureByte conversion" {
    const testing = std.testing;

    const max_distance: f32 = 4.0;

    // Test round-trip conversion
    const original_distances = [_]f32{ -4.0, -2.0, 0.0, 2.0, 4.0 };

    for (original_distances) |distance| {
        const byte = distanceToTextureByte(distance, max_distance);
        const recovered = textureByteToDistance(byte, max_distance);
        try testing.expectApproxEqAbs(distance, recovered, 0.1); // Allow some precision loss
    }

    // Test edge cases
    try testing.expectEqual(@as(u8, 0), distanceToTextureByte(-4.0, 4.0));
    try testing.expectEqual(@as(u8, 255), distanceToTextureByte(4.0, 4.0));
    try testing.expectEqual(@as(u8, 127), distanceToTextureByte(0.0, 4.0));
}
