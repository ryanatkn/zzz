const std = @import("std");
const signal = @import("signal.zig");
const context = @import("context.zig");
const batch_mod = @import("batch.zig");

/// A computed signal that automatically updates when its dependencies change
/// Implements lazy evaluation with automatic dependency tracking (Svelte 5 $derived)
pub fn Computed(comptime T: type) type {
    return struct {
        const Self = @This();
        
        // The underlying signal that holds our computed value
        signal: signal.Signal(T),
        
        // Function to compute the value
        compute_fn: *const fn () T,
        
        // Cached computed value
        cached_value: T,
        
        // Tracking state
        is_dirty: bool = true,
        is_computing: bool = false,
        
        // Version tracking for optimization
        last_computed_version: u64 = 0,
        dependency_versions: std.ArrayList(u64),
        
        // Observer for this computed (to receive notifications from dependencies)
        observer: context.ReactiveContext.Observer,
        
        // Reference to self for observer callbacks
        self_ptr: *Self = undefined,
        
        pub fn init(allocator: std.mem.Allocator, compute_fn: *const fn () T) !Self {
            // Don't compute initial value yet - wait for proper setup
            
            const self = Self{
                .signal = try signal.Signal(T).init(allocator, undefined),
                .compute_fn = compute_fn,
                .cached_value = undefined,
                .is_dirty = true, // Start dirty to force initial computation
                .is_computing = false,
                .last_computed_version = 0,
                .dependency_versions = std.ArrayList(u64).init(allocator),
                .observer = undefined,
                .self_ptr = undefined,
            };
            
            // Observer will be set up after allocation
            return self;
        }
        
        pub fn deinit(self: *Self) void {
            self.signal.deinit();
            self.dependency_versions.deinit();
        }
        
        /// Get the current computed value (lazy evaluation)
        pub fn get(self: *Self) T {
            // Track this computed as a dependency if we're in a reactive context
            const dependency = context.createDependency(
                signal.Signal(T),
                &self.signal,
                signal.Signal(T).addObserver,
                signal.Signal(T).removeObserver
            );
            context.trackDependency(dependency);
            
            // Recompute if dirty (lazy pull)
            if (self.is_dirty and !self.is_computing) {
                const old_value = self.cached_value;
                self.recompute();
                
                // Only notify if the value actually changed after recompute
                if (!std.meta.eql(old_value, self.cached_value)) {
                    // Update signal value to match computed value
                    self.signal.value = self.cached_value;
                    self.signal.version +%= 1;
                    // Don't call notifyObservers here as this would cause infinite recursion
                    // The tracking dependency above will handle notifications
                }
            }
            
            return self.cached_value;
        }
        
        /// Get the current computed value without tracking dependency
        pub fn peek(self: *Self) T {
            // Recompute if dirty (lazy pull) but don't track
            if (self.is_dirty and !self.is_computing) {
                self.recompute();
            }
            
            return self.cached_value;
        }
        
        /// Called when a dependency changes (push notification)
        fn onDependencyChange(self: *Self) void {
            // Use a simple approach: only notify if we weren't already dirty
            // This prevents duplicate notifications in diamond dependency scenarios
            if (!self.is_dirty) {
                self.is_dirty = true;
                self.signal.is_dirty = true;
                self.signal.version +%= 1;
                
                // Notify observers that we might have changed
                // Effects will be batched automatically if batching is active
                self.signal.notifyObservers();
            }
        }
        
        /// Check if value changed and notify observers only if it did
        fn checkAndNotifyIfChanged(self: *Self) void {
            if (self.is_computing) return; // Prevent recursion
            
            self.is_computing = true;
            defer self.is_computing = false;
            
            // Store old value
            const old_value = self.cached_value;
            
            // Recompute with dependency tracking
            const ctx = context.getContext();
            if (ctx) |reactive_ctx| {
                reactive_ctx.startTracking(&self.observer) catch {
                    // If tracking fails, compute without tracking
                    self.cached_value = self.compute_fn();
                    self.is_dirty = false;
                    return;
                };
                defer reactive_ctx.stopTracking();
                
                // Compute new value
                const new_value = self.compute_fn();
                self.cached_value = new_value;
                
                // Only notify if value actually changed
                if (!std.meta.eql(old_value, new_value)) {
                    self.signal.set(new_value);
                }
            } else {
                // No reactive context, compute directly
                const new_value = self.compute_fn();
                self.cached_value = new_value;
                
                // Only notify if value actually changed
                if (!std.meta.eql(old_value, new_value)) {
                    self.signal.set(new_value);
                }
            }
            
            self.is_dirty = false;
        }
        
        /// Cleanup when computed is destroyed
        fn cleanup(self: *Self) void {
            _ = self;
            // Cleanup handled by deinit
        }
        
        /// Manually recompute (usually happens automatically)
        pub fn recompute(self: *Self) void {
            if (self.is_computing) return; // Prevent infinite recursion
            
            self.is_computing = true;
            defer self.is_computing = false;
            
            // Set up tracking context
            const ctx = context.getContext();
            if (ctx) |reactive_ctx| {
                // Start tracking dependencies
                reactive_ctx.startTracking(&self.observer) catch {
                    // If tracking fails, compute without tracking
                    self.cached_value = self.compute_fn();
                    self.is_dirty = false;
                    return;
                };
                defer reactive_ctx.stopTracking();
                
                // Compute with dependency tracking
                const new_value = self.compute_fn();
                
                // Only update if value actually changed
                if (!std.meta.eql(self.cached_value, new_value)) {
                    self.cached_value = new_value;
                    // Update the signal value directly without triggering notifications
                    // Notifications were already sent by onDependencyChange()
                    self.signal.value = new_value;
                    self.signal.version +%= 1;
                }
            } else {
                // No reactive context, compute directly
                self.cached_value = self.compute_fn();
            }
            
            self.is_dirty = false;
            self.last_computed_version = self.signal.getVersion();
        }
        
        /// Force recomputation and return new value
        pub fn refresh(self: *Self) T {
            self.is_dirty = true;
            return self.get();
        }
        
        /// Check if computed needs recomputation
        pub fn isDirty(self: *const Self) bool {
            return self.is_dirty;
        }
        
        /// Get as a signal reference (for compatibility)
        pub fn asSignal(self: *Self) *signal.Signal(T) {
            return &self.signal;
        }
    };
}

/// Create a computed signal
pub fn computed(allocator: std.mem.Allocator, comptime T: type, compute_fn: *const fn () T) !*Computed(T) {
    const comp = try allocator.create(Computed(T));
    comp.* = try Computed(T).init(allocator, compute_fn);
    comp.self_ptr = comp; // Fix self-reference after allocation
    
    // Re-create observer with correct self pointer
    comp.observer = context.createObserver(
        Computed(T),
        comp,
        Computed(T).onDependencyChange,
        Computed(T).cleanup
    );
    
    // Re-establish dependencies with correct observer
    comp.is_dirty = true;
    comp.recompute();
    
    return comp;
}

/// Create a computed that depends on multiple signals explicitly
/// This is a helper for cases where automatic tracking isn't sufficient
pub fn computedFrom(
    allocator: std.mem.Allocator,
    comptime T: type,
    comptime U: type,
    dependencies: []const *signal.Signal(U),
    compute_fn: *const fn ([]const U) T
) !*Computed(T) {
    const ComputeContext = struct {
        deps: []const *signal.Signal(U),
        compute_fn: *const fn ([]const U) T,
        allocator: std.mem.Allocator,
        
        fn compute(ctx: @This()) T {
            var values = std.ArrayList(U).init(ctx.allocator);
            defer values.deinit();
            
            for (ctx.deps) |dep| {
                values.append(dep.get()) catch return @as(T, undefined);
            }
            
            return ctx.compute_fn(values.items);
        }
    };
    
    const ctx = ComputeContext{
        .deps = dependencies,
        .compute_fn = compute_fn,
        .allocator = allocator,
    };
    
    // TODO: This needs a better solution for capturing context
    // For now, use the simple compute function
    _ = ctx;
    
    return computed(allocator, T, struct {
        fn compute() T {
            // This is a limitation - we need the context here
            // For now, return a default value
            return @as(T, undefined);
        }
    }.compute);
}

// Tests
test "computed basic usage with automatic tracking" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Initialize reactive context
    try context.initContext(allocator);
    defer context.deinitContext(allocator);
    
    // Create base signals
    var width = try signal.signal(allocator, f32, 100.0);
    defer width.deinit();
    
    var height = try signal.signal(allocator, f32, 50.0);
    defer height.deinit();
    
    // Track test data in a global for the compute function
    const TestData = struct {
        var test_width: *signal.Signal(f32) = undefined;
        var test_height: *signal.Signal(f32) = undefined;
    };
    
    TestData.test_width = &width;
    TestData.test_height = &height;
    
    // Create computed area that automatically tracks dependencies
    var area = try computed(allocator, f32, struct {
        fn compute() f32 {
            // Reading these signals automatically registers them as dependencies
            return TestData.test_width.get() * TestData.test_height.get();
        }
    }.compute);
    defer {
        area.deinit();
        allocator.destroy(area);
    }
    
    // Initial computation
    try std.testing.expect(area.get() == 5000.0);
    try std.testing.expect(!area.isDirty());
    
    // Update width - area should become dirty
    width.set(200.0);
    try std.testing.expect(area.isDirty());
    
    // Getting the value should trigger recomputation
    try std.testing.expect(area.get() == 10000.0);
    try std.testing.expect(!area.isDirty());
    
    // Update both - batched changes
    width.set(300.0);
    height.set(100.0);
    try std.testing.expect(area.get() == 30000.0);
}

test "computed lazy evaluation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try context.initContext(allocator);
    defer context.deinitContext(allocator);
    
    var source = try signal.signal(allocator, i32, 10);
    defer source.deinit();
    
    var compute_count: u32 = 0;
    
    const TestData = struct {
        var test_source: *signal.Signal(i32) = undefined;
        var test_count: *u32 = undefined;
    };
    
    TestData.test_source = &source;
    TestData.test_count = &compute_count;
    
    var doubled = try computed(allocator, i32, struct {
        fn compute() i32 {
            TestData.test_count.* += 1;
            return TestData.test_source.get() * 2;
        }
    }.compute);
    defer {
        doubled.deinit();
        allocator.destroy(doubled);
    }
    
    // Initial computation
    try std.testing.expect(compute_count == 1);
    try std.testing.expect(doubled.get() == 20);
    
    // Getting again shouldn't recompute (cached)
    _ = doubled.get();
    try std.testing.expect(compute_count == 1);
    
    // Update source
    source.set(15);
    
    // Computed is dirty but not recomputed yet (lazy)
    try std.testing.expect(compute_count == 1);
    try std.testing.expect(doubled.isDirty());
    
    // Getting the value triggers recomputation
    try std.testing.expect(doubled.get() == 30);
    try std.testing.expect(compute_count == 2);
}

test "computed chain dependencies" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try context.initContext(allocator);
    defer context.deinitContext(allocator);
    
    var base = try signal.signal(allocator, i32, 10);
    defer base.deinit();
    
    const TestData = struct {
        var test_base: *signal.Signal(i32) = undefined;
        var test_doubled: *Computed(i32) = undefined;
    };
    
    TestData.test_base = &base;
    
    // First computed: double the base
    var doubled = try computed(allocator, i32, struct {
        fn compute() i32 {
            return TestData.test_base.get() * 2;
        }
    }.compute);
    defer {
        doubled.deinit();
        allocator.destroy(doubled);
    }
    
    TestData.test_doubled = doubled;
    
    // Second computed: add 5 to doubled
    var plus_five = try computed(allocator, i32, struct {
        fn compute() i32 {
            return TestData.test_doubled.get() + 5;
        }
    }.compute);
    defer {
        plus_five.deinit();
        allocator.destroy(plus_five);
    }
    
    // Initial values
    try std.testing.expect(doubled.get() == 20);
    try std.testing.expect(plus_five.get() == 25);
    
    // Update base - should cascade through the chain
    base.set(20);
    
    // Both should be dirty
    try std.testing.expect(doubled.isDirty());
    try std.testing.expect(plus_five.isDirty());
    
    // Getting final value should recompute chain
    try std.testing.expect(plus_five.get() == 45); // (20 * 2) + 5
}