// Vertex Strategy - High-quality rendering using 2000+ vertices per glyph
// Provides maximum quality by triangulating glyph contours directly to GPU vertices

pub const triangulator = @import("triangulator.zig");
pub const vertex_builder = @import("vertex_builder.zig");

// Re-export main types
pub const GlyphTriangulator = triangulator.GlyphTriangulator;
pub const TriangulatedGlyph = triangulator.TriangulatedGlyph;
pub const GlyphVertex = triangulator.GlyphVertex;
pub const GlyphVertexBuilder = vertex_builder.GlyphVertexBuilder;

// Strategy metadata
pub const STRATEGY_NAME = "vertex";
pub const MIN_FONT_SIZE = 24.0; // Best for large text
pub const TYPICAL_VERTICES_PER_GLYPH = 2000;
pub const RENDERING_APPROACH = "Triangulated contours → GPU vertex buffer";
