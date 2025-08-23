// Core rendering infrastructure - device management and abstraction layers

pub const interface = @import("interface.zig");
pub const gpu = @import("gpu.zig");

// Component modules
pub const device = @import("device.zig");
pub const uniforms = @import("uniforms.zig");
pub const shaders = @import("shaders.zig");
pub const pipelines = @import("pipelines.zig");
pub const frame = @import("frame.zig");
pub const batching = @import("batching.zig");
pub const text_integration = @import("text_integration.zig");

// Re-export main types for convenience
pub const RendererInterface = interface.RendererInterface;
pub const RendererGeneric = interface.RendererGeneric;
pub const GPURenderer = gpu.GPURenderer;

// Re-export key component types
pub const ShaderSet = shaders.ShaderSet;
pub const PipelineSet = pipelines.PipelineSet;
pub const TextIntegration = text_integration.TextIntegration;
