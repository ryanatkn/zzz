const std = @import("std");

const entities = @import("entities.zig");
const types = @import("../lib/core/types.zig");
const constants = @import("constants.zig");
const ecs = @import("../lib/game/ecs.zig");

const Vec2 = types.Vec2;
const Unit = entities.Unit;
const Bullet = entities.Bullet;
const HexWorld = @import("hex_world.zig").HexWorld;


// Update unit - chase player or return home
pub fn updateUnit(unit: *Unit, player_pos: Vec2, player_alive: bool, dt: f32) void {
    updateUnitWithAggroMod(unit, player_pos, player_alive, dt, 1.0);
}

// Update unit with aggro modifier (for spell effects)
pub fn updateUnitWithAggroMod(unit: *Unit, player_pos: Vec2, player_alive: bool, dt: f32, aggro_multiplier: f32) void {
    var velocity = Vec2{ .x = 0, .y = 0 };

    if (player_alive) {
        const dx_player = player_pos.x - unit.pos.x;
        const dy_player = player_pos.y - unit.pos.y;
        const dist_sq_to_player = dx_player * dx_player + dy_player * dy_player;
        const effective_aggro_range = unit.aggro_range * aggro_multiplier;
        const aggro_range_sq = effective_aggro_range * effective_aggro_range;
        const min_dist_sq = (unit.radius + constants.PLAYER_RADIUS) * (unit.radius + constants.PLAYER_RADIUS);

        if (dist_sq_to_player < aggro_range_sq and dist_sq_to_player > min_dist_sq) {
            // Chase player (aggro state)
            const distance_to_player = @sqrt(dist_sq_to_player);
            velocity.x = (dx_player / distance_to_player) * constants.UNIT_SPEED;
            velocity.y = (dy_player / distance_to_player) * constants.UNIT_SPEED;
            // Set aggro color - bright red
            unit.color = constants.COLOR_UNIT_AGGRO;
        } else {
            // Return home (non-aggro state)
            velocity = calculateReturnHomeVelocity(unit);
            // Set non-aggro color - dimmed reddish (similar to lifestone dimmed color)
            unit.color = constants.COLOR_UNIT_NON_AGGRO;
        }
    } else {
        // Player dead - return home (non-aggro state)
        velocity = calculateReturnHomeVelocity(unit);
        // Set non-aggro color - dimmed reddish (similar to lifestone dimmed color)
        unit.color = constants.COLOR_UNIT_NON_AGGRO;
    }

    // Apply velocity
    unit.vel = velocity;
    unit.pos.x += velocity.x * dt;
    unit.pos.y += velocity.y * dt;
}

// Calculate velocity for unit returning home
fn calculateReturnHomeVelocity(unit: *const Unit) Vec2 {
    const dx = unit.home_pos.x - unit.pos.x;
    const dy = unit.home_pos.y - unit.pos.y;
    const dist_sq = dx * dx + dy * dy;

    // Use squared distance to avoid sqrt when possible
    const tolerance_sq = constants.UNIT_HOME_TOLERANCE * constants.UNIT_HOME_TOLERANCE;
    if (dist_sq <= tolerance_sq) {
        return Vec2{ .x = 0, .y = 0 };
    }

    const distance = @sqrt(dist_sq);
    return Vec2{
        .x = (dx / distance) * constants.UNIT_WALK_SPEED,
        .y = (dy / distance) * constants.UNIT_WALK_SPEED,
    };
}

// Update bullet position
pub fn updateBullet(bullet: *Bullet, dt: f32) void {
    if (!bullet.active) return;

    bullet.pos.x += bullet.vel.x * dt;
    bullet.pos.y += bullet.vel.y * dt;

    // Update lifetime
    bullet.lifetime -= dt;
    if (bullet.lifetime <= 0) {
        bullet.active = false;
        return;
    }

    // Deactivate if off screen
    if (bullet.pos.x < 0 or bullet.pos.x > constants.SCREEN_WIDTH or
        bullet.pos.y < 0 or bullet.pos.y > constants.SCREEN_HEIGHT)
    {
        bullet.active = false;
    }
}

// Fire a bullet from source position toward target
pub fn fireBullet(bullet: *Bullet, source_pos: Vec2, target_pos: Vec2) void {
    const direction = Vec2{
        .x = target_pos.x - source_pos.x,
        .y = target_pos.y - source_pos.y,
    };

    const length = @sqrt(direction.x * direction.x + direction.y * direction.y);
    if (length > 0) {
        bullet.pos = source_pos;
        bullet.vel.x = (direction.x / length) * constants.BULLET_SPEED;
        bullet.vel.y = (direction.y / length) * constants.BULLET_SPEED;
        bullet.active = true;
        bullet.lifetime = bullet.max_lifetime; // Reset lifetime to max
    }
}


// Kill unit
pub fn killUnit(unit: *Unit) void {
    unit.alive = false;
    unit.color = constants.COLOR_DEAD;
}

// Attune lifestone
pub fn attuneLifestone(lifestone: *entities.Lifestone) void {
    if (!lifestone.attuned) {
        lifestone.attuned = true;
        lifestone.color = constants.COLOR_LIFESTONE_ATTUNED;
    }
}

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
    const tolerance_sq = constants.UNIT_HOME_TOLERANCE * constants.UNIT_HOME_TOLERANCE;
    if (dist_sq <= tolerance_sq) {
        return Vec2{ .x = 0, .y = 0 };
    }

    const distance = @sqrt(dist_sq);
    return Vec2{
        .x = (dx / distance) * constants.UNIT_WALK_SPEED,
        .y = (dy / distance) * constants.UNIT_WALK_SPEED,
    };
}
