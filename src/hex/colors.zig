/// Hex game-specific color constants
/// These colors define the visual identity and gameplay semantics for the Hex game
pub const Color = @import("../lib/core/colors.zig").Color;

// Core game entity colors
pub const PLAYER_ALIVE = Color{ .r = 0.0, .g = 0.275, .b = 0.784, .a = 1.0 }; // BLUE
pub const UNIT_DEFAULT = Color{ .r = 0.392, .g = 0.392, .b = 0.392, .a = 1.0 }; // GRAY (default unit color)
pub const UNIT_AGGRO = Color{ .r = 0.784, .g = 0.118, .b = 0.118, .a = 1.0 }; // RED (aggro)
pub const UNIT_NON_AGGRO = Color{ .r = 0.471, .g = 0.235, .b = 0.235, .a = 1.0 }; // DIMMED RED (non-aggro)
pub const OBSTACLE_DEADLY = Color{ .r = 0.784, .g = 0.392, .b = 0.0, .a = 1.0 }; // ORANGE (deadly)
pub const OBSTACLE_BLOCKING = Color{ .r = 0.0, .g = 0.549, .b = 0.0, .a = 1.0 }; // GREEN (blocking)
pub const BULLET = Color{ .r = 0.863, .g = 0.627, .b = 0.0, .a = 1.0 }; // YELLOW
pub const PORTAL = Color{ .r = 0.471, .g = 0.118, .b = 0.627, .a = 1.0 }; // PURPLE
pub const LIFESTONE_ATTUNED = Color{ .r = 0.0, .g = 0.784, .b = 0.784, .a = 1.0 }; // CYAN (attuned)
pub const LIFESTONE_UNATTUNED = Color{ .r = 0.0, .g = 0.392, .b = 0.392, .a = 1.0 }; // CYAN_FADED (unattuned)
pub const DEAD = Color{ .r = 0.392, .g = 0.392, .b = 0.392, .a = 1.0 }; // GRAY

// UI background colors
pub const BACKGROUND_DARK = Color{ .r = 0.118, .g = 0.118, .b = 0.118, .a = 0.706 };
pub const BACKGROUND_LIGHT = Color{ .r = 0.941, .g = 0.941, .b = 0.941, .a = 0.784 };
pub const OVERLAY = Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.502 };

// Border/effect colors
pub const BLUE_BRIGHT = Color{ .r = 0.392, .g = 0.588, .b = 1.0, .a = 1.0 };
pub const GREEN_BRIGHT = Color{ .r = 0.314, .g = 0.863, .b = 0.314, .a = 1.0 };
pub const PURPLE_BRIGHT = Color{ .r = 0.706, .g = 0.392, .b = 0.941, .a = 1.0 };
pub const RED_BRIGHT = Color{ .r = 1.0, .g = 0.392, .b = 0.392, .a = 1.0 };
pub const YELLOW_BRIGHT = Color{ .r = 1.0, .g = 0.863, .b = 0.314, .a = 1.0 };
pub const ORANGE_BRIGHT = Color{ .r = 1.0, .g = 0.706, .b = 0.314, .a = 1.0 };
pub const BROWN = Color{ .r = 0.545, .g = 0.271, .b = 0.075, .a = 1.0 }; // Saddle brown
pub const CYAN = Color{ .r = 0.0, .g = 0.784, .b = 0.784, .a = 1.0 };
