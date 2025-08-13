const std = @import("std");
const signal = @import("signal.zig");
const context = @import("context.zig");
const batch_mod = @import("batch.zig");

/// A derived signal that automatically updates when its dependencies change
/// Implements lazy evaluation with automatic dependency tracking (Svelte 5 $derived)
pub fn Derived(comptime T: type) type {
    return struct {
        const Self = @This();
        
        // The underlying signal that holds our derived value
        signal: signal.Signal(T),
        
        // Function to derive the value
        derive_fn: *const fn () T,
        
        // Cached derived value
        cached_value: T,
        
        // Tracking state
        is_dirty: bool = true,
        is_deriving: bool = false,
        
        // Version tracking for optimization
        last_derived_version: u64 = 0,
        dependency_versions: std.ArrayList(u64),
        
        // Observer for this derived (to receive notifications from dependencies)
        observer: context.ReactiveContext.Observer,
        
        // Reference to self for observer callbacks
        self_ptr: *Self = undefined,
        
        pub fn init(allocator: std.mem.Allocator, derive_fn: *const fn () T) !Self {
            // Don't derive initial value yet - wait for proper setup
            
            const self = Self{
                .signal = try signal.Signal(T).init(allocator, undefined),
                .derive_fn = derive_fn,
                .cached_value = undefined,
                .is_dirty = true, // Start dirty to force initial derivation
                .is_deriving = false,
                .last_derived_version = 0,
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
        
        /// Get the current derived value (lazy evaluation)
        pub fn get(self: *Self) T {
            // Track this derived as a dependency if we're in a reactive context
            const dependency = context.createDependency(
                signal.Signal(T),
                &self.signal,
                signal.Signal(T).addObserver,
                signal.Signal(T).removeObserver
            );
            context.trackDependency(dependency);
            
            // Rederive if dirty (lazy pull)
            if (self.is_dirty and !self.is_deriving) {
                const old_value = self.cached_value;
                self.rederive();
                
                // Only notify if the value actually changed after rederive
                if (!std.meta.eql(old_value, self.cached_value)) {
                    // Update signal value to match derived value
                    self.signal.value = self.cached_value;
                    self.signal.version +%= 1;
                    // Don't call notifyObservers here as this would cause infinite recursion
                    // The tracking dependency above will handle notifications
                }
            }
            
            return self.cached_value;
        }
        
        /// Get the current derived value without tracking dependency
        pub fn peek(self: *Self) T {
            // Rederive if dirty (lazy pull) but don't track
            if (self.is_dirty and !self.is_deriving) {
                self.rederive();
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
            if (self.is_deriving) return; // Prevent recursion
            
            self.is_deriving = true;
            defer self.is_deriving = false;
            
            // Store old value
            const old_value = self.cached_value;
            
            // Rederive with dependency tracking
            const ctx = context.getContext();
            if (ctx) |reactive_ctx| {
                reactive_ctx.startTracking(&self.observer) catch {
                    // If tracking fails, derive without tracking
                    self.cached_value = self.derive_fn();
                    self.is_dirty = false;
                    return;
                };
                defer reactive_ctx.stopTracking();
                
                // Derive new value
                const new_value = self.derive_fn();
                self.cached_value = new_value;
                
                // Only notify if value actually changed
                if (!std.meta.eql(old_value, new_value)) {
                    self.signal.set(new_value);
                }
            } else {
                // No reactive context, derive directly
                const new_value = self.derive_fn();
                self.cached_value = new_value;
                
                // Only notify if value actually changed
                if (!std.meta.eql(old_value, new_value)) {
                    self.signal.set(new_value);
                }
            }
            
            self.is_dirty = false;
        }
        
        /// Cleanup when derived is destroyed
        fn cleanup(self: *Self) void {
            _ = self;
            // Cleanup handled by deinit
        }
        
        /// Manually rederive (usually happens automatically)
        pub fn rederive(self: *Self) void {
            if (self.is_deriving) return; // Prevent infinite recursion
            
            self.is_deriving = true;
            defer self.is_deriving = false;
            
            // Set up tracking context
            const ctx = context.getContext();
            if (ctx) |reactive_ctx| {
                // Start tracking dependencies
                reactive_ctx.startTracking(&self.observer) catch {
                    // If tracking fails, derive without tracking
                    self.cached_value = self.derive_fn();
                    self.is_dirty = false;
                    return;
                };
                defer reactive_ctx.stopTracking();
                
                // Derive with dependency tracking
                const new_value = self.derive_fn();
                
                // Only update if value actually changed
                if (!std.meta.eql(self.cached_value, new_value)) {
                    self.cached_value = new_value;
                    // Update the signal value directly without triggering notifications
                    // Notifications were already sent by onDependencyChange()
                    self.signal.value = new_value;
                    self.signal.version +%= 1;
                }
            } else {
                // No reactive context, derive directly
                self.cached_value = self.derive_fn();
            }
            
            self.is_dirty = false;
            self.last_derived_version = self.signal.getVersion();
        }
        
        /// Force rederivation and return new value
        pub fn refresh(self: *Self) T {
            self.is_dirty = true;
            return self.get();
        }
        
        /// Check if derived needs rederivation
        pub fn isDirty(self: *const Self) bool {
            return self.is_dirty;
        }
        
        /// Get as a signal reference (for compatibility)
        pub fn asSignal(self: *Self) *signal.Signal(T) {
            return &self.signal;
        }
        
        /// Create a snapshot of the current derived value ($state.snapshot)
        /// For deeply reactive state, this creates a non-reactive copy
        pub fn snapshot(self: *Self) T {
            // Ensure we have the latest value but don't track dependency
            if (self.is_dirty and !self.is_deriving) {
                self.rederive();
            }
            return self.cached_value;
        }
    };
}

/// Create a derived signal ($derived)
pub fn derived(allocator: std.mem.Allocator, comptime T: type, derive_fn: *const fn () T) !*Derived(T) {
    const deriv = try allocator.create(Derived(T));
    deriv.* = try Derived(T).init(allocator, derive_fn);
    deriv.self_ptr = deriv; // Fix self-reference after allocation
    
    // Re-create observer with correct self pointer
    deriv.observer = context.createObserver(
        Derived(T),
        deriv,
        Derived(T).onDependencyChange,
        Derived(T).cleanup
    );
    
    // Re-establish dependencies with correct observer
    deriv.is_dirty = true;
    deriv.rederive();
    
    return deriv;
}


/// Create a derived that depends on multiple signals explicitly
/// This is a helper for cases where automatic tracking isn't sufficient
pub fn derivedFrom(
    allocator: std.mem.Allocator,
    comptime T: type,
    comptime U: type,
    dependencies: []const *signal.Signal(U),
    derive_fn: *const fn ([]const U) T
) !*Derived(T) {
    const DeriveContext = struct {
        deps: []const *signal.Signal(U),
        derive_fn: *const fn ([]const U) T,
        allocator: std.mem.Allocator,
        
        fn derive(ctx: @This()) T {
            var values = std.ArrayList(U).init(ctx.allocator);
            defer values.deinit();
            
            for (ctx.deps) |dep| {
                values.append(dep.get()) catch return @as(T, undefined);
            }
            
            return ctx.derive_fn(values.items);
        }
    };
    
    const ctx = DeriveContext{
        .deps = dependencies,
        .derive_fn = derive_fn,
        .allocator = allocator,
    };
    
    // TODO: This needs a better solution for capturing context
    // For now, use the simple derive function
    _ = ctx;
    
    return derived(allocator, T, struct {
        fn derive() T {
            // This is a limitation - we need the context here
            // For now, return a default value
            return @as(T, undefined);
        }
    }.derive);
}


// Tests
test "derived basic usage with automatic tracking" {
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
    
    // Create derived area that automatically tracks dependencies
    var area = try derived(allocator, f32, struct {
        fn derive() f32 {
            // Reading these signals automatically registers them as dependencies
            return TestData.test_width.get() * TestData.test_height.get();
        }
    }.derive);
    defer {
        area.deinit();
        allocator.destroy(area);
    }
    
    // Initial derivation
    try std.testing.expect(area.get() == 5000.0);
    try std.testing.expect(!area.isDirty());
    
    // Update width - area should become dirty
    width.set(200.0);
    try std.testing.expect(area.isDirty());
    
    // Getting the value should trigger rederivation
    try std.testing.expect(area.get() == 10000.0);
    try std.testing.expect(!area.isDirty());
    
    // Update both - batched changes
    width.set(300.0);
    height.set(100.0);
    try std.testing.expect(area.get() == 30000.0);
}

test "derived lazy evaluation" {
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
    
    var doubled = try derived(allocator, i32, struct {
        fn derive() i32 {
            TestData.test_count.* += 1;
            return TestData.test_source.get() * 2;
        }
    }.derive);
    defer {
        doubled.deinit();
        allocator.destroy(doubled);
    }
    
    // Initial derivation
    try std.testing.expect(compute_count == 1);
    try std.testing.expect(doubled.get() == 20);
    
    // Getting again shouldn't rederive (cached)
    _ = doubled.get();
    try std.testing.expect(compute_count == 1);
    
    // Update source
    source.set(15);
    
    // Derived is dirty but not rederived yet (lazy)
    try std.testing.expect(compute_count == 1);
    try std.testing.expect(doubled.isDirty());
    
    // Getting the value triggers rederivation
    try std.testing.expect(doubled.get() == 30);
    try std.testing.expect(compute_count == 2);
}

test "derived chain dependencies" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try context.initContext(allocator);
    defer context.deinitContext(allocator);
    
    var base = try signal.signal(allocator, i32, 10);
    defer base.deinit();
    
    const TestData = struct {
        var test_base: *signal.Signal(i32) = undefined;
        var test_doubled: *Derived(i32) = undefined;
    };
    
    TestData.test_base = &base;
    
    // First derived: double the base
    var doubled = try derived(allocator, i32, struct {
        fn derive() i32 {
            return TestData.test_base.get() * 2;
        }
    }.derive);
    defer {
        doubled.deinit();
        allocator.destroy(doubled);
    }
    
    TestData.test_doubled = doubled;
    
    // Second derived: add 5 to doubled
    var plus_five = try derived(allocator, i32, struct {
        fn derive() i32 {
            return TestData.test_doubled.get() + 5;
        }
    }.derive);
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
    
    // Getting final value should rederive chain
    try std.testing.expect(plus_five.get() == 45); // (20 * 2) + 5
}