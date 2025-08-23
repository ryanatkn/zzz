const std = @import("std");
const math = @import("../math/mod.zig");
const scalar = @import("../math/scalar.zig");
const vector_path = @import("../vector/path.zig");
const font_metrics = @import("../font/font_metrics.zig");

const Vec2 = math.Vec2;
const VectorPath = vector_path.VectorPath;
const Contour = vector_path.Contour;

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

/// A signed distance field texture
pub const SDFTexture = struct {
    /// SDF data (single channel for SDF, RGB for MSDF)
    data: []u8,

    /// Texture dimensions
    width: u32,
    height: u32,

    /// Number of channels (1 for SDF, 3 for MSDF)
    channels: u32,

    /// Distance field range in texture space
    range: f32,

    /// Memory allocator used for the data
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32, channels: u32, range: f32) !SDFTexture {
        const data = try allocator.alloc(u8, width * height * channels);
        return SDFTexture{
            .data = data,
            .width = width,
            .height = height,
            .channels = channels,
            .range = range,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SDFTexture) void {
        self.allocator.free(self.data);
    }

    /// Get pixel data at specific coordinates
    pub fn getPixel(self: *const SDFTexture, x: u32, y: u32) []const u8 {
        const index = (y * self.width + x) * self.channels;
        return self.data[index .. index + self.channels];
    }

    /// Set pixel data at specific coordinates
    pub fn setPixel(self: *SDFTexture, x: u32, y: u32, value: []const u8) void {
        const index = (y * self.width + x) * self.channels;
        @memcpy(self.data[index .. index + self.channels], value);
    }

    /// Sample the SDF at normalized coordinates (0.0 to 1.0)
    pub fn sample(self: *const SDFTexture, u: f32, v: f32) f32 {
        const x = @as(f32, @floatFromInt(self.width - 1)) * scalar.clamp(u, 0.0, 1.0);
        const y = @as(f32, @floatFromInt(self.height - 1)) * scalar.clamp(v, 0.0, 1.0);

        const x0 = @as(u32, @intFromFloat(@floor(x)));
        const y0 = @as(u32, @intFromFloat(@floor(y)));
        const x1 = @min(x0 + 1, self.width - 1);
        const y1 = @min(y0 + 1, self.height - 1);

        const fx = x - @floor(x);
        const fy = y - @floor(y);

        // Bilinear interpolation
        const v00 = @as(f32, @floatFromInt(self.getPixel(x0, y0)[0])) / 255.0;
        const v10 = @as(f32, @floatFromInt(self.getPixel(x1, y0)[0])) / 255.0;
        const v01 = @as(f32, @floatFromInt(self.getPixel(x0, y1)[0])) / 255.0;
        const v11 = @as(f32, @floatFromInt(self.getPixel(x1, y1)[0])) / 255.0;

        const v0 = math.lerp(v00, v10, fx);
        const v1 = math.lerp(v01, v11, fx);

        return math.lerp(v0, v1, fy);
    }
};

/// SDF generator from vector paths
pub const SDFGenerator = struct {
    allocator: std.mem.Allocator,
    config: SDFConfig,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: SDFConfig) Self {
        return Self{
            .allocator = allocator,
            .config = config,
        };
    }

    /// Generate SDF from a vector path
    pub fn generateSDF(self: *Self, path: *const VectorPath) !SDFTexture {
        const channels = if (self.config.multi_channel) @as(u32, 3) else @as(u32, 1);
        var texture = try SDFTexture.init(self.allocator, self.config.texture_size, self.config.texture_size, channels, self.config.range);

        // Get path bounding box
        const bbox = path.boundingBox() orelse {
            // Empty path - fill with maximum distance
            @memset(texture.data, 0);
            return texture;
        };

        // Calculate scale and offset to fit path in texture
        const path_width = bbox.max.x - bbox.min.x;
        const path_height = bbox.max.y - bbox.min.y;
        const max_dimension = @max(path_width, path_height);

        // Add padding around the glyph
        const padding = self.config.range * 2.0;
        const scale = (@as(f32, @floatFromInt(self.config.texture_size)) - padding) / max_dimension;
        const offset = Vec2{
            .x = (padding * 0.5) - bbox.min.x * scale,
            .y = (padding * 0.5) - bbox.min.y * scale,
        };

        if (self.config.multi_channel) {
            try self.generateMSDF(path, &texture, scale, offset);
        } else {
            try self.generateSimpleSDF(path, &texture, scale, offset);
        }

        return texture;
    }

    /// Generate simple single-channel SDF
    fn generateSimpleSDF(self: *Self, path: *const VectorPath, texture: *SDFTexture, scale: f32, offset: Vec2) !void {
        var y: u32 = 0;
        while (y < self.config.texture_size) : (y += 1) {
            var x: u32 = 0;
            while (x < self.config.texture_size) : (x += 1) {
                // Convert texture coordinates to world coordinates
                const world_pos = Vec2{
                    .x = (@as(f32, @floatFromInt(x)) - offset.x) / scale,
                    .y = (@as(f32, @floatFromInt(y)) - offset.y) / scale,
                };

                // Calculate distance to the path
                var distance = self.calculateDistance(path, world_pos);

                // Apply multi-sampling for anti-aliasing
                if (self.config.sample_count > 1) {
                    distance = self.calculateMultisampledDistance(path, world_pos, scale);
                }

                // Normalize distance to 0-255 range
                const normalized = (distance / self.config.range + 1.0) * 0.5;
                const pixel_value = @as(u8, @intFromFloat(scalar.clamp(normalized * 255.0, 0, 255)));

                texture.setPixel(x, y, &[_]u8{pixel_value});
            }
        }
    }

    /// Generate multi-channel SDF (MSDF) for better quality
    fn generateMSDF(self: *Self, path: *const VectorPath, texture: *SDFTexture, scale: f32, offset: Vec2) !void {
        // MSDF implementation is more complex - this is a simplified version
        // In a full implementation, you would assign different channels to different edge directions

        var y: u32 = 0;
        while (y < self.config.texture_size) : (y += 1) {
            var x: u32 = 0;
            while (x < self.config.texture_size) : (x += 1) {
                const world_pos = Vec2{
                    .x = (@as(f32, @floatFromInt(x)) - offset.x) / scale,
                    .y = (@as(f32, @floatFromInt(y)) - offset.y) / scale,
                };

                // For simplicity, use the same distance for all channels
                // A proper MSDF would analyze edge directions
                var distance = self.calculateDistance(path, world_pos);

                if (self.config.sample_count > 1) {
                    distance = self.calculateMultisampledDistance(path, world_pos, scale);
                }

                const normalized = (distance / self.config.range + 1.0) * 0.5;
                const pixel_value = @as(u8, @intFromFloat(scalar.clamp(normalized * 255.0, 0, 255)));

                texture.setPixel(x, y, &[_]u8{ pixel_value, pixel_value, pixel_value });
            }
        }
    }

    /// Calculate signed distance from a point to the path
    fn calculateDistance(self: *Self, path: *const VectorPath, point: Vec2) f32 {
        var min_distance: f32 = std.math.floatMax(f32);
        var inside = false;

        for (path.contours.items) |*contour| {
            const contour_distance = self.calculateContourDistance(contour, point);
            min_distance = @min(min_distance, @abs(contour_distance));

            // Check if point is inside this contour using winding number
            if (self.isPointInside(contour, point)) {
                inside = !inside; // Toggle for each containing contour
            }
        }

        return if (inside) -min_distance else min_distance;
    }

    /// Calculate distance from point to a contour
    fn calculateContourDistance(self: *Self, contour: *const Contour, point: Vec2) f32 {
        var min_distance: f32 = std.math.floatMax(f32);

        for (contour.segments.items) |segment| {
            const distance = switch (segment) {
                .line => |line| self.distanceToLine(point, line.start, line.end),
                .quadratic => |quad| self.distanceToQuadratic(point, quad),
                .cubic => |cubic| self.distanceToCubic(point, cubic),
            };
            min_distance = @min(min_distance, distance);
        }

        return min_distance;
    }

    /// Calculate distance from point to line segment
    fn distanceToLine(self: *Self, point: Vec2, start: Vec2, end: Vec2) f32 {
        _ = self;
        const line_vec = end.sub(start);
        const point_vec = point.sub(start);

        const line_len_sq = line_vec.lengthSquared();
        if (line_len_sq == 0) {
            return point_vec.length();
        }

        const t = scalar.clamp(point_vec.dot(line_vec) / line_len_sq, 0, 1);
        const projection = start.add(line_vec.scale(t));

        return point.sub(projection).length();
    }

    /// Calculate distance from point to quadratic bezier curve (approximated)
    fn distanceToQuadratic(self: *Self, point: Vec2, curve: vector_path.QuadraticCurve) f32 {
        var min_distance: f32 = std.math.floatMax(f32);

        // Sample the curve at multiple points for approximation
        const samples = 10;
        var prev_point = curve.start;

        var i: u32 = 1;
        while (i <= samples) : (i += 1) {
            const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(samples));
            const current_point = curve.evaluate(t);

            const distance = self.distanceToLine(point, prev_point, current_point);
            min_distance = @min(min_distance, distance);

            prev_point = current_point;
        }

        return min_distance;
    }

    /// Calculate distance from point to cubic bezier curve (approximated)
    fn distanceToCubic(self: *Self, point: Vec2, curve: vector_path.CubicCurve) f32 {
        var min_distance: f32 = std.math.floatMax(f32);

        // Sample the curve at multiple points for approximation
        const samples = 15;
        var prev_point = curve.start;

        var i: u32 = 1;
        while (i <= samples) : (i += 1) {
            const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(samples));
            const current_point = curve.evaluate(t);

            const distance = self.distanceToLine(point, prev_point, current_point);
            min_distance = @min(min_distance, distance);

            prev_point = current_point;
        }

        return min_distance;
    }

    /// Check if a point is inside a contour using winding number
    fn isPointInside(self: *Self, contour: *const Contour, point: Vec2) bool {
        _ = self;
        var winding_number: i32 = 0;

        for (contour.segments.items) |segment| {
            const start = segment.startPoint();
            const end = segment.endPoint();

            if (start.y <= point.y) {
                if (end.y > point.y) { // Upward crossing
                    if (isLeft(start, end, point) > 0) {
                        winding_number += 1;
                    }
                }
            } else {
                if (end.y <= point.y) { // Downward crossing
                    if (isLeft(start, end, point) < 0) {
                        winding_number -= 1;
                    }
                }
            }
        }

        return winding_number != 0;
    }

    /// Multi-sampled distance calculation for anti-aliasing
    fn calculateMultisampledDistance(self: *Self, path: *const VectorPath, center: Vec2, scale: f32) f32 {
        const sample_offset = 0.5 / scale; // Half pixel offset
        var total_distance: f32 = 0;

        // Sample in a grid pattern
        const samples_per_axis = @as(u32, @intFromFloat(@sqrt(@as(f32, @floatFromInt(self.config.sample_count)))));
        const step = sample_offset * 2.0 / @as(f32, @floatFromInt(samples_per_axis));

        var sy: u32 = 0;
        while (sy < samples_per_axis) : (sy += 1) {
            var sx: u32 = 0;
            while (sx < samples_per_axis) : (sx += 1) {
                const sample_pos = Vec2{
                    .x = center.x - sample_offset + @as(f32, @floatFromInt(sx)) * step,
                    .y = center.y - sample_offset + @as(f32, @floatFromInt(sy)) * step,
                };
                total_distance += self.calculateDistance(path, sample_pos);
            }
        }

        return total_distance / @as(f32, @floatFromInt(samples_per_axis * samples_per_axis));
    }
};

/// Utility function to test which side of a line a point is on
fn isLeft(p0: Vec2, p1: Vec2, p2: Vec2) f32 {
    return (p1.x - p0.x) * (p2.y - p0.y) - (p2.x - p0.x) * (p1.y - p0.y);
}

/// SDF quality presets
pub const SDFPresets = struct {
    /// Fast SDF generation for real-time use
    pub const fast = SDFConfig{
        .texture_size = 32,
        .range = 3.0,
        .high_precision = false,
        .sample_count = 1,
        .multi_channel = false,
        .oversample = 1,
    };

    /// Balanced quality and performance
    pub const medium = SDFConfig{
        .texture_size = 64,
        .range = 4.0,
        .high_precision = true,
        .sample_count = 4,
        .multi_channel = false,
        .oversample = 1,
    };

    /// High quality SDF for final output
    pub const high = SDFConfig{
        .texture_size = 128,
        .range = 4.0,
        .high_precision = true,
        .sample_count = 8,
        .multi_channel = false,
        .oversample = 2,
    };

    /// Ultra high quality MSDF
    pub const ultra = SDFConfig{
        .texture_size = 128,
        .range = 4.0,
        .high_precision = true,
        .sample_count = 16,
        .multi_channel = true,
        .oversample = 2,
    };
};

/// SDF atlas for managing multiple SDF textures
pub const SDFAtlas = struct {
    allocator: std.mem.Allocator,
    textures: std.AutoHashMap(u64, SDFTexture),
    generator: SDFGenerator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: SDFConfig) Self {
        return Self{
            .allocator = allocator,
            .textures = std.AutoHashMap(u64, SDFTexture).init(allocator),
            .generator = SDFGenerator.init(allocator, config),
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.textures.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.textures.deinit();
    }

    /// Get or generate SDF for a glyph
    pub fn getOrGenerateSDF(self: *Self, glyph_id: u64, path: *const VectorPath) !*const SDFTexture {
        if (self.textures.getPtr(glyph_id)) |texture| {
            return texture;
        }

        const texture = try self.generator.generateSDF(path);
        try self.textures.put(glyph_id, texture);
        return self.textures.getPtr(glyph_id).?;
    }

    /// Check if SDF exists for a glyph
    pub fn hasSDF(self: *const Self, glyph_id: u64) bool {
        return self.textures.contains(glyph_id);
    }

    /// Remove SDF for a glyph
    pub fn removeSDF(self: *Self, glyph_id: u64) bool {
        if (self.textures.fetchRemove(glyph_id)) |kv| {
            kv.value.deinit();
            return true;
        }
        return false;
    }

    /// Clear all SDFs
    pub fn clear(self: *Self) void {
        var iter = self.textures.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.textures.clearRetainingCapacity();
    }
};

/// Utility for converting paths to SDFs with caching
pub const SDFUtils = struct {
    /// Recommended SDF size based on glyph size and usage
    pub fn recommendSDFSize(glyph_size: f32, usage: enum { ui, text, display }) u32 {
        return switch (usage) {
            .ui => if (glyph_size < 16) @as(u32, 32) else @as(u32, 64),
            .text => if (glyph_size < 24) @as(u32, 64) else @as(u32, 128),
            .display => if (glyph_size < 48) @as(u32, 128) else @as(u32, 256),
        };
    }

    /// Calculate optimal SDF range based on glyph complexity
    pub fn calculateOptimalRange(path: *const VectorPath, texture_size: u32) f32 {

        // Calculate path complexity (number of segments)
        var segment_count: u32 = 0;
        for (path.contours.items) |*contour| {
            segment_count += @intCast(contour.segments.items.len);
        }

        // Base range on texture size and complexity
        const base_range = @as(f32, @floatFromInt(texture_size)) / 16.0;
        const complexity_factor = @min(2.0, @as(f32, @floatFromInt(segment_count)) / 10.0);

        return base_range * (1.0 + complexity_factor * 0.5);
    }

    /// Check if SDF rendering is recommended for given parameters
    pub fn shouldUseSDF(glyph_size: f32, scale_factor: f32) bool {
        // SDF is beneficial when:
        // 1. Glyph might be scaled significantly
        // 2. Very small sizes where bitmap would be pixelated
        // 3. Very large sizes where bitmap would be memory-intensive
        return scale_factor > 1.5 or glyph_size < 12.0 or glyph_size > 64.0;
    }
};

test "SDF texture creation" {
    const testing = std.testing;

    var texture = try SDFTexture.init(testing.allocator, 64, 64, 1, 4.0);
    defer texture.deinit();

    try testing.expect(texture.width == 64);
    try testing.expect(texture.height == 64);
    try testing.expect(texture.channels == 1);
    try testing.expect(texture.data.len == 64 * 64 * 1);
}

test "SDF generator creation" {
    const testing = std.testing;

    const generator = SDFGenerator.init(testing.allocator, SDFPresets.fast);
    try testing.expect(generator.config.texture_size == 32);
    try testing.expect(generator.config.range == 3.0);
}
