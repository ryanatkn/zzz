//! Reactive system for Zzz Game Engine with performance-first shallow reactivity
//!
//! Complete implementation inspired by Svelte 5's rune system with automatic dependency tracking:
//! - $state/$state.raw: Reactive signals with shallow equality and automatic tracking (Signal)
//! - $state.snapshot: Create static snapshots of reactive state
//! - $derived: Derived values that auto-update (Derived)
//! - $effect: Side effects with automatic cleanup (Effect)
//! - $effect.pre: Effects that run before DOM updates
//! - $effect.tracking: Runtime detection of tracking context
//! - $effect.root: Manual effect scopes with lifecycle control
//! - Push-pull reactivity: immediate notification, lazy evaluation
//! - Shallow reactivity: Only top-level changes trigger updates for performance
//!
//! ## Basic Usage
//!
//! ```zig
//! const reactive = @import("lib/reactive/mod.zig");
//!
//! // Initialize reactive context (once per thread)
//! try reactive.init(allocator);
//! defer reactive.deinit(allocator);
//!
//! // Create reactive state ($state) - uses shallow equality
//! var count = try reactive.signal(allocator, u32, 0);
//!
//! // For arrays/structs, only complete replacement triggers updates
//! var position = try reactive.signal(allocator, Vec2, .{ .x = 0, .y = 0 });
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
//!         count.set(5);
//!         position.set(.{ .x = 10, .y = 20 }); // Both updates, effects run once
//!     }
//! }.update);
//!
//! // Manual notification when modifying nested structures
//! position.value.x = 100; // Direct modification - no automatic trigger
//! position.notify(); // Manually notify observers
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
//! - Shallow equality prevents expensive deep comparisons
//! - Use `notify()` method for manual updates when modifying nested structures
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

const context_mod = @import("context.zig");
const signal_mod = @import("signal.zig");
const derived_mod = @import("derived.zig");
const effect_mod = @import("effect.zig");
const batch_mod = @import("batch.zig");
const collections_mod = @import("collections.zig");
const ref_mod = @import("ref.zig");
const convenience_mod = @import("convenience.zig");

// Re-export tests
pub usingnamespace @import("tests.zig");

// Re-export core types with new names
pub const Signal = signal_mod.Signal; // Reactive state with shallow equality (Svelte 5 $state)
pub const Derived = derived_mod.Derived; // Primary name (Svelte 5 $derived)
pub const Effect = effect_mod.Effect;
pub const EffectRoot = effect_mod.EffectRoot; // Root effect scope (Svelte 5 $effect.root)
pub const EffectTiming = effect_mod.EffectTiming; // Effect timing modes
pub const BatchManager = batch_mod.BatchManager;
pub const ReactiveContext = context_mod.ReactiveContext;

// Re-export RAII helpers for automatic cleanup
pub const ReactiveRef = ref_mod.ReactiveRef;
pub const EffectRef = ref_mod.EffectRef;
pub const DerivedRef = ref_mod.DerivedRef;

// Re-export reactive collections
pub const ReactiveArray = collections_mod.ReactiveArray; // Reactive fixed-size arrays
pub const ReactiveSlice = collections_mod.ReactiveSlice; // Reactive dynamic slices

// Re-export context functions
pub const getContext = context_mod.getContext;
pub const trackDependency = context_mod.trackDependency;

// Re-export convenience functions
pub const init = convenience_mod.init;
pub const deinit = convenience_mod.deinit;
pub const signal = convenience_mod.signal;
pub const derived = convenience_mod.derived;
pub const reactiveArray = convenience_mod.reactiveArray;
pub const reactiveSlice = convenience_mod.reactiveSlice;
pub const createEffect = convenience_mod.createEffect;
pub const createEffectPre = convenience_mod.createEffectPre;
pub const createEffectRoot = convenience_mod.createEffectRoot;
pub const isTracking = convenience_mod.isTracking;
pub const createEffectWithCleanup = convenience_mod.createEffectWithCleanup;
pub const watchSignal = convenience_mod.watchSignal;
pub const batchFn = convenience_mod.batch; // Function for batching updates
pub const snapshot = convenience_mod.snapshot;
pub const createEffectRef = convenience_mod.createEffectRef;
pub const createDerivedRef = convenience_mod.createDerivedRef;

// Re-export modules for direct access to their functions
pub const batch = batch_mod; // Module with getGlobalBatcher etc
