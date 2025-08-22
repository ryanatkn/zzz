/// Hex game-specific color constants
/// These colors define the visual identity and gameplay semantics for the Hex game
pub const Color = @import("../lib/core/colors.zig").Color;

// Core game entity colors
pub const PLAYER_ALIVE = Color{ .r = 0, .g = 70, .b = 200, .a = 255 }; // BLUE
pub const UNIT_DEFAULT = Color{ .r = 100, .g = 100, .b = 100, .a = 255 }; // GRAY (default unit color)
pub const UNIT_AGGRO = Color{ .r = 200, .g = 30, .b = 30, .a = 255 }; // RED (aggro)
pub const UNIT_NON_AGGRO = Color{ .r = 120, .g = 60, .b = 60, .a = 255 }; // DIMMED RED (non-aggro)
pub const OBSTACLE_DEADLY = Color{ .r = 200, .g = 100, .b = 0, .a = 255 }; // ORANGE (deadly)
pub const OBSTACLE_BLOCKING = Color{ .r = 0, .g = 140, .b = 0, .a = 255 }; // GREEN (blocking)
pub const BULLET = Color{ .r = 220, .g = 160, .b = 0, .a = 255 }; // YELLOW
pub const PORTAL = Color{ .r = 120, .g = 30, .b = 160, .a = 255 }; // PURPLE
pub const LIFESTONE_ATTUNED = Color{ .r = 0, .g = 200, .b = 200, .a = 255 }; // CYAN (attuned)
pub const LIFESTONE_UNATTUNED = Color{ .r = 0, .g = 100, .b = 100, .a = 255 }; // CYAN_FADED (unattuned)
pub const DEAD = Color{ .r = 100, .g = 100, .b = 100, .a = 255 }; // GRAY

// UI background colors
pub const BACKGROUND_DARK = Color{ .r = 30, .g = 30, .b = 30, .a = 180 };
pub const BACKGROUND_LIGHT = Color{ .r = 240, .g = 240, .b = 240, .a = 200 };
pub const OVERLAY = Color{ .r = 0, .g = 0, .b = 0, .a = 128 };

// Border/effect colors
pub const BLUE_BRIGHT = Color{ .r = 100, .g = 150, .b = 255, .a = 255 };
pub const GREEN_BRIGHT = Color{ .r = 80, .g = 220, .b = 80, .a = 255 };
pub const PURPLE_BRIGHT = Color{ .r = 180, .g = 100, .b = 240, .a = 255 };
pub const RED_BRIGHT = Color{ .r = 255, .g = 100, .b = 100, .a = 255 };
pub const YELLOW_BRIGHT = Color{ .r = 255, .g = 220, .b = 80, .a = 255 };
pub const ORANGE_BRIGHT = Color{ .r = 255, .g = 180, .b = 80, .a = 255 };
pub const BROWN = Color{ .r = 139, .g = 69, .b = 19, .a = 255 }; // Saddle brown
pub const CYAN = Color{ .r = 0, .g = 200, .b = 200, .a = 255 };
