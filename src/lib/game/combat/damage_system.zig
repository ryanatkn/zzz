const std = @import("std");
const components = @import("../components/mod.zig");

/// Generic damage system for health modification
/// Games implement these interfaces for their specific damage mechanics
pub const DamageSystem = struct {
    /// Damage type enumeration - games can extend this
    pub const DamageType = enum {
        physical,
        magical,
        environmental,
        healing, // Negative damage
    };

    /// Damage configuration
    pub const DamageConfig = struct {
        amount: f32,
        damage_type: DamageType = .physical,
        can_kill: bool = true,
        pierce_immunity: bool = false,

        pub fn physical(amount: f32) DamageConfig {
            return .{ .amount = amount, .damage_type = .physical };
        }

        pub fn magical(amount: f32) DamageConfig {
            return .{ .amount = amount, .damage_type = .magical };
        }

        pub fn environmental(amount: f32) DamageConfig {
            return .{ .amount = amount, .damage_type = .environmental };
        }

        pub fn healing(amount: f32) DamageConfig {
            return .{ .amount = -amount, .damage_type = .healing };
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

    /// Apply damage to a health component
    pub fn applyDamage(health: *components.Health, config: DamageConfig) DamageResult {
        const initial_health = health.current;

        // Calculate actual damage after any resistances
        const actual_damage = config.amount;

        // Handle healing (negative damage)
        if (config.damage_type == .healing) {
            health.current = @min(health.current - actual_damage, health.max);
            return DamageResult.init(-actual_damage, false, health.current);
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

    /// Calculate damage with modifiers
    pub fn calculateModifiedDamage(base_damage: f32, damage_multiplier: f32, resistance: f32) f32 {
        const modified = base_damage * damage_multiplier;
        const after_resistance = modified * (1.0 - @min(resistance, 0.95)); // Cap resistance at 95%
        return @max(after_resistance, 0);
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
};

/// Death handling interface
pub const DeathHandling = struct {
    /// Death handler function type
    /// Games implement this to handle entity death
    pub const DeathHandlerFn = *const fn (entity_id: u32, game: anytype) void;

    /// Check if entity should be removed on death
    pub const ShouldRemoveFn = *const fn (entity_id: u32, game: anytype) bool;

    /// Death processing helpers
    pub const DeathHelpers = struct {
        /// Process death with custom handler
        pub fn processDeath(entity_id: u32, game: anytype, handler: DeathHandlerFn, should_remove: ShouldRemoveFn) void {
            handler(entity_id, game);

            if (should_remove(entity_id, game)) {
                // Game-specific removal logic would go here
                // This is just the interface pattern
            }
        }
    };
};
