const colors = @import("../lib/core/colors.zig");
const constants = @import("../lib/core/constants.zig");

// Game-specific screen utilities derived from engine constants
pub const SCREEN_WIDTH = constants.SCREEN.BASE_WIDTH;
pub const SCREEN_HEIGHT = constants.SCREEN.BASE_HEIGHT;
pub const SCREEN_CENTER_X = constants.SCREEN.centerX(SCREEN_WIDTH);
pub const SCREEN_CENTER_Y = constants.SCREEN.centerY(SCREEN_HEIGHT);
pub const ASPECT_RATIO = constants.SCREEN.ASPECT_RATIO;

// Re-export engine utilities for convenience
pub const scaleFromBase = constants.SCREEN.scaleFromBase;

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
pub const UNIT_WALK_SPEED = UNIT_SPEED * 0.333; // TODO should be just a multipler to current speed
pub const UNIT_HOME_TOLERANCE = 2.0; // Distance tolerance for "at home" check
pub const UNIT_DETECTION_RADIUS = 200.0; // Detection radius for units
pub const UNIT_CHASE_SPEED = UNIT_SPEED; // Speed when chasing player
pub const UNIT_CHASE_DURATION = 5.0; // How long to chase in seconds
pub const BULLET_SPEED = 400.0;
pub const BULLET_RADIUS = 5.0;
pub const BULLET_DAMAGE = 150.0; // One-shot kill damage
pub const BULLET_LIFETIME = 4.0; // Bullet lifetime in seconds
pub const PORTAL_SPAWN_OFFSET = 10.0; // Extra distance when spawning near portals

// Camera/zoom constants (game-specific limits)
pub const ZOOM_FACTOR = constants.CAMERA.ZOOM_FACTOR;
pub const MAX_ZOOM = constants.CAMERA.MAX_ZOOM;
pub const MIN_ZOOM = constants.CAMERA.MIN_ZOOM;

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

// UI/HUD positioning constants (bottom right)
pub const FPS_POSITION_X = SCREEN_WIDTH - 200.0; // Right side with margin
pub const FPS_POSITION_Y = SCREEN_HEIGHT - 80.0; // Bottom with margin for FPS + AI text
pub const FPS_FALLBACK_X = constants.UI.FALLBACK_POSITION_X;
pub const FPS_FALLBACK_Y = constants.UI.FALLBACK_POSITION_Y;
pub const FPS_DIGIT_SPACING = constants.UI.DIGIT_SPACING;
pub const FPS_PIXEL_SIZE = 2.0; // Game-specific pixel size for FPS
pub const FPS_DIGIT_PIXEL_SIZE = constants.UI.TEXT_PIXEL_SIZE;

// Animation/visual constants
pub const VISIBILITY_THRESHOLD = constants.RENDERING.VISIBILITY_THRESHOLD;
pub const PAUSED_BORDER_BASE_WIDTH = 6.0; // Base width of paused border
pub const PAUSED_BORDER_PULSE_AMPLITUDE = 4.0; // Pulse amplitude for paused border
pub const DEAD_BORDER_BASE_WIDTH = 9.0; // Base width of dead border
pub const DEAD_BORDER_PULSE_AMPLITUDE = 5.0; // Pulse amplitude for dead border

// Player movement constants
pub const WALK_SPEED_MULTIPLIER = 0.25; // Walking speed is 1/4 of normal
pub const PLAYER_BOUNDARY_MARGIN = constants.CAMERA.BOUNDARY_MARGIN;

// Spell system constants
pub const LULL_RADIUS = 150.0; // Base AoE radius - can be upgraded
pub const LULL_DURATION = 12.0; // Effect duration in seconds
pub const LULL_AGGRO_MULT = 0.3; // Reduce aggro to 30%
pub const LULL_COOLDOWN = 10.0;

pub const BLINK_MAX_DISTANCE = 200.0;
pub const BLINK_COOLDOWN = 3.0;

pub const PHASE_DURATION = 5.0; // Phase effect duration in seconds
pub const PHASE_COOLDOWN = 15.0; // Phase spell cooldown

pub const CHARM_DURATION = 8.0; // Control duration in seconds
pub const CHARM_COOLDOWN = 20.0; // Charm spell cooldown
pub const CHARM_RANGE = 100.0; // Max charm targeting range

pub const LETHARGY_DURATION = 6.0; // Speed reduction duration
pub const LETHARGY_COOLDOWN = 12.0; // Lethargy spell cooldown
pub const LETHARGY_SPEED_MULT = 0.4; // Reduce speed to 40%
pub const LETHARGY_RANGE = 150.0; // Max targeting range

pub const HASTE_DURATION = 8.0; // Speed boost duration
pub const HASTE_COOLDOWN = 12.0; // Haste spell cooldown
pub const HASTE_SPEED_MULT = 1.5; // 50% speed increase

pub const MULTISHOT_COOLDOWN = 8.0; // Multishot spell cooldown
pub const MULTISHOT_COUNT = 3; // Number of bullets in spread
pub const MULTISHOT_SPREAD_ANGLE = 0.3; // Radians between bullets

pub const DAZZLE_RADIUS = 120.0; // Dazzle AoE radius
pub const DAZZLE_DURATION = 5.0; // Dazzle effect duration
pub const DAZZLE_COOLDOWN = 10.0; // Dazzle spell cooldown
pub const DAZZLE_SPEED_MULT = 0.25; // Reduce speed to 25% (confused/dazzled)

pub const MAX_LULL_EFFECTS = 10;

// Border system constants
pub const MAX_BORDER_LAYERS = constants.RENDERING.MAX_BORDER_LAYERS;
pub const COLOR_CYCLE_FREQ = constants.ANIMATION.COLOR_CYCLE_FREQUENCY;

// Behavior configuration constants
pub const BEHAVIOR_IDLE_MIN_DISTANCE = 20.0;
pub const BEHAVIOR_IDLE_WALK_SPEED_MULT = 0.5;
pub const BEHAVIOR_IDLE_CHASE_DURATION = 1.5;
pub const BEHAVIOR_IDLE_HOME_TOLERANCE = 15.0;
pub const BEHAVIOR_IDLE_LOSE_TOLERANCE = 1.05;

pub const BEHAVIOR_DEFENSIVE_SPEED_MULT = 1.2; // Flee faster
pub const BEHAVIOR_WANDERING_DETECTION_MULT = 0.8; // Smaller detection
pub const BEHAVIOR_WANDERING_WALK_SPEED_MULT = 0.7; // Walk slower
pub const BEHAVIOR_WANDERING_CHASE_DURATION = 2.0;
pub const BEHAVIOR_WANDERING_LOSE_TOLERANCE = 1.0; // No lose tolerance

pub const BEHAVIOR_GUARDIAN_DETECTION_MULT = 1.2; // Larger detection
pub const BEHAVIOR_GUARDIAN_MIN_DISTANCE_OFFSET = 15.0; // Extra min distance
pub const BEHAVIOR_GUARDIAN_CHASE_DURATION = 5.0;
pub const BEHAVIOR_GUARDIAN_HOME_TOLERANCE_MULT = 0.5; // Stay closer to home
pub const BEHAVIOR_GUARDIAN_LOSE_TOLERANCE = 1.25;

// Patrol waypoint pattern constants
pub const PATROL_WAYPOINT_OFFSET_X = 100.0;
pub const PATROL_WAYPOINT_OFFSET_Y = 100.0;

// Portal shape types
pub const PortalShape = enum {
    circle,
    square,
    triangle,
};

// Obstacle type for game data loading
pub const ObstacleType = enum {
    blocking,
    deadly,
};

// Patrol pattern types
pub const PatrolPattern = enum {
    square, // 4-point square pattern
    line, // 2-point back-and-forth
    triangle, // 3-point triangle
    circle, // 4-point circular approximation
};

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

// Disposition color mapping - centralized color logic for unit temperament
pub fn getDispositionColor(_: anytype, disposition: anytype) @TypeOf(COLOR_UNIT_AGGRESSIVE) {
    // Primary color is determined by disposition (temperament), not behavior state
    return switch (disposition) {
        .hostile => COLOR_UNIT_AGGRESSIVE, // Always red - aggressive/dangerous
        .fearful => COLOR_OBSTACLE_DEADLY, // Orange - runs away but still dangerous
        .neutral => COLOR_UNIT_NON_AGGRO, // Gray - ignores player
        .friendly => COLOR_PLAYER_ALIVE, // Green/Blue - safe to approach
    };

    // Note: We could add behavior-specific shading in the future:
    // - Slightly brighter when actively chasing/fleeing  
    // - Slightly dimmer when idle
    // - Different shade when returning home
    // But for now, consistent disposition-based colors provide clear visual feedback
}
