//! Reactive system for Dealt Game Engine with Svelte 5 semantics
//! 
//! Features automatic dependency tracking inspired by Svelte 5's runes:
//! - $state: Reactive signals with automatic tracking (Signal)
//! - $derived: Computed values that auto-update (Computed)  
//! - $effect: Side effects with automatic cleanup (Effect)
//! - Push-pull reactivity: immediate notification, lazy evaluation
//!
//! Usage:
//! ```zig
//! const reactive = @import("lib/reactive.zig");
//! 
//! // Initialize reactive context (once per thread)
//! try reactive.init(allocator);
//! defer reactive.deinit(allocator);
//! 
//! // Create reactive state ($state)
//! var count = try reactive.signal(allocator, u32, 0);
//! 
//! // Create derived state ($derived) - automatically tracks count
//! var doubled = try reactive.computed(allocator, u32, struct {
//!     fn compute() u32 { return count.get() * 2; }
//! }.compute);
//! 
//! // Create effects ($effect) - automatically re-runs when count changes
//! _ = try reactive.createEffect(allocator, struct {
//!     fn log() void { std.log.info("Count: {}", .{count.get()}); }
//! }.log);
//! 
//! // Batch updates for efficiency
//! reactive.batch(struct {
//!     fn update() void {
//!         count.set(5); // doubled automatically becomes 10, effect runs
//!     }
//! }.update);
//! ```

const context_mod = @import("reactive/context.zig");
const signal_mod = @import("reactive/signal.zig");
const computed_mod = @import("reactive/computed.zig");
const effect_mod = @import("reactive/effect.zig");
const batch_mod = @import("reactive/batch.zig");

// Re-export core types
pub const Signal = signal_mod.Signal;
pub const Computed = computed_mod.Computed;
pub const Effect = effect_mod.Effect;
pub const BatchManager = batch_mod.BatchManager;
pub const ReactiveContext = context_mod.ReactiveContext;

// Re-export context functions
pub const getContext = context_mod.getContext;
pub const trackDependency = context_mod.trackDependency;

/// Initialize the reactive system (call once per thread at startup)
pub fn init(allocator: std.mem.Allocator) !void {
    // Initialize reactive context for automatic dependency tracking
    try context_mod.initContext(allocator);
    
    // Initialize global batching system
    try batch_mod.initGlobalBatcher(allocator);
}

/// Cleanup the reactive system (call once at shutdown)
pub fn deinit(allocator: std.mem.Allocator) void {
    // Cleanup batching system
    batch_mod.deinitGlobalBatcher(allocator);
    
    // Cleanup reactive context
    context_mod.deinitContext(allocator);
}

/// Convenience function to create a signal
pub fn signal(allocator: std.mem.Allocator, comptime T: type, initial_value: T) !Signal(T) {
    return try Signal(T).init(allocator, initial_value);
}

/// Convenience function to create a computed signal with automatic tracking
pub fn computed(allocator: std.mem.Allocator, comptime T: type, compute_fn: *const fn () T) !*Computed(T) {
    return try computed_mod.computed(allocator, T, compute_fn);
}

/// Create an effect with automatic dependency tracking ($effect)
pub fn createEffect(allocator: std.mem.Allocator, effect_fn: *const fn () void) !*Effect {
    return try effect_mod.createEffect(allocator, effect_fn);
}

/// Create an effect with cleanup function
pub fn createEffectWithCleanup(
    allocator: std.mem.Allocator,
    effect_fn: *const fn () void,
    cleanup_fn: *const fn () void
) !*Effect {
    return try effect_mod.createEffectWithCleanup(allocator, effect_fn, cleanup_fn);
}

/// Watch a signal and run callback on changes
pub fn watchSignal(
    allocator: std.mem.Allocator,
    comptime T: type,
    sig: *Signal(T),
    callback: *const fn (T) void
) !*Effect {
    return try effect_mod.watchSignal(allocator, T, sig, callback);
}

/// Execute function in a batch to optimize multiple reactive updates
pub fn batch(batch_fn: *const fn () void) void {
    batch_mod.batch(batch_fn);
}

// Tests
const std = @import("std");

test "reactive system with automatic dependency tracking" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Initialize reactive system with context
    try init(allocator);
    defer deinit(allocator);
    
    // Create reactive state ($state)
    var width = try signal(allocator, f32, 100.0);
    defer width.deinit();
    
    var height = try signal(allocator, f32, 50.0);
    defer height.deinit();
    
    // Store test data for compute function
    const TestData = struct {
        var test_width: *Signal(f32) = undefined;
        var test_height: *Signal(f32) = undefined;
    };
    
    TestData.test_width = &width;
    TestData.test_height = &height;
    
    // Create computed area ($derived) - automatically tracks width and height
    var area = try computed(allocator, f32, struct {
        fn compute() f32 {
            // Reading signals automatically registers them as dependencies
            return TestData.test_width.get() * TestData.test_height.get();
        }
    }.compute);
    defer {
        area.deinit();
        allocator.destroy(area);
    }
    
    // Test initial values
    try std.testing.expect(width.get() == 100.0);
    try std.testing.expect(height.get() == 50.0);
    try std.testing.expect(area.get() == 5000.0);
    
    // Update width - area should automatically update
    width.set(200.0);
    try std.testing.expect(area.get() == 10000.0);
    
    // Batch updates
    batch(struct {
        fn update() void {
            TestData.test_width.set(300.0);
            TestData.test_height.set(100.0);
        }
    }.update);
    
    try std.testing.expect(area.get() == 30000.0);
}

test "effect with automatic re-run on dependency change" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try init(allocator);
    defer deinit(allocator);
    
    var counter = try signal(allocator, i32, 0);
    defer counter.deinit();
    
    var effect_value: i32 = 0;
    
    const TestData = struct {
        var test_counter: *Signal(i32) = undefined;
        var test_value: *i32 = undefined;
    };
    
    TestData.test_counter = &counter;
    TestData.test_value = &effect_value;
    
    // Create effect ($effect) - automatically tracks counter
    const test_effect = try createEffect(allocator, struct {
        fn run() void {
            // Reading counter automatically makes this effect depend on it
            TestData.test_value.* = TestData.test_counter.get() * 10;
        }
    }.run);
    defer allocator.destroy(test_effect);
    
    // Initial run
    try std.testing.expect(effect_value == 0);
    
    // Update counter - effect should automatically re-run
    counter.set(5);
    try std.testing.expect(effect_value == 50);
    
    counter.set(10);
    try std.testing.expect(effect_value == 100);
}