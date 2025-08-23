// Resource management for rendering - shaders, textures, materials

pub const shaders = @import("shaders.zig");

// Re-export main types for convenience
pub const ShaderManager = shaders.ShaderManager;
pub const ShaderPair = shaders.ShaderPair;
pub const ShaderInfo = shaders.ShaderInfo;
