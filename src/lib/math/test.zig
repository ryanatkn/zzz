// Math Library Test Barrel File
//
// This file re-exports all tests from math modules for clean integration
// with the main test suite.

const std = @import("std");

// All math modules (compilation verified)
test {
    _ = @import("easing.zig");
    _ = @import("interpolation.zig");
    _ = @import("scalar.zig");
    _ = @import("shapes.zig");
    _ = @import("vec2.zig");
    _ = @import("color.zig");
    _ = @import("waves.zig");
    _ = @import("geometry.zig");
    _ = @import("smoothing.zig");
    _ = @import("layout.zig");
    _ = @import("mod.zig");
}
