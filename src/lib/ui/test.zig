/// UI system tests
/// Tests for layout primitives, box model, and text baseline calculations
const std = @import("std");

// Import all the UI modules for testing
test {
    // Include all the individual module tests
    _ = @import("../layout/text_baseline.zig");
    _ = @import("../layout/box_model.zig");
    _ = @import("../layout/primitives/spacing.zig");
    _ = @import("../layout/primitives/sizing.zig");
    _ = @import("../layout/primitives/positioning.zig");
    _ = @import("../layout/primitives/flexbox.zig");
}

// Integration tests that test multiple systems together
test "UI integration: text input with proper baseline and cursor alignment" {
    const testing = std.testing;
    const reactive = @import("../reactive/mod.zig");
    const text_baseline = @import("../layout/text_baseline.zig");
    const font_metrics = @import("../font/font_metrics.zig");
    const math = @import("../math/mod.zig");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try reactive.init(allocator);
    defer reactive.deinit(allocator);

    // Test font metrics
    const metrics = font_metrics.FontMetrics.init(1000, 800, -200, 100, 0.012);

    // Test text positioning in a container
    const container_height: f32 = 30.0;
    const text_y = text_baseline.TextPositioning.getCenteredTextY(10.0, container_height, metrics);

    // Text should be positioned for proper visual centering
    try testing.expect(text_y > 10.0);
    try testing.expect(text_y < 40.0);

    // Test cursor positioning matches text
    const text_pos = math.Vec2{ .x = 15.0, .y = text_y };
    const cursor_pos = text_baseline.TextPositioning.getCursorPosition(text_pos, 5, 8.0, metrics);

    // Cursor should be positioned relative to text baseline
    try testing.expect(cursor_pos.x == 55.0); // 15 + 5*8
    try testing.expect(cursor_pos.y < text_y); // Cursor top above text baseline
}

test "UI integration: flexbox layout with box model spacing" {
    const testing = std.testing;
    const box_model = @import("../layout/box_model.zig");
    const flexbox_mod = @import("../layout/primitives/flexbox.zig");
    const reactive = @import("../reactive/mod.zig");
    const math = @import("../math/mod.zig");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try reactive.init(allocator);
    defer reactive.deinit(allocator);

    // Create container with box model
    var container = try box_model.BoxModel.init(allocator, math.Vec2.ZERO, math.Vec2{ .x = 200, .y = 100 });
    defer container.deinit(allocator);

    container.setPadding(10);

    // Get content area for flexbox layout
    const content_bounds = container.getContentBounds();

    // Create flex layout
    const flex = flexbox_mod.Flexbox.createRowLayout(.flex_start, .flex_start, 5);

    const items = [_]flexbox_mod.Flexbox.FlexItem{
        flexbox_mod.Flexbox.createFlexItem(math.Vec2{ .x = 50, .y = 30 }, 0, 1),
        flexbox_mod.Flexbox.createFlexItem(math.Vec2{ .x = 60, .y = 40 }, 0, 1),
    };

    const layout = try flex.calculateLayout(content_bounds.size, &items, allocator);
    defer allocator.free(layout);

    // Verify layout respects container padding
    try testing.expect(layout.len == 2);
    try testing.expect(layout[0].size.x == 50);
    try testing.expect(layout[1].position.x == 55); // 50 + 5 gap

    // When positioned in container, should account for padding offset
    const final_pos_item1 = math.Vec2{
        .x = content_bounds.position.x + layout[0].position.x,
        .y = content_bounds.position.y + layout[0].position.y,
    };

    try testing.expect(final_pos_item1.x == 10); // Container padding offset
    try testing.expect(final_pos_item1.y == 10); // Container padding offset
}

test "UI integration: responsive box model with constraints" {
    const testing = std.testing;
    const box_model = @import("../layout/box_model.zig");
    const reactive = @import("../reactive/mod.zig");
    const math = @import("../math/mod.zig");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try reactive.init(allocator);
    defer reactive.deinit(allocator);

    // Create responsive box with constraints
    var box = try box_model.BoxModel.init(allocator, math.Vec2.ZERO, math.Vec2{ .x = 100, .y = 50 });
    defer box.deinit(allocator);

    // Set constraints and spacing
    box.setConstraints(box_model.BoxModel.Constraints{
        .min_width = 80,
        .max_width = 300,
        .min_height = 40,
        .max_height = 200,
    });

    box.setPadding(5);
    box.setMargin(10);
    box.setBorderWidth(2);

    const layout = box.getLayout();

    // Verify all areas are calculated correctly
    try testing.expect(layout.content.size.x == 100); // Original size within constraints
    try testing.expect(layout.padding.size.x == 110); // Content + padding
    try testing.expect(layout.border.size.x == 114); // Padding + border
    try testing.expect(layout.margin.size.x == 134); // Border + margin (outer bounds)

    // Test layout is not dirty after access
    try testing.expect(!box.isDirty());

    // Test dirty flag on property change
    box.setSize(math.Vec2{ .x = 150, .y = 75 });
    try testing.expect(box.isDirty());

    // Access should recalculate
    const new_layout = box.getLayout();
    try testing.expect(!box.isDirty());
    try testing.expect(new_layout.content.size.x == 150); // New size applied
}
