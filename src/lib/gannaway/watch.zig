//! Gannaway Watch - Observer system with explicit target declaration
//!
//! Key differences from reactive.Effect:
//! - Explicit target declaration instead of automatic tracking
//! - Manual pause/resume control
//! - Direct callback invocation
//! - No cleanup function (manage manually)

const std = @import("std");
const state_mod = @import("state.zig");

const Watchable = state_mod.Watchable;
const Observer = state_mod.Observer;

/// Configuration for creating a watcher
pub const WatchConfig = struct {
    targets: []const *Watchable,
    callback: *const fn (changed: *const Watchable) void,
    name: ?[]const u8 = null,
};

/// Watcher that observes multiple targets
pub const Watcher = struct {
    const Self = @This();
    
    allocator: std.mem.Allocator,
    targets: std.ArrayList(*Watchable),
    callback: *const fn (changed: *const Watchable) void,
    is_active: bool,
    name: []const u8,
    observer: Observer,
    run_count: u64,
    
    const observer_vtable = Observer.VTable{
        .onNotify = onNotify,
    };
    
    fn onNotify(observer: *Observer, source: *const Watchable) void {
        const self: *Self = @fieldParentPtr("observer", observer);
        if (self.is_active) {
            self.callback(source);
            self.run_count += 1;
        }
    }
    
    /// Initialize a new watcher
    pub fn init(allocator: std.mem.Allocator, config: WatchConfig) !*Self {
        const self = try allocator.create(Self);
        
        self.* = .{
            .allocator = allocator,
            .targets = std.ArrayList(*Watchable).init(allocator),
            .callback = config.callback,
            .is_active = true,
            .name = config.name orelse "watcher",
            .observer = .{
                .vtable = &observer_vtable,
                .ptr = self,
            },
            .run_count = 0,
        };
        
        // Add all targets
        for (config.targets) |target| {
            try self.targets.append(target);
        }
        
        // Run initial callback for each target
        for (self.targets.items) |target| {
            self.callback(target);
            self.run_count += 1;
        }
        
        return self;
    }
    
    /// Clean up watcher
    pub fn deinit(self: *Self) void {
        self.targets.deinit();
        self.allocator.destroy(self);
    }
    
    /// Pause watching (callbacks won't fire)
    pub fn pause(self: *Self) void {
        self.is_active = false;
    }
    
    /// Resume watching
    pub fn unpause(self: *Self) void {
        self.is_active = true;
    }
    
    /// Check if watcher is active
    pub fn isActive(self: *const Self) bool {
        return self.is_active;
    }
    
    /// Get number of times callback has run
    pub fn getRunCount(self: *const Self) u64 {
        return self.run_count;
    }
    
    /// Get as observer interface
    pub fn asObserver(self: *Self) *Observer {
        return &self.observer;
    }
    
    /// Manually trigger the callback for all targets
    pub fn trigger(self: *Self) void {
        if (self.is_active) {
            for (self.targets.items) |target| {
                self.callback(target);
                self.run_count += 1;
            }
        }
    }
    
    /// Add a new target to watch
    pub fn addTarget(self: *Self, target: *Watchable) !void {
        try self.targets.append(target);
        // Run callback for new target
        if (self.is_active) {
            self.callback(target);
            self.run_count += 1;
        }
    }
    
    /// Remove a target from watching
    pub fn removeTarget(self: *Self, target: *Watchable) void {
        for (self.targets.items, 0..) |t, i| {
            if (t == target) {
                _ = self.targets.swapRemove(i);
                break;
            }
        }
    }
};

/// Convenience function for creating watchers
pub fn watch(allocator: std.mem.Allocator, config: WatchConfig) !*Watcher {
    return try Watcher.init(allocator, config);
}

// Tests
test "watcher basics" {
    const allocator = std.testing.allocator;
    const State = state_mod.State;
    
    var state = try State(i32).init(allocator, 42);
    defer state.deinit();
    
    var callback_count: u32 = 0;
    var last_name: []const u8 = "";
    var last_version: u64 = 0;
    
    const TestData = struct {
        var count: *u32 = undefined;
        var name: *[]const u8 = undefined;
        var version: *u64 = undefined;
    };
    TestData.count = &callback_count;
    TestData.name = &last_name;
    TestData.version = &last_version;
    
    var watcher = try watch(allocator, .{
        .targets = &[_]*Watchable{state.asWatchable()},
        .callback = struct {
            fn onChange(changed: *const Watchable) void {
                TestData.count.* += 1;
                TestData.name.* = changed.getName();
                TestData.version.* = changed.getVersion();
            }
        }.onChange,
    });
    defer watcher.deinit();
    
    // Subscribe watcher to state
    try state.subscribe(watcher.asObserver());
    
    // Initial callback should have run
    try std.testing.expect(callback_count == 1);
    try std.testing.expect(watcher.getRunCount() == 1);
    
    // Update state
    state.update(100);
    try std.testing.expect(callback_count == 2);
    try std.testing.expect(last_version == 1);
}

test "watcher pause and resume" {
    const allocator = std.testing.allocator;
    const State = state_mod.State;
    
    var state = try State(bool).init(allocator, false);
    defer state.deinit();
    
    var callback_count: u32 = 0;
    
    const TestData = struct {
        var count: *u32 = undefined;
    };
    TestData.count = &callback_count;
    
    var watcher = try watch(allocator, .{
        .targets = &[_]*Watchable{state.asWatchable()},
        .callback = struct {
            fn onChange(changed: *const Watchable) void {
                _ = changed;
                TestData.count.* += 1;
            }
        }.onChange,
    });
    defer watcher.deinit();
    
    try state.subscribe(watcher.asObserver());
    
    // Initial run
    try std.testing.expect(callback_count == 1);
    
    // Pause watcher
    watcher.pause();
    try std.testing.expect(!watcher.isActive());
    
    // Update while paused - no callback
    state.update(true);
    try std.testing.expect(callback_count == 1);
    
    // Resume watcher
    watcher.unpause();
    try std.testing.expect(watcher.isActive());
    
    // Update while active - callback fires
    state.update(false);
    try std.testing.expect(callback_count == 2);
}

test "watcher with multiple targets" {
    const allocator = std.testing.allocator;
    const State = state_mod.State;
    
    var x = try State(f32).init(allocator, 1.0);
    defer x.deinit();
    
    var y = try State(f32).init(allocator, 2.0);
    defer y.deinit();
    
    var callback_count: u32 = 0;
    var changes = std.ArrayList([]const u8).init(allocator);
    defer changes.deinit();
    
    const TestData = struct {
        var count: *u32 = undefined;
        var change_list: *std.ArrayList([]const u8) = undefined;
    };
    TestData.count = &callback_count;
    TestData.change_list = &changes;
    
    var watcher = try watch(allocator, .{
        .targets = &[_]*Watchable{ x.asWatchable(), y.asWatchable() },
        .callback = struct {
            fn onChange(changed: *const Watchable) void {
                TestData.count.* += 1;
                TestData.change_list.append(changed.getName()) catch {};
            }
        }.onChange,
        .name = "multi_watcher",
    });
    defer watcher.deinit();
    
    try x.subscribe(watcher.asObserver());
    try y.subscribe(watcher.asObserver());
    
    // Initial callbacks for both targets
    try std.testing.expect(callback_count == 2);
    
    // Update x
    x.update(5.0);
    try std.testing.expect(callback_count == 3);
    
    // Update y
    y.update(10.0);
    try std.testing.expect(callback_count == 4);
    
    // Both updated
    x.update(15.0);
    y.update(20.0);
    try std.testing.expect(callback_count == 6);
}

test "watcher manual trigger" {
    const allocator = std.testing.allocator;
    const State = state_mod.State;
    
    var state = try State(u8).init(allocator, 0);
    defer state.deinit();
    
    var callback_count: u32 = 0;
    
    const TestData = struct {
        var count: *u32 = undefined;
    };
    TestData.count = &callback_count;
    
    var watcher = try watch(allocator, .{
        .targets = &[_]*Watchable{state.asWatchable()},
        .callback = struct {
            fn onChange(changed: *const Watchable) void {
                _ = changed;
                TestData.count.* += 1;
            }
        }.onChange,
    });
    defer watcher.deinit();
    
    // Initial run
    try std.testing.expect(callback_count == 1);
    
    // Manual trigger
    watcher.trigger();
    try std.testing.expect(callback_count == 2);
    
    // Manual trigger while paused - no effect
    watcher.pause();
    watcher.trigger();
    try std.testing.expect(callback_count == 2);
}