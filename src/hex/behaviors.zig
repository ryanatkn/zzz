const std = @import("std");
const math = @import("../lib/math/mod.zig");
const constants = @import("constants.zig");
const ecs = @import("../lib/game/ecs.zig");
const hex_game_mod = @import("hex_game.zig");

const Vec2 = math.Vec2;

// Unit update with aggro modifier
pub fn updateUnitWithAggroMod(
    unit_comp: *ecs.components.Unit,
    transform: *ecs.components.Transform,
    visual: *ecs.components.Visual,
    player_pos: Vec2,
    player_alive: bool,
    dt: f32,
    aggro_multiplier: f32,
) void {
    var velocity = Vec2.ZERO;

    if (player_alive) {
        const to_player = player_pos.sub(transform.pos);
        const dist_sq_to_player = to_player.lengthSquared();
        const effective_aggro_range = unit_comp.aggro_range * aggro_multiplier;
        const aggro_range_sq = effective_aggro_range * effective_aggro_range;
        const min_dist_sq = (transform.radius + constants.PLAYER_RADIUS) * (transform.radius + constants.PLAYER_RADIUS);

        if (dist_sq_to_player < aggro_range_sq and dist_sq_to_player > min_dist_sq) {
            // Chase player (aggro state)
            const direction = to_player.normalize();
            velocity = direction.scale(constants.UNIT_SPEED);
            visual.color = constants.COLOR_UNIT_AGGRO;
        } else {
            // Return home (non-aggro state)
            velocity = calculateReturnHomeVelocity(unit_comp, transform);
            visual.color = constants.COLOR_UNIT_NON_AGGRO;
        }
    } else {
        // Player dead - return home (non-aggro state)
        velocity = calculateReturnHomeVelocity(unit_comp, transform);
        visual.color = constants.COLOR_UNIT_NON_AGGRO;
    }

    // Apply velocity
    transform.vel = velocity;
    transform.pos.x += velocity.x * dt;
    transform.pos.y += velocity.y * dt;
}

// Calculate velocity for unit returning home
fn calculateReturnHomeVelocity(unit_comp: *const ecs.components.Unit, transform: *const ecs.components.Transform) Vec2 {
    const to_home = unit_comp.home_pos.sub(transform.pos);
    const dist_sq = to_home.lengthSquared();

    // Use squared distance to avoid sqrt when possible
    if (dist_sq <= constants.UNIT_HOME_TOLERANCE * constants.UNIT_HOME_TOLERANCE) {
        // At home - stop moving
        return Vec2.ZERO;
    }

    // Move towards home
    const direction = to_home.normalize();
    const velocity = direction.scale(constants.UNIT_WALK_SPEED);

    return velocity;
}

// HexGame unit update with aggro modifier  
pub fn updateUnitWithAggroMod_HexGame(
    unit_comp: *hex_game_mod.Unit,
    transform: *hex_game_mod.Transform,
    visual: *hex_game_mod.Visual,
    player_pos: Vec2,
    player_alive: bool,
    dt: f32,
    aggro_multiplier: f32,
) void {
    var velocity = Vec2.ZERO;

    if (player_alive) {
        const to_player = player_pos.sub(transform.pos);
        const dist_sq = to_player.lengthSquared();

        // Apply aggro multiplier to detection range
        const modified_detection_sq = (constants.UNIT_DETECTION_RADIUS * aggro_multiplier) * (constants.UNIT_DETECTION_RADIUS * aggro_multiplier);

        if (dist_sq <= modified_detection_sq) {
            // Player detected - chase
            unit_comp.state = .chasing;
            unit_comp.target_pos = player_pos;
            unit_comp.chase_timer = constants.UNIT_CHASE_DURATION;
            visual.color = constants.COLOR_UNIT_AGGRESSIVE;

            const direction = to_player.normalize();
            velocity = direction.scale(constants.UNIT_CHASE_SPEED);
        } else if (unit_comp.chase_timer > 0) {
            // Continue chasing for duration, but cancel if player gets too far away
            unit_comp.chase_timer -= dt;
            
            // Check if player is now too far away (beyond lose aggro range)
            // Use 15% tolerance buffer to prevent ping-ponging behavior
            const LOSE_AGGRO_TOLERANCE = 1.15;
            const lose_aggro_range_sq = (constants.UNIT_DETECTION_RADIUS * aggro_multiplier * LOSE_AGGRO_TOLERANCE) * (constants.UNIT_DETECTION_RADIUS * aggro_multiplier * LOSE_AGGRO_TOLERANCE);
            if (dist_sq > lose_aggro_range_sq) {
                // Player escaped - stop chasing immediately and return home
                unit_comp.chase_timer = 0;
                unit_comp.state = .returning_home;
                visual.color = constants.COLOR_UNIT_RETURNING;
                velocity = calculateReturnHomeVelocity_HexGame(unit_comp, transform);
            } else {
                // Still within lose range - continue chasing
                visual.color = constants.COLOR_UNIT_AGGRESSIVE;
                const to_target = unit_comp.target_pos.sub(transform.pos);
                const direction = to_target.normalize();
                velocity = direction.scale(constants.UNIT_CHASE_SPEED);

                if (unit_comp.chase_timer <= 0) {
                    unit_comp.state = .returning_home;
                    visual.color = constants.COLOR_UNIT_RETURNING;
                }
            }
        } else {
            // Return home
            unit_comp.state = .returning_home;
            visual.color = constants.COLOR_UNIT_RETURNING;
            velocity = calculateReturnHomeVelocity_HexGame(unit_comp, transform);
        }
    }

    // Apply velocity
    transform.vel = velocity;
    transform.pos = transform.pos.add(velocity.scale(dt));
}

// Calculate velocity for hex_game unit returning home
fn calculateReturnHomeVelocity_HexGame(unit_comp: *const hex_game_mod.Unit, transform: *const hex_game_mod.Transform) Vec2 {
    const to_home = unit_comp.home_pos.sub(transform.pos);
    const dist_sq = to_home.lengthSquared();

    // Use squared distance to avoid sqrt when possible
    if (dist_sq <= constants.UNIT_HOME_TOLERANCE * constants.UNIT_HOME_TOLERANCE) {
        // At home - stop moving
        return Vec2.ZERO;
    }

    // Move towards home
    const direction = to_home.normalize();
    const velocity = direction.scale(constants.UNIT_WALK_SPEED);

    return velocity;
}
