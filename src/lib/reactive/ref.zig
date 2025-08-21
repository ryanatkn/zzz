const std = @import("std");
const effect = @import("effect.zig");
const derived = @import("derived.zig");

/// RAII wrapper for reactive objects that automatically handles cleanup
/// Prevents memory leaks by ensuring allocator.destroy() is always called
pub fn ReactiveRef(comptime T: type) type {
    return struct {
        ptr: *T,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, ptr: *T) Self {
            return Self{
                .ptr = ptr,
                .allocator = allocator,
            };
        }

        /// Get the underlying pointer
        pub fn get(self: *const Self) *T {
            return self.ptr;
        }

        /// Dereference for direct access
        pub fn deref(self: *const Self) *T {
            return self.ptr;
        }

        /// Automatic cleanup - calls deinit() and destroy()
        pub fn deinit(self: *Self) void {
            self.ptr.deinit();
            self.allocator.destroy(self.ptr);
        }
    };
}

/// Convenience type aliases
pub const EffectRef = ReactiveRef(effect.Effect);
pub const DerivedRef = ReactiveRef;

/// Create a managed Effect reference
pub fn createEffectRef(allocator: std.mem.Allocator, effect_fn: *const fn () void) !EffectRef {
    const eff = try effect.createEffect(allocator, effect_fn);
    return EffectRef.init(allocator, eff);
}

/// Create a managed Derived reference
pub fn createDerivedRef(allocator: std.mem.Allocator, comptime T: type, derive_fn: *const fn () T) !ReactiveRef(derived.Derived(T)) {
    const deriv = try derived.derived(allocator, T, derive_fn);
    return ReactiveRef(derived.Derived(T)).init(allocator, deriv);
}

// Tests
test "ReactiveRef automatic cleanup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize reactive context
    const context = @import("context.zig");
    try context.initContext(allocator);
    defer context.deinitContext(allocator);

    var counter: u32 = 0;
    const TestData = struct {
        var test_counter: *u32 = undefined;
    };
    TestData.test_counter = &counter;

    // Create managed effect - should not leak
    var effect_ref = try createEffectRef(allocator, struct {
        fn run() void {
            TestData.test_counter.* += 1;
        }
    }.run);
    defer effect_ref.deinit(); // This handles both deinit() and destroy()

    // Effect should run initially
    try std.testing.expect(counter == 1);

    // Should be able to access the effect
    _ = effect_ref.get();
}

test "ReactiveRef with derived" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const context = @import("context.zig");
    try context.initContext(allocator);
    defer context.deinitContext(allocator);

    const signal = @import("signal.zig");
    var source = try signal.signal(allocator, i32, 10);
    defer source.deinit();

    const TestData = struct {
        var test_source: *signal.Signal(i32) = undefined;
    };
    TestData.test_source = &source;

    // Create managed derived - should not leak
    var derived_ref = try createDerivedRef(allocator, i32, struct {
        fn compute() i32 {
            return TestData.test_source.get() * 2;
        }
    }.compute);
    defer derived_ref.deinit(); // This handles both deinit() and destroy()

    // Should compute correctly
    try std.testing.expect(derived_ref.get().get() == 20);
}
