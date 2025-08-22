// Gannaway Library Test Barrel File
//
// This file re-exports all tests from Gannaway modules for clean integration
// with the main test suite.

const std = @import("std");

// Working Gannaway modules
test {
    _ = @import("compute.zig");
    _ = @import("state.zig");
    _ = @import("watch.zig");
}

// Note: tests.zig is excluded as it's a standalone comprehensive test suite
