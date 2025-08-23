/// Coordinate space transformations for rendering system
const std = @import("std");
const math = @import("../../math/mod.zig");

const Vec2 = math.Vec2;

// ========================
// COORDINATE SPACES
// ========================

/// Different coordinate spaces used in the engine
pub const CoordinateSpace = enum {
    /// World coordinates - game world space
    world,
    /// Screen coordinates - pixel coordinates relative to screen
    screen,
    /// Normalized device coordinates - [-1, 1] range
    ndc,
    /// UI coordinates - interface layout space
    ui,
    /// Camera coordinates - relative to camera position
    camera,
};

/// Coordinate transformation context
pub const CoordinateContext = struct {
    screen_width: f32,
    screen_height: f32,
    camera_position: Vec2,
    camera_zoom: f32,
    ui_scale: f32,

    pub fn init(screen_width: f32, screen_height: f32) CoordinateContext {
        return .{
            .screen_width = screen_width,
            .screen_height = screen_height,
            .camera_position = Vec2{ .x = 0, .y = 0 },
            .camera_zoom = 1.0,
            .ui_scale = 1.0,
        };
    }

    pub fn withCamera(self: CoordinateContext, position: Vec2, zoom: f32) CoordinateContext {
        var result = self;
        result.camera_position = position;
        result.camera_zoom = zoom;
        return result;
    }

    pub fn withUI(self: CoordinateContext, ui_scale: f32) CoordinateContext {
        var result = self;
        result.ui_scale = ui_scale;
        return result;
    }
};

// ========================
// CORE TRANSFORMATIONS
// ========================

/// Transform world coordinates to screen coordinates
pub fn worldToScreen(world_pos: Vec2, context: CoordinateContext) Vec2 {
    // Apply camera transform (translate and zoom)
    const camera_relative = world_pos.sub(context.camera_position);
    const camera_scaled = camera_relative.scale(context.camera_zoom);

    // Convert to screen coordinates (camera center = screen center)
    return Vec2{
        .x = camera_scaled.x + context.screen_width / 2.0,
        .y = camera_scaled.y + context.screen_height / 2.0,
    };
}

/// Transform screen coordinates to world coordinates  
pub fn screenToWorld(screen_pos: Vec2, context: CoordinateContext) Vec2 {
    // Convert from screen coordinates to camera-relative
    const camera_relative = Vec2{
        .x = screen_pos.x - context.screen_width / 2.0,
        .y = screen_pos.y - context.screen_height / 2.0,
    };

    // Apply inverse camera transform
    const camera_scaled = camera_relative.scale(1.0 / context.camera_zoom);
    return camera_scaled.add(context.camera_position);
}

/// Transform screen coordinates to normalized device coordinates [-1, 1]
pub fn screenToNDC(screen_pos: Vec2, context: CoordinateContext) Vec2 {
    return Vec2{
        .x = (2.0 * screen_pos.x / context.screen_width) - 1.0,
        .y = 1.0 - (2.0 * screen_pos.y / context.screen_height), // Flip Y axis
    };
}

/// Transform normalized device coordinates to screen coordinates
pub fn ndcToScreen(ndc_pos: Vec2, context: CoordinateContext) Vec2 {
    return Vec2{
        .x = (ndc_pos.x + 1.0) * context.screen_width / 2.0,
        .y = (1.0 - ndc_pos.y) * context.screen_height / 2.0, // Flip Y axis
    };
}

/// Transform UI coordinates to screen coordinates (with UI scaling)
pub fn uiToScreen(ui_pos: Vec2, context: CoordinateContext) Vec2 {
    return Vec2{
        .x = ui_pos.x * context.ui_scale,
        .y = ui_pos.y * context.ui_scale,
    };
}

/// Transform screen coordinates to UI coordinates
pub fn screenToUI(screen_pos: Vec2, context: CoordinateContext) Vec2 {
    return Vec2{
        .x = screen_pos.x / context.ui_scale,
        .y = screen_pos.y / context.ui_scale,
    };
}

// ========================
// SCALING UTILITIES
// ========================

/// Scale coordinates from base resolution to target resolution
pub fn scaleFromBaseResolution(pos: Vec2, base_width: f32, base_height: f32, target_width: f32, target_height: f32) Vec2 {
    return Vec2{
        .x = pos.x * (target_width / base_width),
        .y = pos.y * (target_height / base_height),
    };
}

/// Scale coordinates from 1080p to current resolution (common use case)
pub fn scaleFrom1080p(pos: Vec2, context: CoordinateContext) Vec2 {
    return scaleFromBaseResolution(pos, 1920.0, 1080.0, context.screen_width, context.screen_height);
}

/// Adjust coordinates for aspect ratio differences
/// Maintains proportions when screen aspect ratio differs from design aspect ratio
pub fn aspectRatioAdjusted(pos: Vec2, context: CoordinateContext) Vec2 {
    const design_aspect = 16.0 / 9.0; // 1920x1080 aspect ratio
    const current_aspect = context.screen_width / context.screen_height;

    if (current_aspect > design_aspect) {
        // Screen is wider - scale by height
        const scale = context.screen_height / 1080.0;
        return pos.scale(scale);
    } else {
        // Screen is taller - scale by width  
        const scale = context.screen_width / 1920.0;
        return pos.scale(scale);
    }
}

// ========================
// UTILITY FUNCTIONS
// ========================

/// Clamp coordinates to stay within bounds
pub fn clampToBounds(pos: Vec2, min_bounds: Vec2, max_bounds: Vec2) Vec2 {
    return Vec2{
        .x = math.clamp(pos.x, min_bounds.x, max_bounds.x),
        .y = math.clamp(pos.y, min_bounds.y, max_bounds.y),
    };
}

/// Wrap coordinates around boundaries (for toroidal worlds)
pub fn wrapToBounds(pos: Vec2, bounds_size: Vec2) Vec2 {
    var result = pos;

    while (result.x < 0) result.x += bounds_size.x;
    while (result.x >= bounds_size.x) result.x -= bounds_size.x;
    while (result.y < 0) result.y += bounds_size.y;
    while (result.y >= bounds_size.y) result.y -= bounds_size.y;

    return result;
}

/// Find closest point on bounding rectangle
pub fn closestPointOnBounds(pos: Vec2, min_bounds: Vec2, max_bounds: Vec2) Vec2 {
    return clampToBounds(pos, min_bounds, max_bounds);
}

/// Linear interpolation between two points
pub fn lerp(a: Vec2, b: Vec2, t: f32) Vec2 {
    const clamped_t = math.clamp(t, 0.0, 1.0);
    return Vec2{
        .x = math.lerp(a.x, b.x, clamped_t),
        .y = math.lerp(a.y, b.y, clamped_t),
    };
}

/// Get normalized direction vector between two points
pub fn directionBetween(from: Vec2, to: Vec2) Vec2 {
    const diff = to.sub(from);
    const length = diff.length();
    
    if (length == 0.0) {
        return Vec2{ .x = 0.0, .y = 0.0 };
    }
    
    return diff.scale(1.0 / length);
}

test "coordinate transformations" {
    const context = CoordinateContext.init(800.0, 600.0)
        .withCamera(Vec2{ .x = 100.0, .y = 50.0 }, 2.0);

    // Test world to screen transform
    const world_pos = Vec2{ .x = 100.0, .y = 50.0 }; // At camera center
    const screen_pos = worldToScreen(world_pos, context);
    try std.testing.expectApproxEqAbs(@as(f32, 400.0), screen_pos.x, 0.1); // Screen center X
    try std.testing.expectApproxEqAbs(@as(f32, 300.0), screen_pos.y, 0.1); // Screen center Y

    // Test round-trip transformation
    const recovered_world = screenToWorld(screen_pos, context);
    try std.testing.expectApproxEqAbs(world_pos.x, recovered_world.x, 0.1);
    try std.testing.expectApproxEqAbs(world_pos.y, recovered_world.y, 0.1);
}

test "NDC transformations" {
    const context = CoordinateContext.init(800.0, 600.0);

    // Test screen to NDC
    const screen_center = Vec2{ .x = 400.0, .y = 300.0 };
    const ndc_pos = screenToNDC(screen_center, context);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), ndc_pos.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), ndc_pos.y, 0.01);

    // Test round-trip
    const recovered_screen = ndcToScreen(ndc_pos, context);
    try std.testing.expectApproxEqAbs(screen_center.x, recovered_screen.x, 0.1);
    try std.testing.expectApproxEqAbs(screen_center.y, recovered_screen.y, 0.1);
}