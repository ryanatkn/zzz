/// Coordinate system utilities for spatial transformations and viewport management
/// Provides reusable coordinate conversion, scaling, and spatial query functionality
const std = @import("std");
const constants = @import("constants.zig");
const math = @import("../math/mod.zig");

// Use standard Vec2 from math module
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

    pub fn withUIScale(self: CoordinateContext, scale: f32) CoordinateContext {
        var result = self;
        result.ui_scale = scale;
        return result;
    }
};

// ========================
// COORDINATE TRANSFORMATIONS
// ========================

/// Convert world coordinates to screen coordinates
pub fn worldToScreen(world_pos: Vec2, context: CoordinateContext) Vec2 {
    // Apply camera transformation
    const camera_relative = Vec2{
        .x = world_pos.x - context.camera_position.x,
        .y = world_pos.y - context.camera_position.y,
    };

    // Apply zoom and center on screen
    return Vec2{
        .x = (camera_relative.x * context.camera_zoom) + (context.screen_width / 2.0),
        .y = (camera_relative.y * context.camera_zoom) + (context.screen_height / 2.0),
    };
}

/// Convert screen coordinates to world coordinates
pub fn screenToWorld(screen_pos: Vec2, context: CoordinateContext) Vec2 {
    // Convert from screen center and apply inverse zoom
    const centered = Vec2{
        .x = screen_pos.x - (context.screen_width / 2.0),
        .y = screen_pos.y - (context.screen_height / 2.0),
    };

    const world_relative = Vec2{
        .x = centered.x / context.camera_zoom,
        .y = centered.y / context.camera_zoom,
    };

    // Add camera position
    return Vec2{
        .x = world_relative.x + context.camera_position.x,
        .y = world_relative.y + context.camera_position.y,
    };
}

/// Convert screen coordinates to normalized device coordinates [-1, 1]
pub fn screenToNDC(screen_pos: Vec2, context: CoordinateContext) Vec2 {
    return Vec2{
        .x = (2.0 * screen_pos.x / context.screen_width) - 1.0,
        .y = 1.0 - (2.0 * screen_pos.y / context.screen_height), // Flip Y for typical NDC
    };
}

/// Convert normalized device coordinates to screen coordinates
pub fn ndcToScreen(ndc_pos: Vec2, context: CoordinateContext) Vec2 {
    return Vec2{
        .x = (ndc_pos.x + 1.0) * context.screen_width / 2.0,
        .y = (1.0 - ndc_pos.y) * context.screen_height / 2.0,
    };
}

/// Convert UI coordinates to screen coordinates with scaling
pub fn uiToScreen(ui_pos: Vec2, context: CoordinateContext) Vec2 {
    return Vec2{
        .x = ui_pos.x * context.ui_scale,
        .y = ui_pos.y * context.ui_scale,
    };
}

/// Convert screen coordinates to UI coordinates with scaling
pub fn screenToUI(screen_pos: Vec2, context: CoordinateContext) Vec2 {
    return Vec2{
        .x = screen_pos.x / context.ui_scale,
        .y = screen_pos.y / context.ui_scale,
    };
}

// ========================
// RESPONSIVE SCALING
// ========================

/// Scale coordinates from a base resolution to target resolution
pub fn scaleFromBaseResolution(pos: Vec2, base_width: f32, base_height: f32, target_width: f32, target_height: f32) Vec2 {
    return Vec2{
        .x = pos.x * (target_width / base_width),
        .y = pos.y * (target_height / base_height),
    };
}

/// Scale coordinates from base 1920x1080 to current screen size
pub fn scaleFrom1080p(pos: Vec2, context: CoordinateContext) Vec2 {
    return scaleFromBaseResolution(
        pos,
        constants.SCREEN.BASE_WIDTH,
        constants.SCREEN.BASE_HEIGHT,
        context.screen_width,
        context.screen_height,
    );
}

/// Get aspect ratio adjusted coordinates maintaining proportion
pub fn aspectRatioAdjusted(pos: Vec2, context: CoordinateContext) Vec2 {
    const target_aspect = context.screen_width / context.screen_height;
    const base_aspect = constants.SCREEN.ASPECT_RATIO;

    if (target_aspect > base_aspect) {
        // Screen is wider - scale by height and center horizontally
        const scale = context.screen_height / constants.SCREEN.BASE_HEIGHT;
        const scaled_width = constants.SCREEN.BASE_WIDTH * scale;
        const x_offset = (context.screen_width - scaled_width) / 2.0;

        return Vec2{
            .x = pos.x * scale + x_offset,
            .y = pos.y * scale,
        };
    } else {
        // Screen is taller - scale by width and center vertically
        const scale = context.screen_width / constants.SCREEN.BASE_WIDTH;
        const scaled_height = constants.SCREEN.BASE_HEIGHT * scale;
        const y_offset = (context.screen_height - scaled_height) / 2.0;

        return Vec2{
            .x = pos.x * scale,
            .y = pos.y * scale + y_offset,
        };
    }
}

// ========================
// VIEWPORT UTILITIES
// ========================

/// Viewport bounds in world coordinates
pub const Viewport = struct {
    min: Vec2,
    max: Vec2,

    pub fn init(center_pos: Vec2, width: f32, height: f32) Viewport {
        const half_width = width / 2.0;
        const half_height = height / 2.0;

        return .{
            .min = Vec2{ .x = center_pos.x - half_width, .y = center_pos.y - half_height },
            .max = Vec2{ .x = center_pos.x + half_width, .y = center_pos.y + half_height },
        };
    }

    pub fn fromContext(context: CoordinateContext) Viewport {
        const world_width = context.screen_width / context.camera_zoom;
        const world_height = context.screen_height / context.camera_zoom;

        return init(context.camera_position, world_width, world_height);
    }

    pub fn contains(self: Viewport, point: Vec2) bool {
        return point.x >= self.min.x and point.x <= self.max.x and
            point.y >= self.min.y and point.y <= self.max.y;
    }

    pub fn intersects(self: Viewport, other: Viewport) bool {
        return !(self.max.x < other.min.x or self.min.x > other.max.x or
            self.max.y < other.min.y or self.min.y > other.max.y);
    }

    pub fn center(self: Viewport) Vec2 {
        return Vec2{
            .x = (self.min.x + self.max.x) / 2.0,
            .y = (self.min.y + self.max.y) / 2.0,
        };
    }

    pub fn size(self: Viewport) Vec2 {
        return Vec2{
            .x = self.max.x - self.min.x,
            .y = self.max.y - self.min.y,
        };
    }

    pub fn expanded(self: Viewport, margin: f32) Viewport {
        return .{
            .min = Vec2{ .x = self.min.x - margin, .y = self.min.y - margin },
            .max = Vec2{ .x = self.max.x + margin, .y = self.max.y + margin },
        };
    }
};

// ========================
// SPATIAL QUERIES
// ========================

/// Check if a point is visible in the current viewport
pub fn isPointVisible(point: Vec2, context: CoordinateContext) bool {
    const viewport = Viewport.fromContext(context);
    return viewport.contains(point);
}

/// Check if a circle is visible in the current viewport
pub fn isCircleVisible(center: Vec2, radius: f32, context: CoordinateContext) bool {
    const viewport = Viewport.fromContext(context).expanded(radius);
    return viewport.contains(center);
}

/// Check if a rectangle is visible in the current viewport
pub fn isRectVisible(pos: Vec2, size: Vec2, context: CoordinateContext) bool {
    const viewport = Viewport.fromContext(context);
    const rect_viewport = Viewport.init(
        Vec2{ .x = pos.x + size.x / 2.0, .y = pos.y + size.y / 2.0 },
        size.x,
        size.y,
    );
    return viewport.intersects(rect_viewport);
}

/// Get all positions within a radius of a center point
pub const PositionsInRadius = struct {
    positions: std.ArrayList(Vec2),

    pub fn init(allocator: std.mem.Allocator) PositionsInRadius {
        return .{
            .positions = std.ArrayList(Vec2).init(allocator),
        };
    }

    pub fn deinit(self: *PositionsInRadius) void {
        self.positions.deinit();
    }

    pub fn findInRadius(self: *PositionsInRadius, candidates: []const Vec2, center: Vec2, radius: f32) !void {
        self.positions.clearRetainingCapacity();
        const radius_squared = radius * radius;

        for (candidates) |pos| {
            const diff = Vec2{ .x = pos.x - center.x, .y = pos.y - center.y };
            const distance_squared = diff.x * diff.x + diff.y * diff.y;
            if (distance_squared <= radius_squared) {
                try self.positions.append(pos);
            }
        }
    }
};

// ========================
// GRID UTILITIES
// ========================

/// Grid-based coordinate system for spatial partitioning
pub const GridCoordinates = struct {
    cell_size: f32,

    pub fn init(cell_size: f32) GridCoordinates {
        return .{ .cell_size = cell_size };
    }

    /// Convert world position to grid cell coordinates
    pub fn worldToGrid(self: GridCoordinates, world_pos: Vec2) Vec2 {
        return Vec2{
            .x = @floor(world_pos.x / self.cell_size),
            .y = @floor(world_pos.y / self.cell_size),
        };
    }

    /// Convert grid cell coordinates to world position (cell center)
    pub fn gridToWorld(self: GridCoordinates, grid_pos: Vec2) Vec2 {
        return Vec2{
            .x = grid_pos.x * self.cell_size + self.cell_size / 2.0,
            .y = grid_pos.y * self.cell_size + self.cell_size / 2.0,
        };
    }

    /// Get all grid cells that intersect with a circle
    pub fn getCellsInRadius(self: GridCoordinates, center: Vec2, radius: f32, allocator: std.mem.Allocator) !std.ArrayList(Vec2) {
        var cells = std.ArrayList(Vec2).init(allocator);

        const center_cell = self.worldToGrid(center);
        const cell_radius = @ceil(radius / self.cell_size);

        var y: f32 = center_cell.y - cell_radius;
        while (y <= center_cell.y + cell_radius) : (y += 1) {
            var x: f32 = center_cell.x - cell_radius;
            while (x <= center_cell.x + cell_radius) : (x += 1) {
                const cell_world_pos = self.gridToWorld(Vec2{ .x = x, .y = y });
                const diff = cell_world_pos.sub(center);
                const distance = diff.length();

                if (distance <= radius + self.cell_size * std.math.sqrt2) {
                    try cells.append(Vec2{ .x = x, .y = y });
                }
            }
        }

        return cells;
    }
};

// ========================
// UTILITY FUNCTIONS
// ========================

/// Clamp coordinates to stay within bounds
pub fn clampToBounds(pos: Vec2, min_bounds: Vec2, max_bounds: Vec2) Vec2 {
    return Vec2{
        .x = std.math.clamp(pos.x, min_bounds.x, max_bounds.x),
        .y = std.math.clamp(pos.y, min_bounds.y, max_bounds.y),
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

/// Get the closest point on a boundary to a given position
pub fn closestPointOnBounds(pos: Vec2, min_bounds: Vec2, max_bounds: Vec2) Vec2 {
    return clampToBounds(pos, min_bounds, max_bounds);
}

/// Linear interpolation between two coordinates
pub fn lerp(a: Vec2, b: Vec2, t: f32) Vec2 {
    const clamped_t = std.math.clamp(t, 0.0, 1.0);
    return Vec2{
        .x = a.x + (b.x - a.x) * clamped_t,
        .y = a.y + (b.y - a.y) * clamped_t,
    };
}

/// Get normalized direction vector between two points
pub fn directionBetween(from: Vec2, to: Vec2) Vec2 {
    const diff = to.sub(from);
    const length = diff.length();

    if (length < constants.PHYSICS.COLLISION_EPSILON) {
        return Vec2{ .x = 0, .y = 0 };
    }

    return Vec2{ .x = diff.x / length, .y = diff.y / length };
}

// ========================
// TESTS
// ========================

test "coordinate transformations" {
    const context = CoordinateContext.init(1920, 1080).withCamera(Vec2{ .x = 100, .y = 50 }, 2.0);

    // Test world to screen
    const world_pos = Vec2{ .x = 150, .y = 100 };
    const screen_pos = worldToScreen(world_pos, context);

    // Should be offset by camera and scaled by zoom, then centered
    try std.testing.expectApproxEqAbs(@as(f32, 1060.0), screen_pos.x, 0.1); // (150-100)*2 + 960
    try std.testing.expectApproxEqAbs(@as(f32, 640.0), screen_pos.y, 0.1); // (100-50)*2 + 540

    // Test round trip
    const back_to_world = screenToWorld(screen_pos, context);
    try std.testing.expectApproxEqAbs(world_pos.x, back_to_world.x, 0.1);
    try std.testing.expectApproxEqAbs(world_pos.y, back_to_world.y, 0.1);
}

test "viewport utilities" {
    const context = CoordinateContext.init(800, 600).withCamera(Vec2{ .x = 0, .y = 0 }, 1.0);
    const viewport = Viewport.fromContext(context);

    // Should be centered at camera position with screen dimensions
    try std.testing.expectApproxEqAbs(@as(f32, -400.0), viewport.min.x, 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, -300.0), viewport.min.y, 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 400.0), viewport.max.x, 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 300.0), viewport.max.y, 0.1);

    // Test contains
    try std.testing.expect(viewport.contains(Vec2{ .x = 0, .y = 0 }));
    try std.testing.expect(!viewport.contains(Vec2{ .x = 500, .y = 0 }));
}

test "grid coordinates" {
    const grid = GridCoordinates.init(32.0);

    // Test world to grid conversion
    const world_pos = Vec2{ .x = 100, .y = 150 };
    const grid_pos = grid.worldToGrid(world_pos);

    try std.testing.expectApproxEqAbs(@as(f32, 3.0), grid_pos.x, 0.1); // floor(100/32)
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), grid_pos.y, 0.1); // floor(150/32)

    // Test grid to world conversion (should give cell center)
    const back_to_world = grid.gridToWorld(grid_pos);
    try std.testing.expectApproxEqAbs(@as(f32, 112.0), back_to_world.x, 0.1); // 3*32 + 16
    try std.testing.expectApproxEqAbs(@as(f32, 144.0), back_to_world.y, 0.1); // 4*32 + 16
}

test "utility functions" {
    // Test clamping
    const pos = Vec2{ .x = -10, .y = 110 };
    const clamped = clampToBounds(pos, Vec2{ .x = 0, .y = 0 }, Vec2{ .x = 100, .y = 100 });

    try std.testing.expectApproxEqAbs(@as(f32, 0.0), clamped.x, 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), clamped.y, 0.1);

    // Test lerp
    const a = Vec2{ .x = 0, .y = 0 };
    const b = Vec2{ .x = 100, .y = 200 };
    const mid = lerp(a, b, 0.5);

    try std.testing.expectApproxEqAbs(@as(f32, 50.0), mid.x, 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), mid.y, 0.1);
}
