//! Gannaway State - Alternative reactive state container with explicit notification
//!
//! Key differences from reactive.Signal:
//! - Explicit notify() required after mutations
//! - Direct observer list instead of automatic tracking
//! - Version counter for change detection
//! - No automatic equality checking

const std = @import("std");

/// Watchable interface for observers
pub const Watchable = struct {
    pub const VTable = struct {
        getName: *const fn (self: *const Watchable) []const u8,
        getVersion: *const fn (self: *const Watchable) u64,
    };

    vtable: *const VTable,
    ptr: *anyopaque,

    pub fn getName(self: *const Watchable) []const u8 {
        return self.vtable.getName(self);
    }

    pub fn getVersion(self: *const Watchable) u64 {
        return self.vtable.getVersion(self);
    }
};

/// Observer interface for watchers
pub const Observer = struct {
    pub const VTable = struct {
        onNotify: *const fn (self: *Observer, source: *const Watchable) void,
    };

    vtable: *const VTable,
    ptr: *anyopaque,

    pub fn onNotify(self: *Observer, source: *const Watchable) void {
        self.vtable.onNotify(self, source);
    }
};

/// State container with explicit notification
pub fn State(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        value: T,
        observers: std.ArrayList(*Observer),
        version: u64,
        name: []const u8,
        watchable: Watchable,

        const vtable = Watchable.VTable{
            .getName = getName,
            .getVersion = getVersion,
        };

        fn getName(watchable: *const Watchable) []const u8 {
            const self: *const Self = @fieldParentPtr("watchable", watchable);
            return self.name;
        }

        fn getVersion(watchable: *const Watchable) u64 {
            const self: *const Self = @fieldParentPtr("watchable", watchable);
            return self.version;
        }

        /// Initialize a new state container
        pub fn init(allocator: std.mem.Allocator, initial_value: T) !*Self {
            const self = try allocator.create(Self);
            self.* = .{
                .allocator = allocator,
                .value = initial_value,
                .observers = std.ArrayList(*Observer).init(allocator),
                .version = 0,
                .name = @typeName(T),
                .watchable = .{
                    .vtable = &vtable,
                    .ptr = self,
                },
            };
            return self;
        }

        /// Clean up state container
        pub fn deinit(self: *Self) void {
            self.observers.deinit();
            self.allocator.destroy(self);
        }

        /// Get current value
        pub fn get(self: *const Self) T {
            return self.value;
        }

        /// Set new value (requires explicit notify() to trigger observers)
        pub fn set(self: *Self, new_value: T) void {
            self.value = new_value;
            self.version +%= 1;
        }

        /// Explicitly notify all observers of changes
        pub fn notify(self: *Self) void {
            // Notify all observers
            for (self.observers.items) |observer| {
                observer.onNotify(&self.watchable);
            }
        }

        /// Subscribe an observer to this state
        pub fn subscribe(self: *Self, observer: *Observer) !void {
            try self.observers.append(observer);
        }

        /// Unsubscribe an observer
        pub fn unsubscribe(self: *Self, observer: *Observer) void {
            for (self.observers.items, 0..) |obs, i| {
                if (obs == observer) {
                    _ = self.observers.swapRemove(i);
                    break;
                }
            }
        }

        /// Get as watchable interface
        pub fn asWatchable(self: *Self) *Watchable {
            return &self.watchable;
        }

        /// Convenience: set and notify in one call
        pub fn update(self: *Self, new_value: T) void {
            self.set(new_value);
            self.notify();
        }
    };
}

// Tests
test "state basics" {
    const allocator = std.testing.allocator;

    var state = try State(u32).init(allocator, 42);
    defer state.deinit();

    try std.testing.expect(state.get() == 42);

    state.set(100);
    try std.testing.expect(state.get() == 100);
    try std.testing.expect(state.version == 1);
}

test "state explicit notification" {
    const allocator = std.testing.allocator;

    var state = try State(i32).init(allocator, 0);
    defer state.deinit();

    // Track notifications
    var notified = false;
    var notified_version: u64 = 0;

    const TestObserver = struct {
        notified: *bool,
        version: *u64,
        observer: Observer,

        const obs_vtable = Observer.VTable{
            .onNotify = onNotify,
        };

        fn onNotify(observer: *Observer, source: *const Watchable) void {
            const self: *@This() = @fieldParentPtr("observer", observer);
            self.notified.* = true;
            self.version.* = source.getVersion();
        }
    };

    var test_observer = TestObserver{
        .notified = &notified,
        .version = &notified_version,
        .observer = .{
            .vtable = &TestObserver.obs_vtable,
            .ptr = undefined,
        },
    };
    test_observer.observer.ptr = &test_observer;

    try state.subscribe(&test_observer.observer);

    // Set without notify - no notification
    state.set(10);
    try std.testing.expect(notified == false);

    // Explicit notify - triggers notification
    state.notify();
    try std.testing.expect(notified == true);
    try std.testing.expect(notified_version == 1);

    // Update helper - set and notify
    notified = false;
    state.update(20);
    try std.testing.expect(state.get() == 20);
    try std.testing.expect(notified == true);
    try std.testing.expect(notified_version == 2);
}

test "state multiple observers" {
    const allocator = std.testing.allocator;

    var state = try State(f32).init(allocator, 1.0);
    defer state.deinit();

    var count1: u32 = 0;
    var count2: u32 = 0;

    const CountObserver = struct {
        count: *u32,
        observer: Observer,

        const obs_vtable = Observer.VTable{
            .onNotify = onNotify,
        };

        fn onNotify(observer: *Observer, source: *const Watchable) void {
            _ = source;
            const self: *@This() = @fieldParentPtr("observer", observer);
            self.count.* += 1;
        }
    };

    var observer1 = CountObserver{
        .count = &count1,
        .observer = .{
            .vtable = &CountObserver.obs_vtable,
            .ptr = undefined,
        },
    };
    observer1.observer.ptr = &observer1;

    var observer2 = CountObserver{
        .count = &count2,
        .observer = .{
            .vtable = &CountObserver.obs_vtable,
            .ptr = undefined,
        },
    };
    observer2.observer.ptr = &observer2;

    try state.subscribe(&observer1.observer);
    try state.subscribe(&observer2.observer);

    state.update(2.0);
    try std.testing.expect(count1 == 1);
    try std.testing.expect(count2 == 1);

    state.update(3.0);
    try std.testing.expect(count1 == 2);
    try std.testing.expect(count2 == 2);

    // Unsubscribe one
    state.unsubscribe(&observer1.observer);

    state.update(4.0);
    try std.testing.expect(count1 == 2); // No change
    try std.testing.expect(count2 == 3); // Still notified
}
