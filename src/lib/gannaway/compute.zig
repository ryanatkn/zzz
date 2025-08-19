//! Gannaway Compute - Computed values with lazy evaluation and explicit dependencies
//!
//! Key differences from reactive.Derived:
//! - Explicit dependency declaration upfront
//! - Manual invalidation on dependency change
//! - Lazy evaluation with caching
//! - No automatic dependency tracking

const std = @import("std");
const state_mod = @import("state.zig");

const Watchable = state_mod.Watchable;
const Observer = state_mod.Observer;

/// Computed value with lazy evaluation
pub fn Compute(comptime T: type) type {
    return struct {
        const Self = @This();
        
        allocator: std.mem.Allocator,
        cached_value: T,
        is_dirty: bool,
        dependencies: std.ArrayList(*Watchable),
        dependency_versions: std.ArrayList(u64),
        compute_fn: *const fn () T,
        version: u64,
        name: []const u8,
        watchable: Watchable,
        observer: Observer,
        
        const watchable_vtable = Watchable.VTable{
            .getName = getName,
            .getVersion = getVersion,
        };
        
        const observer_vtable = Observer.VTable{
            .onNotify = onNotify,
        };
        
        fn getName(watchable: *const Watchable) []const u8 {
            const self: *const Self = @fieldParentPtr("watchable", watchable);
            return self.name;
        }
        
        fn getVersion(watchable: *const Watchable) u64 {
            const self: *const Self = @fieldParentPtr("watchable", watchable);
            return self.version;
        }
        
        fn onNotify(observer: *Observer, source: *const Watchable) void {
            _ = source;
            const self: *Self = @fieldParentPtr("observer", observer);
            self.invalidate();
        }
        
        /// Configuration for creating a computed value
        pub const Config = struct {
            dependencies: []const *Watchable,
            compute_fn: *const fn () T,
            name: ?[]const u8 = null,
        };
        
        /// Initialize a new computed value
        pub fn init(allocator: std.mem.Allocator, config: Config) !*Self {
            const self = try allocator.create(Self);
            
            // Store function for compute
            const stored_fn = config.compute_fn;
            
            self.* = .{
                .allocator = allocator,
                .cached_value = undefined,
                .is_dirty = true,
                .dependencies = std.ArrayList(*Watchable).init(allocator),
                .dependency_versions = std.ArrayList(u64).init(allocator),
                .compute_fn = stored_fn,
                .version = 0,
                .name = config.name orelse @typeName(T),
                .watchable = .{
                    .vtable = &watchable_vtable,
                    .ptr = self,
                },
                .observer = .{
                    .vtable = &observer_vtable,
                    .ptr = self,
                },
            };
            
            // Add dependencies and subscribe to them
            for (config.dependencies) |dep| {
                try self.dependencies.append(dep);
                try self.dependency_versions.append(dep.getVersion());
                
                // Subscribe to dependency changes if it's a State
                if (@hasDecl(@TypeOf(dep.*), "subscribe")) {
                    // This is a bit of a hack - we need proper interface
                    // For now, we'll handle this in the test/usage code
                }
            }
            
            // Compute initial value
            self.cached_value = self.compute_fn();
            self.is_dirty = false;
            
            return self;
        }
        
        /// Clean up computed value
        pub fn deinit(self: *Self) void {
            self.dependencies.deinit();
            self.dependency_versions.deinit();
            self.allocator.destroy(self);
        }
        
        /// Get current value (lazy evaluation)
        pub fn get(self: *Self) T {
            if (self.is_dirty or self.hasDepencencyChanges()) {
                self.recompute();
            }
            return self.cached_value;
        }
        
        /// Check if any dependencies have changed
        fn hasDepencencyChanges(self: *Self) bool {
            for (self.dependencies.items, self.dependency_versions.items) |dep, *stored_version| {
                const current_version = dep.getVersion();
                if (current_version != stored_version.*) {
                    stored_version.* = current_version;
                    return true;
                }
            }
            return false;
        }
        
        /// Recompute the value
        fn recompute(self: *Self) void {
            self.cached_value = self.compute_fn();
            self.is_dirty = false;
            self.version +%= 1;
        }
        
        /// Mark as needing recomputation
        pub fn invalidate(self: *Self) void {
            self.is_dirty = true;
        }
        
        /// Get as watchable interface
        pub fn asWatchable(self: *Self) *Watchable {
            return &self.watchable;
        }
        
        /// Get as observer interface
        pub fn asObserver(self: *Self) *Observer {
            return &self.observer;
        }
        
        /// Manually trigger recomputation
        pub fn refresh(self: *Self) T {
            self.recompute();
            return self.cached_value;
        }
    };
}

// Convenience function for creating computed values
pub fn compute(allocator: std.mem.Allocator, comptime T: type, config: Compute(T).Config) !*Compute(T) {
    return try Compute(T).init(allocator, config);
}

// Tests
test "compute basics" {
    const allocator = std.testing.allocator;
    const State = state_mod.State;
    
    // Create source states
    var x = try State(i32).init(allocator, 10);
    defer x.deinit();
    
    var y = try State(i32).init(allocator, 20);
    defer y.deinit();
    
    // Store states for compute function
    const TestData = struct {
        var test_x: *State(i32) = undefined;
        var test_y: *State(i32) = undefined;
    };
    TestData.test_x = x;
    TestData.test_y = y;
    
    // Create computed value
    var sum = try compute(allocator, i32, .{
        .dependencies = &[_]*Watchable{ x.asWatchable(), y.asWatchable() },
        .compute_fn = struct {
            fn calc() i32 {
                return TestData.test_x.get() + TestData.test_y.get();
            }
        }.calc,
        .name = "sum",
    });
    defer sum.deinit();
    
    // Initial computation
    try std.testing.expect(sum.get() == 30);
    
    // Update source - computed should update lazily
    x.update(15);
    try std.testing.expect(sum.get() == 35);
    
    y.update(25);
    try std.testing.expect(sum.get() == 40);
}

test "compute lazy evaluation" {
    const allocator = std.testing.allocator;
    const State = state_mod.State;
    
    var source = try State(u32).init(allocator, 5);
    defer source.deinit();
    
    var compute_count: u32 = 0;
    
    const TestData = struct {
        var test_source: *State(u32) = undefined;
        var test_count: *u32 = undefined;
    };
    TestData.test_source = source;
    TestData.test_count = &compute_count;
    
    var doubled = try compute(allocator, u32, .{
        .dependencies = &[_]*Watchable{source.asWatchable()},
        .compute_fn = struct {
            fn calc() u32 {
                TestData.test_count.* += 1;
                return TestData.test_source.get() * 2;
            }
        }.calc,
    });
    defer doubled.deinit();
    
    // Initial computation
    try std.testing.expect(doubled.get() == 10);
    try std.testing.expect(compute_count == 1);
    
    // Get again - should use cache
    _ = doubled.get();
    try std.testing.expect(compute_count == 1);
    
    // Update source
    source.update(10);
    
    // Get triggers recomputation
    try std.testing.expect(doubled.get() == 20);
    try std.testing.expect(compute_count == 2);
}

test "compute with multiple dependencies" {
    const allocator = std.testing.allocator;
    const State = state_mod.State;
    
    var a = try State(f32).init(allocator, 2.0);
    defer a.deinit();
    
    var b = try State(f32).init(allocator, 3.0);
    defer b.deinit();
    
    var c = try State(f32).init(allocator, 4.0);
    defer c.deinit();
    
    const TestData = struct {
        var test_a: *State(f32) = undefined;
        var test_b: *State(f32) = undefined;
        var test_c: *State(f32) = undefined;
    };
    TestData.test_a = a;
    TestData.test_b = b;
    TestData.test_c = c;
    
    var product = try compute(allocator, f32, .{
        .dependencies = &[_]*Watchable{ 
            a.asWatchable(), 
            b.asWatchable(), 
            c.asWatchable() 
        },
        .compute_fn = struct {
            fn calc() f32 {
                return TestData.test_a.get() * TestData.test_b.get() * TestData.test_c.get();
            }
        }.calc,
    });
    defer product.deinit();
    
    try std.testing.expect(product.get() == 24.0);
    
    a.update(5.0);
    try std.testing.expect(product.get() == 60.0);
    
    b.update(2.0);
    c.update(3.0);
    try std.testing.expect(product.get() == 30.0);
}