const colors = @import("../lib/core/colors.zig");

// Base screen dimensions - single source of truth for UI coordinate system
pub const BASE_SCREEN_WIDTH = 1920.0;
pub const BASE_SCREEN_HEIGHT = 1080.0;

// Screen/Window dimensions (derived from base)
pub const SCREEN_WIDTH = BASE_SCREEN_WIDTH;
pub const SCREEN_HEIGHT = BASE_SCREEN_HEIGHT;
pub const SCREEN_CENTER_X = SCREEN_WIDTH / 2.0;
pub const SCREEN_CENTER_Y = SCREEN_HEIGHT / 2.0;

// Screen scaling utilities for UI coordinate conversion
pub fn scaleFromBase(coord: f32, is_x: bool, target_width: f32, target_height: f32) f32 {
    if (is_x) {
        return coord * (target_width / BASE_SCREEN_WIDTH);
    } else {
        return coord * (target_height / BASE_SCREEN_HEIGHT);
    }
}

// Entity limits (moved from entities.zig)
pub const MAX_UNITS = 12;
pub const MAX_OBSTACLES = 50;
pub const MAX_BULLETS = 20;
pub const MAX_PORTALS = 6;
pub const MAX_LIFESTONES = 13;

// Movement and gameplay constants
pub const PLAYER_SPEED = 600.0;
pub const PLAYER_RADIUS = 20.0;
pub const UNIT_SPEED = 80.0;
pub const UNIT_AGGRO_RANGE = 300.0;
pub const UNIT_WALK_SPEED = UNIT_SPEED * 0.333; // 1/3 speed when returning home
pub const UNIT_HOME_TOLERANCE = 2.0; // Distance tolerance for "at home" check
pub const UNIT_DETECTION_RADIUS = UNIT_AGGRO_RANGE; // Detection radius for units
pub const UNIT_CHASE_SPEED = UNIT_SPEED; // Speed when chasing player
pub const UNIT_CHASE_DURATION = 5.0; // How long to chase in seconds
pub const BULLET_SPEED = 400.0;
pub const BULLET_RADIUS = 5.0;
pub const BULLET_DAMAGE = 150.0; // One-shot kill damage
pub const BULLET_LIFETIME = 4.0; // Bullet lifetime in seconds
pub const PORTAL_SPAWN_OFFSET = 10.0; // Extra distance when spawning near portals

// Camera/zoom constants
pub const ZOOM_FACTOR = 1.1; // 10% zoom per wheel tick
pub const MAX_ZOOM = 10.0;
pub const MIN_ZOOM = 0.1;

// Border/visual effect constants
pub const BORDER_PULSE_PAUSED = 1.5;
pub const BORDER_PULSE_DEAD = 1.2;
pub const IRIS_WIPE_DURATION = 2.5; // seconds
pub const IRIS_WIPE_BAND_COUNT = 6;
pub const IRIS_WIPE_BAND_WIDTH = 30.0; // pixels

// Camera modes (moved from entities.zig)
pub const CameraMode = enum {
    fixed,
    follow,
};

// UI/HUD positioning constants
pub const FPS_POSITION_X = 100.0; // FPS display left margin
pub const FPS_POSITION_Y = 100.0; // FPS display top margin
pub const FPS_FALLBACK_X = 1840.0; // Fallback geometric FPS position
pub const FPS_FALLBACK_Y = 1060.0; // Fallback geometric FPS position
pub const FPS_DIGIT_SPACING = 12.0; // Spacing between FPS digits
pub const FPS_PIXEL_SIZE = 2.0; // Size of each pixel in geometric FPS
pub const FPS_DIGIT_PIXEL_SIZE = 1.5; // Size of individual digit pixels

// Animation/visual constants
pub const VISIBILITY_THRESHOLD = 0.5; // Minimum width for border visibility
pub const PAUSED_BORDER_BASE_WIDTH = 6.0; // Base width of paused border
pub const PAUSED_BORDER_PULSE_AMPLITUDE = 4.0; // Pulse amplitude for paused border
pub const DEAD_BORDER_BASE_WIDTH = 9.0; // Base width of dead border  
pub const DEAD_BORDER_PULSE_AMPLITUDE = 5.0; // Pulse amplitude for dead border

// Player movement constants
pub const WALK_SPEED_MULTIPLIER = 0.25; // Walking speed is 1/4 of normal
pub const PLAYER_BOUNDARY_MARGIN = 10.0; // Extra margin for boundary checks

// Spell system constants
pub const LULL_RADIUS = 150.0; // Base AoE radius - can be upgraded
pub const LULL_DURATION = 12.0; // Effect duration in seconds
pub const LULL_AGGRO_MULT = 0.3; // Reduce aggro to 30%
pub const LULL_COOLDOWN = 10.0;
pub const BLINK_MAX_DISTANCE = 200.0;
pub const BLINK_COOLDOWN = 3.0;
pub const MAX_LULL_EFFECTS = 10;

// Border system constants
pub const ASPECT_RATIO = 16.0 / 9.0;
pub const MAX_BORDER_LAYERS = 8;
pub const COLOR_CYCLE_FREQ = 4.0;

// Color constants (imported from shared colors module)
pub const COLOR_PLAYER_ALIVE = colors.PLAYER_ALIVE;
pub const COLOR_UNIT_DEFAULT = colors.UNIT_DEFAULT;
pub const COLOR_UNIT_AGGRO = colors.UNIT_AGGRO;
pub const COLOR_UNIT_NON_AGGRO = colors.UNIT_NON_AGGRO;
pub const COLOR_UNIT_AGGRESSIVE = colors.UNIT_AGGRO;
pub const COLOR_UNIT_RETURNING = colors.UNIT_NON_AGGRO;
pub const COLOR_OBSTACLE_DEADLY = colors.OBSTACLE_DEADLY;
pub const COLOR_OBSTACLE_BLOCKING = colors.OBSTACLE_BLOCKING;
pub const COLOR_BULLET = colors.BULLET;
pub const COLOR_PORTAL = colors.PORTAL;
pub const COLOR_LIFESTONE_ATTUNED = colors.LIFESTONE_ATTUNED;
pub const COLOR_LIFESTONE_UNATTUNED = colors.LIFESTONE_UNATTUNED;
pub const COLOR_DEAD = colors.DEAD;
