// Glyph triangulator - converts TTF glyph contours to triangulated vertex buffers
// Uses simple triangulation algorithm to convert vector outlines to triangle meshes

const std = @import("std");
const glyph_extractor = @import("../../core/glyph_extractor.zig");
const curve_utils = @import("../../core/curve_utils.zig");
const loggers = @import("../../../debug/loggers.zig");

const GlyphOutline = glyph_extractor.GlyphOutline;
const Contour = glyph_extractor.Contour;
const Point = glyph_extractor.Point;

/// Vertex data for triangulated glyph
pub const GlyphVertex = extern struct {
    position: [2]f32, // x, y position in glyph space
    _padding: [2]f32, // Align to 16 bytes for GPU
};

/// Triangulated glyph data ready for GPU
pub const TriangulatedGlyph = struct {
    vertices: []GlyphVertex,
    vertex_count: u32,
    bounds: glyph_extractor.GlyphBounds,
    metrics: glyph_extractor.GlyphMetrics,

    pub fn deinit(self: *TriangulatedGlyph, allocator: std.mem.Allocator) void {
        allocator.free(self.vertices);
    }
};

/// Simple cache entry for triangulated glyphs
const CacheEntry = struct {
    char: u8,
    font_id: u32,
    size: f32,
    triangulated_glyph: TriangulatedGlyph,
};

/// Cache statistics for monitoring performance
pub const CacheStats = struct {
    hits: u64,
    misses: u64,
    evictions: u64,

    pub fn hitRate(self: CacheStats) f64 {
        const total = self.hits + self.misses;
        return if (total > 0) @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total)) else 0.0;
    }
};

/// Glyph triangulator - converts glyph outlines to vertex buffers
pub const GlyphTriangulator = struct {
    allocator: std.mem.Allocator,
    cache: std.ArrayList(CacheEntry),
    max_cache_size: usize,
    stats: CacheStats,

    pub fn init(allocator: std.mem.Allocator) GlyphTriangulator {
        return .{
            .allocator = allocator,
            .cache = std.ArrayList(CacheEntry).init(allocator),
            .max_cache_size = 256, // Cache up to 256 unique glyphs
            .stats = CacheStats{ .hits = 0, .misses = 0, .evictions = 0 },
        };
    }

    pub fn initWithCacheSize(allocator: std.mem.Allocator, max_cache_size: usize) GlyphTriangulator {
        return .{
            .allocator = allocator,
            .cache = std.ArrayList(CacheEntry).init(allocator),
            .max_cache_size = max_cache_size,
            .stats = CacheStats{ .hits = 0, .misses = 0, .evictions = 0 },
        };
    }

    /// Get cache performance statistics
    pub fn getStats(self: *const GlyphTriangulator) CacheStats {
        return self.stats;
    }

    pub fn deinit(self: *GlyphTriangulator) void {
        for (self.cache.items) |*entry| {
            entry.triangulated_glyph.deinit(self.allocator);
        }
        self.cache.deinit();
    }

    /// Triangulate a glyph with caching support
    pub fn triangulateGlyph(self: *GlyphTriangulator, char: u8, font_id: u32, size: f32, outline: GlyphOutline) !TriangulatedGlyph {
        const triangulation_log = loggers.getFontLogOptional();

        // Check cache first
        for (self.cache.items) |*entry| {
            if (entry.char == char and entry.font_id == font_id and entry.size == size) {
                self.stats.hits += 1;
                if (triangulation_log) |log| {
                    log.info("cache_hit", "Cache hit for char '{}' (font_id: {}, size: {:.1}) - Hit rate: {:.1}%", .{ @as(u21, char), font_id, size, self.stats.hitRate() * 100.0 });
                }

                // Return a copy of the cached glyph (caller owns the memory)
                const cached_vertices = try self.allocator.dupe(GlyphVertex, entry.triangulated_glyph.vertices);
                return TriangulatedGlyph{
                    .vertices = cached_vertices,
                    .vertex_count = entry.triangulated_glyph.vertex_count,
                    .bounds = entry.triangulated_glyph.bounds,
                    .metrics = entry.triangulated_glyph.metrics,
                };
            }
        }

        self.stats.misses += 1;
        if (triangulation_log) |log| {
            log.info("cache_miss", "Cache miss for char '{}' (font_id: {}, size: {:.1}), triangulating - Hit rate: {:.1}%", .{ @as(u21, char), font_id, size, self.stats.hitRate() * 100.0 });
        }

        // Not in cache, triangulate and add to cache
        const triangulated = try self.triangulateOutline(outline);

        // Evict oldest entries if cache is full
        if (self.cache.items.len >= self.max_cache_size) {
            self.stats.evictions += 1;
            if (triangulation_log) |log| {
                log.info("cache_evict", "Cache full ({}/{}), evicting oldest entries", .{ self.cache.items.len, self.max_cache_size });
            }

            // Remove oldest entries (simple FIFO eviction)
            const entries_to_remove = self.cache.items.len - self.max_cache_size + 1;
            for (0..entries_to_remove) |i| {
                self.cache.items[i].triangulated_glyph.deinit(self.allocator);
            }

            // Shift remaining entries to the front
            if (entries_to_remove < self.cache.items.len) {
                std.mem.copyForwards(CacheEntry, self.cache.items[0 .. self.cache.items.len - entries_to_remove], self.cache.items[entries_to_remove..]);
            }
            self.cache.shrinkRetainingCapacity(self.cache.items.len - entries_to_remove);
        }

        // Add to cache (make a copy for cache storage)
        const cache_vertices = try self.allocator.dupe(GlyphVertex, triangulated.vertices);
        try self.cache.append(CacheEntry{
            .char = char,
            .font_id = font_id,
            .size = size,
            .triangulated_glyph = TriangulatedGlyph{
                .vertices = cache_vertices,
                .vertex_count = triangulated.vertex_count,
                .bounds = triangulated.bounds,
                .metrics = triangulated.metrics,
            },
        });

        if (triangulation_log) |log| {
            log.info("cache_add", "Added char '{}' to cache (cache size: {})", .{ @as(u21, char), self.cache.items.len });
        }

        return triangulated;
    }

    /// Triangulate a glyph outline into vertex buffer data (no caching)
    pub fn triangulate(self: *GlyphTriangulator, outline: GlyphOutline) !TriangulatedGlyph {
        return self.triangulateOutline(outline);
    }

    /// Internal triangulation implementation
    fn triangulateOutline(self: *GlyphTriangulator, outline: GlyphOutline) !TriangulatedGlyph {
        const triangulation_log = loggers.getFontLogOptional();
        if (triangulation_log) |log| {
            log.info("triangulate_start", "Triangulating glyph with {} contours", .{outline.contours.len});
        }

        // Handle empty glyphs (like space character)
        if (outline.contours.len == 0) {
            if (triangulation_log) |log| {
                log.info("empty_glyph", "Empty glyph, returning no vertices", .{});
            }
            return TriangulatedGlyph{
                .vertices = &[_]GlyphVertex{},
                .vertex_count = 0,
                .bounds = outline.bounds,
                .metrics = outline.metrics,
            };
        }

        // Estimate triangle count: for simple contours, roughly 2 * point_count
        var total_points: usize = 0;
        for (outline.contours) |contour| {
            total_points += contour.points.len;
        }

        // Start with estimated capacity
        var vertices = std.ArrayList(GlyphVertex).init(self.allocator);
        try vertices.ensureTotalCapacity(total_points * 3); // Rough estimate

        // Triangulate each contour
        for (outline.contours, 0..) |contour, contour_idx| {
            if (triangulation_log) |log| {
                log.info("triangulate_contour", "Triangulating contour {} with {} points", .{ contour_idx, contour.points.len });
            }
            try self.triangulateContour(contour, &vertices);
        }

        const final_vertex_count = vertices.items.len;
        if (triangulation_log) |log| {
            log.info("triangulate_complete", "Generated {} vertices for glyph", .{final_vertex_count});
        }

        const owned_vertices = try vertices.toOwnedSlice();

        return TriangulatedGlyph{
            .vertices = owned_vertices,
            .vertex_count = @intCast(final_vertex_count),
            .bounds = outline.bounds,
            .metrics = outline.metrics,
        };
    }

    /// Triangulate a single contour with Bezier curve interpolation
    fn triangulateContour(self: *GlyphTriangulator, contour: Contour, vertices: *std.ArrayList(GlyphVertex)) !void {
        const triangulation_log = loggers.getFontLogOptional();

        if (contour.points.len < 3) {
            if (triangulation_log) |log| {
                log.warn("insufficient_points", "Contour has {} points, need at least 3 for triangulation", .{contour.points.len});
            }
            return; // Can't triangulate with less than 3 points
        }

        // First, convert bezier curves to line segments by interpolating
        var interpolated_points = std.ArrayList(Point).init(self.allocator);
        defer interpolated_points.deinit();

        try self.interpolateContour(contour, &interpolated_points);

        if (interpolated_points.items.len < 3) {
            if (triangulation_log) |log| {
                log.warn("insufficient_interpolated_points", "After interpolation: {} points, need at least 3", .{interpolated_points.items.len});
            }
            return;
        }

        // Now triangulate using fan triangulation on the interpolated points
        const center_point = interpolated_points.items[0];

        for (1..interpolated_points.items.len - 1) |i| {
            const p1 = interpolated_points.items[i];
            const p2 = interpolated_points.items[i + 1];

            // Add triangle vertices: center -> p1 -> p2
            try vertices.append(GlyphVertex{
                .position = [2]f32{ center_point.x, center_point.y },
                ._padding = [2]f32{ 0.0, 0.0 },
            });

            try vertices.append(GlyphVertex{
                .position = [2]f32{ p1.x, p1.y },
                ._padding = [2]f32{ 0.0, 0.0 },
            });

            try vertices.append(GlyphVertex{
                .position = [2]f32{ p2.x, p2.y },
                ._padding = [2]f32{ 0.0, 0.0 },
            });
        }

        // Close the contour if needed (last triangle)
        if (contour.closed and interpolated_points.items.len > 2) {
            const last_point = interpolated_points.items[interpolated_points.items.len - 1];
            const first_point = interpolated_points.items[1]; // We already used points[0] as center

            try vertices.append(GlyphVertex{
                .position = [2]f32{ center_point.x, center_point.y },
                ._padding = [2]f32{ 0.0, 0.0 },
            });

            try vertices.append(GlyphVertex{
                .position = [2]f32{ last_point.x, last_point.y },
                ._padding = [2]f32{ 0.0, 0.0 },
            });

            try vertices.append(GlyphVertex{
                .position = [2]f32{ first_point.x, first_point.y },
                ._padding = [2]f32{ 0.0, 0.0 },
            });
        }
    }

    /// Interpolate bezier curves in a contour to create smooth line segments
    fn interpolateContour(self: *GlyphTriangulator, contour: Contour, output: *std.ArrayList(Point)) !void {
        _ = self;

        if (contour.points.len == 0) return;

        var i: usize = 0;
        while (i < contour.points.len) {
            const current = contour.points[i];

            // Always add on-curve points
            if (current.on_curve) {
                try output.append(current);
                i += 1;
                continue;
            }

            // Handle off-curve points (Bezier control points)
            // We need a previous on-curve point to start the Bezier curve
            if (output.items.len == 0) {
                // No previous point - skip this control point for now
                // This can happen if the first point is off-curve
                i += 1;
                continue;
            }

            const start_point = output.items[output.items.len - 1];

            var j = i;
            const control_point = current;
            var end_point: Point = undefined;
            var found_end = false;

            // Look ahead for the end point
            j += 1;
            while (j < contour.points.len and !found_end) {
                if (contour.points[j].on_curve) {
                    end_point = contour.points[j];
                    found_end = true;
                } else {
                    // Two consecutive off-curve points - create implied on-curve point
                    const next_control = contour.points[j];
                    end_point = Point{
                        .x = (control_point.x + next_control.x) / 2.0,
                        .y = (control_point.y + next_control.y) / 2.0,
                        .on_curve = true,
                    };
                    found_end = true;
                    j -= 1; // Don't skip the next control point
                }
                j += 1;
            }

            // If we reached the end and it's a closed contour, wrap to beginning
            if (!found_end and contour.closed) {
                if (contour.points[0].on_curve) {
                    end_point = contour.points[0];
                    found_end = true;
                }
            }

            if (found_end) {
                // Interpolate quadratic Bezier curve: start -> control -> end
                try curve_utils.interpolateBezierCurveAdaptive(start_point, control_point, end_point, output, curve_utils.DEFAULT_CONFIG);
            }

            i = j;
        }
    }
};

// Tests
test "glyph triangulator basic functionality" {
    const testing = std.testing;

    var triangulator = GlyphTriangulator.init(testing.allocator);

    // Create a simple test contour (triangle)
    const test_points = [_]Point{
        .{ .x = 0.0, .y = 0.0, .on_curve = true },
        .{ .x = 100.0, .y = 0.0, .on_curve = true },
        .{ .x = 50.0, .y = 100.0, .on_curve = true },
    };

    const points_copy = try testing.allocator.dupe(Point, &test_points);

    const test_contour = Contour{
        .points = points_copy,
        .closed = true,
    };

    var contours = try testing.allocator.alloc(Contour, 1);
    defer testing.allocator.free(contours);
    contours[0] = test_contour;

    const test_outline = GlyphOutline{
        .contours = contours,
        .bounds = .{ .x_min = 0.0, .y_min = 0.0, .x_max = 100.0, .y_max = 100.0 },
        .metrics = .{ .advance_width = 120.0, .left_side_bearing = 5.0 },
    };

    // Triangulate
    var triangulated = try triangulator.triangulate(test_outline);
    defer triangulated.deinit(testing.allocator);

    // Should have generated vertices (triangulator generates 6 vertices for the triangle with curve interpolation)
    try testing.expect(triangulated.vertex_count == 6);
    try testing.expect(triangulated.vertices.len == 6);

    // Clean up contour points (outline doesn't own them)
    testing.allocator.free(test_contour.points);
}

test "empty glyph triangulation" {
    const testing = std.testing;

    var triangulator = GlyphTriangulator.init(testing.allocator);

    // Empty glyph (like space character)
    const empty_outline = GlyphOutline{
        .contours = &[_]Contour{},
        .bounds = .{ .x_min = 0.0, .y_min = 0.0, .x_max = 0.0, .y_max = 0.0 },
        .metrics = .{ .advance_width = 50.0, .left_side_bearing = 0.0 },
    };

    var triangulated = try triangulator.triangulate(empty_outline);
    defer triangulated.deinit(testing.allocator);

    // Should generate no vertices
    try testing.expect(triangulated.vertex_count == 0);
    try testing.expect(triangulated.vertices.len == 0);
}
