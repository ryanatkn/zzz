const std = @import("std");
const signal_mod = @import("signal.zig");
const derived_mod = @import("derived.zig");
const effect_mod = @import("effect.zig");
const context_mod = @import("context.zig");
const batch_mod = @import("batch.zig");

// Test helper to count calls
pub const CallCounter = struct {
    count: u32 = 0,
    name: []const u8 = "",
    
    pub fn call(self: *@This()) void {
        self.count += 1;
        if (self.name.len > 0) {
            std.debug.print("[{s}] Called: {}\n", .{ self.name, self.count });
        }
    }
    
    pub fn reset(self: *@This()) void {
        self.count = 0;
    }
    
    pub fn expect(self: *const @This(), expected: u32) !void {
        if (self.count != expected) {
            std.debug.print("[{s}] Expected {} calls, got {}\n", .{ self.name, expected, self.count });
            return error.TestUnexpectedResult;
        }
    }
};

// Issue 1: Batching doesn't properly defer notifications
test "issue: batching runs effects multiple times" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try context_mod.initContext(allocator);
    defer context_mod.deinitContext(allocator);
    try batch_mod.initGlobalBatcher(allocator);
    defer batch_mod.deinitGlobalBatcher(allocator);
    
    var counter = CallCounter{ .name = "effect" };
    
    var x = try signal_mod.Signal(i32).init(allocator, 1);
    defer x.deinit();
    var y = try signal_mod.Signal(i32).init(allocator, 2);
    defer y.deinit();
    
    const TestData = struct {
        var x_ref: *signal_mod.Signal(i32) = undefined;
        var y_ref: *signal_mod.Signal(i32) = undefined;
        var counter_ref: *CallCounter = undefined;
    };
    
    TestData.x_ref = &x;
    TestData.y_ref = &y;
    TestData.counter_ref = &counter;
    
    const eff = try effect_mod.createEffect(allocator, struct {
        fn run() void {
            _ = TestData.x_ref.get();
            _ = TestData.y_ref.get();
            TestData.counter_ref.call();
        }
    }.run);
    defer allocator.destroy(eff);
    
    std.debug.print("\n=== Batching Issue Test ===\n", .{});
    
    // Initial run
    try counter.expect(1);
    counter.reset();
    
    // Batch two changes
    std.debug.print("Starting batch...\n", .{});
    batch_mod.batch(struct {
        fn update() void {
            std.debug.print("  Setting x to 10\n", .{});
            TestData.x_ref.set(10);
            std.debug.print("  Setting y to 20\n", .{});
            TestData.y_ref.set(20);
        }
    }.update);
    std.debug.print("Batch complete\n", .{});
    
    // ISSUE: Effect runs twice (once per signal) instead of once
    try counter.expect(1); // Currently fails with 2
}

// Issue 2: Derived values might notify even when value doesn't change
test "issue: derived notifies without value change" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try context_mod.initContext(allocator);
    defer context_mod.deinitContext(allocator);
    
    var effect_counter = CallCounter{ .name = "effect" };
    var derive_counter = CallCounter{ .name = "derive" };
    
    var source = try signal_mod.Signal(i32).init(allocator, 10);
    defer source.deinit();
    
    const TestData = struct {
        var src: *signal_mod.Signal(i32) = undefined;
        var derived_val: *derived_mod.Derived(bool) = undefined;
        var derive_count: *CallCounter = undefined;
        var effect_count: *CallCounter = undefined;
    };
    
    TestData.src = &source;
    TestData.derive_count = &derive_counter;
    TestData.effect_count = &effect_counter;
    
    // Derived that returns same value for different inputs
    var is_positive = try derived_mod.derived(allocator, bool, struct {
        fn compute() bool {
            TestData.derive_count.call();
            return TestData.src.get() > 0;
        }
    }.compute);
    defer {
        is_positive.deinit();
        allocator.destroy(is_positive);
    }
    TestData.derived_val = is_positive;
    
    // Effect that depends on derived
    const eff = try effect_mod.createEffect(allocator, struct {
        fn run() void {
            _ = TestData.derived_val.get();
            TestData.effect_count.call();
        }
    }.run);
    defer allocator.destroy(eff);
    
    std.debug.print("\n=== Derived Notification Issue Test ===\n", .{});
    
    // Initial state
    try derive_counter.expect(1);
    try effect_counter.expect(1);
    
    derive_counter.reset();
    effect_counter.reset();
    
    // Change source from 10 to 20 (both positive, so derived value stays true)
    std.debug.print("Changing source from 10 to 20 (both positive)...\n", .{});
    source.set(20);
    
    // Derived should recompute
    _ = is_positive.get();
    try derive_counter.expect(1);
    
    // ISSUE: Effect might run even though derived value didn't change (true -> true)
    // Ideally, effect should not run if derived value stays the same
    std.debug.print("Effect ran {} times (should be 0 since value didn't change)\n", .{effect_counter.count});
}

// Issue 3: Diamond dependency might cause double updates
test "issue: diamond dependency double update" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try context_mod.initContext(allocator);
    defer context_mod.deinitContext(allocator);
    
    //     source
    //     /    \
    //  left    right
    //     \    /
    //      sum
    //       |
    //    effect
    
    var effect_counter = CallCounter{ .name = "effect" };
    var sum_counter = CallCounter{ .name = "sum_derive" };
    
    var source = try signal_mod.Signal(i32).init(allocator, 1);
    defer source.deinit();
    
    const TestData = struct {
        var src: *signal_mod.Signal(i32) = undefined;
        var left: *derived_mod.Derived(i32) = undefined;
        var right: *derived_mod.Derived(i32) = undefined;
        var sum_count: *CallCounter = undefined;
        var effect_count: *CallCounter = undefined;
    };
    
    TestData.src = &source;
    TestData.sum_count = &sum_counter;
    TestData.effect_count = &effect_counter;
    
    // Left branch
    var left = try derived_mod.derived(allocator, i32, struct {
        fn compute() i32 {
            return TestData.src.get() * 2;
        }
    }.compute);
    defer {
        left.deinit();
        allocator.destroy(left);
    }
    TestData.left = left;
    
    // Right branch
    var right = try derived_mod.derived(allocator, i32, struct {
        fn compute() i32 {
            return TestData.src.get() * 3;
        }
    }.compute);
    defer {
        right.deinit();
        allocator.destroy(right);
    }
    TestData.right = right;
    
    // Sum depends on both branches
    var sum = try derived_mod.derived(allocator, i32, struct {
        fn compute() i32 {
            TestData.sum_count.call();
            return TestData.left.get() + TestData.right.get();
        }
    }.compute);
    defer {
        sum.deinit();
        allocator.destroy(sum);
    }
    
    const TestDataSum = struct {
        var sum_ref: *derived_mod.Derived(i32) = undefined;
    };
    TestDataSum.sum_ref = sum;
    
    // Effect depends on sum
    const eff = try effect_mod.createEffect(allocator, struct {
        fn run() void {
            _ = TestDataSum.sum_ref.get();
            TestData.effect_count.call();
        }
    }.run);
    defer allocator.destroy(eff);
    
    std.debug.print("\n=== Diamond Dependency Issue Test ===\n", .{});
    
    // Initial state
    try sum_counter.expect(1);
    try effect_counter.expect(1);
    
    sum_counter.reset();
    effect_counter.reset();
    
    // Change source
    std.debug.print("Changing source from 1 to 2...\n", .{});
    batch_mod.batch(struct {
        fn update() void {
            TestData.src.set(2);
        }
    }.update);
    
    // Access sum to trigger computation
    _ = sum.get();
    
    // ISSUE: Sum might derive twice (once when left updates, once when right updates)
    std.debug.print("Sum derived {} times (should be 1)\n", .{sum_counter.count});
    std.debug.print("Effect ran {} times (should be 1)\n", .{effect_counter.count});
    
    // Even if we don't have double computation, we might have double notification
    try sum_counter.expect(1);
    try effect_counter.expect(1);
}

// Issue 4: Peek/untrack functionality is missing
test "issue: no way to read without tracking" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try context_mod.initContext(allocator);
    defer context_mod.deinitContext(allocator);
    
    var effect_counter = CallCounter{ .name = "effect" };
    
    var tracked = try signal_mod.Signal(i32).init(allocator, 1);
    defer tracked.deinit();
    var untracked = try signal_mod.Signal(i32).init(allocator, 2);
    defer untracked.deinit();
    
    const TestData = struct {
        var tracked_ref: *signal_mod.Signal(i32) = undefined;
        var untracked_ref: *signal_mod.Signal(i32) = undefined;
        var counter: *CallCounter = undefined;
    };
    
    TestData.tracked_ref = &tracked;
    TestData.untracked_ref = &untracked;
    TestData.counter = &effect_counter;
    
    const eff = try effect_mod.createEffect(allocator, struct {
        fn run() void {
            _ = TestData.tracked_ref.get(); // Should create dependency
            
            // Use peek to read without tracking dependency
            _ = TestData.untracked_ref.peek(); // Should NOT create dependency
            
            TestData.counter.call();
        }
    }.run);
    defer allocator.destroy(eff);
    
    std.debug.print("\n=== Peek/Untrack Issue Test ===\n", .{});
    
    // Initial run
    try effect_counter.expect(1);
    effect_counter.reset();
    
    // Change tracked signal - should trigger
    tracked.set(10);
    try effect_counter.expect(1);
    effect_counter.reset();
    
    // Change untracked signal - should NOT trigger
    std.debug.print("Changing untracked signal...\n", .{});
    untracked.set(20);
    std.debug.print("Effect ran {} times (should be 0 for untracked)\n", .{effect_counter.count});
    
    // Should not trigger since we used peek() instead of get()
    try effect_counter.expect(0);
}

// Issue 5: Excessive re-derivation in chains
test "issue: derived chains might recompute unnecessarily" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try context_mod.initContext(allocator);
    defer context_mod.deinitContext(allocator);
    
    var a_derives: u32 = 0;
    var b_derives: u32 = 0;
    var c_derives: u32 = 0;
    
    var source = try signal_mod.Signal(i32).init(allocator, 1);
    defer source.deinit();
    
    const TestData = struct {
        var src: *signal_mod.Signal(i32) = undefined;
        var a: *derived_mod.Derived(i32) = undefined;
        var b: *derived_mod.Derived(i32) = undefined;
        var a_count: *u32 = undefined;
        var b_count: *u32 = undefined;
        var c_count: *u32 = undefined;
    };
    
    TestData.src = &source;
    TestData.a_count = &a_derives;
    TestData.b_count = &b_derives;
    TestData.c_count = &c_derives;
    
    // Chain: source -> a -> b -> c
    var a = try derived_mod.derived(allocator, i32, struct {
        fn compute() i32 {
            TestData.a_count.* += 1;
            return TestData.src.get() * 2;
        }
    }.compute);
    defer {
        a.deinit();
        allocator.destroy(a);
    }
    TestData.a = a;
    
    var b = try derived_mod.derived(allocator, i32, struct {
        fn compute() i32 {
            TestData.b_count.* += 1;
            return TestData.a.get() + 10;
        }
    }.compute);
    defer {
        b.deinit();
        allocator.destroy(b);
    }
    TestData.b = b;
    
    var c = try derived_mod.derived(allocator, i32, struct {
        fn compute() i32 {
            TestData.c_count.* += 1;
            return TestData.b.get() * 3;
        }
    }.compute);
    defer {
        c.deinit();
        allocator.destroy(c);
    }
    
    std.debug.print("\n=== Derived Chain Recomputation Test ===\n", .{});
    
    // Initial computation
    _ = c.get();
    std.debug.print("Initial: a={}, b={}, c={} derives\n", .{ a_derives, b_derives, c_derives });
    
    // Reset
    a_derives = 0;
    b_derives = 0;
    c_derives = 0;
    
    // Change source
    source.set(2);
    
    // Access only c
    _ = c.get();
    
    std.debug.print("After change: a={}, b={}, c={} derives\n", .{ a_derives, b_derives, c_derives });
    
    // Each should derive exactly once
    try std.testing.expect(a_derives == 1);
    try std.testing.expect(b_derives == 1);
    try std.testing.expect(c_derives == 1);
}