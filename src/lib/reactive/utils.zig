const std = @import("std");

/// Common utilities for the reactive system
/// Extracted to reduce code duplication and provide consistent behavior

/// Version tracking utilities for reactivity optimization
pub const VersionTracker = struct {
    version: u64 = 0,
    
    pub fn increment(self: *@This()) void {
        self.version +%= 1; // Wrap on overflow for performance
    }
    
    pub fn get(self: *const @This()) u64 {
        return self.version;
    }
    
    pub fn set(self: *@This(), version: u64) void {
        self.version = version;
    }
};

/// Enhanced equality checking with performance optimizations
pub fn isEqual(comptime T: type, a: T, b: T) bool {
    // For primitive types, use direct comparison (faster)
    if (@typeInfo(T) == .Int or @typeInfo(T) == .Float or @typeInfo(T) == .Bool) {
        return a == b;
    }
    
    // For complex types, use std.meta.eql
    return std.meta.eql(a, b);
}

/// ArrayList utilities for observer management
pub const ObserverList = struct {
    /// Check if an observer already exists in the list
    pub fn contains(comptime T: type, list: *const std.ArrayList(*const T), observer: *const T) bool {
        for (list.items) |existing| {
            if (existing == observer) return true;
        }
        return false;
    }
    
    /// Add observer if not already present
    pub fn addUnique(comptime T: type, list: *std.ArrayList(*const T), observer: *const T) !void {
        if (!contains(T, list, observer)) {
            try list.append(observer);
        }
    }
    
    /// Remove observer by swapping with last element (O(1) removal)
    pub fn removeSwap(comptime T: type, list: *std.ArrayList(*const T), observer: *const T) void {
        for (list.items, 0..) |existing, i| {
            if (existing == observer) {
                _ = list.swapRemove(i);
                return;
            }
        }
    }
};

/// Memory management helpers for reactive objects
pub const MemoryHelpers = struct {
    /// Create and initialize a reactive object
    pub fn createAndInit(comptime T: type, allocator: std.mem.Allocator, args: anytype) !*T {
        const obj = try allocator.create(T);
        obj.* = try T.init(args);
        return obj;
    }
    
    /// Cleanup and destroy a reactive object with deinit
    pub fn deinitAndDestroy(comptime T: type, allocator: std.mem.Allocator, obj: *T) void {
        obj.deinit();
        allocator.destroy(obj);
    }
};

/// Dirty state management for push-pull reactivity
pub const DirtyState = struct {
    is_dirty: bool = false,
    is_computing: bool = false, // Prevent recursion during computations
    
    pub fn markDirty(self: *@This()) void {
        self.is_dirty = true;
    }
    
    pub fn markClean(self: *@This()) void {
        self.is_dirty = false;
    }
    
    pub fn isDirty(self: *const @This()) bool {
        return self.is_dirty;
    }
    
    /// Start a computation (prevents recursion)
    pub fn startComputing(self: *@This()) bool {
        if (self.is_computing) return false; // Already computing
        self.is_computing = true;
        return true;
    }
    
    /// End a computation
    pub fn endComputing(self: *@This()) void {
        self.is_computing = false;
    }
    
    /// Check if currently computing
    pub fn isComputing(self: *const @This()) bool {
        return self.is_computing;
    }
};

/// Lazy evaluation helpers for $derived semantics
pub const LazyEval = struct {
    /// Execute a function only if needed (dirty) and not already computing
    pub fn executeIfNeeded(
        comptime T: type,
        dirty_state: *DirtyState,
        cached_value: *T,
        compute_fn: *const fn () T
    ) T {
        if (!dirty_state.isDirty() or dirty_state.isComputing()) {
            return cached_value.*;
        }
        
        if (!dirty_state.startComputing()) {
            return cached_value.*; // Recursion guard
        }
        defer dirty_state.endComputing();
        
        const new_value = compute_fn();
        cached_value.* = new_value;
        dirty_state.markClean();
        
        return new_value;
    }
};

/// Function callback types for consistency across modules
pub const CallbackTypes = struct {
    /// Basic effect function (Svelte 5 $effect)
    pub const EffectFn = *const fn () void;
    
    /// Cleanup function for effects and components
    pub const CleanupFn = *const fn () void;
    
    /// Derived computation function (Svelte 5 $derived)
    pub const DeriveFn = fn () anytype;
    
    /// Update function for signals
    pub const UpdateFn = fn (anytype) anytype;
    
    /// Batch function for grouping updates
    pub const BatchFn = *const fn () void;
};

// Tests to ensure utilities work correctly
test "version tracker basic operations" {
    var tracker = VersionTracker{};
    
    try std.testing.expect(tracker.get() == 0);
    
    tracker.increment();
    try std.testing.expect(tracker.get() == 1);
    
    tracker.set(100);
    try std.testing.expect(tracker.get() == 100);
}

test "equality checking with different types" {
    // Primitive types
    try std.testing.expect(isEqual(i32, 42, 42));
    try std.testing.expect(!isEqual(i32, 42, 43));
    
    try std.testing.expect(isEqual(f32, 3.14, 3.14));
    try std.testing.expect(!isEqual(f32, 3.14, 2.71));
    
    try std.testing.expect(isEqual(bool, true, true));
    try std.testing.expect(!isEqual(bool, true, false));
    
    // Complex types (using std.meta.eql internally)
    const Point = struct { x: i32, y: i32 };
    try std.testing.expect(isEqual(Point, .{ .x = 1, .y = 2 }, .{ .x = 1, .y = 2 }));
    try std.testing.expect(!isEqual(Point, .{ .x = 1, .y = 2 }, .{ .x = 1, .y = 3 }));
}

test "observer list operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var list = std.ArrayList(*const i32).init(allocator);
    defer list.deinit();
    
    const item1: i32 = 1;
    const item2: i32 = 2;
    
    // Test contains on empty list
    try std.testing.expect(!ObserverList.contains(i32, &list, &item1));
    
    // Test add unique
    try ObserverList.addUnique(i32, &list, &item1);
    try std.testing.expect(list.items.len == 1);
    try std.testing.expect(ObserverList.contains(i32, &list, &item1));
    
    // Test duplicate add (should not increase size)
    try ObserverList.addUnique(i32, &list, &item1);
    try std.testing.expect(list.items.len == 1);
    
    // Test add different item
    try ObserverList.addUnique(i32, &list, &item2);
    try std.testing.expect(list.items.len == 2);
    
    // Test remove
    ObserverList.removeSwap(i32, &list, &item1);
    try std.testing.expect(list.items.len == 1);
    try std.testing.expect(!ObserverList.contains(i32, &list, &item1));
    try std.testing.expect(ObserverList.contains(i32, &list, &item2));
}

test "dirty state management" {
    var dirty = DirtyState{};
    
    // Initial state
    try std.testing.expect(!dirty.isDirty());
    try std.testing.expect(!dirty.isComputing());
    
    // Mark dirty
    dirty.markDirty();
    try std.testing.expect(dirty.isDirty());
    
    // Start computing
    try std.testing.expect(dirty.startComputing());
    try std.testing.expect(dirty.isComputing());
    
    // Try to start computing again (should fail)
    try std.testing.expect(!dirty.startComputing());
    
    // End computing
    dirty.endComputing();
    try std.testing.expect(!dirty.isComputing());
    
    // Mark clean
    dirty.markClean();
    try std.testing.expect(!dirty.isDirty());
}

test "lazy evaluation" {
    var dirty = DirtyState{};
    var cached_value: i32 = 0;
    var compute_calls: u32 = 0;
    
    const compute_fn = struct {
        var calls: *u32 = undefined;
        fn compute() i32 {
            calls.* += 1;
            return 42;
        }
    }.compute;
    
    // Set up compute function with call counter
    @TypeOf(compute_fn).calls = &compute_calls;
    
    // First call should not compute (not dirty)
    var result = LazyEval.executeIfNeeded(i32, &dirty, &cached_value, compute_fn);
    try std.testing.expect(result == 0); // cached value
    try std.testing.expect(compute_calls == 0);
    
    // Mark dirty and compute
    dirty.markDirty();
    result = LazyEval.executeIfNeeded(i32, &dirty, &cached_value, compute_fn);
    try std.testing.expect(result == 42);
    try std.testing.expect(compute_calls == 1);
    try std.testing.expect(!dirty.isDirty()); // Should be clean after computation
    
    // Second call should use cached value
    result = LazyEval.executeIfNeeded(i32, &dirty, &cached_value, compute_fn);
    try std.testing.expect(result == 42);
    try std.testing.expect(compute_calls == 1); // No additional calls
}