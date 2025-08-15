const std = @import("std");

const types = @import("../lib/core/types.zig");
const constants = @import("constants.zig");

const Vec2 = types.Vec2;
const Color = types.Color;

// Game constants
pub const MAX_UNITS = 12;
pub const MAX_OBSTACLES = 50;
pub const MAX_BULLETS = 20;
pub const MAX_PORTALS = 6;
pub const MAX_LIFESTONES = 13;

// Unit entity (enemies, neutrals, allies)
pub const Unit = struct {
    pos: Vec2,
    vel: Vec2,
    home_pos: Vec2, // Original spawn position for return behavior
    radius: f32,
    color: Color,
    alive: bool,
    active: bool,
    aggro_range: f32, // Base aggro detection range

    pub fn init(x: f32, y: f32, radius: f32) Unit {
        return .{
            .pos = Vec2{ .x = x, .y = y },
            .vel = Vec2{ .x = 0, .y = 0 },
            .home_pos = Vec2{ .x = x, .y = y },
            .radius = radius,
            .color = constants.COLOR_UNIT_DEFAULT,
            .alive = true,
            .active = true,
            .aggro_range = 200.0, // Default aggro range
        };
    }
};

// Obstacle entity (rectangles)
pub const Obstacle = struct {
    pos: Vec2,
    size: Vec2,
    color: Color,
    is_deadly: bool,
    active: bool,

    pub fn init(x: f32, y: f32, width: f32, height: f32, is_deadly: bool) Obstacle {
        return .{
            .pos = Vec2{ .x = x, .y = y },
            .size = Vec2{ .x = width, .y = height },
            .color = if (is_deadly)
                constants.COLOR_OBSTACLE_DEADLY
            else
                constants.COLOR_OBSTACLE_BLOCKING,
            .is_deadly = is_deadly,
            .active = true,
        };
    }
};

// Bullet entity
pub const Bullet = struct {
    pos: Vec2,
    vel: Vec2,
    radius: f32,
    color: Color,
    active: bool,
    lifetime: f32, // Time remaining before bullet expires
    max_lifetime: f32, // Maximum lifetime (can be upgraded)

    pub fn init() Bullet {
        return .{
            .pos = Vec2{ .x = 0, .y = 0 },
            .vel = Vec2{ .x = 0, .y = 0 },
            .radius = constants.BULLET_RADIUS,
            .color = constants.COLOR_BULLET,
            .active = false,
            .lifetime = 0,
            .max_lifetime = 4.0, // 4 seconds base duration - future: upgrade this stat
        };
    }
};

// Portal entity - gateway to travel between zones
pub const Portal = struct {
    pos: Vec2,
    radius: f32,
    color: Color,
    destination_zone: u8,
    active: bool,

    pub fn init(x: f32, y: f32, radius: f32, destination: u8) Portal {
        return .{
            .pos = Vec2{ .x = x, .y = y },
            .radius = radius,
            .color = constants.COLOR_PORTAL,
            .destination_zone = destination,
            .active = true,
        };
    }
};

// Lifestone entity
pub const Lifestone = struct {
    pos: Vec2,
    radius: f32,
    color: Color,
    attuned: bool,
    active: bool,

    pub fn init(x: f32, y: f32, radius: f32, pre_attuned: bool) Lifestone {
        return .{
            .pos = Vec2{ .x = x, .y = y },
            .radius = radius,
            .color = if (pre_attuned)
                constants.COLOR_LIFESTONE_ATTUNED
            else
                constants.COLOR_LIFESTONE_UNATTUNED,
            .attuned = pre_attuned,
            .active = true,
        };
    }
};

// Camera modes
pub const CameraMode = enum {
    fixed,
    follow,
};

// Zone - a distinct area of the game world with environmental properties only
// All entities are now stored in the ECS system instead of here
pub const Zone = struct {
    // Environmental properties
    name: []const u8,
    background_color: Color,
    camera_mode: CameraMode,
    camera_scale: f32, // Zoom level for this zone (1.0 = default, <1.0 = zoomed out, >1.0 = zoomed in)

    pub fn init(name: []const u8, bg_color: Color, cam_mode: CameraMode, scale: f32) Zone {
        return .{
            .name = name,
            .background_color = bg_color,
            .camera_mode = cam_mode,
            .camera_scale = scale,
        };
    }

    // All entity management methods have been removed
    // Entities are now managed through the ECS system
};

