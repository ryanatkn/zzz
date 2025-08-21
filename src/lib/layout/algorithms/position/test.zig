// Position Algorithm Test Barrel File
//
// This file re-exports all tests from the position module for clean integration
// with the main test suite.

// Core positioning utilities and types
test {
    _ = @import("shared.zig");
}

// Position algorithm implementations
test {
    _ = @import("absolute.zig");
    _ = @import("relative.zig");
    _ = @import("sticky.zig");
}
