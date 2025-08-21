//! Gannaway - Alternative reactive UI system with explicit control
//!
//! A different approach to reactivity emphasizing:
//! - Explicit notification over automatic tracking
//! - Manual dependency declaration over magic
//! - Direct control over convenience
//! - Predictable behavior over implicit smartness
//!
//! ## Basic Usage
//!
//! ```zig
//! const gannaway = @import("lib/gannaway/mod.zig");
//!
//! // Create state with explicit notification
//! var count = try gannaway.state(allocator, u32, 0);
//! defer count.deinit();
//!
//! // Create computed value with explicit dependencies
//! var doubled = try gannaway.compute(allocator, u32, .{
//!     .dependencies = &[_]*Watchable{count.asWatchable()},
//!     .compute_fn = struct {
//!         fn calc() u32 { return count.get() * 2; }
//!     }.calc,
//! });
//! defer doubled.deinit();
//!
//! // Create watcher with explicit targets
//! var watcher = try gannaway.watch(allocator, .{
//!     .targets = &[_]*Watchable{count.asWatchable()},
//!     .callback = struct {
//!         fn onChange(changed: *const Watchable) void {
//!             std.log.info("{s} changed", .{changed.getName()});
//!         }
//!     }.onChange,
//! });
//! defer watcher.deinit();
//!
//! // Update state - must explicitly notify
//! count.set(5);
//! count.notify();
//!
//! // Or use update helper
//! count.update(10); // set + notify
//! ```

const std = @import("std");

// Import modules
const state_mod = @import("state.zig");
const compute_mod = @import("compute.zig");
const watch_mod = @import("watch.zig");
const convenience_mod = @import("convenience.zig");

// Re-export core types
pub const State = state_mod.State;
pub const Compute = compute_mod.Compute;
pub const Watcher = watch_mod.Watcher;
pub const WatchConfig = watch_mod.WatchConfig;

// Re-export interfaces
pub const Watchable = state_mod.Watchable;
pub const Observer = state_mod.Observer;

// Re-export convenience functions
pub const state = convenience_mod.state;
pub const compute = convenience_mod.compute;
pub const watch = convenience_mod.watch;
pub const GannawayContext = convenience_mod.GannawayContext;
pub const init = convenience_mod.init;
pub const deinit = convenience_mod.deinit;

// Re-export tests
pub usingnamespace @import("tests.zig");
