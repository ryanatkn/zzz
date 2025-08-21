/// Comprehensive tests for the reactive system
///
/// This module contains integration tests that verify the complete reactive system
/// functionality including signals, derived values, effects, and their interactions.

const std = @import("std");
const convenience = @import("convenience.zig");
const signal_mod = @import("signal.zig");
const derived_mod = @import("derived.zig");
const effect_mod = @import("effect.zig");

test "reactive system with automatic dependency tracking" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize reactive system with context
    try convenience.init(allocator);
    defer convenience.deinit(allocator);

    // Create reactive state ($state)
    var width = try convenience.signal(allocator, f32, 100.0);
    defer width.deinit();

    var height = try convenience.signal(allocator, f32, 50.0);
    defer height.deinit();

    // Store test data for compute function
    const TestData = struct {
        var test_width: *signal_mod.Signal(f32) = undefined;
        var test_height: *signal_mod.Signal(f32) = undefined;
    };

    TestData.test_width = &width;
    TestData.test_height = &height;

    // Create derived area ($derived) - automatically tracks width and height
    var area = try convenience.derived(allocator, f32, struct {
        fn compute() f32 {
            // Reading signals automatically registers them as dependencies
            return TestData.test_width.get() * TestData.test_height.get();
        }
    }.compute);
    defer {
        area.deinit();
        allocator.destroy(area);
    }

    // Test initial values
    try std.testing.expect(width.get() == 100.0);
    try std.testing.expect(height.get() == 50.0);
    try std.testing.expect(area.get() == 5000.0);

    // Update width - area should automatically update
    width.set(200.0);
    try std.testing.expect(area.get() == 10000.0);

    // Batch updates
    convenience.batch(struct {
        fn update() void {
            TestData.test_width.set(300.0);
            TestData.test_height.set(100.0);
        }
    }.update);

    try std.testing.expect(area.get() == 30000.0);
}

test "effect with automatic re-run on dependency change" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try convenience.init(allocator);
    defer convenience.deinit(allocator);

    var counter = try convenience.signal(allocator, i32, 0);
    defer counter.deinit();

    var effect_value: i32 = 0;

    const TestData = struct {
        var test_counter: *signal_mod.Signal(i32) = undefined;
        var test_value: *i32 = undefined;
    };

    TestData.test_counter = &counter;
    TestData.test_value = &effect_value;

    // Create effect ($effect) - automatically tracks counter
    const test_effect = try convenience.createEffect(allocator, struct {
        fn run() void {
            // Reading counter automatically makes this effect depend on it
            TestData.test_value.* = TestData.test_counter.get() * 10;
        }
    }.run);
    defer allocator.destroy(test_effect);

    // Initial run
    try std.testing.expect(effect_value == 0);

    // Update counter - effect should automatically re-run
    counter.set(5);
    try std.testing.expect(effect_value == 50);

    counter.set(10);
    try std.testing.expect(effect_value == 100);
}

test "snapshot functionality" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try convenience.init(allocator);
    defer convenience.deinit(allocator);

    // Test signal snapshot
    var count = try convenience.signal(allocator, i32, 42);
    defer count.deinit();

    const snap1 = count.snapshot();
    try std.testing.expect(snap1 == 42);

    count.set(100);
    const snap2 = convenience.snapshot(count); // Using generic function
    try std.testing.expect(snap2 == 100);
    try std.testing.expect(snap1 == 42); // Old snapshot unchanged

    // Test derived snapshot
    const TestData = struct {
        var test_count: *signal_mod.Signal(i32) = undefined;
    };
    TestData.test_count = &count;

    var doubled = try convenience.derived(allocator, i32, struct {
        fn derive() i32 {
            return TestData.test_count.get() * 2;
        }
    }.derive);
    defer {
        doubled.deinit();
        allocator.destroy(doubled);
    }

    const derived_snap = doubled.snapshot();
    try std.testing.expect(derived_snap == 200); // 100 * 2

    count.set(50);
    const derived_snap2 = convenience.snapshot(doubled); // Using generic function
    try std.testing.expect(derived_snap2 == 100); // 50 * 2
    try std.testing.expect(derived_snap == 200); // Old snapshot unchanged
}

test "effect pre and tracking" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try convenience.init(allocator);
    defer convenience.deinit(allocator);

    var count = try convenience.signal(allocator, i32, 0);
    defer count.deinit();

    var pre_runs: u32 = 0;
    var normal_runs: u32 = 0;
    var tracking_detected: bool = false;

    const TestData = struct {
        var test_count: *signal_mod.Signal(i32) = undefined;
        var test_pre_runs: *u32 = undefined;
        var test_normal_runs: *u32 = undefined;
        var test_tracking: *bool = undefined;
    };

    TestData.test_count = &count;
    TestData.test_pre_runs = &pre_runs;
    TestData.test_normal_runs = &normal_runs;
    TestData.test_tracking = &tracking_detected;

    // Test effect.pre
    const pre_effect = try convenience.createEffectPre(allocator, struct {
        fn run() void {
            _ = TestData.test_count.get();
            TestData.test_pre_runs.* += 1;
            // Test tracking detection
            TestData.test_tracking.* = convenience.isTracking();
        }
    }.run);
    defer allocator.destroy(pre_effect);

    // Test normal effect
    const normal_effect = try convenience.createEffect(allocator, struct {
        fn run() void {
            _ = TestData.test_count.get();
            TestData.test_normal_runs.* += 1;
        }
    }.run);
    defer allocator.destroy(normal_effect);

    // Initial runs
    try std.testing.expect(pre_runs == 1);
    try std.testing.expect(normal_runs == 1);
    try std.testing.expect(tracking_detected == true); // Should detect tracking context

    // Update should trigger both
    count.set(5);
    try std.testing.expect(pre_runs == 2);
    try std.testing.expect(normal_runs == 2);
}

test "effect root scope" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try convenience.init(allocator);
    defer convenience.deinit(allocator);

    var root_runs: u32 = 0;

    const TestData = struct {
        var test_runs: *u32 = undefined;
    };
    TestData.test_runs = &root_runs;

    // Create root scope
    const root = try convenience.createEffectRoot(allocator, struct {
        fn run() void {
            TestData.test_runs.* += 1;
        }
    }.run);
    defer {
        root.deinit();
        allocator.destroy(root);
    }

    // Manually run the root
    root.run();
    try std.testing.expect(root_runs == 1);

    root.run();
    try std.testing.expect(root_runs == 2);

    // Test disposal
    root.dispose();
    try std.testing.expect(root.is_disposed == true);

    // Should not run after disposal
    root.run();
    try std.testing.expect(root_runs == 2); // No change
}