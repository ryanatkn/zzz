const std = @import("std");

const loggers = @import("../../lib/debug/loggers.zig");
const math = @import("../../lib/math/mod.zig");
const time = @import("../../lib/core/time.zig");
const camera = @import("../../lib/game/camera/camera.zig");
const ProjectilePoolImpl = @import("../../lib/game/projectiles/projectile_pool.zig").ProjectilePool;
const entity_queries = @import("../entity_queries.zig");
const world_state_mod = @import("../world_state.zig");
const constants = @import("../constants.zig"); // Use main hex constants (meters/second units)

const Vec2 = math.Vec2;
const Camera = camera.Camera;
const HexGame = world_state_mod.HexGame;

// Re-export ProjectilePool for convenience
pub const ProjectilePool = ProjectilePoolImpl;

/// Hex-specific projectile shooting interface
const HexProjectileInterface = struct {
    pub fn getShooterPos(game: *HexGame) ?Vec2 {
        if (game.getControlledEntity()) |entity_id| {
            return entity_queries.getEntityPos(game, entity_id);
        }
        return null;
    }

    pub fn isShooterAlive(game: *HexGame) bool {
        return game.hasLiveControlledEntity();
    }

    pub fn createProjectile(game: *HexGame, pos: Vec2, velocity: Vec2, radius: f32, lifetime: f32) anyerror!u32 {
        const shooter_id = game.getControlledEntity() orelse return error.NoShooter;
        return game.createProjectile(game.zone_manager.getCurrentZoneIndex(), pos, radius, velocity, lifetime, shooter_id);
    }
};

/// Fire a projectile at a specific world position
pub fn fireProjectile(game: *HexGame, target_pos: Vec2, pool: *ProjectilePool, bypass_cooldown: bool) bool {
    // Check if shooter is alive and can shoot
    if (!HexProjectileInterface.isShooterAlive(game)) return false;

    const shooter_pos = HexProjectileInterface.getShooterPos(game) orelse return false;

    // Handle timing based on bypass_cooldown flag
    const current_time_ms = @as(u64, @intFromFloat(time.Time.getTimeMs()));

    if (bypass_cooldown) {
        // Skill-based: only check projectile count
        if (pool.getCurrentCount() == 0) return false;
        // Manually consume projectile and set cooldown to prevent rhythm double-shot
        pool.current_projectiles -= 1;
        pool.cooldown_remaining = pool.fire_cooldown;
        game.logger.info("projectile_fired", "Projectile fired immediate (skill-based)! pos: {any}, target: {any}", .{ shooter_pos, target_pos });
    } else {
        // Rhythm: check both projectile count and cooldown timing
        if (!pool.canFire()) return false;
        pool.fire();
        game.logger.info("projectile_fired", "Projectile fired rhythm! pos: {any}, target: {any}", .{ shooter_pos, target_pos });
    }

    // Track shot time for both modes
    pool.last_fire_time_ms = current_time_ms;

    // Calculate projectile direction and velocity
    const direction = target_pos.sub(shooter_pos).normalize();
    const velocity = direction.scale(constants.PROJECTILE_SPEED);

    // Create projectile entity
    const projectile_id = HexProjectileInterface.createProjectile(game, shooter_pos, velocity, constants.PROJECTILE_RADIUS, constants.PROJECTILE_LIFETIME) catch return false;

    game.logger.info("projectile_confirmed", "Projectile created with ID: {}", .{projectile_id});
    return true;
}

/// Fire projectile at mouse position (convenience function)
pub fn fireProjectileAtMouse(game: *HexGame, mouse_pos: Vec2, pool: *ProjectilePool, bypass_cooldown: bool) bool {
    return fireProjectile(game, mouse_pos, pool, bypass_cooldown);
}

/// Fire projectile with screen-to-world coordinate conversion
pub fn fireProjectileAtScreenPos(game: *HexGame, screen_pos: Vec2, cam: *const Camera, pool: *ProjectilePool, bypass_cooldown: bool) bool {
    const world_pos = cam.screenToWorldSafe(screen_pos);
    return fireProjectile(game, world_pos, pool, bypass_cooldown);
}
