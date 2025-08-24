// Bitmap Strategy - Efficient rendering using 6 vertices + texture atlas
// Optimized for UI text and small font sizes with good performance

pub const rasterizer = @import("rasterizer.zig");
pub const atlas = @import("atlas.zig");

// Re-export main types
pub const RasterizedGlyph = rasterizer.RasterizedGlyph;
pub const FontAtlas = atlas.FontAtlas;
pub const GlyphInfo = atlas.GlyphInfo;
pub const RenderMode = atlas.RenderMode;

// Strategy metadata
pub const STRATEGY_NAME = "bitmap";
pub const MAX_FONT_SIZE = 24.0; // Best for small text
pub const TYPICAL_VERTICES_PER_GLYPH = 6;
pub const RENDERING_APPROACH = "CPU rasterized bitmap → GPU texture atlas";
