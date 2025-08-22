// Physics Library Test Barrel File
//
// This file re-exports all tests from physics modules for clean integration
// with the main test suite.

const std = @import("std");

// Working physics modules
test {
    _ = @import("shapes.zig");

    // Recently fixed modules
    _ = @import("queries.zig"); // Working: test logic errors resolved
}

// TODO: The following modules are excluded:
// (none currently excluded)
