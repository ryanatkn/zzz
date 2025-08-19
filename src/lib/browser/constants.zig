/// Shared constants for HUD and menu pages
/// Re-exports hex constants to avoid module scope issues

// Import hex game constants which re-export engine constants
const hex_constants = @import("../../hex/constants.zig");

// Re-export all hex constants for menu pages
pub const SCREEN_WIDTH = hex_constants.SCREEN_WIDTH;
pub const SCREEN_HEIGHT = hex_constants.SCREEN_HEIGHT;
pub const SCREEN_CENTER_X = hex_constants.SCREEN_CENTER_X;
pub const SCREEN_CENTER_Y = hex_constants.SCREEN_CENTER_Y;
pub const ASPECT_RATIO = hex_constants.ASPECT_RATIO;

// Re-export SCREEN namespace for consistency with engine constants
pub const SCREEN = struct {
    pub const BASE_WIDTH = hex_constants.SCREEN_WIDTH;
    pub const BASE_HEIGHT = hex_constants.SCREEN_HEIGHT;
    pub const centerX = hex_constants.constants.SCREEN.centerX;
    pub const centerY = hex_constants.constants.SCREEN.centerY;
};
