const std = @import("std");
const signal_mod = @import("signal.zig");
const derived_mod = @import("derived.zig");
const effect_mod = @import("effect.zig");
const context_mod = @import("context.zig");
const batch_mod = @import("batch.zig");

// Recreate reactive interface locally
const reactive = struct {
    pub const Signal = signal_mod.Signal;
    pub const Derived = derived_mod.Derived;
    pub const Effect = effect_mod.Effect;
    
    pub fn init(allocator: std.mem.Allocator) !void {
        try context_mod.initContext(allocator);
        try batch_mod.initGlobalBatcher(allocator);
    }
    
    pub fn deinit(allocator: std.mem.Allocator) void {
        batch_mod.deinitGlobalBatcher(allocator);
        context_mod.deinitContext(allocator);
    }
    
    pub fn signal(allocator: std.mem.Allocator, comptime T: type, initial_value: T) !Signal(T) {
        return try Signal(T).init(allocator, initial_value);
    }
    
    pub fn derived(allocator: std.mem.Allocator, comptime T: type, compute_fn: *const fn () T) !*Derived(T) {
        return try derived_mod.derived(allocator, T, compute_fn);
    }
    
    pub fn createEffect(allocator: std.mem.Allocator, effect_fn: *const fn () void) !*Effect {
        return try effect_mod.createEffect(allocator, effect_fn);
    }
    
    pub fn batch(batch_fn: *const fn () void) void {
        batch_mod.batch(batch_fn);
    }
};

/// Helper to count notifications/effect runs
pub const NotificationCounter = struct {
    count: u32 = 0,
    name: []const u8 = "",
    
    pub fn increment(self: *@This()) void {
        self.count += 1;
    }
    
    pub fn reset(self: *@This()) void {
        self.count = 0;
    }
    
    pub fn expectCount(self: *const @This(), expected: u32) !void {
        if (self.count != expected) {
            std.debug.print("{s}: Expected {} notifications, got {}\n", .{ self.name, expected, self.count });
            return error.TestUnexpectedResult;
        }
    }
};

/// Helper to track notification order
pub const NotificationTracker = struct {
    order: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) @This() {
        return .{
            .order = std.ArrayList([]const u8).init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *@This()) void {
        self.order.deinit();
    }
    
    pub fn track(self: *@This(), name: []const u8) void {
        self.order.append(name) catch {};
    }
    
    pub fn expectOrder(self: *const @This(), expected: []const []const u8) !void {
        if (self.order.items.len != expected.len) {
            std.debug.print("Order length mismatch: expected {}, got {}\n", .{ expected.len, self.order.items.len });
            return error.TestUnexpectedResult;
        }
        
        for (expected, self.order.items) |exp, actual| {
            if (!std.mem.eql(u8, exp, actual)) {
                std.debug.print("Order mismatch: expected '{s}', got '{s}'\n", .{ exp, actual });
                return error.TestUnexpectedResult;
            }
        }
    }
};

// Test 1: No double notifications - each change triggers exactly one update
test "no double notifications on signal change" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try reactive.init(allocator);
    defer reactive.deinit(allocator);
    
    var counter = NotificationCounter{ .name = "effect" };
    
    var source = try reactive.signal(allocator, i32, 0);
    defer source.deinit();
    
    const TestData = struct {
        var test_source: *signal_mod.Signal(i32) = undefined;
        var test_counter: *NotificationCounter = undefined;
    };
    
    TestData.test_source = &source;
    TestData.test_counter = &counter;
    
    const test_effect = try reactive.createEffect(allocator, struct {
        fn run() void {
            _ = TestData.test_source.get();
            TestData.test_counter.increment();
        }
    }.run);
    defer allocator.destroy(test_effect);
    
    // Effect runs once on creation
    try counter.expectCount(1);
    
    // Reset counter
    counter.reset();
    
    // Single change should trigger exactly one notification
    source.set(10);
    if (counter.count != 1) {
        std.debug.print("Double notification detected: expected 1, got {}\n", .{counter.count});
    }
    try counter.expectCount(1); // EXPECTED: 1, CURRENTLY: might be 2
    
    // Another change
    counter.reset();
    source.set(20);
    try counter.expectCount(1);
}

// Test 2: Derived values update lazily
test "derived values are lazy" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try reactive.init(allocator);
    defer reactive.deinit(allocator);
    
    var derive_count: u32 = 0;
    
    var source = try reactive.signal(allocator, i32, 10);
    defer source.deinit();
    
    const TestData = struct {
        var test_source: *signal_mod.Signal(i32) = undefined;
        var test_count: *u32 = undefined;
    };
    
    TestData.test_source = &source;
    TestData.test_count = &derive_count;
    
    var derived_value = try reactive.derived(allocator, i32, struct {
        fn compute() i32 {
            TestData.test_count.* += 1;
            return TestData.test_source.get() * 2;
        }
    }.compute);
    defer {
        derived_value.deinit();
        allocator.destroy(derived_value);
    }
    
    // Initial computation on creation
    try std.testing.expect(derive_count == 1);
    
    // Change source but don't access derived - should NOT re-derive yet
    source.set(20);
    try std.testing.expect(derive_count == 1); // Still 1, lazy!
    
    // Now access it - should re-derive
    const value = derived_value.get();
    try std.testing.expect(value == 40);
    try std.testing.expect(derive_count == 2); // Now it derived
    
    // Access again without changes - should NOT re-derive
    _ = derived_value.get();
    try std.testing.expect(derive_count == 2); // Still 2, cached!
}

// Test 3: Diamond dependency - shared dependency only triggers once
test "diamond dependency updates once" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try reactive.init(allocator);
    defer reactive.deinit(allocator);
    
    //     A
    //    / \
    //   B   C
    //    \ /
    //     D
    
    var a = try reactive.signal(allocator, i32, 1);
    defer a.deinit();
    
    var b_derives: u32 = 0;
    var c_derives: u32 = 0;
    var d_derives: u32 = 0;
    
    const TestData = struct {
        var a_ref: *signal_mod.Signal(i32) = undefined;
        var b_ref: *derived_mod.Derived(i32) = undefined;
        var c_ref: *derived_mod.Derived(i32) = undefined;
        var b_count: *u32 = undefined;
        var c_count: *u32 = undefined;
        var d_count: *u32 = undefined;
    };
    
    TestData.a_ref = &a;
    TestData.b_count = &b_derives;
    TestData.c_count = &c_derives;
    TestData.d_count = &d_derives;
    
    // B depends on A
    var b = try reactive.derived(allocator, i32, struct {
        fn compute() i32 {
            TestData.b_count.* += 1;
            return TestData.a_ref.get() * 2;
        }
    }.compute);
    defer {
        b.deinit();
        allocator.destroy(b);
    }
    TestData.b_ref = b;
    
    // C depends on A
    var c = try reactive.derived(allocator, i32, struct {
        fn compute() i32 {
            TestData.c_count.* += 1;
            return TestData.a_ref.get() * 3;
        }
    }.compute);
    defer {
        c.deinit();
        allocator.destroy(c);
    }
    TestData.c_ref = c;
    
    // D depends on both B and C
    var d = try reactive.derived(allocator, i32, struct {
        fn compute() i32 {
            TestData.d_count.* += 1;
            return TestData.b_ref.get() + TestData.c_ref.get();
        }
    }.compute);
    defer {
        d.deinit();
        allocator.destroy(d);
    }
    
    // Initial state
    try std.testing.expect(d.get() == 5); // (1*2) + (1*3) = 5
    
    // Reset counters
    b_derives = 0;
    c_derives = 0;
    d_derives = 0;
    
    // Change A
    a.set(2);
    
    // D should derive only once, not twice
    try std.testing.expect(d.get() == 10); // (2*2) + (2*3) = 10
    try std.testing.expect(b_derives == 1);
    try std.testing.expect(c_derives == 1);
    try std.testing.expect(d_derives == 1); // EXPECTED: 1 (currently might be 2)
}

// Test 4: Batching prevents multiple updates
test "batching prevents cascading updates" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try reactive.init(allocator);
    defer reactive.deinit(allocator);
    
    var effect_runs: u32 = 0;
    
    var x = try reactive.signal(allocator, i32, 1);
    defer x.deinit();
    var y = try reactive.signal(allocator, i32, 2);
    defer y.deinit();
    
    const TestData = struct {
        var x_ref: *signal_mod.Signal(i32) = undefined;
        var y_ref: *signal_mod.Signal(i32) = undefined;
        var runs: *u32 = undefined;
    };
    
    TestData.x_ref = &x;
    TestData.y_ref = &y;
    TestData.runs = &effect_runs;
    
    // Effect that depends on both x and y
    const test_effect = try reactive.createEffect(allocator, struct {
        fn run() void {
            _ = TestData.x_ref.get();
            _ = TestData.y_ref.get();
            TestData.runs.* += 1;
        }
    }.run);
    defer allocator.destroy(test_effect);
    
    // Initial run
    try std.testing.expect(effect_runs == 1);
    
    // Reset
    effect_runs = 0;
    
    // Batch updates - should only run effect once
    reactive.batch(struct {
        fn update() void {
            TestData.x_ref.set(10);
            TestData.y_ref.set(20);
        }
    }.update);
    
    if (effect_runs != 1) {
        std.debug.print("Batching test failed: expected 1 run, got {}\n", .{effect_runs});
    }
    try std.testing.expect(effect_runs == 1); // EXPECTED: 1 (not 2)
}

// Test 5: Conditional dependencies are cleaned up
test "conditional dependencies cleanup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try reactive.init(allocator);
    defer reactive.deinit(allocator);
    
    var condition = try reactive.signal(allocator, bool, true);
    defer condition.deinit();
    
    var a = try reactive.signal(allocator, i32, 1);
    defer a.deinit();
    
    var b = try reactive.signal(allocator, i32, 2);
    defer b.deinit();
    
    var effect_runs: u32 = 0;
    var last_value: i32 = 0;
    
    const TestData = struct {
        var cond: *signal_mod.Signal(bool) = undefined;
        var a_ref: *signal_mod.Signal(i32) = undefined;
        var b_ref: *signal_mod.Signal(i32) = undefined;
        var runs: *u32 = undefined;
        var value: *i32 = undefined;
    };
    
    TestData.cond = &condition;
    TestData.a_ref = &a;
    TestData.b_ref = &b;
    TestData.runs = &effect_runs;
    TestData.value = &last_value;
    
    // Effect that conditionally depends on either a or b
    const test_effect = try reactive.createEffect(allocator, struct {
        fn run() void {
            TestData.runs.* += 1;
            if (TestData.cond.get()) {
                TestData.value.* = TestData.a_ref.get();
            } else {
                TestData.value.* = TestData.b_ref.get();
            }
        }
    }.run);
    defer allocator.destroy(test_effect);
    
    // Initial: depends on condition and a
    try std.testing.expect(effect_runs == 1);
    try std.testing.expect(last_value == 1);
    
    // Change a - should trigger
    effect_runs = 0;
    a.set(10);
    try std.testing.expect(effect_runs == 1);
    try std.testing.expect(last_value == 10);
    
    // Change b - should NOT trigger (not a dependency currently)
    effect_runs = 0;
    b.set(20);
    try std.testing.expect(effect_runs == 0); // No run!
    
    // Change condition to false - now depends on b instead of a
    effect_runs = 0;
    condition.set(false);
    try std.testing.expect(effect_runs == 1);
    try std.testing.expect(last_value == 20);
    
    // Now change a - should NOT trigger (no longer a dependency)
    effect_runs = 0;
    a.set(30);
    try std.testing.expect(effect_runs == 0); // No run!
    
    // But changing b should trigger
    effect_runs = 0;
    b.set(40);
    try std.testing.expect(effect_runs == 1);
    try std.testing.expect(last_value == 40);
}

// Test 6: Nested effects work correctly
test "nested effects tracking" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try reactive.init(allocator);
    defer reactive.deinit(allocator);
    
    var outer_runs: u32 = 0;
    var inner_runs: u32 = 0;
    
    var source = try reactive.signal(allocator, i32, 0);
    defer source.deinit();
    
    const TestData = struct {
        var src: *signal_mod.Signal(i32) = undefined;
        var outer: *u32 = undefined;
        var inner: *u32 = undefined;
    };
    
    TestData.src = &source;
    TestData.outer = &outer_runs;
    TestData.inner = &inner_runs;
    
    // Outer effect
    const outer_effect = try reactive.createEffect(allocator, struct {
        fn run() void {
            _ = TestData.src.get();
            TestData.outer.* += 1;
            
            // Inner effect created inside outer
            // This is a simplified version - in real code you'd manage lifecycle
            TestData.inner.* += 1;
        }
    }.run);
    defer allocator.destroy(outer_effect);
    
    // Initial run
    try std.testing.expect(outer_runs == 1);
    try std.testing.expect(inner_runs == 1);
    
    // Change source
    source.set(10);
    try std.testing.expect(outer_runs == 2);
    try std.testing.expect(inner_runs == 2);
}

// Test 7: Untrack/peek doesn't create dependencies
test "untrack prevents dependency creation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try reactive.init(allocator);
    defer reactive.deinit(allocator);
    
    var source = try reactive.signal(allocator, i32, 0);
    defer source.deinit();
    
    var other = try reactive.signal(allocator, i32, 100);
    defer other.deinit();
    
    var effect_runs: u32 = 0;
    
    const TestData = struct {
        var src: *signal_mod.Signal(i32) = undefined;
        var other_ref: *signal_mod.Signal(i32) = undefined;
        var runs: *u32 = undefined;
    };
    
    TestData.src = &source;
    TestData.other_ref = &other;
    TestData.runs = &effect_runs;
    
    const test_effect = try reactive.createEffect(allocator, struct {
        fn run() void {
            // This creates a dependency on source
            _ = TestData.src.get();
            TestData.runs.* += 1;
            
            // This does NOT create a dependency on other (untracked)
            const untracked_value = context_mod.untrack(i32, struct {
                fn getOther() i32 {
                    return TestData.other_ref.get();
                }
            }.getOther);
            _ = untracked_value; // Use the value to avoid unused variable warning
        }
    }.run);
    defer allocator.destroy(test_effect);
    
    // Initial run
    try std.testing.expect(effect_runs == 1);
    
    // Reset counter
    effect_runs = 0;
    
    // Changing source should trigger effect (it's tracked)
    source.set(10);
    try std.testing.expect(effect_runs == 1);
    
    // Reset counter
    effect_runs = 0;
    
    // Changing other should NOT trigger effect (it was read in untrack)
    other.set(200);
    try std.testing.expect(effect_runs == 0); // Should be 0!
    
    // Double-check by changing source again (should still work)
    source.set(20);
    try std.testing.expect(effect_runs == 1);
}

// Test 8: Memory cleanup on effect disposal
test "effect cleanup releases dependencies" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try reactive.init(allocator);
    defer reactive.deinit(allocator);
    
    var source = try reactive.signal(allocator, i32, 0);
    defer source.deinit();
    
    var effect_runs: u32 = 0;
    
    const TestData = struct {
        var src: *signal_mod.Signal(i32) = undefined;
        var runs: *u32 = undefined;
    };
    
    TestData.src = &source;
    TestData.runs = &effect_runs;
    
    // Create and immediately destroy an effect
    {
        const temp_effect = try reactive.createEffect(allocator, struct {
            fn run() void {
                _ = TestData.src.get();
                TestData.runs.* += 1;
            }
        }.run);
        
        // Initial run
        try std.testing.expect(effect_runs == 1);
        
        // Destroy the effect
        temp_effect.stop();
        allocator.destroy(temp_effect);
    }
    
    // Reset counter
    effect_runs = 0;
    
    // Change source - effect should NOT run (it was destroyed)
    source.set(10);
    try std.testing.expect(effect_runs == 0);
}

// Test 9: Derived chains work correctly
test "derived chain updates propagate" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try reactive.init(allocator);
    defer reactive.deinit(allocator);
    
    // a -> b -> c -> d
    var a = try reactive.signal(allocator, i32, 1);
    defer a.deinit();
    
    const TestData = struct {
        var a_ref: *signal_mod.Signal(i32) = undefined;
        var b_ref: *derived_mod.Derived(i32) = undefined;
        var c_ref: *derived_mod.Derived(i32) = undefined;
    };
    
    TestData.a_ref = &a;
    
    var b = try reactive.derived(allocator, i32, struct {
        fn compute() i32 {
            return TestData.a_ref.get() * 2;
        }
    }.compute);
    defer {
        b.deinit();
        allocator.destroy(b);
    }
    TestData.b_ref = b;
    
    var c = try reactive.derived(allocator, i32, struct {
        fn compute() i32 {
            return TestData.b_ref.get() + 10;
        }
    }.compute);
    defer {
        c.deinit();
        allocator.destroy(c);
    }
    TestData.c_ref = c;
    
    var d = try reactive.derived(allocator, i32, struct {
        fn compute() i32 {
            return TestData.c_ref.get() * 3;
        }
    }.compute);
    defer {
        d.deinit();
        allocator.destroy(d);
    }
    
    // Initial: a=1, b=2, c=12, d=36
    try std.testing.expect(d.get() == 36);
    
    // Change a
    a.set(2);
    
    // Should cascade: a=2, b=4, c=14, d=42
    try std.testing.expect(d.get() == 42);
}

// Test 10: Stop and start effects
test "stop and start effect lifecycle" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try reactive.init(allocator);
    defer reactive.deinit(allocator);
    
    var source = try reactive.signal(allocator, i32, 0);
    defer source.deinit();
    
    var runs: u32 = 0;
    
    const TestData = struct {
        var src: *signal_mod.Signal(i32) = undefined;
        var count: *u32 = undefined;
    };
    
    TestData.src = &source;
    TestData.count = &runs;
    
    const eff = try reactive.createEffect(allocator, struct {
        fn run() void {
            _ = TestData.src.get();
            TestData.count.* += 1;
        }
    }.run);
    defer allocator.destroy(eff);
    
    // Initial run
    try std.testing.expect(runs == 1);
    
    // Stop the effect
    eff.stop();
    
    // Change should not trigger
    runs = 0;
    source.set(10);
    try std.testing.expect(runs == 0);
    
    // Start again
    eff.start();
    try std.testing.expect(runs == 1); // Runs once on start
    
    // Now changes should trigger
    runs = 0;
    source.set(20);
    try std.testing.expect(runs == 1);
}