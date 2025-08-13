const std = @import("std");

const types = @import("../lib/types.zig");
const entities = @import("entities.zig");
const behaviors = @import("behaviors.zig");
const physics = @import("physics.zig");
const effects = @import("effects.zig");
const constants = @import("constants.zig");

const Vec2 = types.Vec2;
const World = entities.World;
const Player = entities.Player;

// Bullet pool constants
const BULLET_POOL_SIZE = 6; // Even number for rhythm mode
const BULLET_RECHARGE_RATE = 2.0; // Bullets per second (full recharge in 3s)
const BULLET_FIRE_COOLDOWN = 0.15; // 150ms between shots for rhythm

pub const BulletPool = struct {
    max_bullets: u8,
    current_bullets: u8,
    recharge_rate: f32,      // Bullets per second
    recharge_accumulator: f32,
    fire_cooldown: f32,      // Min time between shots
    cooldown_remaining: f32,
    
    pub fn init() BulletPool {
        return .{
            .max_bullets = BULLET_POOL_SIZE,
            .current_bullets = BULLET_POOL_SIZE,
            .recharge_rate = BULLET_RECHARGE_RATE,
            .recharge_accumulator = 0,
            .fire_cooldown = BULLET_FIRE_COOLDOWN,
            .cooldown_remaining = 0,
        };
    }
    
    pub fn canFire(self: *const BulletPool) bool {
        return self.current_bullets > 0 and self.cooldown_remaining <= 0;
    }
    
    pub fn fire(self: *BulletPool) void {
        if (self.canFire()) {
            self.current_bullets -= 1;
            self.cooldown_remaining = self.fire_cooldown;
        }
    }
    
    pub fn update(self: *BulletPool, deltaTime: f32) void {
        // Update cooldown
        if (self.cooldown_remaining > 0) {
            self.cooldown_remaining -= deltaTime;
        }
        
        // Recharge bullets
        if (self.current_bullets < self.max_bullets) {
            self.recharge_accumulator += self.recharge_rate * deltaTime;
            while (self.recharge_accumulator >= 1.0 and self.current_bullets < self.max_bullets) {
                self.current_bullets += 1;
                self.recharge_accumulator -= 1.0;
            }
        } else {
            self.recharge_accumulator = 0;
        }
    }
    
    // Future: Upgrades can modify these values
    pub fn upgradeCapacity(self: *BulletPool, amount: u8) void {
        self.max_bullets += amount;
        self.current_bullets = @min(self.current_bullets + amount, self.max_bullets);
    }
    
    pub fn upgradeRechargeRate(self: *BulletPool, multiplier: f32) void {
        self.recharge_rate *= multiplier;
    }
    
    // Future: Multi-shot modifier
    pub fn getBulletsPerShot(self: *const BulletPool) u8 {
        _ = self;
        return 1; // Future: Can be upgraded to 2+ for multi-shot
    }
};

pub fn fireBullet(world: *World, target_pos: Vec2, pool: *BulletPool) bool {
    if (!world.player.alive) return false;
    if (!pool.canFire()) return false;

    if (world.findInactiveBullet()) |bullet| {
        behaviors.fireBullet(bullet, world.player.pos, target_pos);
        pool.fire();
        
        // Future: Bullet travel distance upgrade
        // bullet.max_distance = getUpgradedBulletDistance();
        return true;
    }
    return false;
}

pub fn fireBulletAtMouse(world: *World, mouse_pos: Vec2, pool: *BulletPool) bool {
    return fireBullet(world, mouse_pos, pool);
}

pub fn respawnPlayer(game_state: anytype) void {
    const world = &game_state.world;
    const effect_system = &game_state.effect_system;
    const nearest = physics.findNearestAttunedLifestone(world, world.player.pos);

    var respawn_pos: Vec2 = undefined;

    if (nearest) |result| {
        if (result.zone_index != world.current_zone) {
            game_state.travelToZone(result.zone_index);
            std.debug.print("Traveling to zone {} for nearest lifestone\n", .{result.zone_index});
        }
        respawn_pos = result.pos;
    } else {
        if (world.current_zone != 0) {
            game_state.travelToZone(0);
            std.debug.print("No lifestones found, returning to overworld spawn\n", .{});
        }
        respawn_pos = Vec2{ .x = constants.SCREEN_CENTER_X, .y = constants.SCREEN_CENTER_Y };
    }

    // Common respawn logic
    behaviors.respawnPlayer(&world.player, respawn_pos);
    effect_system.addPlayerSpawnEffect(respawn_pos, world.player.radius);
    std.debug.print("Player respawned!\n", .{});
}

pub fn handlePlayerDeath(player: *Player) void {
    behaviors.killPlayer(player);
    std.debug.print("Player died! Press R or click to respawn\n", .{});
}

pub fn handlePlayerDeathOnHazard(player: *Player) void {
    behaviors.killPlayer(player);
    std.debug.print("Player died on hazard! Press R or click to respawn\n", .{});
}

pub fn handleUnitDeath(unit: *entities.Unit) void {
    behaviors.killUnit(unit);
    std.debug.print("Unit defeated!\n", .{});
}

pub fn handleUnitDeathOnHazard(unit: *entities.Unit) void {
    behaviors.killUnit(unit);
    std.debug.print("Unit died on hazard!\n", .{});
}
