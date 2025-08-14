const std = @import("std");
const glyph_extractor = @import("glyph_extractor.zig");
const curve_tessellation = @import("curve_tessellation.zig");

const log = std.log.scoped(.edge_builder);
const GlyphOutline = glyph_extractor.GlyphOutline;
const Point = glyph_extractor.Point;

/// Edge for scanline rendering
pub const Edge = struct {
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
    winding: i32,
    
    // Fixed-point versions for better precision (16.16 format)
    fx0: i32 = 0,
    fy0: i32 = 0,
    fx1: i32 = 0,
    fy1: i32 = 0,
    
    pub fn init(x0: f32, y0: f32, x1: f32, y1: f32, winding: i32) Edge {
        return Edge{
            .x0 = x0,
            .y0 = y0,
            .x1 = x1,
            .y1 = y1,
            .winding = winding,
        };
    }
    
    pub fn initWithFixedPoint(x0: f32, y0: f32, x1: f32, y1: f32, winding: i32) Edge {
        const FIXED_SHIFT = 16;
        return Edge{
            .x0 = x0,
            .y0 = y0,
            .x1 = x1,
            .y1 = y1,
            .winding = winding,
            .fx0 = @intFromFloat(x0 * @as(f32, 1 << FIXED_SHIFT)),
            .fy0 = @intFromFloat(y0 * @as(f32, 1 << FIXED_SHIFT)),
            .fx1 = @intFromFloat(x1 * @as(f32, 1 << FIXED_SHIFT)),
            .fy1 = @intFromFloat(y1 * @as(f32, 1 << FIXED_SHIFT)),
        };
    }
    
    /// Check if edge crosses scanline
    pub fn crossesScanline(self: Edge, y: f32) bool {
        const min_y = @min(self.y0, self.y1);
        const max_y = @max(self.y0, self.y1);
        return y >= min_y and y < max_y;
    }
    
    /// Get X coordinate at scanline Y
    pub fn xAtY(self: Edge, y: f32) f32 {
        if (@abs(self.y1 - self.y0) < 0.001) {
            return self.x0;
        }
        const t = (y - self.y0) / (self.y1 - self.y0);
        return self.x0 + t * (self.x1 - self.x0);
    }
};

/// Configuration for edge building
pub const EdgeBuildConfig = struct {
    /// Offset to apply to all coordinates
    offset_x: f32 = 0,
    offset_y: f32 = 0,
    
    /// Tessellation quality for curves
    tessellation_config: curve_tessellation.TessellationConfig = curve_tessellation.QualityPresets.medium,
    
    /// Minimum edge length (edges shorter than this are discarded)
    min_edge_length: f32 = 0.001,
    
    /// Whether to use fixed-point precision
    use_fixed_point: bool = true,
};

/// Builds edges from glyph outlines
pub const EdgeBuilder = struct {
    allocator: std.mem.Allocator,
    config: EdgeBuildConfig,
    
    pub fn init(allocator: std.mem.Allocator, config: EdgeBuildConfig) EdgeBuilder {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }
    
    /// Build edges from a glyph outline
    pub fn buildEdges(self: *EdgeBuilder, outline: GlyphOutline) ![]Edge {
        var edges = std.ArrayList(Edge).init(self.allocator);
        defer edges.deinit();
        
        for (outline.contours) |contour| {
            try self.buildContourEdges(&edges, contour.points);
        }
        
        return edges.toOwnedSlice();
    }
    
    /// Build edges from a single contour
    fn buildContourEdges(self: *EdgeBuilder, edges: *std.ArrayList(Edge), points: []const Point) !void {
        if (points.len < 2) return;
        
        const offset_x = self.config.offset_x;
        const offset_y = self.config.offset_y;
        
        var i: usize = 0;
        while (i < points.len) : (i += 1) {
            const curr = points[i];
            const next = points[(i + 1) % points.len];
            
            if (curr.on_curve and next.on_curve) {
                // Straight line
                const x0 = curr.x + offset_x;
                const y0 = curr.y + offset_y;
                const x1 = next.x + offset_x;
                const y1 = next.y + offset_y;
                
                if (self.shouldAddEdge(x0, y0, x1, y1)) {
                    const winding = if (y0 < y1) @as(i32, 1) else @as(i32, -1);
                    const edge = if (self.config.use_fixed_point)
                        Edge.initWithFixedPoint(x0, y0, x1, y1, winding)
                    else
                        Edge.init(x0, y0, x1, y1, winding);
                    try edges.append(edge);
                }
            } else if (curr.on_curve and !next.on_curve) {
                // Start of quadratic curve
                const control = next;
                const end_idx = (i + 2) % points.len;
                const end = if (points[end_idx].on_curve)
                    points[end_idx]
                else
                    // Implied on-curve point between two off-curve points
                    Point{
                        .x = (control.x + points[end_idx].x) / 2,
                        .y = (control.y + points[end_idx].y) / 2,
                        .on_curve = true,
                    };
                
                try self.tessellateQuadratic(
                    edges,
                    curr.x + offset_x,
                    curr.y + offset_y,
                    control.x + offset_x,
                    control.y + offset_y,
                    end.x + offset_x,
                    end.y + offset_y,
                );
                
                i += 1; // Skip control point
            } else if (!curr.on_curve and !next.on_curve) {
                // Two consecutive off-curve points - implied on-curve between them
                const implied = Point{
                    .x = (curr.x + next.x) / 2,
                    .y = (curr.y + next.y) / 2,
                    .on_curve = true,
                };
                
                const prev_idx = if (i == 0) points.len - 1 else i - 1;
                const start = if (points[prev_idx].on_curve)
                    points[prev_idx]
                else
                    Point{
                        .x = (points[prev_idx].x + curr.x) / 2,
                        .y = (points[prev_idx].y + curr.y) / 2,
                        .on_curve = true,
                    };
                
                try self.tessellateQuadratic(
                    edges,
                    start.x + offset_x,
                    start.y + offset_y,
                    curr.x + offset_x,
                    curr.y + offset_y,
                    implied.x + offset_x,
                    implied.y + offset_y,
                );
            }
        }
    }
    
    /// Tessellate a quadratic Bezier curve into line segments
    fn tessellateQuadratic(
        self: *EdgeBuilder,
        edges: *std.ArrayList(Edge),
        x0: f32, y0: f32,
        x1: f32, y1: f32,
        x2: f32, y2: f32,
    ) !void {
        const config = self.config.tessellation_config;
        
        // Estimate number of segments needed
        const dx1 = x1 - x0;
        const dy1 = y1 - y0;
        const dx2 = x2 - x1;
        const dy2 = y2 - y1;
        const deviation = @sqrt(dx1 * dx1 + dy1 * dy1) + @sqrt(dx2 * dx2 + dy2 * dy2);
        
        const segments = @max(2, @as(u32, @intFromFloat(deviation / config.tolerance)));
        
        var prev_x = x0;
        var prev_y = y0;
        
        for (1..segments + 1) |seg| {
            const t = @as(f32, @floatFromInt(seg)) / @as(f32, @floatFromInt(segments));
            const one_minus_t = 1.0 - t;
            
            const x = one_minus_t * one_minus_t * x0 + 2.0 * one_minus_t * t * x1 + t * t * x2;
            const y = one_minus_t * one_minus_t * y0 + 2.0 * one_minus_t * t * y1 + t * t * y2;
            
            if (self.shouldAddEdge(prev_x, prev_y, x, y)) {
                const winding = if (prev_y < y) @as(i32, 1) else @as(i32, -1);
                const edge = if (self.config.use_fixed_point)
                    Edge.initWithFixedPoint(prev_x, prev_y, x, y, winding)
                else
                    Edge.init(prev_x, prev_y, x, y, winding);
                try edges.append(edge);
            }
            
            prev_x = x;
            prev_y = y;
        }
    }
    
    /// Check if an edge should be added (not too small)
    fn shouldAddEdge(self: *EdgeBuilder, x0: f32, y0: f32, x1: f32, y1: f32) bool {
        const dx = x1 - x0;
        const dy = y1 - y0;
        const length_squared = dx * dx + dy * dy;
        const min_length = self.config.min_edge_length;
        return length_squared >= min_length * min_length;
    }
};