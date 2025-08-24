// Resource management for rendering - shaders only (buffer-based rendering)

pub const shaders = @import("shaders.zig");

// Re-export main types for convenience
pub const ShaderManager = shaders.ShaderManager;
pub const ShaderPair = shaders.ShaderPair;
pub const ShaderInfo = shaders.ShaderInfo;
