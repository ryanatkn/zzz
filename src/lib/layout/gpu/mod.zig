// GPU layout system with compute shader acceleration
// Import core implementations
const structures_mod = @import("structures.zig");
const engine_mod = @import("engine.zig");

// Re-export GPU data structures
pub const UIElement = structures_mod.UIElement;
pub const LayoutConstraint = structures_mod.LayoutConstraint;
pub const SpringState = structures_mod.SpringState;
pub const FrameData = structures_mod.FrameData;

// Re-export main engine
pub const GPULayoutEngine = engine_mod.GPULayoutEngine;

// Hybrid CPU/GPU layout management
pub const hybrid = @import("hybrid.zig");

// Re-export tests
pub usingnamespace @import("tests.zig");
