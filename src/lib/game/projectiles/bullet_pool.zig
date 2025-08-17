const std = @import("std");

/// BulletPool - Rate-limited bullet firing system
///
/// Provides a pool of bullets with:
/// - Rate limiting (bullets per second)
/// - Fire cooldown (minimum time between shots)
/// - Automatic recharge system
/// - Upgrade support for capacity and recharge rate
pub const BulletPool = struct {
    max_bullets: u8,
    current_bullets: u8,
    recharge_rate: f32, // Bullets per second
    recharge_accumulator: f32,
    fire_cooldown: f32, // Min time between shots
    cooldown_remaining: f32,

    /// Default configuration for balanced gameplay
    pub const DEFAULT_CONFIG = struct {
        pub const SIZE = 6; // Even number for rhythm mode
        pub const RECHARGE_RATE = 2.0; // Bullets per second (full recharge in 3s)
        pub const FIRE_COOLDOWN = 0.15; // 150ms between shots for rhythm
    };

    /// Initialize with default configuration
    pub fn init() BulletPool {
        return initWithConfig(DEFAULT_CONFIG.SIZE, DEFAULT_CONFIG.RECHARGE_RATE, DEFAULT_CONFIG.FIRE_COOLDOWN);
    }

    /// Initialize with custom configuration
    pub fn initWithConfig(max_bullets: u8, recharge_rate: f32, fire_cooldown: f32) BulletPool {
        return .{
            .max_bullets = max_bullets,
            .current_bullets = max_bullets,
            .recharge_rate = recharge_rate,
            .recharge_accumulator = 0,
            .fire_cooldown = fire_cooldown,
            .cooldown_remaining = 0,
        };
    }

    /// Check if we can fire (have bullets and not on cooldown)
    pub fn canFire(self: *const BulletPool) bool {
        return self.current_bullets > 0 and self.cooldown_remaining <= 0;
    }

    /// Consume a bullet and apply cooldown
    pub fn fire(self: *BulletPool) void {
        if (self.canFire()) {
            self.current_bullets -= 1;
            self.cooldown_remaining = self.fire_cooldown;
        }
    }

    /// Update the pool (should be called each frame)
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

    /// Get current bullet count
    pub fn getCurrentCount(self: *const BulletPool) u8 {
        return self.current_bullets;
    }

    /// Get maximum bullet capacity
    pub fn getMaxCount(self: *const BulletPool) u8 {
        return self.max_bullets;
    }

    /// Get current recharge rate
    pub fn getRechargeRate(self: *const BulletPool) f32 {
        return self.recharge_rate;
    }

    /// Check if pool is full
    pub fn isFull(self: *const BulletPool) bool {
        return self.current_bullets >= self.max_bullets;
    }

    /// Check if pool is empty
    pub fn isEmpty(self: *const BulletPool) bool {
        return self.current_bullets == 0;
    }

    /// Get time remaining until next bullet recharge
    pub fn getTimeToNextRecharge(self: *const BulletPool) f32 {
        if (self.isFull()) return 0.0;
        const time_per_bullet = 1.0 / self.recharge_rate;
        return time_per_bullet - self.recharge_accumulator * time_per_bullet;
    }

    // === Upgrade System ===

    /// Upgrade bullet capacity by amount
    pub fn upgradeCapacity(self: *BulletPool, amount: u8) void {
        self.max_bullets += amount;
        self.current_bullets = @min(self.current_bullets + amount, self.max_bullets);
    }

    /// Upgrade recharge rate by multiplier
    pub fn upgradeRechargeRate(self: *BulletPool, multiplier: f32) void {
        self.recharge_rate *= multiplier;
    }

    /// Set fire cooldown (for upgrade system)
    pub fn setFireCooldown(self: *BulletPool, cooldown: f32) void {
        self.fire_cooldown = cooldown;
    }

    // === Future Features ===

    /// Get bullets per shot (for multi-shot upgrades)
    pub fn getBulletsPerShot(self: *const BulletPool) u8 {
        _ = self;
        return 1; // Future: Can be upgraded to 2+ for multi-shot
    }

    // === Debug/Testing ===

    /// Force set bullet count (for testing)
    pub fn setBulletCount(self: *BulletPool, count: u8) void {
        self.current_bullets = @min(count, self.max_bullets);
    }

    /// Reset to full capacity
    pub fn reset(self: *BulletPool) void {
        self.current_bullets = self.max_bullets;
        self.recharge_accumulator = 0;
        self.cooldown_remaining = 0;
    }
};

// Tests
const testing = std.testing;

test "BulletPool basic functionality" {
    var pool = BulletPool.init();

    // Should start full
    try testing.expect(pool.isFull());
    try testing.expectEqual(@as(u8, 6), pool.getCurrentCount());
    try testing.expect(pool.canFire());

    // Fire a bullet
    pool.fire();
    try testing.expectEqual(@as(u8, 5), pool.getCurrentCount());
    try testing.expect(!pool.isFull());

    // Should be on cooldown briefly
    try testing.expect(!pool.canFire()); // Due to fire cooldown

    // Wait for cooldown to pass
    pool.update(0.2); // More than 0.15s cooldown
    try testing.expect(pool.canFire());
}

test "BulletPool recharge system" {
    var pool = BulletPool.init();

    // Empty the pool
    while (pool.canFire()) {
        pool.fire();
        pool.update(0.2); // Clear cooldown
    }
    try testing.expect(pool.isEmpty());

    // Should recharge over time
    // At 2 bullets/second, should take 0.5s for first bullet
    pool.update(0.5);
    try testing.expectEqual(@as(u8, 1), pool.getCurrentCount());

    // Full recharge should take 3 seconds
    pool.update(2.5);
    try testing.expectEqual(@as(u8, 6), pool.getCurrentCount());
    try testing.expect(pool.isFull());
}

test "BulletPool upgrade system" {
    var pool = BulletPool.init();

    // Upgrade capacity
    pool.upgradeCapacity(2);
    try testing.expectEqual(@as(u8, 8), pool.getMaxCount());
    try testing.expectEqual(@as(u8, 8), pool.getCurrentCount()); // Should get instant bullets

    // Upgrade recharge rate
    const old_rate = pool.getRechargeRate();
    pool.upgradeRechargeRate(2.0);
    try testing.expectEqual(old_rate * 2.0, pool.getRechargeRate());
}

test "BulletPool custom configuration" {
    var pool = BulletPool.initWithConfig(10, 5.0, 0.1);

    try testing.expectEqual(@as(u8, 10), pool.getMaxCount());
    try testing.expectEqual(@as(f32, 5.0), pool.getRechargeRate());
}
