const std = @import("std");
const Point = @import("point.zig").Point;
const Line = @import("shapes.zig").Line;
const Circle = @import("shapes.zig").Circle;

/// Geometric utility functions
pub const Utils = struct {
    
    /// Calculate winding number for point-in-polygon test
    /// Used for font glyph rasterization
    pub fn windingNumber(point: Point, contour: []const Point) i32 {
        var wn: i32 = 0;
        
        for (0..contour.len) |i| {
            const p1 = contour[i];
            const p2 = contour[(i + 1) % contour.len];
            
            if (p1.y <= point.y) {
                if (p2.y > point.y) { // Upward crossing
                    if (isLeft(p1, p2, point) > 0) {
                        wn += 1;
                    }
                }
            } else {
                if (p2.y <= point.y) { // Downward crossing
                    if (isLeft(p1, p2, point) < 0) {
                        wn -= 1;
                    }
                }
            }
        }
        
        return wn;
    }
    
    /// Test if point is left|on|right of line from p1 to p2
    /// Returns: >0 for left, =0 for on, <0 for right
    pub fn isLeft(p1: Point, p2: Point, point: Point) f32 {
        return (p2.x - p1.x) * (point.y - p1.y) - (point.x - p1.x) * (p2.y - p1.y);
    }
    
    /// Check if point is inside polygon using winding number
    pub fn pointInPolygon(point: Point, polygon: []const Point) bool {
        return windingNumber(point, polygon) != 0;
    }
    
    /// Check if point is inside polygon using ray casting (alternative method)
    pub fn pointInPolygonRayCast(point: Point, polygon: []const Point) bool {
        var inside = false;
        
        for (0..polygon.len) |i| {
            const p1 = polygon[i];
            const p2 = polygon[(i + 1) % polygon.len];
            
            if (((p1.y > point.y) != (p2.y > point.y)) and
                (point.x < (p2.x - p1.x) * (point.y - p1.y) / (p2.y - p1.y) + p1.x)) {
                inside = !inside;
            }
        }
        
        return inside;
    }
    
    /// Calculate distance between point and line segment
    pub fn pointToLineDistance(point: Point, line: Line) f32 {
        return line.distanceToPoint(point);
    }
    
    /// Check if two line segments intersect
    pub fn lineSegmentsIntersect(line1: Line, line2: Line) bool {
        const d1 = isLeft(line2.start, line2.end, line1.start);
        const d2 = isLeft(line2.start, line2.end, line1.end);
        const d3 = isLeft(line1.start, line1.end, line2.start);
        const d4 = isLeft(line1.start, line1.end, line2.end);
        
        if (((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and
            ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0))) {
            return true;
        }
        
        // Check for collinear cases
        return (d1 == 0 and pointOnSegment(line2.start, line2.end, line1.start)) or
               (d2 == 0 and pointOnSegment(line2.start, line2.end, line1.end)) or
               (d3 == 0 and pointOnSegment(line1.start, line1.end, line2.start)) or
               (d4 == 0 and pointOnSegment(line1.start, line1.end, line2.end));
    }
    
    /// Check if point lies on line segment
    pub fn pointOnSegment(line_start: Point, line_end: Point, point: Point) bool {
        if (isLeft(line_start, line_end, point) != 0) return false;
        
        return point.x >= @min(line_start.x, line_end.x) and
               point.x <= @max(line_start.x, line_end.x) and
               point.y >= @min(line_start.y, line_end.y) and
               point.y <= @max(line_start.y, line_end.y);
    }
    
    /// Transform point by translation
    pub fn translatePoint(point: Point, offset: Point) Point {
        return point.add(offset);
    }
    
    /// Transform point by scaling around origin
    pub fn scalePoint(point: Point, scale_factor: f32) Point {
        return point.scale(scale_factor);
    }
    
    /// Transform point by scaling around center
    pub fn scalePointAround(point: Point, center: Point, scale_factor: f32) Point {
        return point.sub(center).scale(scale_factor).add(center);
    }
    
    /// Rotate point around origin
    pub fn rotatePoint(point: Point, angle_radians: f32) Point {
        const cos_a = @cos(angle_radians);
        const sin_a = @sin(angle_radians);
        
        return Point.init(
            point.x * cos_a - point.y * sin_a,
            point.x * sin_a + point.y * cos_a,
        );
    }
    
    /// Rotate point around center
    pub fn rotatePointAround(point: Point, center: Point, angle_radians: f32) Point {
        return rotatePoint(point.sub(center), angle_radians).add(center);
    }
    
    /// Calculate angle between two vectors
    pub fn angleBetween(v1: Point, v2: Point) f32 {
        const dot = v1.dot(v2);
        const mag_product = v1.length() * v2.length();
        if (mag_product == 0) return 0;
        return std.math.acos(std.math.clamp(dot / mag_product, -1.0, 1.0));
    }
    
    /// Calculate signed area of triangle (for orientation testing)
    pub fn triangleSignedArea(p1: Point, p2: Point, p3: Point) f32 {
        return ((p2.x - p1.x) * (p3.y - p1.y) - (p3.x - p1.x) * (p2.y - p1.y)) * 0.5;
    }
    
    /// Check orientation of three points
    /// Returns: 0 = collinear, 1 = clockwise, 2 = counterclockwise
    pub fn orientation(p1: Point, p2: Point, p3: Point) u8 {
        const val = triangleSignedArea(p1, p2, p3);
        if (@abs(val) < 1e-10) return 0; // Collinear
        return if (val > 0) 2 else 1; // Counter-clockwise or clockwise
    }
};

test "winding number" {
    // Square: (0,0), (10,0), (10,10), (0,10)
    const square = [_]Point{
        Point.init(0.0, 0.0),
        Point.init(10.0, 0.0),
        Point.init(10.0, 10.0),
        Point.init(0.0, 10.0),
    };
    
    // Point inside
    const inside_point = Point.init(5.0, 5.0);
    try std.testing.expect(Utils.pointInPolygon(inside_point, &square));
    
    // Point outside
    const outside_point = Point.init(15.0, 5.0);
    try std.testing.expect(!Utils.pointInPolygon(outside_point, &square));
    
    // Point on edge should be considered inside
    const edge_point = Point.init(0.0, 5.0);
    try std.testing.expect(Utils.pointInPolygon(edge_point, &square));
}

test "line intersection" {
    const line1 = Line.init(Point.init(0.0, 0.0), Point.init(10.0, 10.0));
    const line2 = Line.init(Point.init(0.0, 10.0), Point.init(10.0, 0.0));
    
    // These lines should intersect (they form an X)
    try std.testing.expect(Utils.lineSegmentsIntersect(line1, line2));
    
    // Parallel lines should not intersect
    const line3 = Line.init(Point.init(0.0, 5.0), Point.init(10.0, 15.0));
    try std.testing.expect(!Utils.lineSegmentsIntersect(line1, line3));
}

test "point transformations" {
    const point = Point.init(3.0, 4.0);
    
    // Translation
    const translated = Utils.translatePoint(point, Point.init(2.0, 1.0));
    try std.testing.expect(translated.x == 5.0 and translated.y == 5.0);
    
    // Scaling
    const scaled = Utils.scalePoint(point, 2.0);
    try std.testing.expect(scaled.x == 6.0 and scaled.y == 8.0);
    
    // Rotation by 90 degrees
    const rotated = Utils.rotatePoint(point, std.math.pi / 2.0);
    try std.testing.expect(@abs(rotated.x - (-4.0)) < 0.001);
    try std.testing.expect(@abs(rotated.y - 3.0) < 0.001);
}