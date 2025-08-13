//! Reactive system for Dealt Game Engine with full Svelte 5 semantics
//! 
//! Complete implementation of Svelte 5's rune system with automatic dependency tracking:
//! - $state: Reactive signals with automatic tracking (Signal)
//! - $state.raw: Non-reactive state for performance optimization (SignalRaw)
//! - $state.snapshot: Create static snapshots of reactive state
//! - $derived: Derived values that auto-update (Derived)  
//! - $effect: Side effects with automatic cleanup (Effect)
//! - $effect.pre: Effects that run before DOM updates
//! - $effect.tracking: Runtime detection of tracking context
//! - $effect.root: Manual effect scopes with lifecycle control
//! - Push-pull reactivity: immediate notification, lazy evaluation
//!
//! ## Basic Usage
//!
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
//! // Create non-reactive state ($state.raw) - no dependencies tracked
//! var config = try reactive.signalRaw(allocator, bool, true);
//! 
//! // Create derived state ($derived) - automatically tracks count
//! var doubled = try reactive.derived(allocator, u32, struct {
//!     fn derive() u32 { return count.get() * 2; }
//! }.derive);
//! 
//! // Create effects ($effect) - automatically re-runs when count changes
//! const effect = try reactive.createEffect(allocator, struct {
//!     fn run() void { std.log.info("Count: {}", .{count.get()}); }
//! }.run);
//! 
//! // Create pre-effects ($effect.pre) - run before updates
//! const pre_effect = try reactive.createEffectPre(allocator, struct {
//!     fn run() void { 
//!         if (reactive.isTracking()) {
//!             std.log.info("Pre-update: {}", .{count.get()}); 
//!         }
//!     }
//! }.run);
//! 
//! // Create snapshots ($state.snapshot)
//! const snap = reactive.snapshot(count); // Non-reactive copy
//! 
//! // Batch updates for efficiency
//! reactive.batch(struct {
//!     fn update() void {
//!         count.set(5); // doubled becomes 10, effects run once
//!     }
//! }.update);
//! 
//! // Manual effect scopes ($effect.root)
//! const root = try reactive.createEffectRoot(allocator, struct {
//!     fn setup() void {
//!         // Create effects that won't auto-cleanup
//!     }
//! }.setup);
//! defer { root.deinit(); allocator.destroy(root); }
//! ```
//!
//! ## Advanced Features
//!
//! ### Performance Optimization
//! - Use `SignalRaw` for non-reactive state that doesn't trigger effects
//! - Use `snapshot()` to create static copies for external APIs
//! - Batch multiple updates to prevent cascading effect runs
//!
//! ### Effect Control
//! - `$effect.pre` for logic that must run before visual updates
//! - `$effect.tracking()` to detect reactive context at runtime
//! - `$effect.root` for manual lifecycle management
//!
//! ### Memory Management
//! - All reactive values must be manually cleaned up
//! - Effect roots manage child effect lifecycles
//! - Snapshots are plain values with no cleanup needed

const context_mod = @import("reactive/context.zig");
const signal_mod = @import("reactive/signal.zig");
const derived_mod = @import("reactive/derived.zig");
const effect_mod = @import("reactive/effect.zig");
const batch_mod = @import("reactive/batch.zig");

// Re-export core types with new names
pub const Signal = signal_mod.Signal;
pub const SignalRaw = signal_mod.SignalRaw;  // Non-reactive state (Svelte 5 $state.raw)
pub const Derived = derived_mod.Derived;  // Primary name (Svelte 5 $derived)
pub const Effect = effect_mod.Effect;
pub const EffectRoot = effect_mod.EffectRoot; // Root effect scope (Svelte 5 $effect.root)
pub const EffectTiming = effect_mod.EffectTiming; // Effect timing modes
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

/// Convenience function to create a signal ($state)
pub fn signal(allocator: std.mem.Allocator, comptime T: type, initial_value: T) !Signal(T) {
    return try Signal(T).init(allocator, initial_value);
}

/// Convenience function to create a raw (non-reactive) signal ($state.raw)
pub fn signalRaw(allocator: std.mem.Allocator, comptime T: type, initial_value: T) !SignalRaw(T) {
    return try SignalRaw(T).init(allocator, initial_value);
}

/// Convenience function to create a derived signal with automatic tracking ($derived)
pub fn derived(allocator: std.mem.Allocator, comptime T: type, derive_fn: *const fn () T) !*Derived(T) {
    return try derived_mod.derived(allocator, T, derive_fn);
}


/// Create an effect with automatic dependency tracking ($effect)
pub fn createEffect(allocator: std.mem.Allocator, effect_fn: *const fn () void) !*Effect {
    return try effect_mod.createEffect(allocator, effect_fn);
}

/// Create a pre-effect that runs before DOM updates ($effect.pre)
pub fn createEffectPre(allocator: std.mem.Allocator, effect_fn: *const fn () void) !*Effect {
    return try effect_mod.createEffectPre(allocator, effect_fn);
}

/// Create a root effect scope for manual control ($effect.root)
pub fn createEffectRoot(allocator: std.mem.Allocator, root_fn: *const fn () void) !*EffectRoot {
    return try effect_mod.createEffectRoot(allocator, root_fn);
}

/// Check if code is running in a tracking context ($effect.tracking)
pub fn isTracking() bool {
    return effect_mod.isTracking();
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

/// Create a snapshot of any reactive value ($state.snapshot)
/// This provides a convenient generic interface for snapshots
pub fn snapshot(value: anytype) @TypeOf(value.snapshot()) {
    return value.snapshot();
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
    
    // Create derived area ($derived) - automatically tracks width and height
    var area = try derived(allocator, f32, struct {
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

test "snapshot functionality" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try init(allocator);
    defer deinit(allocator);
    
    // Test signal snapshot
    var count = try signal(allocator, i32, 42);
    defer count.deinit();
    
    const snap1 = count.snapshot();
    try std.testing.expect(snap1 == 42);
    
    count.set(100);
    const snap2 = snapshot(count); // Using generic function
    try std.testing.expect(snap2 == 100);
    try std.testing.expect(snap1 == 42); // Old snapshot unchanged
    
    // Test derived snapshot
    const TestData = struct {
        var test_count: *Signal(i32) = undefined;
    };
    TestData.test_count = &count;
    
    var doubled = try derived(allocator, i32, struct {
        fn derive() i32 {
            return TestData.test_count.get() * 2;
        }
    }.derive);
    defer {
        doubled.deinit();
        allocator.destroy(doubled);
    }
    
    const derived_snap = doubled.snapshot();
    try std.testing.expect(derived_snap == 200); // 100 * 2
    
    count.set(50);
    const derived_snap2 = snapshot(doubled); // Using generic function
    try std.testing.expect(derived_snap2 == 100); // 50 * 2
    try std.testing.expect(derived_snap == 200); // Old snapshot unchanged
}

test "effect pre and tracking" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try init(allocator);
    defer deinit(allocator);
    
    var count = try signal(allocator, i32, 0);
    defer count.deinit();
    
    var pre_runs: u32 = 0;
    var normal_runs: u32 = 0;
    var tracking_detected: bool = false;
    
    const TestData = struct {
        var test_count: *Signal(i32) = undefined;
        var test_pre_runs: *u32 = undefined;
        var test_normal_runs: *u32 = undefined;
        var test_tracking: *bool = undefined;
    };
    
    TestData.test_count = &count;
    TestData.test_pre_runs = &pre_runs;
    TestData.test_normal_runs = &normal_runs;
    TestData.test_tracking = &tracking_detected;
    
    // Test effect.pre
    const pre_effect = try createEffectPre(allocator, struct {
        fn run() void {
            _ = TestData.test_count.get();
            TestData.test_pre_runs.* += 1;
            // Test tracking detection
            TestData.test_tracking.* = isTracking();
        }
    }.run);
    defer allocator.destroy(pre_effect);
    
    // Test normal effect
    const normal_effect = try createEffect(allocator, struct {
        fn run() void {
            _ = TestData.test_count.get();
            TestData.test_normal_runs.* += 1;
        }
    }.run);
    defer allocator.destroy(normal_effect);
    
    // Initial runs
    try std.testing.expect(pre_runs == 1);
    try std.testing.expect(normal_runs == 1);
    try std.testing.expect(tracking_detected == true); // Should detect tracking context
    
    // Update should trigger both
    count.set(5);
    try std.testing.expect(pre_runs == 2);
    try std.testing.expect(normal_runs == 2);
}

test "effect root scope" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try init(allocator);
    defer deinit(allocator);
    
    var root_runs: u32 = 0;
    
    const TestData = struct {
        var test_runs: *u32 = undefined;
    };
    TestData.test_runs = &root_runs;
    
    // Create root scope
    const root = try createEffectRoot(allocator, struct {
        fn run() void {
            TestData.test_runs.* += 1;
        }
    }.run);
    defer {
        root.deinit();
        allocator.destroy(root);
    }
    
    // Manually run the root
    root.run();
    try std.testing.expect(root_runs == 1);
    
    root.run();
    try std.testing.expect(root_runs == 2);
    
    // Test disposal
    root.dispose();
    try std.testing.expect(root.is_disposed == true);
    
    // Should not run after disposal
    root.run();
    try std.testing.expect(root_runs == 2); // No change
}