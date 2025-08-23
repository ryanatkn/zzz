const std = @import("std");
const math = @import("../../math/mod.zig");
// Note: Camera should not import game-specific constants
// Constants will be passed as parameters instead

const Vec2 = math.Vec2;

// Camera-specific errors
pub const CameraError = error{
    InvalidDimensions,
    NotInitialized,
};

pub const Camera = struct {
    // Screen dimensions (pixels) - for transforms only
    screen_width: f32,
    screen_height: f32,

    // Viewport window (what slice of world we're viewing)
    view_center: Vec2, // Where camera is pointing in world space
    viewport_width: f32, // Width of view window in world units
    viewport_height: f32, // Height of view window in world units

    // Zoom state (applied to viewport dimensions)
    zoom_level: f32, // 1.0 = normal, 2.0 = zoomed in 2x, 0.5 = zoomed out 2x

    // Zoom configuration constants - easily tweakable
    zoom_factor: f32 = 1.4, // How much to zoom per step (1.4x per wheel click)
    max_zoom: f32 = 8.0, // Maximum zoom level
    min_zoom: f32 = 0.05, // Minimum zoom level

    // Initialization state tracking
    initialized: bool,

    const Self = @This();

    pub fn init(screen_w: f32, screen_h: f32) Self {
        return .{
            .screen_width = screen_w,
            .screen_height = screen_h,
            .view_center = Vec2{ .x = 0.0, .y = 0.0 },
            .viewport_width = 16.0, // Default 16x9 meter viewport - games should set via setViewport
            .viewport_height = 9.0, // Will be overridden by game initialization
            .zoom_level = 1.0, // Default zoom
            .initialized = true,
        };
    }

    // Validate camera state
    pub fn validate(self: *const Self) CameraError!void {
        // Check dimensions first as a basic sanity check
        if (self.screen_width <= 0.0 or self.screen_height <= 0.0 or
            self.screen_width > 10000.0 or self.screen_height > 10000.0)
        {
            return CameraError.InvalidDimensions;
        }

        // For backwards compatibility, don't require initialized field for now
        // In the future when all cameras are properly initialized, we can uncomment this:
        // if (!self.initialized) {
        //     return CameraError.NotInitialized;
        // }
    }

    // Pure geometric interface - set viewport directly
    pub fn setViewport(self: *Self, center: Vec2, width: f32, height: f32) void {
        self.view_center = center;
        self.viewport_width = width;
        self.viewport_height = height;
    }

    // Helper: Set viewport to show entire world bounds
    pub fn setViewportToFitWorld(self: *Self, world_width: f32, world_height: f32) void {
        self.view_center = Vec2{ .x = world_width / 2.0, .y = world_height / 2.0 };
        self.viewport_width = world_width;
        self.viewport_height = world_height;
    }

    // Convert world position to screen position
    pub fn worldToScreen(self: *const Self, world_pos: Vec2) Vec2 {
        // Get effective viewport size with zoom applied
        const effective_size = self.getEffectiveViewportSize();

        // Calculate view bounds from center and effective size
        const view_left = self.view_center.x - effective_size.width / 2.0;
        const view_top = self.view_center.y - effective_size.height / 2.0;

        // Normalize to view space [0,1]
        const norm_x = (world_pos.x - view_left) / effective_size.width;
        const norm_y = (world_pos.y - view_top) / effective_size.height;

        // Map to screen pixels
        return Vec2{
            .x = norm_x * self.screen_width,
            .y = norm_y * self.screen_height,
        };
    }

    // Convert world size to screen size (for radii, dimensions)
    pub fn worldSizeToScreen(self: *const Self, world_size: f32) f32 {
        // Use effective viewport size with zoom applied
        const effective_size = self.getEffectiveViewportSize();
        return (world_size / effective_size.width) * self.screen_width;
    }

    // Convert screen position to world position (for mouse input)
    pub fn screenToWorld(self: *const Self, screen_pos: Vec2) CameraError!Vec2 {
        // Validate camera state first
        try self.validate();

        // Get effective viewport size with zoom applied
        const effective_size = self.getEffectiveViewportSize();

        // Calculate view bounds from center and effective size
        const view_left = self.view_center.x - effective_size.width / 2.0;
        const view_top = self.view_center.y - effective_size.height / 2.0;

        // Perform coordinate conversion
        const norm_x = screen_pos.x / self.screen_width;
        const norm_y = screen_pos.y / self.screen_height;

        return Vec2{
            .x = norm_x * effective_size.width + view_left,
            .y = norm_y * effective_size.height + view_top,
        };
    }

    // Fallback version that returns a safe default on error
    pub fn screenToWorldSafe(self: *const Self, screen_pos: Vec2) Vec2 {
        // Extra safety: try to detect completely corrupted pointers
        // by checking if we can even access the struct safely

        // Try to access the fields directly in a way that might catch corruption
        const screen_w = self.screen_width;
        const screen_h = self.screen_height;

        // Basic sanity checks for totally corrupted values
        if (screen_w != screen_w or screen_h != screen_h or // NaN check
            screen_w <= 0.0 or screen_h <= 0.0 or
            screen_w > 50000.0 or screen_h > 50000.0)
        {
            // Return screen coordinates as world coordinates as fallback
            return screen_pos;
        }

        // If basic access works, try the proper validation
        return self.screenToWorld(screen_pos) catch screen_pos;
    }

    // Zoom controls
    pub fn zoomIn(self: *Self) void {
        self.zoom_level = @min(self.max_zoom, self.zoom_level * self.zoom_factor);
    }

    pub fn zoomOut(self: *Self) void {
        self.zoom_level = @max(self.min_zoom, self.zoom_level / self.zoom_factor);
    }

    pub fn getEffectiveViewportSize(self: *const Self) struct { width: f32, height: f32 } {
        // Apply zoom to viewport dimensions - higher zoom = smaller viewport (zoomed in)
        return .{
            .width = self.viewport_width / self.zoom_level,
            .height = self.viewport_height / self.zoom_level,
        };
    }
};
