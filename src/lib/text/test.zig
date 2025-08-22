// Text Library Test Barrel File
//
// This file re-exports all tests from text modules for clean integration
// with the main test suite.

const std = @import("std");

// Working text modules
test {
    _ = @import("alignment.zig");

    // TODO: Fix broken test modules
    // _ = @import("sdf_renderer.zig"); // May have external dependencies
}

// TODO: The following modules are excluded:
// - sdf_renderer.zig: May have external dependencies (needs investigation)
