const std = @import("std");
const utils = @import("utils.zig");

/// Observer pattern implementation for reactive system
/// Extracted from context.zig to provide reusable observer management
/// Maintains Svelte 5 semantics for reactive notifications

/// Type-erased observer interface for receiving notifications
/// This is the core of Svelte 5's reactive system - observers get notified when dependencies change
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

/// Type-erased dependency interface for registering observers
/// This allows signals and derived values to manage their observers uniformly
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

/// Observable interface for objects that can have observers
/// This is implemented by Signal and Derived to provide consistent observer management
pub fn Observable(comptime T: type) type {
    return struct {
        const Self = @This();
        
        observers: std.ArrayList(*const Observer),
        allocator: std.mem.Allocator,
        
        pub fn initObservable(allocator: std.mem.Allocator) Self {
            return Self{
                .observers = std.ArrayList(*const Observer).init(allocator),
                .allocator = allocator,
            };
        }
        
        pub fn deinitObservable(self: *Self) void {
            self.observers.deinit();
        }
        
        /// Add observer (Svelte 5 automatic subscription)
        pub fn addObserver(self: *Self, observer: *const Observer) !void {
            try utils.ObserverList.addUnique(Observer, &self.observers, observer);
        }
        
        /// Remove observer (Svelte 5 automatic cleanup)
        pub fn removeObserver(self: *Self, observer: *const Observer) void {
            utils.ObserverList.removeSwap(Observer, &self.observers, observer);
        }
        
        /// Notify all observers immediately (push notification)
        pub fn notifyObserversImmediate(self: *Self) void {
            // Create a copy of observers to prevent issues with concurrent modifications
            const observers_copy = self.allocator.dupe(*const Observer, self.observers.items) catch {
                // If we can't allocate, just iterate directly (may miss concurrent changes)
                for (self.observers.items) |observer| {
                    observer.notify();
                }
                return;
            };
            defer self.allocator.free(observers_copy);
            
            for (observers_copy) |observer| {
                observer.notify();
            }
        }
        
        /// Check if has any observers
        pub fn hasObservers(self: *const Self) bool {
            return self.observers.items.len > 0;
        }
        
        /// Get observer count (for debugging/optimization)
        pub fn getObserverCount(self: *const Self) usize {
            return self.observers.items.len;
        }
    };
}

/// Helper to create a dependency from a signal-like object
/// This provides the type erasure needed for dependency tracking
pub fn createDependency(
    comptime T: type,
    signal: *T,
    comptime add_observer_fn: fn (*T, *const Observer) anyerror!void,
    comptime remove_observer_fn: fn (*T, *const Observer) void
) Dependency {
    const Wrapper = struct {
        fn addObserver(ptr: *anyopaque, observer: *const Observer) anyerror!void {
            const sig = @as(*T, @ptrCast(@alignCast(ptr)));
            try add_observer_fn(sig, observer);
        }
        
        fn removeObserver(ptr: *anyopaque, observer: *const Observer) void {
            const sig = @as(*T, @ptrCast(@alignCast(ptr)));
            remove_observer_fn(sig, observer);
        }
    };
    
    return Dependency{
        .ptr = signal,
        .add_observer_fn = Wrapper.addObserver,
        .remove_observer_fn = Wrapper.removeObserver,
    };
}

/// Helper to create an observer from an effect-like object
/// This provides the type erasure needed for effect notifications
pub fn createObserver(
    comptime T: type,
    effect: *T,
    comptime notify_fn: fn (*T) void,
    comptime cleanup_fn: ?fn (*T) void
) Observer {
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
    
    return Observer{
        .ptr = effect,
        .notify_fn = Wrapper.notify,
        .cleanup_fn = if (cleanup_fn != null) Wrapper.cleanup else null,
    };
}

/// Observer manager for batched notifications
/// This handles the batching semantics required by Svelte 5
pub const ObserverManager = struct {
    observers: std.ArrayList(*const Observer),
    pending_notifications: std.ArrayList(*const Observer),
    allocator: std.mem.Allocator,
    is_notifying: bool = false,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .observers = std.ArrayList(*const Observer).init(allocator),
            .pending_notifications = std.ArrayList(*const Observer).init(allocator),
            .allocator = allocator,
            .is_notifying = false,
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.observers.deinit();
        self.pending_notifications.deinit();
    }
    
    /// Add observer to the managed list
    pub fn addObserver(self: *Self, observer: *const Observer) !void {
        try utils.ObserverList.addUnique(Observer, &self.observers, observer);
    }
    
    /// Remove observer from the managed list
    pub fn removeObserver(self: *Self, observer: *const Observer) void {
        utils.ObserverList.removeSwap(Observer, &self.observers, observer);
        utils.ObserverList.removeSwap(Observer, &self.pending_notifications, observer);
    }
    
    /// Queue a notification for batched execution
    pub fn queueNotification(self: *Self, observer: *const Observer) !void {
        if (self.is_notifying) {
            // If we're already notifying, queue for next batch
            try utils.ObserverList.addUnique(Observer, &self.pending_notifications, observer);
        } else {
            // Immediate notification
            observer.notify();
        }
    }
    
    /// Start batch mode (defer notifications)
    pub fn startBatch(self: *Self) void {
        self.is_notifying = true;
    }
    
    /// End batch mode and flush all pending notifications
    pub fn endBatch(self: *Self) void {
        if (!self.is_notifying) return;
        
        self.is_notifying = false;
        
        // Notify all pending observers
        const pending_copy = self.allocator.dupe(*const Observer, self.pending_notifications.items) catch {
            // If allocation fails, just notify directly
            for (self.pending_notifications.items) |observer| {
                observer.notify();
            }
            self.pending_notifications.clearRetainingCapacity();
            return;
        };
        defer self.allocator.free(pending_copy);
        
        self.pending_notifications.clearRetainingCapacity();
        
        for (pending_copy) |observer| {
            observer.notify();
        }
    }
    
    /// Execute function with batched notifications
    pub fn batch(self: *Self, batch_fn: utils.CallbackTypes.BatchFn) void {
        self.startBatch();
        defer self.endBatch();
        batch_fn();
    }
    
    /// Check if currently in batch mode
    pub fn isBatching(self: *const Self) bool {
        return self.is_notifying;
    }
};

// Tests for observer pattern functionality
test "observer basic operations" {
    const MockEffect = struct {
        notified: bool = false,
        
        fn notify(self: *@This()) void {
            self.notified = true;
        }
        
        fn cleanup(self: *@This()) void {
            self.notified = false;
        }
    };
    
    var effect = MockEffect{};
    const observer = createObserver(MockEffect, &effect, MockEffect.notify, MockEffect.cleanup);
    
    try std.testing.expect(!effect.notified);
    
    observer.notify();
    try std.testing.expect(effect.notified);
    
    observer.cleanup();
    try std.testing.expect(!effect.notified);
}

test "observable mixin functionality" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const TestObservable = struct {
        observable: Observable(@This()),
        value: i32 = 0,
        
        pub fn init(alloc: std.mem.Allocator, initial_value: i32) @This() {
            return @This(){
                .observable = Observable(@This()).initObservable(alloc),
                .value = initial_value,
            };
        }
        
        pub fn deinit(self: *@This()) void {
            self.observable.deinitObservable();
        }
        
        pub fn addObserver(self: *@This(), observer: *const Observer) !void {
            try self.observable.addObserver(observer);
        }
        
        pub fn removeObserver(self: *@This(), observer: *const Observer) void {
            self.observable.removeObserver(observer);
        }
        
        pub fn setValue(self: *@This(), new_value: i32) void {
            self.value = new_value;
            self.observable.notifyObserversImmediate();
        }
    };
    
    var observable = TestObservable.init(allocator, 10);
    defer observable.deinit();
    
    const MockEffect = struct {
        notified: bool = false,
        fn notify(self: *@This()) void { self.notified = true; }
    };
    
    var effect = MockEffect{};
    const observer = createObserver(MockEffect, &effect, MockEffect.notify, null);
    
    try std.testing.expect(!observable.observable.hasObservers());
    
    try observable.addObserver(&observer);
    try std.testing.expect(observable.observable.hasObservers());
    try std.testing.expect(observable.observable.getObserverCount() == 1);
    
    observable.setValue(20);
    try std.testing.expect(effect.notified);
    
    observable.removeObserver(&observer);
    try std.testing.expect(!observable.observable.hasObservers());
}

test "observer manager batching" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var manager = ObserverManager.init(allocator);
    defer manager.deinit();
    
    const MockEffect = struct {
        notify_count: u32 = 0,
        fn notify(self: *@This()) void { self.notify_count += 1; }
    };
    
    var effect1 = MockEffect{};
    var effect2 = MockEffect{};
    
    const observer1 = createObserver(MockEffect, &effect1, MockEffect.notify, null);
    const observer2 = createObserver(MockEffect, &effect2, MockEffect.notify, null);
    
    try manager.addObserver(&observer1);
    try manager.addObserver(&observer2);
    
    // Test immediate notifications
    try manager.queueNotification(&observer1);
    try std.testing.expect(effect1.notify_count == 1);
    
    // Test batched notifications
    manager.startBatch();
    try manager.queueNotification(&observer1);
    try manager.queueNotification(&observer2);
    
    // Should not have been notified yet
    try std.testing.expect(effect1.notify_count == 1); // No change
    try std.testing.expect(effect2.notify_count == 0);
    
    manager.endBatch();
    
    // Now both should be notified
    try std.testing.expect(effect1.notify_count == 2);
    try std.testing.expect(effect2.notify_count == 1);
}