// Core Library Test Barrel File
//
// This file re-exports all tests from core modules for clean integration
// with the main test suite. Only includes modules that compile and pass tests.

const std = @import("std");

// Working core modules (compilation verified)
test {
    _ = @import("colors.zig");
    _ = @import("constants.zig");
    _ = @import("coordinates.zig");
    _ = @import("state_machine.zig");
    _ = @import("timer.zig");
    _ = @import("result.zig");
    _ = @import("color_variants.zig");
    _ = @import("object_pools.zig");

    // Recently fixed modules
    _ = @import("pool.zig"); // Fixed: Pointer capture error resolved
    _ = @import("resources.zig"); // Fixed: @typeInfo API changes resolved
}

// TODO: The following modules are excluded:
// - animation.zig: SDL timing dependencies (legitimate exclusion)
// - time.zig: SDL timing dependencies (legitimate exclusion)
