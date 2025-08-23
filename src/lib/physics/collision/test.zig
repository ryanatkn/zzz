//! Collision Detection Test Barrel
//!
//! Imports all collision detection modules to run their tests.
//! This provides a central place to test the entire collision system.

const std = @import("std");

// Import all collision modules to run their tests
test {
    // Core modules
    _ = @import("types.zig");
    _ = @import("detection.zig");
    _ = @import("detailed.zig");
    _ = @import("spatial.zig");
    _ = @import("batch.zig");
    _ = @import("utils.zig");

    // Primitive collision modules
    _ = @import("primitives/mod.zig");
    _ = @import("primitives/circle.zig");
    _ = @import("primitives/rectangle.zig");
    _ = @import("primitives/line.zig");
    _ = @import("primitives/point.zig");

    // Test modules
    _ = @import("test_utils.zig");
    _ = @import("edge_cases_test.zig");
    _ = @import("integration_test.zig");
    _ = @import("property_test.zig");
}
