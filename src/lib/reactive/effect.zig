const std = @import("std");
const signal = @import("signal.zig");
const context = @import("context.zig");
const batch_mod = @import("batch.zig");

/// An effect that automatically runs when its dependencies change
/// Implements Svelte 5's $effect with automatic dependency tracking
pub const Effect = struct {
    allocator: std.mem.Allocator,
    run_fn: *const fn () void,
    cleanup_fn: ?*const fn () void = null,
    is_active: bool = true,
    is_running: bool = false,
    
    // Observer for automatic dependency tracking
    observer: context.ReactiveContext.Observer,
    
    // Self reference for observer callbacks
    self_ptr: *Effect = undefined,
    
    // Track if we need to run cleanup on next execution
    needs_cleanup: bool = false,
    
    pub fn init(
        allocator: std.mem.Allocator, 
        run_fn: *const fn () void, 
        cleanup_fn: ?*const fn () void
    ) Effect {
        var self = Effect{
            .allocator = allocator,
            .run_fn = run_fn,
            .cleanup_fn = cleanup_fn,
            .is_active = true,
            .is_running = false,
            .observer = undefined,
            .needs_cleanup = false,
        };
        
        // Set up self reference
        self.self_ptr = &self;
        
        // Create observer for receiving dependency updates
        self.observer = context.createObserver(
            Effect,
            self.self_ptr,
            Effect.onDependencyChange,
            Effect.cleanup
        );
        
        return self;
    }
    
    /// Run the effect with automatic dependency tracking
    pub fn run(self: *Effect) void {
        if (!self.is_active or self.is_running) return;
        
        self.is_running = true;
        defer self.is_running = false;
        
        // Run cleanup from previous execution if needed
        if (self.needs_cleanup and self.cleanup_fn != null) {
            self.cleanup_fn.?();
            self.needs_cleanup = false;
        }
        
        // Get reactive context for tracking
        const ctx = context.getContext();
        if (ctx) |reactive_ctx| {
            // Start tracking dependencies
            reactive_ctx.startTracking(&self.observer) catch {
                // If tracking fails, run without tracking
                self.run_fn();
                return;
            };
            defer reactive_ctx.stopTracking();
            
            // Run the effect - this will track dependencies
            self.run_fn();
        } else {
            // No context, run without tracking
            self.run_fn();
        }
        
        // Mark that we need cleanup on next run
        self.needs_cleanup = true;
    }
    
    /// Called when a dependency changes
    fn onDependencyChange(self: *Effect) void {
        // Check if batching is active
        if (batch_mod.getGlobalBatcher()) |batcher| {
            if (batcher.isBatching()) {
                // Queue the effect to run at batch end
                batcher.queueEffect(self);
                return;
            }
        }
        
        // No batching, run immediately
        self.run();
    }
    
    /// Cleanup the effect
    pub fn cleanup(self: *Effect) void {
        if (self.cleanup_fn) |cleanup_fn| {
            cleanup_fn();
        }
        self.is_active = false;
    }
    
    pub fn deinit(self: *Effect) void {
        self.cleanup();
    }
    
    /// Stop the effect from running
    pub fn stop(self: *Effect) void {
        self.is_active = false;
        self.cleanup();
    }
    
    /// Start the effect again after stopping
    pub fn start(self: *Effect) void {
        self.is_active = true;
        self.run(); // Re-establish dependencies
    }
};

/// Create an effect that automatically tracks dependencies
pub fn createEffect(
    allocator: std.mem.Allocator, 
    effect_fn: *const fn () void
) !*Effect {
    const effect = try allocator.create(Effect);
    effect.* = Effect.init(allocator, effect_fn, null);
    effect.self_ptr = effect; // Fix self-reference after allocation
    
    // Re-create observer with correct self pointer
    effect.observer = context.createObserver(
        Effect,
        effect,
        Effect.onDependencyChange,
        Effect.cleanup
    );
    
    // Run once to establish dependencies and initial effect
    effect.run();
    
    return effect;
}

/// Create an effect with cleanup
pub fn createEffectWithCleanup(
    allocator: std.mem.Allocator, 
    effect_fn: *const fn () void,
    cleanup_fn: *const fn () void
) !*Effect {
    const effect = try allocator.create(Effect);
    effect.* = Effect.init(allocator, effect_fn, cleanup_fn);
    effect.self_ptr = effect; // Fix self-reference after allocation
    
    // Re-create observer with correct self pointer
    effect.observer = context.createObserver(
        Effect,
        effect,
        Effect.onDependencyChange,
        Effect.cleanup
    );
    
    // Run once to establish dependencies and initial effect
    effect.run();
    
    return effect;
}

/// Watch a specific signal and run callback on changes
/// This is a helper that creates an effect to watch a signal
pub fn watchSignal(
    allocator: std.mem.Allocator,
    comptime T: type,
    watched_signal: *signal.Signal(T),
    callback: *const fn (T) void
) !*Effect {
    const WatchContext = struct {
        var sig: *signal.Signal(T) = undefined;
        var cb: *const fn (T) void = undefined;
    };
    
    WatchContext.sig = watched_signal;
    WatchContext.cb = callback;
    
    return try createEffect(allocator, struct {
        fn watch() void {
            const value = WatchContext.sig.get();
            WatchContext.cb(value);
        }
    }.watch);
}

/// Create an effect that only runs once
pub fn createOneTimeEffect(
    allocator: std.mem.Allocator,
    effect_fn: *const fn () void
) !*Effect {
    const effect = try allocator.create(Effect);
    effect.* = Effect.init(allocator, struct {
        var original_fn: *const fn () void = undefined;
        var ran: bool = false;
        
        fn runOnce() void {
            if (!ran) {
                original_fn();
                ran = true;
            }
        }
    }.runOnce, null);
    
    // Store the original function
    const Context = struct {
        var original_fn: *const fn () void = undefined;
        var ran: bool = false;
    };
    Context.original_fn = effect_fn;
    Context.ran = false;
    
    effect.self_ptr = effect;
    effect.observer = context.createObserver(
        Effect,
        effect,
        Effect.onDependencyChange,
        Effect.cleanup
    );
    
    effect.run();
    return effect;
}

// Tests
test "effect with automatic dependency tracking" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Initialize reactive context
    try context.initContext(allocator);
    defer context.deinitContext(allocator);
    
    // Create a signal to watch
    var counter = try signal.signal(allocator, u32, 0);
    defer counter.deinit();
    
    // Track effect runs
    var effect_runs: u32 = 0;
    
    const TestData = struct {
        var test_counter: *signal.Signal(u32) = undefined;
        var test_runs: *u32 = undefined;
    };
    
    TestData.test_counter = &counter;
    TestData.test_runs = &effect_runs;
    
    // Create an effect that automatically tracks the counter signal
    const test_effect = try createEffect(allocator, struct {
        fn run() void {
            // Reading the signal automatically registers it as a dependency
            _ = TestData.test_counter.get();
            TestData.test_runs.* += 1;
        }
    }.run);
    defer allocator.destroy(test_effect);
    
    // Effect should have run once during creation
    try std.testing.expect(effect_runs == 1);
    
    // Changing the signal should automatically re-run the effect
    counter.set(5);
    try std.testing.expect(effect_runs == 2);
    
    counter.set(10);
    try std.testing.expect(effect_runs == 3);
}

test "effect with multiple dependencies" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try context.initContext(allocator);
    defer context.deinitContext(allocator);
    
    var width = try signal.signal(allocator, f32, 100.0);
    defer width.deinit();
    
    var height = try signal.signal(allocator, f32, 50.0);
    defer height.deinit();
    
    var area: f32 = 0;
    
    const TestData = struct {
        var test_width: *signal.Signal(f32) = undefined;
        var test_height: *signal.Signal(f32) = undefined;
        var test_area: *f32 = undefined;
    };
    
    TestData.test_width = &width;
    TestData.test_height = &height;
    TestData.test_area = &area;
    
    // Effect that depends on both width and height
    const area_effect = try createEffect(allocator, struct {
        fn calculateArea() void {
            TestData.test_area.* = TestData.test_width.get() * TestData.test_height.get();
        }
    }.calculateArea);
    defer allocator.destroy(area_effect);
    
    // Initial calculation
    try std.testing.expect(area == 5000.0);
    
    // Changing width should recalculate
    width.set(200.0);
    try std.testing.expect(area == 10000.0);
    
    // Changing height should also recalculate
    height.set(100.0);
    try std.testing.expect(area == 20000.0);
}

test "effect cleanup and stop/resume" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try context.initContext(allocator);
    defer context.deinitContext(allocator);
    
    var source = try signal.signal(allocator, i32, 0);
    defer source.deinit();
    
    var run_count: u32 = 0;
    var cleanup_count: u32 = 0;
    
    const TestData = struct {
        var test_source: *signal.Signal(i32) = undefined;
        var test_run_count: *u32 = undefined;
        var test_cleanup_count: *u32 = undefined;
    };
    
    TestData.test_source = &source;
    TestData.test_run_count = &run_count;
    TestData.test_cleanup_count = &cleanup_count;
    
    const test_effect = try createEffectWithCleanup(
        allocator,
        struct {
            fn run() void {
                _ = TestData.test_source.get();
                TestData.test_run_count.* += 1;
            }
        }.run,
        struct {
            fn cleanup() void {
                TestData.test_cleanup_count.* += 1;
            }
        }.cleanup
    );
    defer allocator.destroy(test_effect);
    
    // Initial run
    try std.testing.expect(run_count == 1);
    try std.testing.expect(cleanup_count == 0);
    
    // Update should trigger cleanup then run
    source.set(10);
    try std.testing.expect(run_count == 2);
    try std.testing.expect(cleanup_count == 1);
    
    // Stop the effect
    test_effect.stop();
    try std.testing.expect(cleanup_count == 2);
    
    // Updates shouldn't trigger the effect
    source.set(20);
    try std.testing.expect(run_count == 2); // No change
    
    // Start the effect again
    test_effect.start();
    try std.testing.expect(run_count == 3); // Runs once on start
    
    // Updates should work again
    source.set(30);
    try std.testing.expect(run_count == 4);
}

test "watch signal helper" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try context.initContext(allocator);
    defer context.deinitContext(allocator);
    
    var value = try signal.signal(allocator, i32, 10);
    defer value.deinit();
    
    var last_value: i32 = 0;
    
    const TestData = struct {
        var test_last_value: *i32 = undefined;
    };
    
    TestData.test_last_value = &last_value;
    
    const watcher = try watchSignal(allocator, i32, &value, struct {
        fn onValueChange(new_value: i32) void {
            TestData.test_last_value.* = new_value;
        }
    }.onValueChange);
    defer allocator.destroy(watcher);
    
    // Initial value should be captured
    try std.testing.expect(last_value == 10);
    
    // Changes should be tracked
    value.set(20);
    try std.testing.expect(last_value == 20);
    
    value.set(30);
    try std.testing.expect(last_value == 30);
}