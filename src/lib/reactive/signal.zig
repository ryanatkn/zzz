const std = @import("std");
const context = @import("context.zig");
const observer = @import("observer.zig");
const utils = @import("utils.zig");
const batch_mod = @import("batch.zig");
const effect_mod = @import("effect.zig");

/// A reactive signal that holds a value and notifies observers when changed
/// Uses shallow equality checking for optimal performance
/// Inspired by Solid.js and Svelte 5 signals with automatic dependency tracking
pub fn Signal(comptime T: type) type {
    return struct {
        const Self = @This();

        // Core signal state
        value: T,
        allocator: std.mem.Allocator,

        // Observer management using the Observable mixin
        observable: observer.Observable(@This()),

        // Version tracking for optimization
        version_tracker: utils.VersionTracker = .{},

        // Dirty state management
        dirty_state: utils.DirtyState = .{},

        pub fn init(allocator: std.mem.Allocator, initial_value: T) !Self {
            return Self{
                .value = initial_value,
                .allocator = allocator,
                .observable = observer.Observable(@This()).initObservable(allocator),
                .version_tracker = utils.VersionTracker{},
                .dirty_state = utils.DirtyState{},
            };
        }

        pub fn deinit(self: *Self) void {
            self.observable.deinitObservable();
        }

        /// Get the current value (tracks dependency if in reactive context)
        pub fn get(self: *Self) T {
            // Register this signal as a dependency in the current reactive context
            const dependency = context.createDependency(Self, self, Self.addObserver, Self.removeObserver);
            context.trackDependency(dependency);

            return self.value;
        }

        /// Get the current value without tracking dependency
        pub fn peek(self: *const Self) T {
            return self.value;
        }

        /// Set a new value and notify all observers
        /// Uses shallow equality checking for performance
        pub fn set(self: *Self, new_value: T) void {
            const old_value = self.value;

            // Only update if value actually changed (shallow comparison)
            if (utils.shallowEqual(T, old_value, new_value)) {
                return;
            }

            self.value = new_value;
            self.version_tracker.increment();
            self.dirty_state.markDirty();
            self.notifyObservers();
        }

        /// Update value through a function
        pub fn update(self: *Self, update_fn: utils.CallbackTypes.UpdateFn(T)) void {
            const new_value = update_fn(self.value);
            self.set(new_value);
        }

        /// Force notification of observers without changing the value
        /// Useful when modifying nested structures manually
        pub fn notify(self: *Self) void {
            self.version_tracker.increment();
            self.dirty_state.markDirty();
            self.notifyObservers();
        }

        /// Add an observer to be notified on changes
        pub fn addObserver(self: *Self, obs: *const observer.Observer) !void {
            try self.observable.addObserver(obs);
        }

        /// Remove an observer
        pub fn removeObserver(self: *Self, obs: *const observer.Observer) void {
            self.observable.removeObserver(obs);
        }

        /// Notify all observers of changes
        pub fn notifyObservers(self: *Self) void {
            // Always notify observers, but effects will handle batching themselves
            self.notifyObserversImmediate();
        }

        /// Immediate notification without batch checking
        pub fn notifyObserversImmediate(self: *Self) void {
            self.observable.notifyObserversImmediate();
        }

        /// Get the current version (for optimization)
        pub fn getVersion(self: *const Self) u64 {
            return self.version_tracker.get();
        }

        /// Check if signal is dirty
        pub fn isDirty(self: *const Self) bool {
            return self.dirty_state.isDirty();
        }

        /// Clear dirty flag
        pub fn clearDirty(self: *Self) void {
            self.dirty_state.markClean();
        }

        /// Create a snapshot of the current value ($state.snapshot)
        /// For deeply reactive state, this creates a non-reactive copy
        pub fn snapshot(self: *const Self) T {
            return self.value;
        }
    };
}

// Effect creation has been moved to effect.zig with proper dependency tracking

/// Utility function to create a signal with initial value
pub fn signal(allocator: std.mem.Allocator, comptime T: type, initial_value: T) !Signal(T) {
    return try Signal(T).init(allocator, initial_value);
}

/// Batch multiple signal updates to prevent cascading effects
pub fn batch(batch_fn: utils.CallbackTypes.BatchFn) void {
    // Batching is now handled by batch.zig
    batch_mod.batch(batch_fn);
}

// Example usage and tests
test "signal creation and basic operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize reactive context for testing
    try context.initContext(allocator);
    defer context.deinitContext(allocator);

    var count = try signal(allocator, u32, 0);
    defer count.deinit();

    try std.testing.expect(count.get() == 0);

    count.set(5);
    try std.testing.expect(count.get() == 5);

    count.update(struct {
        fn increment(val: u32) u32 {
            return val + 1;
        }
    }.increment);
    try std.testing.expect(count.get() == 6);
}

test "signal automatic dependency tracking" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try context.initContext(allocator);
    defer context.deinitContext(allocator);

    var source = try signal(allocator, i32, 10);
    defer source.deinit();

    // Track how many times observer is notified
    const TestObserver = struct {
        notify_count: u32 = 0,

        fn notify(self: *@This()) void {
            self.notify_count += 1;
        }
    };

    var test_observer = TestObserver{};
    const obs = context.createObserver(TestObserver, &test_observer, TestObserver.notify, null);

    // Start tracking and read the signal
    const ctx = context.getContext().?;
    try ctx.startTracking(&obs);
    _ = source.get(); // This should register the dependency
    ctx.stopTracking();

    // Now changing the signal should notify our observer
    source.set(20);
    try std.testing.expect(test_observer.notify_count == 1);

    source.set(30);
    try std.testing.expect(test_observer.notify_count == 2);
}

test "signal shallow equality semantics" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try context.initContext(allocator);
    defer context.deinitContext(allocator);

    // Test with struct - shallow equality means entire struct must change
    const Point = struct { x: i32, y: i32 };
    var point_signal = try signal(allocator, Point, .{ .x = 1, .y = 2 });
    defer point_signal.deinit();

    var effect_runs: u32 = 0;
    const TestData = struct {
        var signal_ref: *Signal(Point) = undefined;
        var runs: *u32 = undefined;
    };

    TestData.signal_ref = &point_signal;
    TestData.runs = &effect_runs;

    const test_effect = try effect_mod.createEffect(allocator, struct {
        fn run() void {
            _ = TestData.signal_ref.get();
            TestData.runs.* += 1;
        }
    }.run);
    defer allocator.destroy(test_effect);

    // Initial run
    try std.testing.expect(effect_runs == 1);

    // Set same value - should not trigger (shallow equal)
    effect_runs = 0;
    point_signal.set(.{ .x = 1, .y = 2 });
    try std.testing.expect(effect_runs == 0);

    // Set different value - should trigger
    point_signal.set(.{ .x = 2, .y = 2 });
    try std.testing.expect(effect_runs == 1);
}

test "signal manual notification" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try context.initContext(allocator);
    defer context.deinitContext(allocator);

    var list_signal = try signal(allocator, [3]i32, [3]i32{ 1, 2, 3 });
    defer list_signal.deinit();

    var effect_runs: u32 = 0;
    const TestData = struct {
        var signal_ref: *Signal([3]i32) = undefined;
        var runs: *u32 = undefined;
    };

    TestData.signal_ref = &list_signal;
    TestData.runs = &effect_runs;

    const test_effect = try effect_mod.createEffect(allocator, struct {
        fn run() void {
            _ = TestData.signal_ref.get();
            TestData.runs.* += 1;
        }
    }.run);
    defer allocator.destroy(test_effect);

    // Initial run
    try std.testing.expect(effect_runs == 1);
    effect_runs = 0;

    // Manually notify without changing value - should trigger
    list_signal.notify();
    try std.testing.expect(effect_runs == 1);

    // Peek doesn't create dependencies
    effect_runs = 0;
    _ = list_signal.peek();
    list_signal.notify();
    try std.testing.expect(effect_runs == 1); // Still triggers because effect was already tracking
}
