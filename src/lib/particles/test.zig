// Particles Library Test Barrel File
//
// This file re-exports all tests from particle modules for clean integration
// with the main test suite.

const std = @import("std");

// Working particle modules
test {
    _ = @import("duration.zig"); // Fixed: @typeInfo API changes resolved
}

// TODO: Particle system core tests (needs implementation)
// TODO: Game particles tests (needs implementation)
