// Text Library Test Barrel File
//
// This file re-exports all tests from text modules for clean integration
// with the main test suite.

const std = @import("std");

// Working text modules
test {
    _ = @import("alignment.zig");

    // SDF renderer module tests:
    _ = @import("sdf_renderer.zig");
}
