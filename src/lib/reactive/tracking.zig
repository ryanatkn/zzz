const std = @import("std");
const observer = @import("observer.zig");
const utils = @import("utils.zig");

/// Dependency tracking system for reactive computations
/// Extracted from context.zig to provide cleaner separation
/// Implements Svelte 5's automatic dependency tracking semantics

/// Reactive context for automatic dependency tracking
/// This manages the current computation context and tracks dependencies
pub const ReactiveContext = struct {
    const Self = @This();
    
    /// Current computation being executed
    current_observer: ?*const observer.Observer = null,
    
    /// Stack of nested computations (for nested effects)
    observer_stack: std.ArrayList(*const observer.Observer),
    
    /// Dependencies collected during current computation
    current_dependencies: std.ArrayList(observer.Dependency),
    
    /// Previous dependencies (for cleanup)
    previous_dependencies: std.ArrayList(observer.Dependency),
    
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .current_observer = null,
            .observer_stack = std.ArrayList(*const observer.Observer).init(allocator),
            .current_dependencies = std.ArrayList(observer.Dependency).init(allocator),
            .previous_dependencies = std.ArrayList(observer.Dependency).init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.observer_stack.deinit();
        self.current_dependencies.deinit();
        self.previous_dependencies.deinit();
    }
    
    /// Start tracking dependencies for a computation (Svelte 5 effect setup)
    pub fn startTracking(self: *Self, obs: *const observer.Observer) !void {
        // Save current observer on stack (for nested computations)
        if (self.current_observer) |current| {
            try self.observer_stack.append(current);
        }
        
        // Move current deps to previous (for cleanup later)
        std.mem.swap(std.ArrayList(observer.Dependency), &self.current_dependencies, &self.previous_dependencies);
        self.current_dependencies.clearRetainingCapacity();
        
        self.current_observer = obs;
    }
    
    /// Stop tracking and cleanup old dependencies (Svelte 5 effect cleanup)
    pub fn stopTracking(self: *Self) void {
        // Remove observer from previous dependencies that are no longer needed
        if (self.current_observer) |obs| {
            for (self.previous_dependencies.items) |dep| {
                // Check if this dependency is not in current dependencies
                var found = false;
                for (self.current_dependencies.items) |current_dep| {
                    if (dep.ptr == current_dep.ptr) {
                        found = true;
                        break;
                    }
                }
                
                if (!found) {
                    // This dependency is no longer needed, remove observer
                    dep.removeObserver(obs);
                }
            }
        }
        
        // Clear previous dependencies
        self.previous_dependencies.clearRetainingCapacity();
        
        // Restore previous observer from stack
        if (self.observer_stack.items.len > 0) {
            self.current_observer = self.observer_stack.pop();
        } else {
            self.current_observer = null;
        }
    }
    
    /// Track a dependency (called by signals when read) - Svelte 5 automatic tracking
    pub fn trackDependency(self: *Self, dependency: observer.Dependency) !void {
        if (self.current_observer) |obs| {
            // Add this observer to the dependency
            try dependency.addObserver(obs);
            
            // Track this dependency for cleanup
            try self.current_dependencies.append(dependency);
        }
    }
    
    /// Check if currently tracking (Svelte 5 $effect.tracking)
    pub fn isTracking(self: *const Self) bool {
        return self.current_observer != null;
    }
    
    /// Get current observer (if any)
    pub fn getCurrentObserver(self: *const Self) ?*const observer.Observer {
        return self.current_observer;
    }
    
    /// Get tracking depth (for debugging nested effects)
    pub fn getTrackingDepth(self: *const Self) usize {
        return self.observer_stack.items.len + if (self.current_observer != null) @as(usize, 1) else 0;
    }
    
    /// Get current dependency count (for optimization analysis)
    pub fn getCurrentDependencyCount(self: *const Self) usize {
        return self.current_dependencies.items.len;
    }
};

/// Thread-local reactive context for automatic dependency tracking
/// This provides the global context that Svelte 5 uses for automatic tracking
threadlocal var reactive_context: ?*ReactiveContext = null;

/// Initialize thread-local reactive context
pub fn initContext(allocator: std.mem.Allocator) !void {
    if (reactive_context != null) return;
    
    const ctx = try allocator.create(ReactiveContext);
    ctx.* = ReactiveContext.init(allocator);
    reactive_context = ctx;
}

/// Cleanup thread-local reactive context
pub fn deinitContext(allocator: std.mem.Allocator) void {
    if (reactive_context) |ctx| {
        ctx.deinit();
        allocator.destroy(ctx);
        reactive_context = null;
    }
}

/// Get current reactive context
pub fn getContext() ?*ReactiveContext {
    return reactive_context;
}

/// Track a dependency in the current context (Svelte 5 automatic tracking)
pub fn trackDependency(dependency: observer.Dependency) void {
    if (reactive_context) |ctx| {
        ctx.trackDependency(dependency) catch {
            // Silently ignore tracking errors (non-critical for functionality)
        };
    }
}

/// Execute a function with dependency tracking (effect execution wrapper)
pub fn withTracking(
    obs: *const observer.Observer,
    comptime func: fn () void
) void {
    if (reactive_context) |ctx| {
        ctx.startTracking(obs) catch {
            // If we can't track, just run the function
            func();
            return;
        };
        defer ctx.stopTracking();
        
        func();
    } else {
        // No context, just run the function
        func();
    }
}

/// Execute a function without tracking dependencies (Svelte 5 untrack)
/// This is the equivalent of Svelte 5's untrack() function
pub fn untrack(comptime T: type, untrack_fn: *const fn () T) T {
    const ctx = getContext();
    if (ctx) |reactive_ctx| {
        // Temporarily disable tracking by clearing current observer
        const saved_observer = reactive_ctx.current_observer;
        reactive_ctx.current_observer = null;
        defer reactive_ctx.current_observer = saved_observer;
        
        return untrack_fn();
    } else {
        // No context, just run the function
        return untrack_fn();
    }
}

/// Check if code is running in a tracking context (Svelte 5 $effect.tracking)
pub fn isTracking() bool {
    if (getContext()) |ctx| {
        return ctx.isTracking();
    }
    return false;
}

/// Get tracking depth for debugging nested effects
pub fn getTrackingDepth() usize {
    if (getContext()) |ctx| {
        return ctx.getTrackingDepth();
    }
    return 0;
}

/// Get current dependency count for optimization analysis
pub fn getCurrentDependencyCount() usize {
    if (getContext()) |ctx| {
        return ctx.getCurrentDependencyCount();
    }
    return 0;
}

/// Tracking scope for manual dependency management
/// This provides more explicit control over tracking similar to Svelte 5's effect roots
pub const TrackingScope = struct {
    context: *ReactiveContext,
    scope_observer: observer.Observer,
    dependencies: std.ArrayList(observer.Dependency),
    allocator: std.mem.Allocator,
    is_active: bool = true,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, scope_fn: utils.CallbackTypes.EffectFn) !Self {
        const ctx = getContext() orelse return error.NoReactiveContext;
        
        var scope = Self{
            .context = ctx,
            .scope_observer = undefined,
            .dependencies = std.ArrayList(observer.Dependency).init(allocator),
            .allocator = allocator,
            .is_active = true,
        };
        
        // Create observer for this scope
        scope.scope_observer = observer.createObserver(
            TrackingScope,
            &scope,
            TrackingScope.onDependencyChange,
            TrackingScope.cleanup
        );
        
        // Execute the scope function with tracking
        scope.execute(scope_fn);
        
        return scope;
    }
    
    pub fn deinit(self: *Self) void {
        self.cleanup();
        self.dependencies.deinit();
    }
    
    /// Execute function within this tracking scope
    pub fn execute(self: *Self, func: utils.CallbackTypes.EffectFn) void {
        if (!self.is_active) return;
        
        withTracking(&self.scope_observer, func);
    }
    
    /// Dispose of this scope and cleanup all dependencies
    pub fn dispose(self: *Self) void {
        self.is_active = false;
        self.cleanup();
    }
    
    /// Check if scope is still active
    pub fn isActive(self: *const Self) bool {
        return self.is_active;
    }
    
    /// Get dependency count for this scope
    pub fn getDependencyCount(self: *const Self) usize {
        return self.dependencies.items.len;
    }
    
    fn onDependencyChange(self: *Self) void {
        // Scope dependencies changed - could trigger re-execution
        _ = self;
        // Implementation depends on specific use case
    }
    
    fn cleanup(self: *Self) void {
        // Remove this observer from all dependencies
        for (self.dependencies.items) |dep| {
            dep.removeObserver(&self.scope_observer);
        }
        self.dependencies.clearRetainingCapacity();
    }
};

// Tests for tracking functionality
test "reactive context basic tracking" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try initContext(allocator);
    defer deinitContext(allocator);
    
    const ctx = getContext().?;
    try std.testing.expect(!ctx.isTracking());
    try std.testing.expect(!isTracking());
    
    // Create a mock observer
    const MockObserver = struct {
        notified: bool = false,
        
        fn notify(self: *@This()) void {
            self.notified = true;
        }
    };
    
    var mock = MockObserver{};
    const obs = observer.createObserver(MockObserver, &mock, MockObserver.notify, null);
    
    try ctx.startTracking(&obs);
    try std.testing.expect(ctx.isTracking());
    try std.testing.expect(isTracking());
    try std.testing.expect(getTrackingDepth() == 1);
    
    ctx.stopTracking();
    try std.testing.expect(!ctx.isTracking());
    try std.testing.expect(!isTracking());
    try std.testing.expect(getTrackingDepth() == 0);
}

test "reactive context nested tracking" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try initContext(allocator);
    defer deinitContext(allocator);
    
    const ctx = getContext().?;
    
    const MockObserver = struct {
        id: u32,
        fn notify(self: *@This()) void {
            _ = self;
        }
    };
    
    var observer1 = MockObserver{ .id = 1 };
    var observer2 = MockObserver{ .id = 2 };
    
    const obs1 = observer.createObserver(MockObserver, &observer1, MockObserver.notify, null);
    const obs2 = observer.createObserver(MockObserver, &observer2, MockObserver.notify, null);
    
    // Start nested tracking
    try ctx.startTracking(&obs1);
    try std.testing.expect(ctx.getCurrentObserver() == &obs1);
    try std.testing.expect(getTrackingDepth() == 1);
    
    try ctx.startTracking(&obs2);
    try std.testing.expect(ctx.getCurrentObserver() == &obs2);
    try std.testing.expect(getTrackingDepth() == 2);
    
    ctx.stopTracking();
    try std.testing.expect(ctx.getCurrentObserver() == &obs1);
    try std.testing.expect(getTrackingDepth() == 1);
    
    ctx.stopTracking();
    try std.testing.expect(ctx.getCurrentObserver() == null);
    try std.testing.expect(getTrackingDepth() == 0);
}

test "untrack function prevents dependency tracking" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try initContext(allocator);
    defer deinitContext(allocator);
    
    const ctx = getContext().?;
    
    const MockObserver = struct {
        fn notify(self: *@This()) void { _ = self; }
    };
    
    var mock = MockObserver{};
    const obs = observer.createObserver(MockObserver, &mock, MockObserver.notify, null);
    
    try ctx.startTracking(&obs);
    try std.testing.expect(isTracking());
    
    // Test untrack prevents tracking inside function
    const result = untrack(bool, struct {
        fn check() bool {
            // This should not be tracked even though we're in a tracking context
            return isTracking();
        }
    }.check);
    
    try std.testing.expect(!result); // Should be false inside untrack
    try std.testing.expect(isTracking()); // Should still be tracking outside
    
    ctx.stopTracking();
}

test "with tracking function wrapper" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try initContext(allocator);
    defer deinitContext(allocator);
    
    var tracking_detected: bool = false;
    
    const MockObserver = struct {
        fn notify(self: *@This()) void { _ = self; }
    };
    
    var mock = MockObserver{};
    const obs = observer.createObserver(MockObserver, &mock, MockObserver.notify, null);
    
    const TestData = struct {
        var detected: *bool = undefined;
    };
    TestData.detected = &tracking_detected;
    
    withTracking(&obs, struct {
        fn testFunc() void {
            TestData.detected.* = isTracking();
        }
    }.testFunc);
    
    try std.testing.expect(tracking_detected); // Should detect tracking inside function
    try std.testing.expect(!isTracking()); // Should not be tracking outside
}