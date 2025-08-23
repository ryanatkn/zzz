/// Unified viewport system using consolidated math.Bounds
const std = @import("std");
const math = @import("../../math/mod.zig");
const camera_mod = @import("../../game/camera/mod.zig");
const transforms = @import("transforms.zig");

const Vec2 = math.Vec2;
const Bounds = math.Bounds;
const Camera = camera_mod.Camera;
const CoordinateContext = transforms.CoordinateContext;

/// Unified viewport representing the visible world area
///
/// Combines world bounds calculation with camera-based transformations
/// to provide a complete spatial view of the rendering area.
pub const Viewport = struct {
    /// World space bounds of the visible area
    bounds: Bounds,

    /// Reference to the camera for coordinate transformations
    camera: *const Camera,

    /// Create viewport from camera state
    pub fn fromCamera(camera: *const Camera) Viewport {
        // Calculate world bounds from camera viewport
        const half_width = camera.viewport_width / 2.0;
        const half_height = camera.viewport_height / 2.0;

        const world_bounds = Bounds.init(
            camera.view_center.x - half_width,
            camera.view_center.y - half_height,
            camera.view_center.x + half_width,
            camera.view_center.y + half_height,
        );

        return .{
            .bounds = world_bounds,
            .camera = camera,
        };
    }

    /// Create viewport from center point and size
    pub fn init(center_point: Vec2, width: f32, height: f32, camera: *const Camera) Viewport {
        const bounds = Bounds.fromCenterSize(center_point, width, height);
        return .{
            .bounds = bounds,
            .camera = camera,
        };
    }

    /// Create viewport from coordinate context (backward compatibility)
    pub fn fromContext(context: CoordinateContext, camera: *const Camera) Viewport {
        const world_width = context.screen_width / context.camera_zoom;
        const world_height = context.screen_height / context.camera_zoom;

        return init(context.camera_position, world_width, world_height, camera);
    }

    /// Check if a point is inside the viewport bounds
    pub fn contains(self: Viewport, point: Vec2) bool {
        return self.bounds.contains(point);
    }

    /// Check if viewport intersects with another viewport
    pub fn intersects(self: Viewport, other: Viewport) bool {
        return self.bounds.intersects(other.bounds);
    }

    /// Get the center point of the viewport
    pub fn center(self: Viewport) Vec2 {
        return self.bounds.center();
    }

    /// Get the size of the viewport (width, height)
    pub fn size(self: Viewport) Vec2 {
        return Vec2{
            .x = self.bounds.width(),
            .y = self.bounds.height(),
        };
    }

    /// Expand viewport bounds by margin
    pub fn expanded(self: Viewport, margin: f32) Viewport {
        return .{
            .bounds = self.bounds.expand(margin),
            .camera = self.camera,
        };
    }

    /// Transform screen coordinates to world coordinates using camera
    pub fn screenToWorld(self: Viewport, screen_pos: Vec2) Vec2 {
        return self.camera.screenToWorldSafe(screen_pos);
    }

    /// Transform world coordinates to screen coordinates using camera
    pub fn worldToScreen(self: Viewport, world_pos: Vec2) Vec2 {
        const context = CoordinateContext.init(self.camera.screen_width, self.camera.screen_height)
            .withCamera(self.camera.view_center, self.camera.zoom_level);

        return transforms.worldToScreen(world_pos, context);
    }

    /// Check if a circle intersects with the viewport
    pub fn intersectsCircle(self: Viewport, circle_center: Vec2, radius: f32) bool {
        // Check if circle center is within expanded bounds
        const expanded_bounds = self.bounds.expand(radius);
        return expanded_bounds.contains(circle_center);
    }

    /// Check if a rectangle intersects with the viewport
    pub fn intersectsRect(self: Viewport, pos: Vec2, rect_size: Vec2) bool {
        const rect_bounds = Bounds.init(pos.x, pos.y, pos.x + rect_size.x, pos.y + rect_size.y);
        return self.bounds.intersects(rect_bounds);
    }

    /// Get viewport area in world units
    pub fn area(self: Viewport) f32 {
        return self.bounds.area();
    }

    /// Clamp a point to viewport bounds
    pub fn clampPoint(self: Viewport, point: Vec2) Vec2 {
        return Vec2{
            .x = math.clamp(point.x, self.bounds.x_min, self.bounds.x_max),
            .y = math.clamp(point.y, self.bounds.y_min, self.bounds.y_max),
        };
    }

    /// Get distance from point to viewport bounds (0 if inside)
    pub fn distanceToPoint(self: Viewport, point: Vec2) f32 {
        if (self.contains(point)) {
            return 0.0;
        }

        const clamped = self.clampPoint(point);
        return point.distance(clamped);
    }
};

test "viewport creation and basic operations" {
    // Mock camera for testing
    const camera = Camera.init(800.0, 600.0);

    const viewport = Viewport.init(Vec2{ .x = 0.0, .y = 0.0 }, 100.0, 80.0, &camera);

    // Test bounds
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), viewport.bounds.width(), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 80.0), viewport.bounds.height(), 0.01);

    // Test center
    const center = viewport.center();
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), center.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), center.y, 0.01);

    // Test containment
    try std.testing.expect(viewport.contains(Vec2{ .x = 10.0, .y = 10.0 }));
    try std.testing.expect(!viewport.contains(Vec2{ .x = 60.0, .y = 60.0 }));
}

test "viewport intersection tests" {
    const camera = Camera.init(800.0, 600.0);

    const viewport1 = Viewport.init(Vec2{ .x = 0.0, .y = 0.0 }, 20.0, 20.0, &camera);
    const viewport2 = Viewport.init(Vec2{ .x = 10.0, .y = 10.0 }, 20.0, 20.0, &camera); // Overlapping
    const viewport3 = Viewport.init(Vec2{ .x = 50.0, .y = 50.0 }, 20.0, 20.0, &camera); // Non-overlapping

    try std.testing.expect(viewport1.intersects(viewport2));
    try std.testing.expect(!viewport1.intersects(viewport3));

    // Test circle intersection
    try std.testing.expect(viewport1.intersectsCircle(Vec2{ .x = 5.0, .y = 5.0 }, 3.0));
    try std.testing.expect(!viewport1.intersectsCircle(Vec2{ .x = 50.0, .y = 50.0 }, 3.0));

    // Test rectangle intersection
    try std.testing.expect(viewport1.intersectsRect(Vec2{ .x = 5.0, .y = 5.0 }, Vec2{ .x = 10.0, .y = 10.0 }));
    try std.testing.expect(!viewport1.intersectsRect(Vec2{ .x = 50.0, .y = 50.0 }, Vec2{ .x = 10.0, .y = 10.0 }));
}
