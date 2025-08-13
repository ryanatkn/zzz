const std = @import("std");
const context = @import("context.zig");
const batch_mod = @import("batch.zig");

/// A reactive signal that holds a value and notifies observers when changed
/// Inspired by Solid.js and Svelte 5 signals with automatic dependency tracking
pub fn Signal(comptime T: type) type {
    return struct {
        const Self = @This();
        
        // Core signal state
        value: T,
        allocator: std.mem.Allocator,
        
        // Observer management
        observers: std.ArrayList(*const context.ReactiveContext.Observer),
        
        // Version tracking for optimization
        version: u64 = 0,
        
        // Dirty flag for push-pull reactivity
        is_dirty: bool = false,
        
        pub fn init(allocator: std.mem.Allocator, initial_value: T) !Self {
            return Self{
                .value = initial_value,
                .allocator = allocator,
                .observers = std.ArrayList(*const context.ReactiveContext.Observer).init(allocator),
                .version = 0,
                .is_dirty = false,
            };
        }
        
        pub fn deinit(self: *Self) void {
            self.observers.deinit();
        }
        
        /// Get the current value (tracks dependency if in reactive context)
        pub fn get(self: *Self) T {
            // Register this signal as a dependency in the current reactive context
            const dependency = context.createDependency(
                Self,
                self,
                Self.addObserver,
                Self.removeObserver
            );
            context.trackDependency(dependency);
            
            return self.value;
        }
        
        /// Get the current value without tracking dependency
        pub fn peek(self: *const Self) T {
            return self.value;
        }
        
        /// Set a new value and notify all observers
        pub fn set(self: *Self, new_value: T) void {
            const old_value = self.value;
            
            // Only update if value actually changed
            if (std.meta.eql(old_value, new_value)) {
                return;
            }
            
            self.value = new_value;
            self.version +%= 1; // Wrap on overflow
            self.is_dirty = true;
            self.notifyObservers();
        }
        
        /// Update value through a function
        pub fn update(self: *Self, update_fn: *const fn (T) T) void {
            const new_value = update_fn(self.value);
            self.set(new_value);
        }
        
        /// Add an observer to be notified on changes
        pub fn addObserver(self: *Self, observer: *const context.ReactiveContext.Observer) !void {
            // Check if observer already exists
            for (self.observers.items) |existing| {
                if (existing == observer) return;
            }
            try self.observers.append(observer);
        }
        
        /// Remove an observer
        pub fn removeObserver(self: *Self, observer: *const context.ReactiveContext.Observer) void {
            for (self.observers.items, 0..) |existing, i| {
                if (existing == observer) {
                    _ = self.observers.swapRemove(i);
                    return;
                }
            }
        }
        
        /// Notify all observers of changes
        pub fn notifyObservers(self: *Self) void {
            // Always notify observers, but effects will handle batching themselves
            self.notifyObserversImmediate();
        }
        
        /// Immediate notification without batch checking
        pub fn notifyObserversImmediate(self: *Self) void {
            // Make a copy to avoid issues if observers modify the list
            var observers_copy = self.observers.clone() catch {
                // If we can't clone, notify directly (less safe but functional)
                for (self.observers.items) |observer| {
                    observer.notify();
                }
                return;
            };
            defer observers_copy.deinit();
            
            for (observers_copy.items) |observer| {
                observer.notify();
            }
        }
        
        /// Get the current version (for optimization)
        pub fn getVersion(self: *const Self) u64 {
            return self.version;
        }
        
        /// Check if signal is dirty
        pub fn isDirty(self: *const Self) bool {
            return self.is_dirty;
        }
        
        /// Clear dirty flag
        pub fn clearDirty(self: *Self) void {
            self.is_dirty = false;
        }
        
        /// Create a snapshot of the current value ($state.snapshot)
        /// For deeply reactive state, this creates a non-reactive copy
        pub fn snapshot(self: *const Self) T {
            return self.value;
        }
        
        /// Create a computed signal that derives from this one
        /// TODO: This should use the new Computed type for proper lazy evaluation
        pub fn map(self: *Self, allocator: std.mem.Allocator, comptime U: type, map_fn: *const fn (T) U) !Signal(U) {
            const computed = try Signal(U).init(allocator, map_fn(self.get()));
            
            // TODO: Create proper computed with automatic dependency tracking
            // For now, return a simple mapped signal
            
            return computed;
        }
    };
}

/// A non-reactive signal that holds a value but doesn't notify observers ($state.raw)
/// Inspired by Svelte 5's $state.raw for performance optimization
pub fn SignalRaw(comptime T: type) type {
    return struct {
        const Self = @This();
        
        // Core state (no observers or reactivity)
        value: T,
        allocator: std.mem.Allocator,
        
        pub fn init(allocator: std.mem.Allocator, initial_value: T) !Self {
            return Self{
                .value = initial_value,
                .allocator = allocator,
            };
        }
        
        pub fn deinit(self: *Self) void {
            _ = self; // No cleanup needed for raw signals
        }
        
        /// Get the current value (never tracks dependencies)
        pub fn get(self: *const Self) T {
            return self.value;
        }
        
        /// Alias for get (consistent with reactive signals)
        pub fn peek(self: *const Self) T {
            return self.value;
        }
        
        /// Set a new value (no notifications)
        pub fn set(self: *Self, new_value: T) void {
            self.value = new_value;
        }
        
        /// Update value through a function (no notifications)
        pub fn update(self: *Self, update_fn: *const fn (T) T) void {
            self.value = update_fn(self.value);
        }
        
        /// Create a snapshot of the current value
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

/// Utility function to create a raw (non-reactive) signal with initial value ($state.raw)
pub fn signalRaw(allocator: std.mem.Allocator, comptime T: type, initial_value: T) !SignalRaw(T) {
    return try SignalRaw(T).init(allocator, initial_value);
}

/// Batch multiple signal updates to prevent cascading effects
pub fn batch(batch_fn: *const fn () void) void {
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
    const observer = context.createObserver(
        TestObserver,
        &test_observer,
        TestObserver.notify,
        null
    );
    
    // Start tracking and read the signal
    const ctx = context.getContext().?;
    try ctx.startTracking(&observer);
    _ = source.get(); // This should register the dependency
    ctx.stopTracking();
    
    // Now changing the signal should notify our observer
    source.set(20);
    try std.testing.expect(test_observer.notify_count == 1);
    
    source.set(30);
    try std.testing.expect(test_observer.notify_count == 2);
}

test "raw signal basic operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var count = try signalRaw(allocator, u32, 42);
    defer count.deinit();
    
    // Basic operations
    try std.testing.expect(count.get() == 42);
    try std.testing.expect(count.peek() == 42);
    try std.testing.expect(count.snapshot() == 42);
    
    // Set new value
    count.set(100);
    try std.testing.expect(count.get() == 100);
    
    // Update through function
    count.update(struct {
        fn double(val: u32) u32 {
            return val * 2;
        }
    }.double);
    try std.testing.expect(count.get() == 200);
}

test "raw signal non-reactive behavior" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try context.initContext(allocator);
    defer context.deinitContext(allocator);
    
    var raw_signal = try signalRaw(allocator, i32, 5);
    defer raw_signal.deinit();
    
    var effect_runs: u32 = 0;
    
    // Create an effect that reads the raw signal
    const effect_mod = @import("effect.zig");
    const TestData = struct {
        var raw_ref: *SignalRaw(i32) = undefined;
        var runs: *u32 = undefined;
    };
    
    TestData.raw_ref = &raw_signal;
    TestData.runs = &effect_runs;
    
    const test_effect = try effect_mod.createEffect(allocator, struct {
        fn run() void {
            _ = TestData.raw_ref.get(); // This should NOT create a dependency
            TestData.runs.* += 1;
        }
    }.run);
    defer allocator.destroy(test_effect);
    
    // Initial run
    try std.testing.expect(effect_runs == 1);
    
    // Change raw signal - effect should NOT run again
    raw_signal.set(10);
    try std.testing.expect(effect_runs == 1); // Still 1, not reactive!
    
    raw_signal.set(15);
    try std.testing.expect(effect_runs == 1); // Still 1, confirmed non-reactive
}