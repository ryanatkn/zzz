const std = @import("std");
const math = @import("../lib/math/mod.zig");
const constants = @import("constants.zig");
const ecs = @import("../lib/game/ecs.zig");
const hex_game_mod = @import("hex_game.zig");
const behaviors = @import("../lib/game/behaviors/mod.zig");

const Vec2 = math.Vec2;

// Unit update with aggro modifier (using lib utilities)
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
        // Use simple chase behavior from lib
        const min_distance = transform.radius + constants.PLAYER_RADIUS;
        const chase_velocity = behaviors.simpleChase(
            transform.pos,
            player_pos,
            player_alive,
            unit_comp.aggro_range,
            min_distance,
            constants.UNIT_SPEED,
            aggro_multiplier,
        );

        if (chase_velocity.x != 0.0 or chase_velocity.y != 0.0) {
            // Chasing player
            velocity = chase_velocity;
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

// Calculate velocity for unit returning home (using lib utility)
fn calculateReturnHomeVelocity(unit_comp: *const ecs.components.Unit, transform: *const ecs.components.Transform) Vec2 {
    return behaviors.simpleReturnHome(
        transform.pos,
        unit_comp.home_pos,
        constants.UNIT_HOME_TOLERANCE,
        constants.UNIT_WALK_SPEED,
    );
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
    } else {
        // Player is dead - always return home immediately, reset any chase state
        unit_comp.chase_timer = 0;
        unit_comp.state = .returning_home;
        visual.color = constants.COLOR_UNIT_RETURNING;
        velocity = calculateReturnHomeVelocity_HexGame(unit_comp, transform);
    }

    // Apply velocity
    transform.vel = velocity;
    transform.pos = transform.pos.add(velocity.scale(dt));
}

// Calculate velocity for hex_game unit returning home (using lib utility)
fn calculateReturnHomeVelocity_HexGame(unit_comp: *const hex_game_mod.Unit, transform: *const hex_game_mod.Transform) Vec2 {
    return behaviors.simpleReturnHome(
        transform.pos,
        unit_comp.home_pos,
        constants.UNIT_HOME_TOLERANCE,
        constants.UNIT_WALK_SPEED,
    );
}
