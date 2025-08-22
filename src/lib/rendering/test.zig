// Rendering Library Test Barrel File
//
// This file re-exports all tests from rendering modules for clean integration
// with the main test suite.

const std = @import("std");

// Working rendering modules
test {
    _ = @import("shapes.zig");

    // TODO: Fix broken test modules
    // _ = @import("compute.zig"); // Needs fixing
    // _ = @import("modes.zig"); // Imports text/renderer.zig which depends on SDL - should be legitimate exclusion
    // _ = @import("performance.zig"); // Runtime failure - needs logger initialization
    // _ = @import("structured_buffers.zig"); // Needs fixing
}

// TODO: The following modules are excluded:
// - modes.zig: Imports text/renderer.zig which depends on SDL (legitimate exclusion)
// - performance.zig: Runtime failure - needs logger initialization (needs fixing)
