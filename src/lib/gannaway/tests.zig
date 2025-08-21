/// Tests for the Gannaway alternative reactive system
///
/// This module contains integration tests that verify the complete Gannaway
/// reactive system functionality including state, compute, and watch capabilities.
const std = @import("std");
const state_mod = @import("state.zig");
const compute_mod = @import("compute.zig");
const watch_mod = @import("watch.zig");
const convenience = @import("convenience.zig");

const State = state_mod.State;
const Watchable = state_mod.Watchable;

// Tests for the public API
test "gannaway basic usage" {
    const allocator = std.testing.allocator;

    // Create state
    var count = try convenience.state(u32).init(allocator, 0);
    defer count.deinit();

    try std.testing.expect(count.get() == 0);

    // Update with explicit notification
    count.set(5);
    try std.testing.expect(count.get() == 5);

    count.update(10); // set + notify
    try std.testing.expect(count.get() == 10);
}

test "gannaway compute integration" {
    const allocator = std.testing.allocator;

    var source = try convenience.state(i32).init(allocator, 10);
    defer source.deinit();

    const TestData = struct {
        var test_source: *State(i32) = undefined;
    };
    TestData.test_source = source;

    var doubled = try convenience.compute(allocator, i32, .{
        .dependencies = &[_]*Watchable{source.asWatchable()},
        .compute_fn = struct {
            fn calc() i32 {
                return TestData.test_source.get() * 2;
            }
        }.calc,
    });
    defer doubled.deinit();

    try std.testing.expect(doubled.get() == 20);

    source.update(15);
    try std.testing.expect(doubled.get() == 30);
}

test "gannaway watch integration" {
    const allocator = std.testing.allocator;

    var value = try convenience.state(bool).init(allocator, false);
    defer value.deinit();

    var watch_count: u32 = 0;

    const TestData = struct {
        var count: *u32 = undefined;
    };
    TestData.count = &watch_count;

    var watcher = try convenience.watch(allocator, .{
        .targets = &[_]*Watchable{value.asWatchable()},
        .callback = struct {
            fn onChange(changed: *const Watchable) void {
                _ = changed;
                TestData.count.* += 1;
            }
        }.onChange,
    });
    defer watcher.deinit();

    try value.subscribe(watcher.asObserver());

    // Initial callback
    try std.testing.expect(watch_count == 1);

    // Update triggers callback
    value.update(true);
    try std.testing.expect(watch_count == 2);
}

test "gannaway complete example" {
    const allocator = std.testing.allocator;

    // State
    var x = try convenience.state(f32).init(allocator, 3.0);
    defer x.deinit();

    var y = try convenience.state(f32).init(allocator, 4.0);
    defer y.deinit();

    const TestData = struct {
        var test_x: *State(f32) = undefined;
        var test_y: *State(f32) = undefined;
    };
    TestData.test_x = x;
    TestData.test_y = y;

    // Computed
    var hypotenuse = try convenience.compute(allocator, f32, .{
        .dependencies = &[_]*Watchable{ x.asWatchable(), y.asWatchable() },
        .compute_fn = struct {
            fn calc() f32 {
                const x_val = TestData.test_x.get();
                const y_val = TestData.test_y.get();
                return @sqrt(x_val * x_val + y_val * y_val);
            }
        }.calc,
        .name = "hypotenuse",
    });
    defer hypotenuse.deinit();

    // Watch
    var changes = std.ArrayList([]const u8).init(allocator);
    defer changes.deinit();

    const WatchData = struct {
        var change_list: *std.ArrayList([]const u8) = undefined;
    };
    WatchData.change_list = &changes;

    var watcher = try convenience.watch(allocator, .{
        .targets = &[_]*Watchable{ x.asWatchable(), y.asWatchable(), hypotenuse.asWatchable() },
        .callback = struct {
            fn onChange(changed: *const Watchable) void {
                WatchData.change_list.append(changed.getName()) catch {};
            }
        }.onChange,
    });
    defer watcher.deinit();

    try x.subscribe(watcher.asObserver());
    try y.subscribe(watcher.asObserver());

    // Initial values
    try std.testing.expect(hypotenuse.get() == 5.0);
    try std.testing.expect(changes.items.len == 3); // Initial callbacks

    // Update x
    x.update(5.0);
    try std.testing.expect(hypotenuse.get() == @sqrt(41.0));

    // Update y
    y.update(12.0);
    try std.testing.expect(hypotenuse.get() == 13.0);
}
