// Camera coordinate transformation tests
// Validates screen-to-world and world-to-screen conversions

const std = @import("std");
const testing = std.testing;
const math = @import("../../math/mod.zig");
const Camera = @import("camera.zig").Camera;

const Vec2 = math.Vec2;

test "camera coordinate transformation accuracy" {
    // Create camera with known parameters
    var camera = Camera.init(1920.0, 1080.0);
    camera.setViewport(Vec2.init(80.0, 45.0), 16.0, 9.0); // 16x9m viewport centered at (80,45)

    // Test center point transformation
    const center_screen = Vec2.init(960.0, 540.0); // Screen center
    const center_world = camera.screenToWorldSafe(center_screen);

    // Should transform to viewport center
    try testing.expectApproxEqAbs(@as(f32, 80.0), center_world.x, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 45.0), center_world.y, 0.001);

    // Test round-trip accuracy
    const back_to_screen = camera.worldToScreen(center_world);
    try testing.expectApproxEqAbs(center_screen.x, back_to_screen.x, 0.1);
    try testing.expectApproxEqAbs(center_screen.y, back_to_screen.y, 0.1);
}

test "camera world space boundaries" {
    var camera = Camera.init(1920.0, 1080.0);
    camera.setViewport(Vec2.init(80.0, 45.0), 16.0, 9.0); // 16x9m viewport

    // Test corner transformations
    const corners = [_]Vec2{
        Vec2.init(0.0, 0.0), // Screen top-left
        Vec2.init(1920.0, 0.0), // Screen top-right
        Vec2.init(0.0, 1080.0), // Screen bottom-left
        Vec2.init(1920.0, 1080.0), // Screen bottom-right
    };

    for (corners) |corner| {
        const world_pos = camera.screenToWorldSafe(corner);
        const back_to_screen = camera.worldToScreen(world_pos);

        // Verify round-trip accuracy within pixel tolerance
        try testing.expectApproxEqAbs(corner.x, back_to_screen.x, 1.0);
        try testing.expectApproxEqAbs(corner.y, back_to_screen.y, 1.0);
    }
}

test "camera viewport scaling" {
    var camera = Camera.init(1920.0, 1080.0);

    // Test different viewport sizes
    const test_cases = [_]struct {
        viewport_width: f32,
        viewport_height: f32,
        expected_scale_x: f32,
        expected_scale_y: f32,
    }{
        .{ .viewport_width = 16.0, .viewport_height = 9.0, .expected_scale_x = 120.0, .expected_scale_y = 120.0 }, // 1920/16 = 120
        .{ .viewport_width = 32.0, .viewport_height = 18.0, .expected_scale_x = 60.0, .expected_scale_y = 60.0 }, // 1920/32 = 60
        .{ .viewport_width = 8.0, .viewport_height = 4.5, .expected_scale_x = 240.0, .expected_scale_y = 240.0 }, // 1920/8 = 240
    };

    for (test_cases) |test_case| {
        camera.setViewport(Vec2.init(0.0, 0.0), test_case.viewport_width, test_case.viewport_height);

        // Test that a 1-meter world distance maps to expected screen distance
        const world_pos1 = Vec2.init(0.0, 0.0);
        const world_pos2 = Vec2.init(1.0, 0.0); // 1 meter to the right

        const screen_pos1 = camera.worldToScreen(world_pos1);
        const screen_pos2 = camera.worldToScreen(world_pos2);

        const screen_distance = screen_pos2.sub(screen_pos1).length();
        try testing.expectApproxEqAbs(test_case.expected_scale_x, screen_distance, 1.0);
    }
}

test "camera viewport transformations" {
    var camera = Camera.init(1920.0, 1080.0);

    // Set up a known viewport
    camera.setViewport(Vec2.init(80.0, 45.0), 16.0, 9.0);

    // Test screen center transforms to viewport center
    const screen_center = Vec2.init(960.0, 540.0);
    const world_center = camera.screenToWorldSafe(screen_center);

    // Should map to viewport center (80, 45)
    try testing.expectApproxEqAbs(@as(f32, 80.0), world_center.x, 0.1);
    try testing.expectApproxEqAbs(@as(f32, 45.0), world_center.y, 0.1);

    // Test that coordinate transformation is reversible
    const back_to_screen = camera.worldToScreen(world_center);
    try testing.expectApproxEqAbs(screen_center.x, back_to_screen.x, 1.0);
    try testing.expectApproxEqAbs(screen_center.y, back_to_screen.y, 1.0);
}

test "coordinate space consistency" {
    var camera = Camera.init(1920.0, 1080.0);
    camera.setViewport(Vec2.init(80.0, 45.0), 16.0, 9.0);

    // Test multiple points for consistent transformation
    const test_points = [_]Vec2{
        Vec2.init(100.0, 200.0),
        Vec2.init(800.0, 400.0),
        Vec2.init(1500.0, 900.0),
        Vec2.init(300.0, 600.0),
    };

    for (test_points) |screen_point| {
        // Screen → World → Screen should be consistent
        const world_point = camera.screenToWorldSafe(screen_point);
        const back_to_screen = camera.worldToScreen(world_point);

        // Verify accuracy within reasonable tolerance
        const transform_error = screen_point.sub(back_to_screen).length();
        try testing.expect(transform_error < 1.0); // Less than 1 pixel error
    }
}
