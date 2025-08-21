// Layout Test Barrel File
//
// This file re-exports all tests from the layout module for clean integration
// with the main test suite. It ensures all layout tests are discoverable
// and runnable through a single import point.

// Core layout types and interfaces
test {
    _ = @import("core/types.zig");
    _ = @import("core/interface.zig");
}

// Algorithm implementations
test {
    _ = @import("algorithms/block.zig");
    _ = @import("algorithms/flex/mod.zig");
    _ = @import("algorithms/position/mod.zig");
    _ = @import("algorithms/box_model/mod.zig");
    _ = @import("algorithms/text/mod.zig");
}

// Runtime engine and benchmarking
test {
    _ = @import("runtime/engine.zig");
    _ = @import("runtime/benchmark.zig");
}

// Supporting utilities
test {
    _ = @import("measurement/mod.zig");
    _ = @import("arrangement/mod.zig");
    _ = @import("animation/mod.zig");
    _ = @import("debug/mod.zig");
}