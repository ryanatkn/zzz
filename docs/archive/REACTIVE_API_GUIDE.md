# Reactive System API Guide

**Status:** Updated January 2025 | **Coverage:** Complete API Reference

This guide covers the enhanced reactive system APIs introduced in the January 2025 improvements, including peek operations, untracked execution, and improved batching support.

---

## 📚 **Table of Contents**

1. [Quick Start](#quick-start)
2. [Core APIs](#core-apis)
3. [Peek Operations](#peek-operations)
4. [Untracked Execution](#untracked-execution)
5. [Batching System](#batching-system)
6. [Performance Patterns](#performance-patterns)
7. [Common Pitfalls](#common-pitfalls)
8. [Migration Guide](#migration-guide)

---

## 🚀 **Quick Start**

### Basic Setup
```zig
const reactive = @import("lib/reactive.zig");

// Initialize reactive context (once per thread)
try reactive.context.initContext(allocator);
defer reactive.context.deinitContext(allocator);

// Initialize batching system
try reactive.batch.initGlobalBatcher(allocator);
defer reactive.batch.deinitGlobalBatcher(allocator);
```

### Key Concepts
- **Signals** - Reactive primitive values that notify on change
- **Computed** - Derived values that update automatically  
- **Effects** - Side effects that run when dependencies change
- **Peek** - Read values without creating dependencies
- **Untrack** - Execute code without tracking dependencies
- **Batching** - Group updates to run effects only once

---

## 🔧 **Core APIs**

### Signals
```zig
// Create a signal
var count = try signal.Signal(i32).init(allocator, 0);
defer count.deinit();

// Read with dependency tracking
const value = count.get(); // Creates dependency if in reactive context

// Read without dependency tracking (NEW)
const value_untracked = count.peek(); // Never creates dependencies

// Update value
count.set(42); // Notifies all observers

// Update via function
count.update(struct {
    fn increment(current: i32) i32 {
        return current + 1;
    }
}.increment);
```

### Computed Values
```zig
// Create computed value
var doubled = try computed.computed(allocator, i32, struct {
    fn compute() i32 {
        return count.get() * 2; // Automatically tracks count dependency
    }
}.compute);
defer {
    doubled.deinit();
    allocator.destroy(doubled);
}

// Read with dependency tracking
const value = doubled.get(); // Creates dependency, lazy evaluation

// Read without dependency tracking (NEW)
const value_untracked = doubled.peek(); // No dependency, still lazy
```

### Effects
```zig
// Create effect
const eff = try effect.createEffect(allocator, struct {
    fn run() void {
        const current = count.get(); // Automatically tracks count
        std.debug.print("Count is now: {}\n", .{current});
    }
}.run);
defer allocator.destroy(eff);

// Effect runs immediately and re-runs when count changes
```

---

## 👀 **Peek Operations**

### Overview
Peek operations allow reading reactive values without creating dependencies. This is crucial for performance optimization and avoiding unwanted reactive chains.

### Signal Peek
```zig
var signal = try signal.Signal(i32).init(allocator, 100);
defer signal.deinit();

const eff = try effect.createEffect(allocator, struct {
    fn run() void {
        // This creates a dependency - effect will re-run when signal changes
        const tracked_value = signal.get(); 
        
        // This does NOT create a dependency - safe to read
        const untracked_value = signal.peek();
        
        std.debug.print("Tracked: {}, Untracked: {}\n", .{ tracked_value, untracked_value });
    }
}.run);

// Changing signal will cause effect to re-run due to tracked dependency
signal.set(200);
```

### Computed Peek
```zig
var source = try signal.Signal(i32).init(allocator, 5);
defer source.deinit();

var computed_val = try computed.computed(allocator, i32, struct {
    fn compute() i32 {
        return source.get() * 10;
    }
}.compute);
defer {
    computed_val.deinit();
    allocator.destroy(computed_val);
}

const eff = try effect.createEffect(allocator, struct {
    fn run() void {
        // Creates dependency on computed_val
        const reactive_result = computed_val.get();
        
        // No dependency created, but still gets latest computed value
        const peeked_result = computed_val.peek();
        
        // Both values are the same, but dependency behavior differs
        std.debug.print("Reactive: {}, Peeked: {}\n", .{ reactive_result, peeked_result });
    }
}.run);
```

### When to Use Peek
- **Debugging/Logging** - Reading values for debug output without affecting dependencies
- **Conditional Logic** - Checking values to decide whether to create dependencies
- **Performance** - Avoiding unnecessary effect re-runs
- **Initialization** - Reading initial values during setup

---

## 🔓 **Untracked Execution**

### Overview
The `untrack()` function executes code without tracking any dependencies, even if the code calls `get()` on signals or computed values.

### Basic Usage
```zig
const reactive = @import("lib/reactive.zig");

var signal_a = try signal.Signal(i32).init(allocator, 10);
defer signal_a.deinit();
var signal_b = try signal.Signal(i32).init(allocator, 20);
defer signal_b.deinit();

const eff = try effect.createEffect(allocator, struct {
    fn run() void {
        // This creates a dependency on signal_a
        const a = signal_a.get();
        
        // This does NOT create any dependencies, even though it calls get()
        const b = reactive.context.untrack(i32, struct {
            fn read() i32 {
                return signal_b.get(); // get() called but no dependency created
            }
        }.read);
        
        std.debug.print("A: {}, B: {}\n", .{ a, b });
    }
}.run);

// This will trigger the effect (signal_a dependency)
signal_a.set(15);

// This will NOT trigger the effect (no signal_b dependency)
signal_b.set(25);
```

### Advanced Untracked Patterns
```zig
// Untracked computation for conditional dependencies
const eff = try effect.createEffect(allocator, struct {
    fn run() void {
        // Check a condition without creating dependency
        const should_track = reactive.context.untrack(bool, struct {
            fn check() bool {
                return some_config_signal.get() > 0;
            }
        }.check);
        
        if (should_track) {
            // Only create dependency if condition is met
            const value = main_signal.get();
            processValue(value);
        }
    }
}.run);
```

### When to Use Untrack
- **Conditional Dependencies** - Only track some signals based on runtime conditions
- **Performance Optimization** - Expensive operations that shouldn't trigger re-computation
- **Event Handlers** - Reading state in event handlers without creating dependencies
- **Initialization Logic** - Setup code that reads current state without ongoing tracking

---

## ⚡ **Batching System**

### Overview
Batching groups multiple reactive updates to ensure effects run only once per update cycle, improving performance and preventing cascading updates.

### Automatic Batching
Effects are automatically batched when notifications occur:

```zig
var signal_x = try signal.Signal(i32).init(allocator, 1);
defer signal_x.deinit();
var signal_y = try signal.Signal(i32).init(allocator, 2);
defer signal_y.deinit();

const eff = try effect.createEffect(allocator, struct {
    fn run() void {
        const x = signal_x.get();
        const y = signal_y.get();
        std.debug.print("Effect ran: x={}, y={}\n", .{ x, y });
    }
}.run);

// Without batching, effect would run twice
// With batching, effect runs only once after both updates
batch.batch(struct {
    fn update() void {
        signal_x.set(10); // Effect queued, not run yet
        signal_y.set(20); // Effect already queued, no duplicate
    }
}.update);
// Effect runs once here with final values: x=10, y=20
```

### Manual Batching
Use the batch API for grouping multiple updates:

```zig
const batch_mod = @import("lib/reactive/batch.zig");

// Method 1: Using batch() function
batch_mod.batch(struct {
    fn doUpdates() void {
        signal1.set(100);
        signal2.set(200);
        signal3.set(300);
        // All effects run only once at the end
    }
}.doUpdates);

// Method 2: Manual control
if (batch_mod.getGlobalBatcher()) |batcher| {
    batcher.startBatch();
    signal1.set(100);
    signal2.set(200);
    signal3.set(300);
    batcher.endBatch(); // Effects run here
}
```

### Nested Batching
Batches can be nested safely:

```zig
batch_mod.batch(struct {
    fn outerUpdate() void {
        signal1.set(10);
        
        batch_mod.batch(struct {
            fn innerUpdate() void {
                signal2.set(20);
                signal3.set(30);
            }
        }.innerUpdate);
        
        signal4.set(40);
    }
}.outerUpdate);
// All effects run once at the end of the outer batch
```

---

## 🎯 **Performance Patterns**

### Pattern 1: Conditional Dependency Creation
```zig
// BAD: Always creates dependency on config_signal
const eff = try effect.createEffect(allocator, struct {
    fn run() void {
        const enabled = config_signal.get(); // Always tracked
        if (enabled) {
            const data = data_signal.get();
            processData(data);
        }
    }
}.run);

// GOOD: Only track config_signal for changes, peek data conditionally
const eff = try effect.createEffect(allocator, struct {
    fn run() void {
        const enabled = config_signal.get(); // Tracked
        if (enabled) {
            const data = data_signal.peek(); // Not tracked, but current value
            processData(data);
        }
    }
}.run);
```

### Pattern 2: Efficient Debugging
```zig
const eff = try effect.createEffect(allocator, struct {
    fn run() void {
        const value = main_signal.get(); // Creates dependency
        
        // Debug information without affecting reactivity
        const debug_info = reactive.context.untrack(DebugInfo, struct {
            fn getDebug() DebugInfo {
                return DebugInfo{
                    .aux_value = aux_signal.get(), // No dependency
                    .timestamp = time_signal.get(), // No dependency
                    .frame_count = frame_signal.get(), // No dependency
                };
            }
        }.getDebug);
        
        processValue(value, debug_info);
    }
}.run);
```

### Pattern 3: Optimized Computed Chains
```zig
var expensive_computed = try computed.computed(allocator, Result, struct {
    fn compute() Result {
        // Peek upstream values to check if computation is needed
        const input_changed = reactive.context.untrack(bool, struct {
            fn check() bool {
                const current = input_signal.peek();
                return current != last_processed_value;
            }
        }.check);
        
        if (!input_changed) {
            return cached_result; // Skip expensive computation
        }
        
        // Only now create the dependency and do expensive work
        const input = input_signal.get();
        return doExpensiveComputation(input);
    }
}.compute);
```

---

## ⚠️ **Common Pitfalls**

### Pitfall 1: Forgetting to Use Peek
```zig
// BAD: Creates unwanted dependency
const eff = try effect.createEffect(allocator, struct {
    fn run() void {
        const main_value = main_signal.get(); // Tracked
        
        // Only want to log current debug value, but accidentally tracked it
        const debug_value = debug_signal.get(); // Oops! Now tracked too
        std.debug.print("Main: {}, Debug: {}\n", .{ main_value, debug_value });
    }
}.run);

// GOOD: Use peek for debug information
const eff = try effect.createEffect(allocator, struct {
    fn run() void {
        const main_value = main_signal.get(); // Tracked
        const debug_value = debug_signal.peek(); // Not tracked
        std.debug.print("Main: {}, Debug: {}\n", .{ main_value, debug_value });
    }
}.run);
```

### Pitfall 2: Mixing Peek and Get Inconsistently
```zig
// BAD: Inconsistent reading of the same signal
const eff = try effect.createEffect(allocator, struct {
    fn run() void {
        const value1 = signal.get(); // Creates dependency
        // ... some code ...
        const value2 = signal.peek(); // Same signal, but no dependency
        
        // value1 and value2 are the same, but reactive behavior is confusing
    }
}.run);

// GOOD: Be consistent about dependency intent
const eff = try effect.createEffect(allocator, struct {
    fn run() void {
        const value = signal.get(); // Creates dependency - effect will re-run
        
        // Use the same value throughout, or use peek() for additional reads
        processValue(value);
        logValue(value); // Don't read again
    }
}.run);
```

### Pitfall 3: Unnecessary Batching
```zig
// BAD: Over-batching single updates
batch_mod.batch(struct {
    fn singleUpdate() void {
        signal.set(42); // Only one update, batching is unnecessary overhead
    }
}.singleUpdate);

// GOOD: Only batch when you have multiple updates
signal.set(42); // Direct update for single change

// GOOD: Batch when updating multiple signals
batch_mod.batch(struct {
    fn multipleUpdates() void {
        signal1.set(10);
        signal2.set(20);
        signal3.set(30);
    }
}.multipleUpdates);
```

---

## 🔄 **Migration Guide**

### From Manual State Management
```zig
// OLD: Manual state management
const UI = struct {
    fps_text: []const u8 = "",
    needs_update: bool = false,
    
    fn updateFPS(self: *UI, new_fps: f32) void {
        // Manual string formatting
        self.fps_text = std.fmt.allocPrint(allocator, "FPS: {d:.1}", .{new_fps}) catch "FPS: --";
        self.needs_update = true;
    }
    
    fn render(self: *UI) void {
        if (self.needs_update) {
            // Manual render trigger
            renderText(self.fps_text);
            self.needs_update = false;
        }
    }
};

// NEW: Reactive state management
var fps_signal = try signal.Signal(f32).init(allocator, 0.0);
defer fps_signal.deinit();

var fps_text = try computed.computed(allocator, []const u8, struct {
    fn compute() []const u8 {
        const fps = fps_signal.get(); // Auto-dependency
        return std.fmt.allocPrint(allocator, "FPS: {d:.1}", .{fps}) catch "FPS: --";
    }
}.compute);
defer {
    fps_text.deinit();
    allocator.destroy(fps_text);
}

const render_effect = try effect.createEffect(allocator, struct {
    fn run() void {
        const text = fps_text.get(); // Auto-updates when fps changes
        renderText(text);
    }
}.run);
defer allocator.destroy(render_effect);

// Update is now simple
fps_signal.set(60.0); // Automatically triggers text update and re-render
```

### From Basic Reactive to Optimized
```zig
// BASIC: Simple reactive pattern
const eff = try effect.createEffect(allocator, struct {
    fn run() void {
        const a = signal_a.get();
        const b = signal_b.get();
        const c = signal_c.get();
        processData(a, b, c);
    }
}.run);

// OPTIMIZED: Using peek and batching
const eff = try effect.createEffect(allocator, struct {
    fn run() void {
        const primary = signal_a.get(); // Main dependency
        
        // Only read others if primary value indicates they're needed
        if (primary > 0) {
            const secondary = signal_b.get(); // Conditional dependency
            const debug = signal_c.peek(); // Debug info, no dependency
            processData(primary, secondary, debug);
        }
    }
}.run);

// And batch updates for efficiency
batch_mod.batch(struct {
    fn updateAll() void {
        signal_a.set(10);
        signal_b.set(20);
        signal_c.set(30); // Effect runs once with all final values
    }
}.updateAll);
```

---

## 🧪 **Testing Patterns**

### Testing Reactive Components
```zig
test "reactive component with peek" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    try reactive.context.initContext(allocator);
    defer reactive.context.deinitContext(allocator);
    try reactive.batch.initGlobalBatcher(allocator);
    defer reactive.batch.deinitGlobalBatcher(allocator);
    
    var signal = try signal.Signal(i32).init(allocator, 10);
    defer signal.deinit();
    
    var effect_runs: u32 = 0;
    
    const eff = try effect.createEffect(allocator, struct {
        var signal_ref: *signal.Signal(i32) = undefined;
        var counter: *u32 = undefined;
        
        fn run() void {
            _ = signal_ref.get(); // Creates dependency
            counter.* += 1;
        }
    }.run);
    eff.signal_ref = &signal;
    eff.counter = &effect_runs;
    defer allocator.destroy(eff);
    
    // Test that peek doesn't create dependency
    _ = signal.peek(); // Should not trigger effect
    try std.testing.expect(effect_runs == 1); // Only initial run
    
    // Test that normal get creates dependency
    signal.set(20); // Should trigger effect
    try std.testing.expect(effect_runs == 2);
}
```

---

## 📖 **API Reference**

### Signal Methods
- `init(allocator, initial_value)` - Create new signal
- `deinit()` - Cleanup signal
- `get()` - Read value with dependency tracking
- `peek()` - **NEW** Read value without dependency tracking
- `set(new_value)` - Update value and notify observers
- `update(update_fn)` - Update value via function

### Computed Methods
- `computed(allocator, ReturnType, compute_fn)` - Create computed value
- `deinit()` - Cleanup computed value
- `get()` - Read computed value with dependency tracking (lazy)
- `peek()` - **NEW** Read computed value without dependency tracking (lazy)
- `refresh()` - Force recomputation

### Context Functions
- `initContext(allocator)` - Initialize reactive context
- `deinitContext(allocator)` - Cleanup reactive context
- `untrack(ReturnType, fn)` - **NEW** Execute function without tracking dependencies
- `trackDependency(dependency)` - Internal: track a dependency

### Batch Functions
- `initGlobalBatcher(allocator)` - Initialize batching system
- `deinitGlobalBatcher(allocator)` - Cleanup batching system
- `batch(batch_fn)` - Execute function with batching
- `getGlobalBatcher()` - Get global batch manager

---

*This guide covers the enhanced reactive system. For implementation details and architecture, see the archived documentation in `docs/archive/`.*