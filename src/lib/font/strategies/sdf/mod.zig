// SDF Strategy - Scalable rendering using Signed Distance Fields
// Provides scalable text with effects support, good for medium-sized text

pub const generator = @import("generator.zig");

// Re-export main types
pub const SDFGenerator = generator.SDFGenerator;
pub const SDFGlyphData = generator.SDFGlyphData;
pub const SDFConfig = generator.SDFConfig;

// Strategy metadata
pub const STRATEGY_NAME = generator.STRATEGY_NAME;
pub const OPTIMAL_FONT_SIZE_RANGE = generator.OPTIMAL_FONT_SIZE_RANGE;
pub const TYPICAL_VERTICES_PER_GLYPH = generator.TYPICAL_VERTICES_PER_GLYPH;
pub const RENDERING_APPROACH = generator.RENDERING_APPROACH;
