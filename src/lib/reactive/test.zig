// Reactive Library Test Barrel File
//
// This file re-exports all tests from reactive modules for clean integration
// with the main test suite. Does not include standalone integration test suites.

const std = @import("std");

// Working reactive modules
test {
    _ = @import("batch.zig");
    _ = @import("collections.zig");
    _ = @import("derived.zig");
    _ = @import("ref.zig");
    _ = @import("effect.zig");
    _ = @import("mod.zig");
    _ = @import("observer.zig");
    _ = @import("signal.zig");
    _ = @import("utils.zig");

    // Recently fixed modules (tests now pass)
    _ = @import("component.zig"); // Working: fmt slice formatting resolved
    _ = @import("tracking.zig"); // Working: comptime value resolution resolved
}

// TODO: The following modules are excluded:
// - tests.zig: Standalone integration test suite (legitimate exclusion)
// - test_utils.zig: Test utility file (legitimate exclusion)
// - test_expected_behavior.zig: Test utility file (legitimate exclusion)
