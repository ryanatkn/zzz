// Layout Test Barrel File
//
// This file re-exports all tests from the layout module for clean integration
// with the main test suite. It ensures all layout tests are discoverable
// and runnable through a single import point.

// Core layout types and interfaces
test {
    _ = @import("core/types.zig");
    _ = @import("core/interface.zig");
    _ = @import("mod.zig"); // Main layout module tests
}

// Algorithm implementations
test {
    _ = @import("algorithms/test.zig"); // Use algorithm test barrel
    _ = @import("algorithms/box_model/layout.zig"); // Include box model tests
    _ = @import("algorithms/box_model/factory.zig"); // Include factory tests
    _ = @import("algorithms/flex/flex_layout.zig"); // Include flex layout tests
    _ = @import("algorithms/text/measurement.zig"); // Include text measurement tests
    _ = @import("algorithms/text/baseline.zig"); // Include text baseline tests
}

// Runtime engine
test {
    _ = @import("runtime/engine.zig");
}

// Note: math.zig was removed - it was just a barrel import with no testable logic

// TODO: Add text and flex algorithm tests once imports are fixed
