// Hex Game Test Barrel File
//
// This file re-exports all tests from hex game modules for clean integration
// with the main test suite.

const std = @import("std");

// Working hex game modules
test {
    _ = @import("factions.zig");
}
