// Glyph vertex generation - creates simple procedural vertex data for buffer rendering
// This module stays in the font domain and produces vertex data for GPU rendering

const std = @import("std");
const loggers = @import("../../../debug/loggers.zig");

/// Simple glyph info without bitmap data (for buffer-based rendering)
const SimpleGlyph = struct {
    width: f32,
    height: f32,
    bearing_x: f32,
    bearing_y: f32,
    advance: f32,
};

/// Vertex data for a single glyph quad
pub const GlyphVertex = extern struct {
    position: [2]f32, // Local position within glyph quad (-1 to 1)
    coverage: f32, // Glyph coverage at this vertex (0.0 to 1.0)
    _padding: f32, // Align to 16 bytes
};

/// Instance data for glyph positioning and sizing
pub const GlyphInstance = extern struct {
    screen_pos: [2]f32, // Screen position in pixels
    size: [2]f32, // Glyph size in pixels
    color: [4]f32, // r, g, b, a
    uv_offset: [2]f32, // UV offset into coverage data
    uv_scale: [2]f32, // UV scaling for coverage sampling
};

/// Glyph vertex builder - converts bitmap glyphs to vertex data
pub const GlyphVertexBuilder = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) GlyphVertexBuilder {
        return GlyphVertexBuilder{
            .allocator = allocator,
        };
    }

    /// Generate vertices for a simple glyph quad (no bitmap coverage)
    /// Returns 6 vertices (2 triangles) for the glyph quad
    pub fn buildGlyphVertices(
        self: *GlyphVertexBuilder,
        char: u8,
    ) ![6]GlyphVertex {
        _ = self; // May be used for future optimizations
        _ = char; // TODO: Could use char for different shapes

        // For now, all characters use full coverage (solid rectangles)
        const coverage = 1.0; // Full opacity

        // Generate 6 vertices for 2 triangles (top-left, top-right, bottom-left, bottom-left, top-right, bottom-right)
        return [6]GlyphVertex{
            // First triangle: top-left, top-right, bottom-left
            GlyphVertex{ .position = [2]f32{ -1.0, -1.0 }, .coverage = coverage, ._padding = 0.0 }, // top-left
            GlyphVertex{ .position = [2]f32{ 1.0, -1.0 }, .coverage = coverage, ._padding = 0.0 }, // top-right
            GlyphVertex{ .position = [2]f32{ -1.0, 1.0 }, .coverage = coverage, ._padding = 0.0 }, // bottom-left

            // Second triangle: bottom-left, top-right, bottom-right
            GlyphVertex{ .position = [2]f32{ -1.0, 1.0 }, .coverage = coverage, ._padding = 0.0 }, // bottom-left
            GlyphVertex{ .position = [2]f32{ 1.0, -1.0 }, .coverage = coverage, ._padding = 0.0 }, // top-right
            GlyphVertex{ .position = [2]f32{ 1.0, 1.0 }, .coverage = coverage, ._padding = 0.0 }, // bottom-right
        };
    }

    /// Create instance data for positioning a glyph on screen
    pub fn buildGlyphInstance(
        self: *GlyphVertexBuilder,
        char: u8,
        font_size: f32,
        screen_x: f32,
        screen_y: f32,
        color: [4]f32,
    ) GlyphInstance {
        _ = self; // May be used for future optimizations
        _ = char; // TODO: Could use char for specific sizing

        // Simple procedural glyph sizing
        const glyph_width = font_size * 0.6; // Rough character width
        const glyph_height = font_size;

        return GlyphInstance{
            .screen_pos = [2]f32{ screen_x, screen_y },
            .size = [2]f32{ glyph_width, glyph_height },
            .color = color,
            .uv_offset = [2]f32{ 0.0, 0.0 }, // Full glyph coverage
            .uv_scale = [2]f32{ 1.0, 1.0 },
        };
    }
};

// Sample coverage function removed - we use procedural shapes now

// Tests
test "glyph vertex builder basic functionality" {
    const testing = std.testing;

    var builder = GlyphVertexBuilder.init(testing.allocator);

    // Test vertex generation for simple character
    const vertices = try builder.buildGlyphVertices('A');
    try testing.expect(vertices.len == 6);

    // Verify all vertices have full coverage (solid rectangles)
    for (vertices) |vertex| {
        try testing.expect(vertex.coverage == 1.0);
    }

    // Test instance generation
    const instance = builder.buildGlyphInstance('A', 16.0, 100.0, 200.0, [4]f32{ 1.0, 0.0, 0.0, 1.0 });
    try testing.expect(instance.screen_pos[0] == 100.0);
    try testing.expect(instance.screen_pos[1] == 200.0);
    try testing.expect(instance.size[0] == 9.6); // 16.0 * 0.6
    try testing.expect(instance.size[1] == 16.0);
}

test "procedural glyph properties" {
    const testing = std.testing;

    var builder = GlyphVertexBuilder.init(testing.allocator);

    // Test that different characters can have different properties
    const instance_a = builder.buildGlyphInstance('A', 16.0, 0.0, 0.0, [4]f32{ 1.0, 1.0, 1.0, 1.0 });
    const instance_w = builder.buildGlyphInstance('W', 16.0, 0.0, 0.0, [4]f32{ 1.0, 1.0, 1.0, 1.0 });

    // For now, all characters have the same size (procedural)
    try testing.expect(instance_a.size[0] == instance_w.size[0]);
    try testing.expect(instance_a.size[1] == instance_w.size[1]);

    // Test that size scales with font size
    const small_instance = builder.buildGlyphInstance('A', 12.0, 0.0, 0.0, [4]f32{ 1.0, 1.0, 1.0, 1.0 });
    const large_instance = builder.buildGlyphInstance('A', 24.0, 0.0, 0.0, [4]f32{ 1.0, 1.0, 1.0, 1.0 });

    try testing.expect(small_instance.size[1] < large_instance.size[1]);
}
