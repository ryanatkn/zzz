const std = @import("std");

const types = @import("../lib/core/types.zig");
const constants = @import("constants.zig");
const ecs = @import("../lib/game/ecs.zig");

const Vec2 = types.Vec2;

// ECS-compatible unit update with aggro modifier
pub fn updateUnitWithAggroModECS(
    unit_comp: *ecs.components.Unit,
    transform: *ecs.components.Transform,
    visual: *ecs.components.Visual,
    player_pos: Vec2,
    player_alive: bool,
    dt: f32,
    aggro_multiplier: f32,
) void {
    var velocity = Vec2{ .x = 0, .y = 0 };

    if (player_alive) {
        const dx_player = player_pos.x - transform.pos.x;
        const dy_player = player_pos.y - transform.pos.y;
        const dist_sq_to_player = dx_player * dx_player + dy_player * dy_player;
        const effective_aggro_range = unit_comp.aggro_range * aggro_multiplier;
        const aggro_range_sq = effective_aggro_range * effective_aggro_range;
        const min_dist_sq = (transform.radius + constants.PLAYER_RADIUS) * (transform.radius + constants.PLAYER_RADIUS);

        if (dist_sq_to_player < aggro_range_sq and dist_sq_to_player > min_dist_sq) {
            // Chase player (aggro state)
            const distance_to_player = @sqrt(dist_sq_to_player);
            velocity.x = (dx_player / distance_to_player) * constants.UNIT_SPEED;
            velocity.y = (dy_player / distance_to_player) * constants.UNIT_SPEED;
            visual.color = constants.COLOR_UNIT_AGGRO;
        } else {
            // Return home (non-aggro state)
            velocity = calculateReturnHomeVelocityECS(unit_comp, transform);
            visual.color = constants.COLOR_UNIT_NON_AGGRO;
        }
    } else {
        // Player dead - return home (non-aggro state)
        velocity = calculateReturnHomeVelocityECS(unit_comp, transform);
        visual.color = constants.COLOR_UNIT_NON_AGGRO;
    }

    // Apply velocity
    transform.vel = velocity;
    transform.pos.x += velocity.x * dt;
    transform.pos.y += velocity.y * dt;
}

// Calculate velocity for ECS unit returning home
fn calculateReturnHomeVelocityECS(unit_comp: *const ecs.components.Unit, transform: *const ecs.components.Transform) Vec2 {
    const dx = unit_comp.home_pos.x - transform.pos.x;
    const dy = unit_comp.home_pos.y - transform.pos.y;
    const dist_sq = dx * dx + dy * dy;

    // Use squared distance to avoid sqrt when possible
    if (dist_sq <= constants.UNIT_HOME_TOLERANCE * constants.UNIT_HOME_TOLERANCE) {
        // At home - stop moving
        return Vec2{ .x = 0, .y = 0 };
    }

    // Move towards home
    const distance = @sqrt(dist_sq);
    const velocity = Vec2{
        .x = (dx / distance) * constants.UNIT_WALK_SPEED,
        .y = (dy / distance) * constants.UNIT_WALK_SPEED,
    };

    return velocity;
}