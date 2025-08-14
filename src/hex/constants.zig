const colors = @import("../lib/core/colors.zig");

// Screen/Window dimensions
pub const SCREEN_WIDTH = 1920.0;
pub const SCREEN_HEIGHT = 1080.0;
pub const SCREEN_CENTER_X = SCREEN_WIDTH / 2.0;
pub const SCREEN_CENTER_Y = SCREEN_HEIGHT / 2.0;

// Movement and gameplay constants
pub const PLAYER_SPEED = 600.0;
pub const PLAYER_RADIUS = 20.0;
pub const UNIT_SPEED = 80.0;
pub const UNIT_AGGRO_RANGE = 300.0;
pub const UNIT_WALK_SPEED = UNIT_SPEED * 0.333; // 1/3 speed when returning home
pub const UNIT_HOME_TOLERANCE = 2.0; // Distance tolerance for "at home" check
pub const BULLET_SPEED = 400.0;
pub const BULLET_RADIUS = 5.0;
pub const PORTAL_SPAWN_OFFSET = 10.0; // Extra distance when spawning near portals

// Color constants (imported from shared colors module)
pub const COLOR_PLAYER_ALIVE = colors.PLAYER_ALIVE;
pub const COLOR_UNIT_DEFAULT = colors.UNIT_DEFAULT;
pub const COLOR_UNIT_AGGRO = colors.UNIT_AGGRO;
pub const COLOR_UNIT_NON_AGGRO = colors.UNIT_NON_AGGRO;
pub const COLOR_OBSTACLE_DEADLY = colors.OBSTACLE_DEADLY;
pub const COLOR_OBSTACLE_BLOCKING = colors.OBSTACLE_BLOCKING;
pub const COLOR_BULLET = colors.BULLET;
pub const COLOR_PORTAL = colors.PORTAL;
pub const COLOR_LIFESTONE_ATTUNED = colors.LIFESTONE_ATTUNED;
pub const COLOR_LIFESTONE_UNATTUNED = colors.LIFESTONE_UNATTUNED;
pub const COLOR_DEAD = colors.DEAD;
