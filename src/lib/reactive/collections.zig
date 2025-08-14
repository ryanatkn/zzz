const std = @import("std");
const signal_mod = @import("signal.zig");
const context = @import("context.zig");
const observer = @import("observer.zig");
const utils = @import("utils.zig");

/// Reactive Array - fixed-size array with reactive element access and modification
/// This provides reactive semantics for array operations in an idiomatic Zig way
pub fn ReactiveArray(comptime T: type, comptime N: usize) type {
    return struct {
        const Self = @This();

        // Core array storage
        items: [N]T,
        allocator: std.mem.Allocator,

        // Observer management for reactivity
        observable: observer.Observable(@This()),

        // Version tracking for optimization
        version_tracker: utils.VersionTracker = .{},

        // Dirty state management
        dirty_state: utils.DirtyState = .{},

        pub fn init(allocator: std.mem.Allocator, initial_items: [N]T) !Self {
            return Self{
                .items = initial_items,
                .allocator = allocator,
                .observable = observer.Observable(@This()).initObservable(allocator),
                .version_tracker = utils.VersionTracker{},
                .dirty_state = utils.DirtyState{},
            };
        }

        pub fn deinit(self: *Self) void {
            self.observable.deinitObservable();
        }

        /// Get an element at index (tracks dependency if in reactive context)
        pub fn get(self: *Self, index: usize) T {
            if (index >= N) {
                @panic("ReactiveArray index out of bounds");
            }

            // Register this array as a dependency in the current reactive context
            const dependency = context.createDependency(Self, self, Self.addObserver, Self.removeObserver);
            context.trackDependency(dependency);

            return self.items[index];
        }

        /// Get an element without tracking dependency
        pub fn peek(self: *const Self, index: usize) T {
            if (index >= N) {
                @panic("ReactiveArray index out of bounds");
            }
            return self.items[index];
        }

        /// Set an element at index and notify observers
        pub fn set(self: *Self, index: usize, value: T) void {
            if (index >= N) {
                @panic("ReactiveArray index out of bounds");
            }

            const old_value = self.items[index];

            // Only update if value actually changed (shallow comparison)
            if (utils.shallowEqual(T, old_value, value)) {
                return;
            }

            self.items[index] = value;
            self.version_tracker.increment();
            self.dirty_state.markDirty();
            self.notifyObservers();
        }

        /// Get the entire array (tracks dependency)
        pub fn getAll(self: *Self) [N]T {
            // Register this array as a dependency
            const dependency = context.createDependency(Self, self, Self.addObserver, Self.removeObserver);
            context.trackDependency(dependency);

            return self.items;
        }

        /// Get the entire array without tracking
        pub fn peekAll(self: *const Self) [N]T {
            return self.items;
        }

        /// Set the entire array and notify observers
        pub fn setAll(self: *Self, new_items: [N]T) void {
            // Check if array actually changed
            if (utils.shallowEqual([N]T, self.items, new_items)) {
                return;
            }

            self.items = new_items;
            self.version_tracker.increment();
            self.dirty_state.markDirty();
            self.notifyObservers();
        }

        /// Get array length (always N for fixed arrays)
        pub fn len(self: *const Self) usize {
            _ = self;
            return N;
        }

        /// Force notification of observers without changing values
        /// Useful when modifying elements through direct access
        pub fn notify(self: *Self) void {
            self.version_tracker.increment();
            self.dirty_state.markDirty();
            self.notifyObservers();
        }

        /// Fill all elements with a value
        pub fn fill(self: *Self, value: T) void {
            const changed = blk: {
                for (self.items) |item| {
                    if (!utils.shallowEqual(T, item, value)) {
                        break :blk true;
                    }
                }
                break :blk false;
            };

            if (!changed) return;

            for (&self.items) |*item| {
                item.* = value;
            }

            self.version_tracker.increment();
            self.dirty_state.markDirty();
            self.notifyObservers();
        }

        /// Swap two elements
        pub fn swap(self: *Self, a: usize, b: usize) void {
            if (a >= N or b >= N) {
                @panic("ReactiveArray index out of bounds");
            }

            if (a == b) return; // No change

            const temp = self.items[a];
            self.items[a] = self.items[b];
            self.items[b] = temp;

            self.version_tracker.increment();
            self.dirty_state.markDirty();
            self.notifyObservers();
        }

        /// Create a snapshot of the current array
        pub fn snapshot(self: *const Self) [N]T {
            return self.items;
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
            self.observable.notifyObserversImmediate();
        }

        /// Get the current version (for optimization)
        pub fn getVersion(self: *const Self) u64 {
            return self.version_tracker.get();
        }

        /// Check if array is dirty
        pub fn isDirty(self: *const Self) bool {
            return self.dirty_state.isDirty();
        }

        /// Clear dirty flag
        pub fn clearDirty(self: *Self) void {
            self.dirty_state.markClean();
        }
    };
}

/// Reactive Slice - dynamic slice wrapper with reactive semantics
/// This provides reactive tracking for slice operations
pub fn ReactiveSlice(comptime T: type) type {
    return struct {
        const Self = @This();

        // Core slice storage
        items: []T,
        allocator: std.mem.Allocator,

        // Observer management for reactivity
        observable: observer.Observable(@This()),

        // Version tracking for optimization
        version_tracker: utils.VersionTracker = .{},

        // Dirty state management
        dirty_state: utils.DirtyState = .{},

        pub fn init(allocator: std.mem.Allocator, items: []T) !Self {
            return Self{
                .items = items,
                .allocator = allocator,
                .observable = observer.Observable(@This()).initObservable(allocator),
                .version_tracker = utils.VersionTracker{},
                .dirty_state = utils.DirtyState{},
            };
        }

        pub fn deinit(self: *Self) void {
            self.observable.deinitObservable();
        }

        /// Get an element at index (tracks dependency if in reactive context)
        pub fn get(self: *Self, index: usize) T {
            if (index >= self.items.len) {
                @panic("ReactiveSlice index out of bounds");
            }

            // Register this slice as a dependency in the current reactive context
            const dependency = context.createDependency(Self, self, Self.addObserver, Self.removeObserver);
            context.trackDependency(dependency);

            return self.items[index];
        }

        /// Get an element without tracking dependency
        pub fn peek(self: *const Self, index: usize) T {
            if (index >= self.items.len) {
                @panic("ReactiveSlice index out of bounds");
            }
            return self.items[index];
        }

        /// Set an element at index and notify observers
        pub fn set(self: *Self, index: usize, value: T) void {
            if (index >= self.items.len) {
                @panic("ReactiveSlice index out of bounds");
            }

            const old_value = self.items[index];

            // Only update if value actually changed (shallow comparison)
            if (utils.shallowEqual(T, old_value, value)) {
                return;
            }

            self.items[index] = value;
            self.version_tracker.increment();
            self.dirty_state.markDirty();
            self.notifyObservers();
        }

        /// Get slice length
        pub fn len(self: *const Self) usize {
            return self.items.len;
        }

        /// Force notification of observers without changing values
        pub fn notify(self: *Self) void {
            self.version_tracker.increment();
            self.dirty_state.markDirty();
            self.notifyObservers();
        }

        /// Create a snapshot of the current slice
        pub fn snapshot(self: *Self) ![]T {
            const copy = try self.allocator.alloc(T, self.items.len);
            @memcpy(copy, self.items);
            return copy;
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
            self.observable.notifyObserversImmediate();
        }

        /// Get the current version (for optimization)
        pub fn getVersion(self: *const Self) u64 {
            return self.version_tracker.get();
        }

        /// Check if slice is dirty
        pub fn isDirty(self: *const Self) bool {
            return self.dirty_state.isDirty();
        }

        /// Clear dirty flag
        pub fn clearDirty(self: *Self) void {
            self.dirty_state.markClean();
        }
    };
}

/// Convenience function to create a reactive array
pub fn reactiveArray(allocator: std.mem.Allocator, comptime T: type, comptime N: usize, initial_items: [N]T) !ReactiveArray(T, N) {
    return try ReactiveArray(T, N).init(allocator, initial_items);
}

/// Convenience function to create a reactive slice
pub fn reactiveSlice(allocator: std.mem.Allocator, comptime T: type, items: []T) !ReactiveSlice(T) {
    return try ReactiveSlice(T).init(allocator, items);
}

// Tests
test "reactive array basic operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize reactive context for testing
    try context.initContext(allocator);
    defer context.deinitContext(allocator);

    var arr = try reactiveArray(allocator, i32, 3, [3]i32{ 1, 2, 3 });
    defer arr.deinit();

    // Test basic access
    try std.testing.expect(arr.peek(0) == 1);
    try std.testing.expect(arr.peek(1) == 2);
    try std.testing.expect(arr.peek(2) == 3);
    try std.testing.expect(arr.len() == 3);

    // Test modification
    arr.set(1, 42);
    try std.testing.expect(arr.peek(1) == 42);

    // Test array-wide operations
    arr.fill(10);
    try std.testing.expect(arr.peek(0) == 10);
    try std.testing.expect(arr.peek(1) == 10);
    try std.testing.expect(arr.peek(2) == 10);

    // Test swap
    arr.set(0, 1);
    arr.set(2, 3);
    arr.swap(0, 2);
    try std.testing.expect(arr.peek(0) == 3);
    try std.testing.expect(arr.peek(2) == 1);
}

test "reactive array dependency tracking" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try context.initContext(allocator);
    defer context.deinitContext(allocator);

    var arr = try reactiveArray(allocator, i32, 2, [2]i32{ 1, 2 });
    defer arr.deinit();

    var effect_runs: u32 = 0;

    const effect_mod = @import("effect.zig");
    const TestData = struct {
        var arr_ref: *ReactiveArray(i32, 2) = undefined;
        var runs: *u32 = undefined;
    };

    TestData.arr_ref = &arr;
    TestData.runs = &effect_runs;

    const test_effect = try effect_mod.createEffect(allocator, struct {
        fn run() void {
            _ = TestData.arr_ref.get(0); // Track dependency on the array
            TestData.runs.* += 1;
        }
    }.run);
    defer allocator.destroy(test_effect);

    // Initial run
    try std.testing.expect(effect_runs == 1);

    // Change tracked element - should trigger
    effect_runs = 0;
    arr.set(0, 42);
    try std.testing.expect(effect_runs == 1);

    // Change non-tracked element - should still trigger (whole array tracked)
    effect_runs = 0;
    arr.set(1, 99);
    try std.testing.expect(effect_runs == 1);

    // Set same value - should not trigger
    effect_runs = 0;
    arr.set(0, 42);
    try std.testing.expect(effect_runs == 0);
}

test "reactive slice basic operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try context.initContext(allocator);
    defer context.deinitContext(allocator);

    var items = [_]i32{ 10, 20, 30 };
    var slice = try reactiveSlice(allocator, i32, items[0..]);
    defer slice.deinit();

    // Test basic access
    try std.testing.expect(slice.peek(0) == 10);
    try std.testing.expect(slice.peek(1) == 20);
    try std.testing.expect(slice.len() == 3);

    // Test modification
    slice.set(1, 99);
    try std.testing.expect(slice.peek(1) == 99);
    try std.testing.expect(items[1] == 99); // Should modify original
}
