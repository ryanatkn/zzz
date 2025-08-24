// Rendering capability module - GPU-accelerated 2D rendering with procedural graphics
//
// This module provides a capability-based organization of rendering functionality:
// - Core: Device management and renderer abstraction
// - Resources: Shader and material management
// - Primitives: Basic shape drawing and vector graphics
// - Systems: High-level batch renderers
// - UI: User interface drawing patterns
// - Optimization: Performance monitoring and rendering strategies

// Core rendering infrastructure
pub const core = @import("core/mod.zig");

// Resource management
pub const resources = @import("resources/mod.zig");

// Basic drawing primitives
pub const primitives = @import("primitives/mod.zig");

// High-level rendering systems
pub const systems = @import("systems/mod.zig");

// UI drawing patterns
pub const ui = @import("ui/mod.zig");

// Performance and optimization
pub const optimization = @import("optimization/mod.zig");

// Spatial coordinate and transformation systems
pub const spatial = @import("spatial/mod.zig");

// Convenience re-exports for common usage
pub const GPURenderer = core.GPURenderer;
pub const RendererInterface = core.RendererInterface;
pub const RendererGeneric = core.RendererGeneric;
pub const ShaderManager = resources.ShaderManager;
pub const EntityBatchRenderer = systems.EntityBatchRenderer;
pub const PerformanceMonitor = optimization.PerformanceMonitor;
pub const RenderingMode = optimization.RenderingMode;
pub const Viewport = spatial.Viewport;
pub const CoordinateContext = spatial.CoordinateContext;

// Texture and format utilities
pub const texture_formats = @import("texture_formats.zig");
pub const TextureFormat = texture_formats.TextureFormat;
pub const RGBAPixel = texture_formats.RGBAPixel;
pub const TextureTransfer = texture_formats.TextureTransfer;
pub const TextureCreation = texture_formats.TextureCreation;

// For backward compatibility during transition
pub const gpu = core.gpu;
pub const interface = core.interface;
pub const shaders = resources.shaders;
pub const shapes = primitives.shapes;
pub const vector_utils = primitives.vector_utils;
pub const entity_renderer = systems.entity_renderer;
pub const drawing = ui.drawing;
pub const performance = optimization.performance;
pub const modes = optimization.modes;
