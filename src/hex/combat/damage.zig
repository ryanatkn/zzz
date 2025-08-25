const std = @import("std");
const components = @import("../../lib/game/components/mod.zig");
const constants = @import("../constants.zig"); // Use main hex constants (meters/second units)

/// Hex-specific damage types
pub const DamageType = enum {
    projectile, // From player/unit projectiles
    environmental, // Pit falls, hazards
    collision, // Unit-to-unit contact damage
    spell, // Magic damage from spells
};

/// Hex damage configuration
pub const DamageConfig = struct {
    amount: f32,
    damage_type: DamageType,
    can_kill: bool = true,
    pierce_immunity: bool = false,

    pub fn projectile(amount: f32) DamageConfig {
        return .{ .amount = amount, .damage_type = .projectile };
    }

    pub fn environmental(amount: f32) DamageConfig {
        return .{ .amount = amount, .damage_type = .environmental };
    }

    pub fn collision(amount: f32) DamageConfig {
        return .{ .amount = amount, .damage_type = .collision };
    }

    pub fn spell(amount: f32) DamageConfig {
        return .{ .amount = amount, .damage_type = .spell };
    }

    pub fn fatal() DamageConfig {
        return .{ .amount = constants.COLLISION_DAMAGE, .damage_type = .environmental };
    }
};

/// Damage result information
pub const DamageResult = struct {
    damage_dealt: f32,
    target_killed: bool,
    target_health_remaining: f32,
    damage_blocked: f32 = 0,

    pub fn init(damage_dealt: f32, target_killed: bool, health_remaining: f32) DamageResult {
        return .{
            .damage_dealt = damage_dealt,
            .target_killed = target_killed,
            .target_health_remaining = health_remaining,
        };
    }
};

/// Apply damage to a health component using Hex-specific rules
pub fn applyDamage(health: *components.Health, config: DamageConfig) DamageResult {
    const initial_health = health.current;

    // Apply Hex-specific damage calculation
    var actual_damage = config.amount;

    // Hex-specific damage type modifications
    switch (config.damage_type) {
        .environmental => {
            // Environmental damage is typically fatal (pits, etc.)
            actual_damage = constants.COLLISION_DAMAGE; // Same as collision damage (fatal)
        },
        .collision => {
            // Collision damage uses Hex constants
            actual_damage = constants.COLLISION_DAMAGE;
        },
        .projectile => {
            // Projectile damage from constants
            actual_damage = constants.PROJECTILE_DAMAGE;
        },
        .spell => {
            // Spell damage varies by spell
            // Amount passed in config is used as-is
        },
    }

    // Apply damage
    health.current = @max(health.current - actual_damage, if (config.can_kill) 0 else 1);

    // Update alive status
    if (health.current <= 0) {
        health.alive = false;
    }

    const damage_dealt = initial_health - health.current;
    return DamageResult.init(damage_dealt, !health.alive, health.current);
}

/// Check if entity can take damage
pub fn canTakeDamage(health: *const components.Health) bool {
    return health.alive and health.current > 0;
}

/// Heal entity to full health
pub fn healToFull(health: *components.Health) void {
    health.current = health.max;
    health.alive = true;
}

/// Check if entity is at full health
pub fn isAtFullHealth(health: *const components.Health) bool {
    return health.current >= health.max;
}

/// Get health percentage (0.0 to 1.0)
pub fn getHealthPercentage(health: *const components.Health) f32 {
    if (health.max <= 0) return 0;
    return health.current / health.max;
}
