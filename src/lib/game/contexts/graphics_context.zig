/// Graphics context for rendering operations
const std = @import("std");
const UpdateContext = @import("update_context.zig").UpdateContext;
const camera_mod = @import("../../rendering/camera.zig");
const math = @import("../../math/mod.zig");

const Vec2 = math.Vec2;

/// Graphics context for rendering operations
pub const GraphicsContext = struct {
    base: UpdateContext,

    // Screen dimensions
    screen_width: f32,
    screen_height: f32,

    // Camera state
    camera_position: Vec2,
    camera_zoom: f32,

    // Viewport info (calculated from camera and screen)
    viewport_bounds: struct {
        min_x: f32,
        min_y: f32,
        max_x: f32,
        max_y: f32,
    },

    // Optional integration with engine camera
    engine_camera: ?*const camera_mod.Camera,

    pub fn init(base_context: UpdateContext, screen_width: f32, screen_height: f32) GraphicsContext {
        return .{
            .base = base_context,
            .screen_width = screen_width,
            .screen_height = screen_height,
            .camera_position = Vec2.ZERO,
            .camera_zoom = 1.0,
            .viewport_bounds = .{
                .min_x = -screen_width / 2.0,
                .min_y = -screen_height / 2.0,
                .max_x = screen_width / 2.0,
                .max_y = screen_height / 2.0,
            },
            .engine_camera = null,
        };
    }

    pub fn withCamera(self: GraphicsContext, position: Vec2, zoom: f32) GraphicsContext {
        var result = self;
        result.camera_position = position;
        result.camera_zoom = zoom;

        // Update viewport bounds based on camera
        const world_width = result.screen_width / zoom;
        const world_height = result.screen_height / zoom;
        result.viewport_bounds = .{
            .min_x = position.x - world_width / 2.0,
            .min_y = position.y - world_height / 2.0,
            .max_x = position.x + world_width / 2.0,
            .max_y = position.y + world_height / 2.0,
        };

        return result;
    }

    pub fn withEngineCamera(self: GraphicsContext, camera: *const camera_mod.Camera) GraphicsContext {
        var result = self;
        result.engine_camera = camera;
        
        // Update from camera if available
        result.screen_width = camera.screen_width;
        result.screen_height = camera.screen_height;
        
        // Calculate camera center position from view bounds
        const center_x = camera.view_x + camera.view_width / 2.0;
        const center_y = camera.view_y + camera.view_height / 2.0;
        result.camera_position = Vec2.init(center_x, center_y);
        result.camera_zoom = camera.scale;

        // Update viewport bounds
        result.viewport_bounds = .{
            .min_x = camera.view_x,
            .min_y = camera.view_y,
            .max_x = camera.view_x + camera.view_width,
            .max_y = camera.view_y + camera.view_height,
        };

        return result;
    }

    /// Check if a point is visible in the current viewport
    pub fn isPointVisible(self: GraphicsContext, point: Vec2) bool {
        return point.x >= self.viewport_bounds.min_x and point.x <= self.viewport_bounds.max_x and
            point.y >= self.viewport_bounds.min_y and point.y <= self.viewport_bounds.max_y;
    }

    /// Check if a circle is visible in the current viewport
    pub fn isCircleVisible(self: GraphicsContext, center: Vec2, radius: f32) bool {
        return center.x + radius >= self.viewport_bounds.min_x and center.x - radius <= self.viewport_bounds.max_x and
            center.y + radius >= self.viewport_bounds.min_y and center.y - radius <= self.viewport_bounds.max_y;
    }

    /// Get viewport bounds as a rectangle for easy collision testing
    pub fn getViewportRect(self: GraphicsContext) struct { x: f32, y: f32, width: f32, height: f32 } {
        return .{
            .x = self.viewport_bounds.min_x,
            .y = self.viewport_bounds.min_y,
            .width = self.viewport_bounds.max_x - self.viewport_bounds.min_x,
            .height = self.viewport_bounds.max_y - self.viewport_bounds.min_y,
        };
    }

    /// Convert screen coordinates to world coordinates
    pub fn screenToWorld(self: GraphicsContext, screen_pos: Vec2) Vec2 {
        if (self.engine_camera) |camera| {
            // Use engine camera's conversion if available
            const viewport = camera.getViewport();
            return viewport.screenToWorld(screen_pos);
        }

        // Fallback calculation
        const world_width = self.screen_width / self.camera_zoom;
        const world_height = self.screen_height / self.camera_zoom;
        
        const normalized_x = (screen_pos.x / self.screen_width) - 0.5;
        const normalized_y = (screen_pos.y / self.screen_height) - 0.5;
        
        return Vec2.init(
            self.camera_position.x + normalized_x * world_width,
            self.camera_position.y + normalized_y * world_height,
        );
    }
};