const hex_colors = @import("colors.zig");
const color_mappings = @import("color_mappings.zig");
const constants = @import("../lib/core/constants.zig");

// Game-specific screen utilities derived from engine constants
pub const SCREEN_WIDTH = constants.SCREEN.BASE_WIDTH;
pub const SCREEN_HEIGHT = constants.SCREEN.BASE_HEIGHT;
pub const SCREEN_CENTER_X = constants.SCREEN.centerX(SCREEN_WIDTH);
pub const SCREEN_CENTER_Y = constants.SCREEN.centerY(SCREEN_HEIGHT);
pub const ASPECT_RATIO = constants.SCREEN.ASPECT_RATIO;

// Re-export engine utilities for convenience
pub const scaleFromBase = constants.SCREEN.scaleFromBase;

// Window configuration constants
pub const WINDOW_TITLE = "Hex GPU Game";
pub const WINDOW_WIDTH = @as(u32, @intFromFloat(SCREEN_WIDTH));
pub const WINDOW_HEIGHT = @as(u32, @intFromFloat(SCREEN_HEIGHT));

// Coordinate conversion
pub const PIXELS_TO_METERS = 1.0 / 12.0; // 1 meter ≈ 12 pixels
pub const METERS_TO_PIXELS = 12.0;

// Entity limits (moved from entities.zig)
pub const MAX_UNITS = 12;
pub const MAX_TERRAIN = 50;
pub const MAX_PROJECTILES = 20;
pub const MAX_PORTALS = 6;
pub const MAX_LIFESTONES = 13;

// Movement and gameplay constants (in meters)
pub const PLAYER_SPEED = 50.0; // 50 m/s (was 600 pixels/s ≈ 50 m/s)
// PLAYER_RADIUS removed - defined in ZON data since constants can't be imported
pub const PLAYER_DAMAGE = 25.0; // Damage values stay the same
pub const UNIT_SPEED = 6.7; // 6.7 m/s (was 80 pixels/s ≈ 6.7 m/s)
pub const UNIT_DAMAGE = 10.0; // Damage values stay the same
pub const UNIT_WALK_SPEED = UNIT_SPEED * 0.333; // Walk speed multiplier unchanged
pub const UNIT_HOME_TOLERANCE = 0.17; // 17cm tolerance (was 2 pixels ≈ 17cm)
pub const UNIT_DETECTION_RADIUS = 16.7; // 16.7m detection (was 200 pixels ≈ 16.7m)
pub const UNIT_CHASE_SPEED = UNIT_SPEED; // Same as normal speed
pub const UNIT_CHASE_DURATION = 5.0; // Time values stay the same
pub const PROJECTILE_SPEED = 33.3; // 33.3 m/s (was 400 pixels/s ≈ 33.3 m/s)
pub const PROJECTILE_RADIUS = 0.2; // 20cm radius - visible but not huge (was 5 pixels ≈ 42cm)
pub const PROJECTILE_DAMAGE = 150.0; // Damage values stay the same
pub const PROJECTILE_LIFETIME = 4.0; // Time values stay the same
pub const PORTAL_SPAWN_OFFSET = 0.83; // 83cm offset (was 10 pixels ≈ 83cm)

// Camera viewport constants (in meters)
pub const DEFAULT_VIEWPORT_WIDTH = 16.0; // Default 16m wide viewport
pub const DEFAULT_VIEWPORT_HEIGHT = 9.0; // Default 9m tall viewport (16:9 ratio)
pub const FOLLOW_VIEWPORT_WIDTH = 32.0; // Follow camera wider view
pub const FOLLOW_VIEWPORT_HEIGHT = 18.0; // Follow camera taller view (16:9 ratio)

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

// Energy level for entity color intensity
pub const EnergyLevel = enum {
    lowered, // Low energy - idle, passive, non-threatening
    normal, // Standard energy - default behavior, ready, patrolling
    raised, // High energy - active, excited, aggressive
};

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

// Spell system constants (in meters for distances)
pub const LULL_RADIUS = 12.5; // 12.5m AoE radius (was 150 pixels ≈ 12.5m)
pub const LULL_DURATION = 12.0; // Effect duration in seconds (unchanged)
pub const LULL_AGGRO_MULT = 0.3; // Reduce aggro to 30% (unchanged)
pub const LULL_COOLDOWN = 10.0; // Time values unchanged

pub const BLINK_MAX_DISTANCE = 16.7; // 16.7m teleport (was 200 pixels ≈ 16.7m)
pub const BLINK_COOLDOWN = 3.0; // Time values unchanged

pub const PHASE_DURATION = 5.0; // Phase effect duration in seconds (unchanged)
pub const PHASE_COOLDOWN = 15.0; // Phase spell cooldown (unchanged)

pub const CHARM_DURATION = 8.0; // Control duration in seconds (unchanged)
pub const CHARM_COOLDOWN = 20.0; // Charm spell cooldown (unchanged)
pub const CHARM_RANGE = 8.3; // 8.3m charm range (was 100 pixels ≈ 8.3m)

pub const LETHARGY_DURATION = 6.0; // Speed reduction duration (unchanged)
pub const LETHARGY_COOLDOWN = 12.0; // Lethargy spell cooldown (unchanged)
pub const LETHARGY_SPEED_MULT = 0.4; // Reduce speed to 40% (unchanged)
pub const LETHARGY_RANGE = 12.5; // 12.5m range (was 150 pixels ≈ 12.5m)

pub const HASTE_DURATION = 8.0; // Speed boost duration (unchanged)
pub const HASTE_COOLDOWN = 12.0; // Haste spell cooldown (unchanged)
pub const HASTE_SPEED_MULT = 1.5; // 50% speed increase (unchanged)

pub const MULTISHOT_COOLDOWN = 8.0; // Multishot spell cooldown
pub const MULTISHOT_COUNT = 3; // Number of bullets in spread
pub const MULTISHOT_SPREAD_ANGLE = 0.3; // Radians between bullets

pub const DAZZLE_RADIUS = 10.0; // 10m Dazzle AoE radius (was 120 pixels ≈ 10m)
pub const DAZZLE_DURATION = 5.0; // Dazzle effect duration
pub const DAZZLE_COOLDOWN = 10.0; // Dazzle spell cooldown
pub const DAZZLE_SPEED_MULT = 0.25; // Reduce speed to 25% (confused/dazzled)

pub const MAX_LULL_EFFECTS = 10;

// Border system constants
pub const MAX_BORDER_LAYERS = constants.RENDERING.MAX_BORDER_LAYERS;
pub const COLOR_CYCLE_FREQ = constants.ANIMATION.COLOR_CYCLE_FREQUENCY;

// Behavior configuration constants
pub const BEHAVIOR_IDLE_MIN_DISTANCE = 1.7; // 1.7m idle distance (was 20 pixels ≈ 1.7m)
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

// Terrain type for game data loading
pub const TerrainType = enum {
    rock,
    pit,
};

// Patrol pattern types
pub const PatrolPattern = enum {
    square, // 4-point square pattern
    line, // 2-point back-and-forth
    triangle, // 3-point triangle
    circle, // 4-point circular approximation
};

// Color constants (imported from shared colors module)
pub const COLOR_PLAYER_ALIVE = hex_colors.PLAYER_ALIVE;
pub const COLOR_UNIT_DEFAULT = hex_colors.UNIT_DEFAULT;
pub const COLOR_UNIT_AGGRO = hex_colors.UNIT_AGGRO;
pub const COLOR_UNIT_NON_AGGRO = hex_colors.UNIT_NON_AGGRO;
pub const COLOR_UNIT_AGGRESSIVE = hex_colors.UNIT_AGGRO;
pub const COLOR_UNIT_RETURNING = hex_colors.UNIT_NON_AGGRO;
pub const COLOR_OBSTACLE_DEADLY = hex_colors.OBSTACLE_DEADLY;
pub const COLOR_OBSTACLE_BLOCKING = hex_colors.OBSTACLE_BLOCKING;
pub const COLOR_BULLET = hex_colors.BULLET;
pub const COLOR_PORTAL = hex_colors.PORTAL;
pub const COLOR_LIFESTONE_ATTUNED = hex_colors.LIFESTONE_ATTUNED;
pub const COLOR_LIFESTONE_UNATTUNED = hex_colors.LIFESTONE_UNATTUNED;
pub const COLOR_DEAD = hex_colors.DEAD;
