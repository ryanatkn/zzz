/// Visibility and culling queries for efficient rendering
const std = @import("std");
const math = @import("../../math/mod.zig");
const transforms = @import("transforms.zig");
const viewport = @import("viewport.zig");

const Vec2 = math.Vec2;
const Viewport = viewport.Viewport;
const CoordinateContext = transforms.CoordinateContext;

// ========================
// VISIBILITY QUERIES
// ========================

/// Check if a point is visible within the camera viewport
pub fn isPointVisible(point: Vec2, context: CoordinateContext) bool {
    const viewport_width = context.screen_width / context.camera_zoom;
    const viewport_height = context.screen_height / context.camera_zoom;
    
    const half_width = viewport_width / 2.0;
    const half_height = viewport_height / 2.0;
    
    return point.x >= context.camera_position.x - half_width and
           point.x <= context.camera_position.x + half_width and
           point.y >= context.camera_position.y - half_height and
           point.y <= context.camera_position.y + half_height;
}

/// Check if a circle is visible (partially or fully) within the viewport
pub fn isCircleVisible(center: Vec2, radius: f32, context: CoordinateContext) bool {
    const viewport_width = context.screen_width / context.camera_zoom;
    const viewport_height = context.screen_height / context.camera_zoom;
    
    const half_width = viewport_width / 2.0;
    const half_height = viewport_height / 2.0;
    
    // Check if circle intersects viewport rectangle (expanded by radius)
    return center.x >= context.camera_position.x - half_width - radius and
           center.x <= context.camera_position.x + half_width + radius and
           center.y >= context.camera_position.y - half_height - radius and
           center.y <= context.camera_position.y + half_height + radius;
}

/// Check if a rectangle is visible (partially or fully) within the viewport
pub fn isRectVisible(pos: Vec2, size: Vec2, context: CoordinateContext) bool {
    const viewport_width = context.screen_width / context.camera_zoom;
    const viewport_height = context.screen_height / context.camera_zoom;
    
    const half_width = viewport_width / 2.0;
    const half_height = viewport_height / 2.0;
    
    const camera_left = context.camera_position.x - half_width;
    const camera_right = context.camera_position.x + half_width;
    const camera_top = context.camera_position.y - half_height;
    const camera_bottom = context.camera_position.y + half_height;
    
    const rect_right = pos.x + size.x;
    const rect_bottom = pos.y + size.y;
    
    // Rectangle intersection test
    return !(rect_right < camera_left or pos.x > camera_right or
             rect_bottom < camera_top or pos.y > camera_bottom);
}

/// Check if a point is visible within a specific viewport
pub fn isPointVisibleInViewport(point: Vec2, view: Viewport) bool {
    return view.contains(point);
}

/// Check if a circle is visible within a specific viewport
pub fn isCircleVisibleInViewport(center: Vec2, radius: f32, view: Viewport) bool {
    return view.intersectsCircle(center, radius);
}

/// Check if a rectangle is visible within a specific viewport
pub fn isRectVisibleInViewport(pos: Vec2, size: Vec2, view: Viewport) bool {
    return view.intersectsRect(pos, size);
}

// ========================
// CULLING UTILITIES
// ========================

/// Cull objects based on distance from camera
pub fn isWithinCullDistance(pos: Vec2, camera_pos: Vec2, max_distance: f32) bool {
    const distance_sq = pos.distanceSquared(camera_pos);
    return distance_sq <= (max_distance * max_distance);
}

/// Frustum culling for objects with bounds
pub fn isBoundsVisible(min_pos: Vec2, max_pos: Vec2, context: CoordinateContext) bool {
    const size = max_pos.sub(min_pos);
    return isRectVisible(min_pos, size, context);
}

/// Check if an object should be rendered based on size on screen
pub fn isLargeEnoughToRender(world_size: f32, context: CoordinateContext, min_screen_pixels: f32) bool {
    const screen_size = world_size * context.camera_zoom;
    return screen_size >= min_screen_pixels;
}

// ========================
// SPATIAL QUERIES
// ========================

/// Get all positions within a radius of a center point
pub const PositionsInRadius = struct {
    positions: []Vec2,
    count: usize,
    
    pub fn init(allocator: std.mem.Allocator, center: Vec2, radius: f32, all_positions: []const Vec2) !PositionsInRadius {
        var result_positions = try allocator.alloc(Vec2, all_positions.len);
        var count: usize = 0;
        
        const radius_sq = radius * radius;
        for (all_positions) |pos| {
            if (center.distanceSquared(pos) <= radius_sq) {
                result_positions[count] = pos;
                count += 1;
            }
        }
        
        return PositionsInRadius{
            .positions = result_positions,
            .count = count,
        };
    }
    
    pub fn deinit(self: PositionsInRadius, allocator: std.mem.Allocator) void {
        allocator.free(self.positions);
    }
    
    pub fn getSlice(self: PositionsInRadius) []Vec2 {
        return self.positions[0..self.count];
    }
};

/// Calculate level of detail based on distance from camera
pub fn calculateLOD(object_pos: Vec2, camera_pos: Vec2, max_distance: f32, max_lod: u32) u32 {
    const distance = object_pos.distance(camera_pos);
    const normalized_distance = math.clamp(distance / max_distance, 0.0, 1.0);
    
    return @intFromFloat(@floor(normalized_distance * @as(f32, @floatFromInt(max_lod))));
}

test "visibility queries" {
    const context = transforms.CoordinateContext.init(800.0, 600.0)
        .withCamera(Vec2{ .x = 0.0, .y = 0.0 }, 1.0);

    // Test point visibility
    try std.testing.expect(isPointVisible(Vec2{ .x = 0.0, .y = 0.0 }, context)); // Center
    try std.testing.expect(isPointVisible(Vec2{ .x = 300.0, .y = 200.0 }, context)); // Inside
    try std.testing.expect(!isPointVisible(Vec2{ .x = 500.0, .y = 400.0 }, context)); // Outside

    // Test circle visibility
    try std.testing.expect(isCircleVisible(Vec2{ .x = 0.0, .y = 0.0 }, 10.0, context));
    try std.testing.expect(!isCircleVisible(Vec2{ .x = 1000.0, .y = 1000.0 }, 10.0, context));

    // Test rectangle visibility
    try std.testing.expect(isRectVisible(Vec2{ .x = -10.0, .y = -10.0 }, Vec2{ .x = 20.0, .y = 20.0 }, context));
    try std.testing.expect(!isRectVisible(Vec2{ .x = 1000.0, .y = 1000.0 }, Vec2{ .x = 10.0, .y = 10.0 }, context));
}

test "culling utilities" {
    const camera_pos = Vec2{ .x = 0.0, .y = 0.0 };
    
    // Test distance culling
    try std.testing.expect(isWithinCullDistance(Vec2{ .x = 5.0, .y = 0.0 }, camera_pos, 10.0));
    try std.testing.expect(!isWithinCullDistance(Vec2{ .x = 15.0, .y = 0.0 }, camera_pos, 10.0));
    
    // Test LOD calculation
    const lod_close = calculateLOD(Vec2{ .x = 1.0, .y = 0.0 }, camera_pos, 100.0, 5);
    const lod_far = calculateLOD(Vec2{ .x = 50.0, .y = 0.0 }, camera_pos, 100.0, 5);
    
    try std.testing.expect(lod_close < lod_far); // Closer objects should have lower LOD
}