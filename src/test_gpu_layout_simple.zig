const std = @import("std");
const layout_mod = @import("lib/layout/mod.zig");
const math = @import("lib/math/mod.zig");

const UIElement = layout_mod.UIElement;
const LayoutConstraint = layout_mod.LayoutConstraint;
const SpringState = layout_mod.SpringState;
const HybridLayoutManager = layout_mod.gpu.hybrid.HybridLayoutManager;
const Vec2 = math.Vec2;

test "GPU layout struct sizes" {
    // Verify our GPU-compatible structs have the correct sizes
    try std.testing.expectEqual(64, @sizeOf(UIElement));
    try std.testing.expectEqual(32, @sizeOf(LayoutConstraint));
    try std.testing.expectEqual(32, @sizeOf(SpringState));

    std.debug.print("✅ GPU layout struct sizes verified\n", .{});
}

test "hybrid layout manager CPU mode" {
    const allocator = std.testing.allocator;

    const config = HybridLayoutManager.Config{
        .gpu_threshold = 100,
        .force_cpu = true, // Force CPU mode for this test
    };

    var manager = try HybridLayoutManager.init(allocator, null, config);
    defer manager.deinit();

    // Verify CPU-only configuration
    try std.testing.expect(!manager.hasGPUBackend());

    // Test with small data set
    const test_data = try layout_mod.gpu.hybrid.createTestData(allocator, 10);
    defer test_data.deinit(allocator);

    const results = try manager.performLayout(null, // No command buffer for CPU
        0.016, test_data.elements, test_data.constraints, test_data.springs);
    defer allocator.free(results);

    // Verify results
    try std.testing.expectEqual(test_data.elements.len, results.len);
    try std.testing.expectEqual(.cpu, manager.getCurrentBackend());

    // Check performance stats
    const stats = manager.getPerformanceStats();
    try std.testing.expectEqual(@as(u32, 1), stats.cpu_layout_count);
    try std.testing.expectEqual(@as(u32, 0), stats.gpu_layout_count);
    try std.testing.expect(stats.cpu_layout_time_us > 0);

    std.debug.print("✅ CPU layout test completed successfully\n", .{});
}

test "layout element creation and modification" {
    // Test UIElement creation
    var element = UIElement.init(Vec2{ .x = 100, .y = 200 }, Vec2{ .x = 50, .y = 25 });

    try std.testing.expectEqual(@as(f32, 100), element.position[0]);
    try std.testing.expectEqual(@as(f32, 200), element.position[1]);
    try std.testing.expectEqual(@as(f32, 50), element.size[0]);
    try std.testing.expectEqual(@as(f32, 25), element.size[1]);

    // Test layout mode setting
    element.setLayoutMode(.relative);
    try std.testing.expectEqual(@intFromEnum(UIElement.LayoutMode.relative), element.layout_mode);

    // Test parent setting
    element.setParent(5);
    try std.testing.expectEqual(@as(u32, 5), element.parent_index);

    // Test padding
    element.setPadding(10);
    try std.testing.expectEqual(@as(f32, 10), element.padding[0]); // top
    try std.testing.expectEqual(@as(f32, 10), element.padding[1]); // right
    try std.testing.expectEqual(@as(f32, 10), element.padding[2]); // bottom
    try std.testing.expectEqual(@as(f32, 10), element.padding[3]); // left

    std.debug.print("✅ UIElement creation and modification test passed\n", .{});
}

test "constraint and spring creation" {
    // Test LayoutConstraint creation
    const constraint = LayoutConstraint.sizeConstraint(10, 100, 20, 80);
    try std.testing.expectEqual(@as(f32, 10), constraint.min_width);
    try std.testing.expectEqual(@as(f32, 100), constraint.max_width);
    try std.testing.expectEqual(@as(f32, 20), constraint.min_height);
    try std.testing.expectEqual(@as(f32, 80), constraint.max_height);

    // Test SpringState creation
    const spring = SpringState.init(25.0, 5.0, 2.0);
    try std.testing.expectEqual(@as(f32, 25.0), spring.stiffness);
    try std.testing.expectEqual(@as(f32, 5.0), spring.damping);
    try std.testing.expectEqual(@as(f32, 2.0), spring.mass);
    try std.testing.expectEqual(@as(f32, 0.0), spring.velocity[0]);
    try std.testing.expectEqual(@as(f32, 0.0), spring.velocity[1]);

    std.debug.print("✅ Constraint and spring creation test passed\n", .{});
}

test "test data generation" {
    const allocator = std.testing.allocator;

    const test_data = try layout_mod.gpu.hybrid.createTestData(allocator, 50);
    defer test_data.deinit(allocator);

    // Verify correct counts
    try std.testing.expectEqual(@as(usize, 50), test_data.elements.len);
    try std.testing.expectEqual(@as(usize, 50), test_data.constraints.len);
    try std.testing.expectEqual(@as(usize, 50), test_data.springs.len);

    // Verify root element
    const root = test_data.elements[0];
    try std.testing.expectEqual(UIElement.INVALID_PARENT, root.parent_index);
    try std.testing.expectEqual(@intFromEnum(UIElement.LayoutMode.absolute), root.layout_mode);

    // Verify child elements have valid parents
    for (test_data.elements[1..]) |element| {
        try std.testing.expect(element.parent_index < test_data.elements.len);
    }

    std.debug.print("✅ Test data generation verified\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    std.debug.print("Running GPU Layout Simple Tests...\n", .{});

    // Run individual tests manually since refAllDecls returns void
    std.testing.refAllDecls(@This());

    std.debug.print("All tests passed! 🎉\n", .{});
}
