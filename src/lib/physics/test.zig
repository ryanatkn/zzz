// Physics Library Test Barrel File
//
// This file re-exports all tests from physics modules for clean integration
// with the main test suite.

const std = @import("std");

// Working physics modules
test {
    _ = @import("collision/test.zig");
    _ = @import("queries.zig");
    _ = @import("shapes.zig");
}

// TODO: The following modules are excluded:
// (none currently excluded)
