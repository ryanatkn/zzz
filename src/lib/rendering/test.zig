// Rendering Library Test Barrel File
//
// This file re-exports all tests from rendering modules for clean integration
// with the main test suite.

const std = @import("std");

// Working rendering modules (SDL-free)
test {
    _ = @import("primitives/shapes.zig");
    _ = @import("primitives/vector_utils.zig");
    _ = @import("optimization/performance.zig"); // Fixed: Now uses optional logger access
    _ = @import("core/uniforms.zig"); // Pure data structures, no dependencies

    // TODO: Fix broken test modules
    // _ = @import("optimization/modes.zig"); // Imports text/renderer.zig which depends on SDL - should be legitimate exclusion
}

// Note: compute.zig and structured_buffers.zig were removed - they were unused GPU compute infrastructure

// TODO: The following modules are excluded from tests due to SDL dependencies:
// - modes.zig: Imports text/renderer.zig which depends on SDL (legitimate exclusion)
// - All core/ modules except uniforms.zig: Depend on SDL GPU API
// - All primitive renderers: Depend on SDL for GPU operations
// - interface.zig: Uses SDL types in renderer interface
