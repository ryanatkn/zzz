const std = @import("std");

const math = @import("../math/mod.zig");
// Note: Camera should not import game-specific constants
// Constants will be passed as parameters instead

const Vec2 = math.Vec2;

// Camera-specific errors
pub const CameraError = error{
    InvalidDimensions,
    NotInitialized,
};

pub const Camera = struct {
    // Screen dimensions (pixels)
    screen_width: f32,
    screen_height: f32,

    // World view bounds
    view_x: f32, // Left edge of view in world space
    view_y: f32, // Top edge of view in world space
    view_width: f32, // Width of view in world units
    view_height: f32, // Height of view in world units

    // Visual scale (zoom level)
    scale: f32,
    
    // Initialization state tracking
    initialized: bool,

    const Self = @This();

    pub fn init(screen_w: f32, screen_h: f32) Self {
        return .{
            .screen_width = screen_w,
            .screen_height = screen_h,
            .view_x = 0.0,
            .view_y = 0.0,
            .view_width = screen_w,
            .view_height = screen_h,
            .scale = 1.0,
            .initialized = true,
        };
    }
    
    // Validate camera state
    pub fn validate(self: *const Self) CameraError!void {
        // Check dimensions first as a basic sanity check
        if (self.screen_width <= 0.0 or self.screen_height <= 0.0 or 
            self.screen_width > 10000.0 or self.screen_height > 10000.0) {
            return CameraError.InvalidDimensions;
        }
        
        // For backwards compatibility, don't require initialized field for now
        // In the future when all cameras are properly initialized, we can uncomment this:
        // if (!self.initialized) {
        //     return CameraError.NotInitialized;
        // }
    }

    // Fixed camera - shows entire world with adjustable zoom
    pub fn setupFixed(self: *Self, scale: f32) void {
        self.scale = scale;
        // View always encompasses entire world
        self.view_x = 0.0;
        self.view_y = 0.0;
        self.view_width = self.screen_width;
        self.view_height = self.screen_height;
    }

    // Follow camera - tracks player position with adjustable zoom
    pub fn setupFollow(self: *Self, player_pos: Vec2, scale: f32) void {
        self.scale = scale;
        // Zoom affects view size (inverse relationship)
        self.view_width = self.screen_width / self.scale;
        self.view_height = self.screen_height / self.scale;
        // Center view on player
        self.view_x = player_pos.x - self.view_width / 2.0;
        self.view_y = player_pos.y - self.view_height / 2.0;
    }

    // Convert world position to screen position
    pub fn worldToScreen(self: *const Self, world_pos: Vec2) Vec2 {
        // Normalize to view space [0,1]
        const norm_x = (world_pos.x - self.view_x) / self.view_width;
        const norm_y = (world_pos.y - self.view_y) / self.view_height;
        // Map to screen pixels
        return Vec2{
            .x = norm_x * self.screen_width,
            .y = norm_y * self.screen_height,
        };
    }

    // Convert world size to screen size (for radii, dimensions)
    pub fn worldSizeToScreen(self: *const Self, world_size: f32) f32 {
        return (world_size / self.view_width) * self.screen_width;
    }

    // Convert screen position to world position (for mouse input)
    pub fn screenToWorld(self: *const Self, screen_pos: Vec2) CameraError!Vec2 {
        // Validate camera state first
        try self.validate();
        
        // Perform coordinate conversion
        const norm_x = screen_pos.x / self.screen_width;
        const norm_y = screen_pos.y / self.screen_height;
        
        return Vec2{
            .x = norm_x * self.view_width + self.view_x,
            .y = norm_y * self.view_height + self.view_y,
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
        if (screen_w != screen_w or screen_h != screen_h or  // NaN check
            screen_w <= 0.0 or screen_h <= 0.0 or
            screen_w > 50000.0 or screen_h > 50000.0) {
            // Return screen coordinates as world coordinates as fallback
            return screen_pos;
        }
        
        // If basic access works, try the proper validation
        return self.screenToWorld(screen_pos) catch screen_pos;
    }
};
