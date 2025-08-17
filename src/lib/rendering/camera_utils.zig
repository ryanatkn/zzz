// Camera utilities for common rendering transformations
// Provides reusable patterns for camera-aware rendering operations

const std = @import("std");
const math = @import("../math/mod.zig");
const camera_mod = @import("camera.zig");

const Vec2 = math.Vec2;
const Camera = camera_mod.Camera;

/// Batch transform world positions to screen coordinates
/// Useful for transforming arrays of entity positions efficiently
pub fn worldToScreenBatch(cam: *const Camera, world_positions: []const Vec2, screen_positions: []Vec2) void {
    std.debug.assert(world_positions.len == screen_positions.len);
    
    for (world_positions, screen_positions) |world_pos, *screen_pos| {
        screen_pos.* = cam.worldToScreen(world_pos);
    }
}

/// Transform world size to screen size with camera scaling
pub fn worldSizeToScreen(cam: *const Camera, world_size: f32) f32 {
    return cam.worldSizeToScreen(world_size);
}

/// Transform world size Vec2 to screen size Vec2 with camera scaling
pub fn worldSizeVec2ToScreen(cam: *const Camera, world_size: Vec2) Vec2 {
    return Vec2{
        .x = cam.worldSizeToScreen(world_size.x),
        .y = cam.worldSizeToScreen(world_size.y),
    };
}

/// Check if a world position is visible within the camera's viewport
/// Includes a margin for off-screen culling optimization
pub fn isWorldPositionVisible(cam: *const Camera, world_pos: Vec2, world_radius: f32, margin: f32) bool {
    const screen_pos = cam.worldToScreen(world_pos);
    const screen_radius = cam.worldSizeToScreen(world_radius);
    const total_radius = screen_radius + margin;
    
    return screen_pos.x + total_radius >= 0 and
           screen_pos.x - total_radius <= cam.screen_width and
           screen_pos.y + total_radius >= 0 and
           screen_pos.y - total_radius <= cam.screen_height;
}

/// Batch visibility test for multiple entities
/// Returns count of visible entities, fills visible_indices with indices of visible entities
pub fn batchVisibilityTest(
    cam: *const Camera,
    world_positions: []const Vec2,
    world_radii: []const f32,
    margin: f32,
    visible_indices: []u32,
) u32 {
    std.debug.assert(world_positions.len == world_radii.len);
    
    var visible_count: u32 = 0;
    for (world_positions, world_radii, 0..) |world_pos, world_radius, i| {
        if (isWorldPositionVisible(cam, world_pos, world_radius, margin)) {
            if (visible_count < visible_indices.len) {
                visible_indices[visible_count] = @intCast(i);
                visible_count += 1;
            }
        }
    }
    return visible_count;
}

/// Camera transformation data for an entity
pub const EntityTransform = struct {
    screen_pos: Vec2,
    screen_radius: f32,
    
    pub fn fromWorld(cam: *const Camera, world_pos: Vec2, world_radius: f32) EntityTransform {
        return EntityTransform{
            .screen_pos = cam.worldToScreen(world_pos),
            .screen_radius = cam.worldSizeToScreen(world_radius),
        };
    }
};

/// Camera transformation data for a rectangle entity
pub const RectTransform = struct {
    screen_pos: Vec2,
    screen_size: Vec2,
    
    pub fn fromWorld(cam: *const Camera, world_pos: Vec2, world_size: Vec2) RectTransform {
        return RectTransform{
            .screen_pos = cam.worldToScreen(world_pos),
            .screen_size = worldSizeVec2ToScreen(cam, world_size),
        };
    }
};

/// Batch transform entities to screen coordinates
/// Fills transforms array with screen coordinates for entities
pub fn batchTransformEntities(
    cam: *const Camera,
    world_positions: []const Vec2,
    world_radii: []const f32,
    transforms: []EntityTransform,
) void {
    std.debug.assert(world_positions.len == world_radii.len);
    std.debug.assert(world_positions.len == transforms.len);
    
    for (world_positions, world_radii, transforms) |world_pos, world_radius, *transform| {
        transform.* = EntityTransform.fromWorld(cam, world_pos, world_radius);
    }
}

/// Batch transform rectangle entities to screen coordinates
pub fn batchTransformRects(
    cam: *const Camera,
    world_positions: []const Vec2,
    world_sizes: []const Vec2,
    transforms: []RectTransform,
) void {
    std.debug.assert(world_positions.len == world_sizes.len);
    std.debug.assert(world_positions.len == transforms.len);
    
    for (world_positions, world_sizes, transforms) |world_pos, world_size, *transform| {
        transform.* = RectTransform.fromWorld(cam, world_pos, world_size);
    }
}

/// Depth-based sorting for rendering order
/// Sorts entity indices by world Y coordinate for depth ordering
pub fn sortEntitiesByDepth(world_positions: []const Vec2, indices: []u32) void {
    const Context = struct {
        positions: []const Vec2,
        
        pub fn lessThan(ctx: @This(), a_index: u32, b_index: u32) bool {
            return ctx.positions[a_index].y < ctx.positions[b_index].y;
        }
    };
    
    const context = Context{ .positions = world_positions };
    std.sort.pdq(u32, indices, context, Context.lessThan);
}

/// Combined visibility test and transform for optimal performance
/// Returns the number of visible entities and fills the transforms array
pub fn transformVisibleEntities(
    cam: *const Camera,
    world_positions: []const Vec2,
    world_radii: []const f32,
    margin: f32,
    transforms: []EntityTransform,
    visible_indices: []u32,
) u32 {
    std.debug.assert(world_positions.len == world_radii.len);
    
    var visible_count: u32 = 0;
    for (world_positions, world_radii, 0..) |world_pos, world_radius, i| {
        if (isWorldPositionVisible(cam, world_pos, world_radius, margin)) {
            if (visible_count < transforms.len and visible_count < visible_indices.len) {
                visible_indices[visible_count] = @intCast(i);
                transforms[visible_count] = EntityTransform.fromWorld(cam, world_pos, world_radius);
                visible_count += 1;
            }
        }
    }
    return visible_count;
}

/// Performance configuration for camera utilities
pub const CameraUtilsConfig = struct {
    /// Margin for off-screen culling (in screen pixels)
    culling_margin: f32 = 50.0,
    
    /// Enable depth sorting for entities
    enable_depth_sorting: bool = false,
    
    /// Maximum entities to process in batch operations
    max_batch_size: u32 = 1000,
};

/// Optimal combined operation: cull, transform, and optionally sort
/// This is the most efficient function for typical entity rendering
pub fn prepareEntitiesForRendering(
    cam: *const Camera,
    world_positions: []const Vec2,
    world_radii: []const f32,
    config: CameraUtilsConfig,
    transforms: []EntityTransform,
    visible_indices: []u32,
) u32 {
    const batch_size = @min(@min(world_positions.len, config.max_batch_size), transforms.len);
    const positions_slice = world_positions[0..batch_size];
    const radii_slice = world_radii[0..batch_size];
    
    // Combine culling and transformation in single pass
    const visible_count = transformVisibleEntities(
        cam,
        positions_slice,
        radii_slice,
        config.culling_margin,
        transforms,
        visible_indices,
    );
    
    // Optional depth sorting
    if (config.enable_depth_sorting and visible_count > 1) {
        const indices_slice = visible_indices[0..visible_count];
        sortEntitiesByDepth(positions_slice, indices_slice);
        
        // Reorder transforms to match sorted indices
        var temp_transforms: [1000]EntityTransform = undefined;
        for (indices_slice, 0..) |index, i| {
            temp_transforms[i] = transforms[i];
        }
        for (indices_slice, 0..) |index, i| {
            transforms[i] = EntityTransform.fromWorld(cam, positions_slice[index], radii_slice[index]);
        }
    }
    
    return visible_count;
}