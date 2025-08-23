const std = @import("std");

// Core capabilities
const math = @import("../../lib/math/mod.zig");

// Physics capabilities
const collision = @import("../../lib/physics/collision/mod.zig");

// Game system capabilities
const components = @import("../../lib/game/components/mod.zig");

// Hex game modules
const world_state_mod = @import("../world_state.zig");
const physics = @import("../physics.zig");
const portals = @import("../portals.zig");
const constants = @import("../constants.zig");

// Debug capabilities
const loggers = @import("../../lib/debug/loggers.zig");

const Vec2 = math.Vec2;
const HexGame = world_state_mod.HexGame;

/// Collision detection system extracted from game.zig
pub const CollisionSystem = struct {
    /// Main collision checking function - extracted from game.zig checkCollisions()
    pub fn checkAllCollisions(game_state: anytype) void {
        const world = &game_state.hex_game;

        // Bullet-unit collision is handled in world.updateProjectiles()
        if (!world.getPlayerAlive()) return;

        // Debug: Check if portal checking is being called
        game_state.logger.debug("game_loop", "Checking portal collisions in game loop", .{});
        if (portals.checkPortalCollisions(world)) {
            game_state.logger.info("game_portal_activated", "Portal activated, exiting game loop", .{});
            return;
        }

        // Get player position and radius for collision checks
        const player_pos = world.getPlayerPos();
        const player_radius = world.getPlayerRadius();

        // Check player-unit collisions (player dies on contact)
        if (physics.checkPlayerUnitCollision(world)) {
            // Player dies on unit contact
            world.setPlayerAlive(false);
            world.setPlayerColor(constants.COLOR_DEAD);
            return;
        }

        // Check lifestone collisions - delegated to lifestone system
        @import("lifestone.zig").LifestoneSystem.checkLifestoneCollisions(game_state, player_pos, player_radius);

        // Check collision with deadly obstacles
        if (physics.collidesWithDeadlyObstacle(player_pos, player_radius, world)) {
            // Player dies on hazard contact
            world.setPlayerAlive(false);
            world.setPlayerColor(constants.COLOR_DEAD);
        }
    }

    /// Check collision between two circular entities
    pub fn checkCircleCollision(pos1: Vec2, radius1: f32, pos2: Vec2, radius2: f32) bool {
        return collision.checkCircleCollision(pos1, radius1, pos2, radius2);
    }

    /// Check collision between circle and rectangle
    pub fn checkCircleRectCollision(circle_pos: Vec2, circle_radius: f32, rect_pos: Vec2, rect_size: Vec2) bool {
        const circle_shape = collision.Shape{ .circle = .{ .center = circle_pos, .radius = circle_radius } };
        const rect_shape = collision.Shape{ .rectangle = .{ .position = rect_pos, .size = rect_size } };
        return collision.checkCollision(circle_shape, rect_shape);
    }

    /// Get detailed collision information for physics calculations
    pub fn checkCollisionDetailed(shape1: collision.Shape, shape2: collision.Shape) collision.CollisionResult {
        return collision.checkCollisionDetailed(shape1, shape2);
    }
};
