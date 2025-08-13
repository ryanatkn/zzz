const std = @import("std");

/// Test utilities for reactive system tests
/// Provides cleaner patterns for working around Zig's closure limitations

/// Context manager for test data that needs to be shared across closures
/// This provides a cleaner alternative to global TestData structs
pub fn TestContext(comptime T: type) type {
    return struct {
        const Self = @This();
        
        data: T,
        
        pub fn init(data: T) Self {
            return Self{ .data = data };
        }
        
        /// Create a function that captures this context
        pub fn createFunction(
            self: *Self,
            comptime func: fn (*T) void
        ) *const fn () void {
            const Wrapper = struct {
                context: *T,
                
                fn call(wrapper: @This()) void {
                    func(wrapper.context);
                }
            };
            
            // This is still a limitation of Zig - we need static storage
            // But at least it's more organized
            const wrapper = Wrapper{ .context = &self.data };
            return wrapper.call;
        }
        
        /// Create a parameterized function that captures this context
        pub fn createParameterizedFunction(
            self: *Self,
            comptime RetType: type,
            comptime func: fn (*T) RetType
        ) *const fn () RetType {
            const Wrapper = struct {
                context: *T,
                
                fn call(wrapper: @This()) RetType {
                    return func(wrapper.context);
                }
            };
            
            const wrapper = Wrapper{ .context = &self.data };
            return wrapper.call;
        }
    };
}

/// Counter utility for tracking effect runs
pub const EffectCounter = struct {
    count: u32 = 0,
    name: []const u8 = "effect",
    
    pub fn increment(self: *@This()) void {
        self.count += 1;
    }
    
    pub fn reset(self: *@This()) void {
        self.count = 0;
    }
    
    pub fn expectCount(self: *const @This(), expected: u32) !void {
        if (self.count != expected) {
            std.debug.print("{s}: Expected {} runs, got {}\n", .{ self.name, expected, self.count });
            return error.TestUnexpectedResult;
        }
    }
    
    pub fn get(self: *const @This()) u32 {
        return self.count;
    }
};

/// Value tracker for storing effect results
pub fn ValueTracker(comptime T: type) type {
    return struct {
        const Self = @This();
        
        value: T,
        history: std.ArrayList(T),
        allocator: std.mem.Allocator,
        
        pub fn init(allocator: std.mem.Allocator, initial: T) Self {
            return Self{
                .value = initial,
                .history = std.ArrayList(T).init(allocator),
                .allocator = allocator,
            };
        }
        
        pub fn deinit(self: *Self) void {
            self.history.deinit();
        }
        
        pub fn set(self: *Self, new_value: T) void {
            self.history.append(self.value) catch {};
            self.value = new_value;
        }
        
        pub fn get(self: *const Self) T {
            return self.value;
        }
        
        pub fn expectValue(self: *const Self, expected: T) !void {
            if (!std.meta.eql(self.value, expected)) {
                std.debug.print("Expected value {any}, got {any}\n", .{ expected, self.value });
                return error.TestUnexpectedResult;
            }
        }
        
        pub fn getHistoryCount(self: *const Self) usize {
            return self.history.items.len;
        }
    };
}

/// Multi-signal test helper
pub fn MultiSignalTest(comptime T: type, comptime count: usize) type {
    return struct {
        const Self = @This();
        
        signals: [count]*Signal(T),
        counters: [count]EffectCounter,
        
        pub fn init(signals: [count]*Signal(T)) Self {
            var counters: [count]EffectCounter = undefined;
            for (&counters, 0..) |*counter, i| {
                counter.* = EffectCounter{
                    .name = std.fmt.allocPrint(std.heap.page_allocator, "signal_{}", .{i}) catch "signal",
                };
            }
            
            return Self{
                .signals = signals,
                .counters = counters,
            };
        }
        
        pub fn getSignal(self: *Self, index: usize) *Signal(T) {
            return self.signals[index];
        }
        
        pub fn getCounter(self: *Self, index: usize) *EffectCounter {
            return &self.counters[index];
        }
        
        pub fn resetAllCounters(self: *Self) void {
            for (&self.counters) |*counter| {
                counter.reset();
            }
        }
    };
}

/// Helper to simplify reactive test setup
pub const ReactiveTestSetup = struct {
    allocator: std.mem.Allocator,
    initialized: bool = false,
    
    pub fn init(allocator: std.mem.Allocator) !@This() {
        const reactive = @import("../reactive.zig");
        try reactive.init(allocator);
        
        return @This(){
            .allocator = allocator,
            .initialized = true,
        };
    }
    
    pub fn deinit(self: *@This()) void {
        if (self.initialized) {
            const reactive = @import("../reactive.zig");
            reactive.deinit(self.allocator);
            self.initialized = false;
        }
    }
    
    pub fn createSignal(self: *@This(), comptime T: type, initial: T) !@import("signal.zig").Signal(T) {
        const signal_mod = @import("signal.zig");
        return try signal_mod.signal(self.allocator, T, initial);
    }
    
    pub fn createDerived(self: *@This(), comptime T: type, derive_fn: *const fn() T) !*@import("derived.zig").Derived(T) {
        const derived_mod = @import("derived.zig");
        return try derived_mod.derived(self.allocator, T, derive_fn);
    }
    
    pub fn createEffect(self: *@This(), effect_fn: *const fn() void) !*@import("effect.zig").Effect {
        const effect_mod = @import("effect.zig");
        return try effect_mod.createEffect(self.allocator, effect_fn);
    }
};

// Export for use by other modules
const Signal = @import("signal.zig").Signal;

// Tests for the test utilities themselves
test "effect counter basic operations" {
    var counter = EffectCounter{ .name = "test_counter" };
    
    try std.testing.expect(counter.get() == 0);
    
    counter.increment();
    try counter.expectCount(1);
    
    counter.increment();
    try counter.expectCount(2);
    
    counter.reset();
    try counter.expectCount(0);
}

test "value tracker operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var tracker = ValueTracker(i32).init(allocator, 10);
    defer tracker.deinit();
    
    try tracker.expectValue(10);
    try std.testing.expect(tracker.getHistoryCount() == 0);
    
    tracker.set(20);
    try tracker.expectValue(20);
    try std.testing.expect(tracker.getHistoryCount() == 1);
    
    tracker.set(30);
    try tracker.expectValue(30);
    try std.testing.expect(tracker.getHistoryCount() == 2);
}