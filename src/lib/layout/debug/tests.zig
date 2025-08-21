/// Tests for layout debugging and profiling utilities
///
/// This module contains tests that verify the layout debugging system
/// functionality including debug suite initialization and validation.
const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../core/types.zig");
const debug_suite = @import("debug_suite.zig");
const presets = @import("presets.zig");

// Tests
test "debug suite initialization" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var debug_suite_instance = debug_suite.LayoutDebugSuite.init(allocator, presets.DebugPresets.development);
    defer debug_suite_instance.deinit();

    const stats = debug_suite_instance.getDebugStats();
    try testing.expect(stats.validation_enabled);
    try testing.expect(stats.profiling_enabled);
    try testing.expect(stats.debugging_enabled);
    try testing.expect(stats.layout_health); // Should be healthy initially
}

test "debug suite layout validation" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var debug_suite_instance = debug_suite.LayoutDebugSuite.init(allocator, presets.DebugPresets.development);
    defer debug_suite_instance.deinit();

    // Test with valid layout
    const valid_elements = [_]types.LayoutResult{
        types.LayoutResult{
            .position = math.Vec2{ .x = 0, .y = 0 },
            .size = math.Vec2{ .x = 100, .y = 50 },
            .content = math.Rectangle{
                .position = math.Vec2{ .x = 0, .y = 0 },
                .size = math.Vec2{ .x = 100, .y = 50 },
            },
            .element_index = 0,
        },
    };

    const container = math.Rectangle{
        .position = math.Vec2.ZERO,
        .size = math.Vec2{ .x = 800, .y = 600 },
    };

    try debug_suite_instance.validateLayout(&valid_elements, container);

    const stats = debug_suite_instance.getDebugStats();
    try testing.expect(stats.validation_error_count == 0);
    try testing.expect(stats.layout_health);
}
