const std = @import("std");
const gpu_layout = @import("lib/layout/gpu/mod.zig");
const math = @import("lib/math/mod.zig");
const sdl = @import("lib/platform/sdl.zig");
const loggers = @import("lib/debug/loggers.zig");

const UIElement = gpu_layout.UIElement;
const GPULayoutEngine = gpu_layout.GPULayoutEngine;
const LayoutConstraint = gpu_layout.LayoutConstraint;
const SpringState = gpu_layout.SpringState;
const Vec2 = math.Vec2;

/// Test GPU layout with actual SDL GPU device
pub fn runGPULayoutTest(device: *sdl.sdl.SDL_GPUDevice, command_buffer: *sdl.sdl.SDL_GPUCommandBuffer) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    loggers.getRenderLog().info("gpu_layout_test_start", "🧪 Starting GPU Layout Engine Test", .{});

    // Initialize GPU layout engine
    var engine = try GPULayoutEngine.init(allocator, device, 1000);
    defer engine.deinit();

    // Create test elements
    const test_elements = try createTestElements(allocator);
    defer allocator.free(test_elements);

    const test_constraints = try createTestConstraints(allocator, test_elements.len);
    defer allocator.free(test_constraints);

    const test_springs = try createTestSprings(allocator, test_elements.len);
    defer allocator.free(test_springs);

    // Upload test data to GPU
    try engine.uploadElements(test_elements);
    try engine.uploadConstraints(test_constraints);
    try engine.uploadSprings(test_springs);

    // Set viewport
    engine.setViewportSize(Vec2{ .x = 1920, .y = 1080 });

    loggers.getRenderLog().info("gpu_layout_data_uploaded", "Test data uploaded: {} elements", .{test_elements.len});

    // Perform GPU layout calculation
    const start_time = std.time.nanoTimestamp();
    try engine.performLayout(command_buffer, 0.016); // 60 FPS delta time
    const end_time = std.time.nanoTimestamp();

    const layout_time_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;
    loggers.getRenderLog().info("gpu_layout_performance", "GPU layout completed in {d:.3} ms for {} elements", .{ layout_time_ms, test_elements.len });

    // Download results and verify
    const results = try engine.downloadElements(command_buffer);
    defer allocator.free(results);

    // Verify results make sense
    var valid_positions: u32 = 0;
    var elements_with_changes: u32 = 0;

    for (results, 0..) |result, i| {
        const original = test_elements[i];

        // Check if position is within reasonable bounds
        if (result.position[0] >= 0 and result.position[0] <= 1920 and
            result.position[1] >= 0 and result.position[1] <= 1080)
        {
            valid_positions += 1;
        }

        // Check if element was processed (position might have changed)
        if (result.position[0] != original.position[0] or result.position[1] != original.position[1]) {
            elements_with_changes += 1;
        }
    }

    loggers.getRenderLog().info("gpu_layout_results", "Results: {}/{} valid positions, {} elements changed", .{ valid_positions, results.len, elements_with_changes });

    if (valid_positions == results.len) {
        loggers.getRenderLog().info("gpu_layout_test_success", "✅ GPU Layout Engine test completed successfully!", .{});
    } else {
        loggers.getRenderLog().err("gpu_layout_test_fail", "❌ GPU Layout Engine test failed - invalid positions detected", .{});
        return error.GPULayoutTestFailed;
    }
}

fn createTestElements(allocator: std.mem.Allocator) ![]UIElement {
    const element_count = 250; // Test with reasonable number
    const elements = try allocator.alloc(UIElement, element_count);

    // Create a hierarchy of elements for testing
    for (elements, 0..) |*elem, i| {
        const fi = @as(f32, @floatFromInt(i));

        // Create different types of layouts
        if (i == 0) {
            // Root container
            elem.* = UIElement.init(Vec2{ .x = 0, .y = 0 }, Vec2{ .x = 1920, .y = 1080 });
            elem.setLayoutMode(.absolute);
            elem.setPadding(20);
        } else if (i < 10) {
            // Top-level containers
            elem.* = UIElement.init(Vec2{ .x = fi * 180, .y = 50 }, Vec2{ .x = 160, .y = 200 });
            elem.setParent(0);
            elem.setLayoutMode(.relative);
            elem.setPadding(10);
            elem.setMargin(5);
        } else if (i < 50) {
            // Child elements of first few containers
            const parent_index = 1 + (i - 10) % 9; // Distribute among containers
            elem.* = UIElement.init(Vec2{ .x = 10, .y = (fi - 10) * 25 }, Vec2{ .x = 140, .y = 20 });
            elem.setParent(@intCast(parent_index));
            elem.setLayoutMode(.relative);
            elem.setPadding(2);
        } else {
            // Random positioned elements
            elem.* = UIElement.init(Vec2{ .x = @mod(fi * 73, 1800), .y = @mod(fi * 113, 900) }, Vec2{ .x = 50 + @mod(fi * 17, 100), .y = 20 + @mod(fi * 23, 50) });
            elem.setLayoutMode(.absolute);
        }

        // Mark all as needing layout
        elem.markDirty(.layout);
    }

    return elements;
}

fn createTestConstraints(allocator: std.mem.Allocator, element_count: usize) ![]LayoutConstraint {
    const constraints = try allocator.alloc(LayoutConstraint, element_count);

    for (constraints, 0..) |*constraint, i| {
        if (i == 0) {
            // Root element - fixed size
            constraint.* = LayoutConstraint.sizeConstraint(1920, 1920, 1080, 1080);
            constraint.priority = 10; // Highest priority
        } else if (i < 10) {
            // Containers - flexible width, fixed height
            constraint.* = LayoutConstraint.sizeConstraint(100, 300, 200, 200);
            constraint.priority = 5;
        } else if (i < 50) {
            // Children - minimum sizes
            constraint.* = LayoutConstraint.sizeConstraint(50, 200, 15, 30);
            constraint.priority = 2;
        } else {
            // Random elements - basic constraints
            constraint.* = LayoutConstraint.sizeConstraint(20, 150, 10, 80);
            constraint.priority = 1;
        }
    }

    return constraints;
}

fn createTestSprings(allocator: std.mem.Allocator, element_count: usize) ![]SpringState {
    const springs = try allocator.alloc(SpringState, element_count);

    for (springs, 0..) |*spring, i| {
        const fi = @as(f32, @floatFromInt(i));

        if (i == 0) {
            // Root element - very stiff
            spring.* = SpringState.init(50.0, 10.0, 5.0);
        } else if (i < 10) {
            // Containers - medium stiffness
            spring.* = SpringState.init(20.0, 5.0, 2.0);
        } else {
            // Children and random elements - responsive
            spring.* = SpringState.init(10.0 + @mod(fi, 10), 2.0 + @mod(fi * 0.1, 3), 1.0);
        }
    }

    return springs;
}

/// Export for use in main game loop
pub const gpu_layout_test = struct {
    pub const runTest = runGPULayoutTest;
};
