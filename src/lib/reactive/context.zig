const std = @import("std");

/// Reactive context for automatic dependency tracking
/// This manages the current computation context and tracks dependencies
pub const ReactiveContext = struct {
    const Self = @This();
    
    /// Type-erased observer interface
    pub const Observer = struct {
        ptr: *anyopaque,
        notify_fn: *const fn (*anyopaque) void,
        cleanup_fn: ?*const fn (*anyopaque) void = null,
        
        pub fn notify(self: *const Observer) void {
            self.notify_fn(self.ptr);
        }
        
        pub fn cleanup(self: *const Observer) void {
            if (self.cleanup_fn) |cleanup_fn| {
                cleanup_fn(self.ptr);
            }
        }
    };
    
    /// Type-erased signal interface for dependency tracking
    pub const Dependency = struct {
        ptr: *anyopaque,
        add_observer_fn: *const fn (*anyopaque, *const Observer) anyerror!void,
        remove_observer_fn: *const fn (*anyopaque, *const Observer) void,
        
        pub fn addObserver(self: *const Dependency, observer: *const Observer) !void {
            try self.add_observer_fn(self.ptr, observer);
        }
        
        pub fn removeObserver(self: *const Dependency, observer: *const Observer) void {
            self.remove_observer_fn(self.ptr, observer);
        }
    };
    
    /// Current computation being executed
    current_observer: ?*const Observer = null,
    
    /// Stack of nested computations (for nested effects)
    observer_stack: std.ArrayList(*const Observer),
    
    /// Dependencies collected during current computation
    current_dependencies: std.ArrayList(Dependency),
    
    /// Previous dependencies (for cleanup)
    previous_dependencies: std.ArrayList(Dependency),
    
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .current_observer = null,
            .observer_stack = std.ArrayList(*const Observer).init(allocator),
            .current_dependencies = std.ArrayList(Dependency).init(allocator),
            .previous_dependencies = std.ArrayList(Dependency).init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.observer_stack.deinit();
        self.current_dependencies.deinit();
        self.previous_dependencies.deinit();
    }
    
    /// Start tracking dependencies for a computation
    pub fn startTracking(self: *Self, observer: *const Observer) !void {
        // Save current observer on stack (for nested computations)
        if (self.current_observer) |current| {
            try self.observer_stack.append(current);
        }
        
        // Move current deps to previous (for cleanup later)
        std.mem.swap(std.ArrayList(Dependency), &self.current_dependencies, &self.previous_dependencies);
        self.current_dependencies.clearRetainingCapacity();
        
        self.current_observer = observer;
    }
    
    /// Stop tracking and cleanup old dependencies
    pub fn stopTracking(self: *Self) void {
        // Remove observer from previous dependencies
        if (self.current_observer) |observer| {
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
                    dep.removeObserver(observer);
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
    
    /// Track a dependency (called by signals when read)
    pub fn trackDependency(self: *Self, dependency: Dependency) !void {
        if (self.current_observer) |observer| {
            // Add this observer to the dependency
            try dependency.addObserver(observer);
            
            // Track this dependency for cleanup
            try self.current_dependencies.append(dependency);
        }
    }
    
    /// Check if currently tracking
    pub fn isTracking(self: *const Self) bool {
        return self.current_observer != null;
    }
    
    /// Get current observer (if any)
    pub fn getCurrentObserver(self: *const Self) ?*const Observer {
        return self.current_observer;
    }
};

/// Thread-local reactive context
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

/// Track a dependency in the current context
pub fn trackDependency(dependency: ReactiveContext.Dependency) void {
    if (reactive_context) |ctx| {
        ctx.trackDependency(dependency) catch {
            // Silently ignore tracking errors (non-critical)
        };
    }
}

/// Execute a function with dependency tracking
pub fn withTracking(
    observer: *const ReactiveContext.Observer,
    comptime func: fn () void
) void {
    if (reactive_context) |ctx| {
        ctx.startTracking(observer) catch {
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

/// Execute a function without tracking dependencies
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

/// Helper to create a dependency from a signal-like object
pub fn createDependency(
    comptime T: type,
    signal: *T,
    comptime add_observer_fn: fn (*T, *const ReactiveContext.Observer) anyerror!void,
    comptime remove_observer_fn: fn (*T, *const ReactiveContext.Observer) void
) ReactiveContext.Dependency {
    const Wrapper = struct {
        fn addObserver(ptr: *anyopaque, observer: *const ReactiveContext.Observer) anyerror!void {
            const sig = @as(*T, @ptrCast(@alignCast(ptr)));
            try add_observer_fn(sig, observer);
        }
        
        fn removeObserver(ptr: *anyopaque, observer: *const ReactiveContext.Observer) void {
            const sig = @as(*T, @ptrCast(@alignCast(ptr)));
            remove_observer_fn(sig, observer);
        }
    };
    
    return ReactiveContext.Dependency{
        .ptr = signal,
        .add_observer_fn = Wrapper.addObserver,
        .remove_observer_fn = Wrapper.removeObserver,
    };
}

/// Helper to create an observer from an effect-like object
pub fn createObserver(
    comptime T: type,
    effect: *T,
    comptime notify_fn: fn (*T) void,
    comptime cleanup_fn: ?fn (*T) void
) ReactiveContext.Observer {
    const Wrapper = struct {
        fn notify(ptr: *anyopaque) void {
            const eff = @as(*T, @ptrCast(@alignCast(ptr)));
            notify_fn(eff);
        }
        
        fn cleanup(ptr: *anyopaque) void {
            if (cleanup_fn) |clean| {
                const eff = @as(*T, @ptrCast(@alignCast(ptr)));
                clean(eff);
            }
        }
    };
    
    return ReactiveContext.Observer{
        .ptr = effect,
        .notify_fn = Wrapper.notify,
        .cleanup_fn = if (cleanup_fn != null) Wrapper.cleanup else null,
    };
}

// Tests
test "reactive context basic tracking" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try initContext(allocator);
    defer deinitContext(allocator);
    
    const ctx = getContext().?;
    try std.testing.expect(!ctx.isTracking());
    
    // Create a mock observer
    const MockObserver = struct {
        notified: bool = false,
        
        fn notify(self: *@This()) void {
            self.notified = true;
        }
    };
    
    var mock = MockObserver{};
    const observer = createObserver(MockObserver, &mock, MockObserver.notify, null);
    
    try ctx.startTracking(&observer);
    try std.testing.expect(ctx.isTracking());
    
    ctx.stopTracking();
    try std.testing.expect(!ctx.isTracking());
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
    
    const obs1 = createObserver(MockObserver, &observer1, MockObserver.notify, null);
    const obs2 = createObserver(MockObserver, &observer2, MockObserver.notify, null);
    
    // Start nested tracking
    try ctx.startTracking(&obs1);
    try std.testing.expect(ctx.getCurrentObserver() == &obs1);
    
    try ctx.startTracking(&obs2);
    try std.testing.expect(ctx.getCurrentObserver() == &obs2);
    
    ctx.stopTracking();
    try std.testing.expect(ctx.getCurrentObserver() == &obs1);
    
    ctx.stopTracking();
    try std.testing.expect(ctx.getCurrentObserver() == null);
}