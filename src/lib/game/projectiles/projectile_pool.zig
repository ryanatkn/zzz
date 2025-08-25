const std = @import("std");

/// ProjectilePool - Rate-limited projectile firing system
///
/// Provides a pool of projectiles with:
/// - Rate limiting (projectiles per second)
/// - Fire cooldown (minimum time between shots)
/// - Automatic recharge system
/// - Upgrade support for capacity and recharge rate
pub const ProjectilePool = struct {
    max_projectiles: u8,
    current_projectiles: u8,
    recharge_rate: f32, // Projectiles per second
    recharge_accumulator: f32,
    fire_cooldown: f32, // Min time between shots
    cooldown_remaining: f32,
    last_fire_time_ms: u64, // Track when any shot was fired

    /// Default configuration for balanced gameplay
    pub const DEFAULT_CONFIG = struct {
        pub const SIZE = 6; // Even number for rhythm mode
        pub const RECHARGE_RATE = 2.0; // Projectiles per second (full recharge in 3s)
        pub const FIRE_COOLDOWN = 2.0 / 6.0; // TODO needs to be computed from `recharge_rate / size`
    };

    /// Initialize with default configuration
    pub fn init() ProjectilePool {
        return initWithConfig(DEFAULT_CONFIG.SIZE, DEFAULT_CONFIG.RECHARGE_RATE, DEFAULT_CONFIG.FIRE_COOLDOWN);
    }

    /// Initialize with custom configuration
    pub fn initWithConfig(max_projectiles: u8, recharge_rate: f32, fire_cooldown: f32) ProjectilePool {
        return .{
            .max_projectiles = max_projectiles,
            .current_projectiles = max_projectiles,
            .recharge_rate = recharge_rate,
            .recharge_accumulator = 0,
            .fire_cooldown = fire_cooldown,
            .cooldown_remaining = 0,
            .last_fire_time_ms = 0,
        };
    }

    /// Check if we can fire (have projectiles and not on cooldown)
    pub fn canFire(self: *const ProjectilePool) bool {
        return self.current_projectiles > 0 and self.cooldown_remaining <= 0;
    }

    /// Consume a projectile and apply cooldown
    pub fn fire(self: *ProjectilePool) void {
        if (self.canFire()) {
            self.current_projectiles -= 1;
            self.cooldown_remaining = self.fire_cooldown;
        }
    }

    /// Update the pool (should be called each frame)
    pub fn update(self: *ProjectilePool, deltaTime: f32) void {
        // Update cooldown
        if (self.cooldown_remaining > 0) {
            self.cooldown_remaining -= deltaTime;
        }

        // Recharge projectiles
        if (self.current_projectiles < self.max_projectiles) {
            self.recharge_accumulator += self.recharge_rate * deltaTime;
            while (self.recharge_accumulator >= 1.0 and self.current_projectiles < self.max_projectiles) {
                self.current_projectiles += 1;
                self.recharge_accumulator -= 1.0;
            }
        } else {
            self.recharge_accumulator = 0;
        }
    }

    /// Get current projectile count
    pub fn getCurrentCount(self: *const ProjectilePool) u8 {
        return self.current_projectiles;
    }

    /// Get maximum projectile capacity
    pub fn getMaxCount(self: *const ProjectilePool) u8 {
        return self.max_projectiles;
    }

    /// Get current recharge rate
    pub fn getRechargeRate(self: *const ProjectilePool) f32 {
        return self.recharge_rate;
    }

    /// Check if pool is full
    pub fn isFull(self: *const ProjectilePool) bool {
        return self.current_projectiles >= self.max_projectiles;
    }

    /// Check if pool is empty
    pub fn isEmpty(self: *const ProjectilePool) bool {
        return self.current_projectiles == 0;
    }

    /// Get time remaining until next projectile recharge
    pub fn getTimeToNextRecharge(self: *const ProjectilePool) f32 {
        if (self.isFull()) return 0.0;
        const time_per_projectile = 1.0 / self.recharge_rate;
        return time_per_projectile - self.recharge_accumulator * time_per_projectile;
    }

    // === Upgrade System ===

    /// Upgrade projectile capacity by amount
    pub fn upgradeCapacity(self: *ProjectilePool, amount: u8) void {
        self.max_projectiles += amount;
        self.current_projectiles = @min(self.current_projectiles + amount, self.max_projectiles);
    }

    /// Upgrade recharge rate by multiplier
    pub fn upgradeRechargeRate(self: *ProjectilePool, multiplier: f32) void {
        self.recharge_rate *= multiplier;
    }

    /// Set fire cooldown (for upgrade system)
    pub fn setFireCooldown(self: *ProjectilePool, cooldown: f32) void {
        self.fire_cooldown = cooldown;
    }

    // === Future Features ===

    /// Get projectiles per shot (for multi-shot upgrades)
    pub fn getProjectilesPerShot(self: *const ProjectilePool) u8 {
        _ = self;
        return 1; // Future: Can be upgraded to 2+ for multi-shot
    }

    // === Debug/Testing ===

    /// Force set projectile count (for testing)
    pub fn setProjectileCount(self: *ProjectilePool, count: u8) void {
        self.current_projectiles = @min(count, self.max_projectiles);
    }

    /// Reset to full capacity
    pub fn reset(self: *ProjectilePool) void {
        self.current_projectiles = self.max_projectiles;
        self.recharge_accumulator = 0;
        self.cooldown_remaining = 0;
    }
};

// Tests
const testing = std.testing;

test "ProjectilePool basic functionality" {
    var pool = ProjectilePool.init();

    // Should start full
    try testing.expect(pool.isFull());
    try testing.expectEqual(@as(u8, 6), pool.getCurrentCount());
    try testing.expect(pool.canFire());

    // Fire a projectile
    pool.fire();
    try testing.expectEqual(@as(u8, 5), pool.getCurrentCount());
    try testing.expect(!pool.isFull());

    // Should be on cooldown briefly
    try testing.expect(!pool.canFire()); // Due to fire cooldown

    // Wait for cooldown to pass
    pool.update(0.4); // More than 0.33s cooldown
    try testing.expect(pool.canFire());
}

test "ProjectilePool recharge system" {
    var pool = ProjectilePool.init();

    // Empty the pool
    while (pool.canFire()) {
        pool.fire();
        pool.update(0.4); // Clear cooldown (more than 0.33s)
    }
    try testing.expect(pool.isEmpty());

    // Should recharge over time
    // At 2 projectiles/second, should take 0.5s for first projectile
    pool.update(0.5);
    try testing.expectEqual(@as(u8, 1), pool.getCurrentCount());

    // Full recharge should take 3 seconds
    pool.update(2.5);
    try testing.expectEqual(@as(u8, 6), pool.getCurrentCount());
    try testing.expect(pool.isFull());
}

test "ProjectilePool upgrade system" {
    var pool = ProjectilePool.init();

    // Upgrade capacity
    pool.upgradeCapacity(2);
    try testing.expectEqual(@as(u8, 8), pool.getMaxCount());
    try testing.expectEqual(@as(u8, 8), pool.getCurrentCount()); // Should get instant projectiles

    // Upgrade recharge rate
    const old_rate = pool.getRechargeRate();
    pool.upgradeRechargeRate(2.0);
    try testing.expectEqual(old_rate * 2.0, pool.getRechargeRate());
}

test "ProjectilePool custom configuration" {
    var pool = ProjectilePool.initWithConfig(10, 5.0, 0.1);

    try testing.expectEqual(@as(u8, 10), pool.getMaxCount());
    try testing.expectEqual(@as(f32, 5.0), pool.getRechargeRate());
}
