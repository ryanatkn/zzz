// Layout Algorithms Test Barrel File
//
// This file re-exports all tests from the algorithms module for clean integration
// with the main test suite.

// Core algorithm implementations
test {
    _ = @import("block.zig");
    _ = @import("flex/mod.zig");
}

// Modular algorithm implementations
test {
    _ = @import("position/test.zig");
    _ = @import("box_model/mod.zig");
    _ = @import("text/mod.zig");
}
