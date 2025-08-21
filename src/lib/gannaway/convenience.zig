/// Convenience functions for the Gannaway reactive system
///
/// This module provides easy-to-use factory functions and utilities
/// for working with the Gannaway alternative reactive system.
const std = @import("std");
const state_mod = @import("state.zig");
const compute_mod = @import("compute.zig");
const watch_mod = @import("watch.zig");

/// Global context for Gannaway system (future use)
pub const GannawayContext = struct {
    allocator: std.mem.Allocator,
    // Future: scheduler, batch manager, etc.
};

/// Initialize Gannaway system (currently a no-op, reserved for future)
pub fn init(allocator: std.mem.Allocator) !void {
    _ = allocator;
    // Future: Initialize global context, scheduler, etc.
}

/// Deinitialize Gannaway system
pub fn deinit() void {
    // Future: Cleanup global resources
}

// Convenience functions
pub const state = state_mod.State;
pub const compute = compute_mod.compute;
pub const watch = watch_mod.watch;
