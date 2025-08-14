const std = @import("std");
const reactive = @import("reactive.zig");

/// Example demonstrating Svelte 5-style automatic dependency tracking
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize reactive system
    try reactive.init(allocator);
    defer reactive.deinit(allocator);

    // Create reactive state ($state in Svelte 5)
    var count = try reactive.signal(allocator, i32, 0);
    defer count.deinit();

    var multiplier = try reactive.signal(allocator, i32, 2);
    defer multiplier.deinit();

    // Store signals for compute functions
    const State = struct {
        var count_ref: *reactive.Signal(i32) = undefined;
        var multiplier_ref: *reactive.Signal(i32) = undefined;
        var result_ref: *reactive.Derived(i32) = undefined;
    };

    State.count_ref = &count;
    State.multiplier_ref = &multiplier;

    // Create derived state ($derived in Svelte 5)
    // Automatically tracks count and multiplier
    var result = try reactive.derived(allocator, i32, struct {
        fn compute() i32 {
            // Just by reading these signals, we automatically depend on them
            return State.count_ref.get() * State.multiplier_ref.get();
        }
    }.compute);
    defer {
        result.deinit();
        allocator.destroy(result);
    }

    State.result_ref = result;

    // Create an effect ($effect in Svelte 5)
    // Automatically re-runs when any dependency changes
    const logger = try reactive.createEffect(allocator, struct {
        fn log() void {
            // Reading signals here automatically makes the effect depend on them
            std.debug.print("Count: {}, Multiplier: {}, Result: {}\n", .{
                State.count_ref.get(),
                State.multiplier_ref.get(),
                State.result_ref.get(),
            });
        }
    }.log);
    defer allocator.destroy(logger);

    // Initial state logged by effect
    std.debug.print("\n--- Automatic Dependency Tracking Demo ---\n", .{});

    // Change count - effect automatically re-runs
    std.debug.print("\nSetting count to 5...\n", .{});
    count.set(5);

    // Change multiplier - effect automatically re-runs
    std.debug.print("\nSetting multiplier to 3...\n", .{});
    multiplier.set(3);

    // Batch multiple changes
    std.debug.print("\nBatching multiple updates...\n", .{});
    reactive.batch(struct {
        fn update() void {
            State.count_ref.set(10);
            State.multiplier_ref.set(4);
        }
    }.update);

    // Watch a specific signal
    const watcher = try reactive.watchSignal(allocator, i32, &count, struct {
        fn onCountChange(value: i32) void {
            std.debug.print("  [Watcher] Count changed to: {}\n", .{value});
        }
    }.onCountChange);
    defer allocator.destroy(watcher);

    std.debug.print("\nSetting count to 20 (watcher will trigger)...\n", .{});
    count.set(20);

    std.debug.print("\n--- Demo Complete ---\n", .{});
}

// Test the example
test "reactive example" {
    // The example demonstrates:
    // 1. Automatic dependency tracking (no manual wiring)
    // 2. Derived values that auto-update
    // 3. Effects that re-run on dependency changes
    // 4. Batching for efficiency
    // 5. Signal watchers for specific tracking

    // This is similar to Svelte 5:
    // let count = $state(0);
    // let multiplier = $state(2);
    // let result = $derived(count * multiplier);
    // $effect(() => {
    //     console.log(`Count: ${count}, Multiplier: ${multiplier}, Result: ${result}`);
    // });

    try main();
}
