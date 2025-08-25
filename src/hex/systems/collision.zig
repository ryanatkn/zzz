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

        // Projectile-unit collision is handled in world.updateProjectiles()
        // Check if controlled entity is alive before processing collisions
        const controlled_entity_alive = if (world.getControlledEntity()) |controlled_entity| blk: {
            const zone = world.getCurrentZoneConst();
            if (zone.units.getComponent(controlled_entity, .health)) |health| {
                break :blk health.alive;
            }
            break :blk false;
        } else false;

        if (!controlled_entity_alive) return;

        // Debug: Check if portal checking is being called
        game_state.logger.debug("game_loop", "Checking portal collisions in game loop", .{});
        if (portals.checkPortalCollisions(world)) {
            game_state.logger.info("game_portal_activated", "Portal activated, exiting game loop", .{});
            return;
        }

        // Check hostile unit collisions - kill player if hostile touches them
        if (physics.checkControlledEntityUnitCollision(world)) {
            if (world.getControlledEntity()) |controlled_entity| {
                const zone = world.getCurrentZone();
                if (zone.units.getComponentMut(controlled_entity, .health)) |health| {
                    health.alive = false;
                    game_state.logger.info("player_death", "Player killed by hostile collision", .{});

                    // Set visual to dead color
                    if (zone.units.getComponentMut(controlled_entity, .visual)) |visual| {
                        visual.color = constants.COLOR_DEAD;
                    }
                }
            }
            return; // Exit collision checking once player dies
        }

        // Check hostile-friendly unit collisions - kill hostiles when they touch friendlies
        _ = physics.checkHostileFriendlyUnitCollision(world);

        // Check lifestone collisions - delegated to lifestone system (uses controlled entity internally)
        @import("lifestone.zig").LifestoneSystem.checkLifestoneCollisions(game_state);
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
