/// Convenience factory functions for the reactive system
///
/// This module provides easy-to-use factory functions that wrap the core reactive
/// primitives with sensible defaults and simplified APIs. These functions handle
/// common patterns like signal creation, derived value setup, and effect management.

const std = @import("std");
const context_mod = @import("context.zig");
const signal_mod = @import("signal.zig");
const derived_mod = @import("derived.zig");
const effect_mod = @import("effect.zig");
const batch_mod = @import("batch.zig");
const collections_mod = @import("collections.zig");
const ref_mod = @import("ref.zig");

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
/// Uses shallow equality for optimal performance
pub fn signal(allocator: std.mem.Allocator, comptime T: type, initial_value: T) !signal_mod.Signal(T) {
    return try signal_mod.Signal(T).init(allocator, initial_value);
}

/// Convenience function to create a derived signal with automatic tracking ($derived)
pub fn derived(allocator: std.mem.Allocator, comptime T: type, derive_fn: *const fn () T) !*derived_mod.Derived(T) {
    return try derived_mod.derived(allocator, T, derive_fn);
}

/// Convenience function to create a reactive array
pub fn reactiveArray(allocator: std.mem.Allocator, comptime T: type, comptime N: usize, initial_items: [N]T) !collections_mod.ReactiveArray(T, N) {
    return try collections_mod.reactiveArray(allocator, T, N, initial_items);
}

/// Convenience function to create a reactive slice
pub fn reactiveSlice(allocator: std.mem.Allocator, comptime T: type, items: []T) !collections_mod.ReactiveSlice(T) {
    return try collections_mod.reactiveSlice(allocator, T, items);
}

/// Create an effect with automatic dependency tracking ($effect)
pub fn createEffect(allocator: std.mem.Allocator, effect_fn: *const fn () void) !*effect_mod.Effect {
    return try effect_mod.createEffect(allocator, effect_fn);
}

/// Create a pre-effect that runs before DOM updates ($effect.pre)
pub fn createEffectPre(allocator: std.mem.Allocator, effect_fn: *const fn () void) !*effect_mod.Effect {
    return try effect_mod.createEffectPre(allocator, effect_fn);
}

/// Create a root effect scope for manual control ($effect.root)
pub fn createEffectRoot(allocator: std.mem.Allocator, root_fn: *const fn () void) !*effect_mod.EffectRoot {
    return try effect_mod.createEffectRoot(allocator, root_fn);
}

/// Check if code is running in a tracking context ($effect.tracking)
pub fn isTracking() bool {
    return effect_mod.isTracking();
}

/// Create an effect with cleanup function
pub fn createEffectWithCleanup(allocator: std.mem.Allocator, effect_fn: *const fn () void, cleanup_fn: *const fn () void) !*effect_mod.Effect {
    return try effect_mod.createEffectWithCleanup(allocator, effect_fn, cleanup_fn);
}

/// Watch a signal and run callback on changes
pub fn watchSignal(allocator: std.mem.Allocator, comptime T: type, sig: *signal_mod.Signal(T), callback: *const fn (T) void) !*effect_mod.Effect {
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

/// Create a managed Effect reference (RAII cleanup)
pub fn createEffectRef(allocator: std.mem.Allocator, effect_fn: *const fn () void) !ref_mod.EffectRef {
    return try ref_mod.createEffectRef(allocator, effect_fn);
}

/// Create a managed Derived reference (RAII cleanup)
pub fn createDerivedRef(allocator: std.mem.Allocator, comptime T: type, derive_fn: *const fn () T) !ref_mod.ReactiveRef(derived_mod.Derived(T)) {
    return try ref_mod.createDerivedRef(allocator, T, derive_fn);
}