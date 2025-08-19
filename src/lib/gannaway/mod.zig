//! Gannaway - Alternative reactive UI system with explicit control
//!
//! A different approach to reactivity emphasizing:
//! - Explicit notification over automatic tracking
//! - Manual dependency declaration over magic
//! - Direct control over convenience
//! - Predictable behavior over implicit smartness
//!
//! ## Basic Usage
//!
//! ```zig
//! const gannaway = @import("lib/gannaway/mod.zig");
//!
//! // Create state with explicit notification
//! var count = try gannaway.state(allocator, u32, 0);
//! defer count.deinit();
//!
//! // Create computed value with explicit dependencies
//! var doubled = try gannaway.compute(allocator, u32, .{
//!     .dependencies = &[_]*Watchable{count.asWatchable()},
//!     .compute_fn = struct {
//!         fn calc() u32 { return count.get() * 2; }
//!     }.calc,
//! });
//! defer doubled.deinit();
//!
//! // Create watcher with explicit targets
//! var watcher = try gannaway.watch(allocator, .{
//!     .targets = &[_]*Watchable{count.asWatchable()},
//!     .callback = struct {
//!         fn onChange(changed: *const Watchable) void {
//!             std.log.info("{s} changed", .{changed.getName()});
//!         }
//!     }.onChange,
//! });
//! defer watcher.deinit();
//!
//! // Update state - must explicitly notify
//! count.set(5);
//! count.notify();
//!
//! // Or use update helper
//! count.update(10); // set + notify
//! ```

const std = @import("std");

// Import modules
const state_mod = @import("state.zig");
const compute_mod = @import("compute.zig");
const watch_mod = @import("watch.zig");

// Re-export core types
pub const State = state_mod.State;
pub const Compute = compute_mod.Compute;
pub const Watcher = watch_mod.Watcher;
pub const WatchConfig = watch_mod.WatchConfig;

// Re-export interfaces
pub const Watchable = state_mod.Watchable;
pub const Observer = state_mod.Observer;

// Convenience functions
pub const state = State;
pub const compute = compute_mod.compute;
pub const watch = watch_mod.watch;

/// Global context for Gannaway system (future use)
pub const GannawayContext = struct {
    allocator: std.mem.Allocator,
    // Future: scheduler, batch manager, etc.
};

/// Initialize Gannaway system (currently a no-op, reserved for future)
pub fn init(allocator: std.mem.Allocator) !void {
    _ = allocator;
    // Future: Initialize global context, scheduler, etc.
}

/// Deinitialize Gannaway system
pub fn deinit() void {
    // Future: Cleanup global resources
}

// Tests for the public API
test "gannaway basic usage" {
    const allocator = std.testing.allocator;
    
    // Create state
    var count = try state(u32).init(allocator, 0);
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
    
    var source = try state(i32).init(allocator, 10);
    defer source.deinit();
    
    const TestData = struct {
        var test_source: *State(i32) = undefined;
    };
    TestData.test_source = source;
    
    var doubled = try compute(allocator, i32, .{
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
    
    var value = try state(bool).init(allocator, false);
    defer value.deinit();
    
    var watch_count: u32 = 0;
    
    const TestData = struct {
        var count: *u32 = undefined;
    };
    TestData.count = &watch_count;
    
    var watcher = try watch(allocator, .{
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
    var x = try state(f32).init(allocator, 3.0);
    defer x.deinit();
    
    var y = try state(f32).init(allocator, 4.0);
    defer y.deinit();
    
    const TestData = struct {
        var test_x: *State(f32) = undefined;
        var test_y: *State(f32) = undefined;
    };
    TestData.test_x = x;
    TestData.test_y = y;
    
    // Computed
    var hypotenuse = try compute(allocator, f32, .{
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
    
    var watcher = try watch(allocator, .{
        .targets = &[_]*Watchable{ 
            x.asWatchable(), 
            y.asWatchable(), 
            hypotenuse.asWatchable() 
        },
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