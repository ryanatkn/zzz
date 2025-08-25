const std = @import("std");

/// Generic resource pool with automatic recharge and cooldown mechanics
/// Useful for ammo, spell slots, special abilities, etc.
pub fn ResourcePool(comptime config: PoolConfig) type {
    return struct {
        const Self = @This();

        max_resources: u32,
        current_resources: u32,
        recharge_rate: f32, // Resources per second
        recharge_accumulator: f32,
        fire_cooldown: f32, // Min time between uses
        cooldown_remaining: f32,

        pub fn init() Self {
            return .{
                .max_resources = config.max_size,
                .current_resources = config.max_size,
                .recharge_rate = config.recharge_rate,
                .recharge_accumulator = 0,
                .fire_cooldown = config.fire_cooldown,
                .cooldown_remaining = 0,
            };
        }

        /// Check if a resource can be consumed
        pub fn canUse(self: *const Self) bool {
            return self.current_resources > 0 and self.cooldown_remaining <= 0;
        }

        /// Consume a resource if available
        pub fn use(self: *Self) bool {
            if (self.canUse()) {
                self.current_resources -= 1;
                self.cooldown_remaining = self.fire_cooldown;
                return true;
            }
            return false;
        }

        /// Force consume a resource (bypassing availability checks)
        pub fn forceUse(self: *Self) void {
            if (self.current_resources > 0) {
                self.current_resources -= 1;
            }
            self.cooldown_remaining = self.fire_cooldown;
        }

        /// Update recharge and cooldown timers
        pub fn update(self: *Self, deltaTime: f32) void {
            // Update cooldown
            if (self.cooldown_remaining > 0) {
                self.cooldown_remaining -= deltaTime;
                if (self.cooldown_remaining < 0) {
                    self.cooldown_remaining = 0;
                }
            }

            // Update recharge (only if not at max)
            if (self.current_resources < self.max_resources) {
                self.recharge_accumulator += self.recharge_rate * deltaTime;

                // Recharge whole resources
                while (self.recharge_accumulator >= 1.0 and self.current_resources < self.max_resources) {
                    self.current_resources += 1;
                    self.recharge_accumulator -= 1.0;
                }
            }
        }

        /// Get current resource count
        pub fn getCurrentCount(self: *const Self) u32 {
            return self.current_resources;
        }

        /// Get maximum resource count
        pub fn getMaxCount(self: *const Self) u32 {
            return self.max_resources;
        }

        /// Get percentage full (0.0 to 1.0)
        pub fn getPercentFull(self: *const Self) f32 {
            return @as(f32, @floatFromInt(self.current_resources)) / @as(f32, @floatFromInt(self.max_resources));
        }

        /// Check if pool is full
        pub fn isFull(self: *const Self) bool {
            return self.current_resources >= self.max_resources;
        }

        /// Check if pool is empty
        pub fn isEmpty(self: *const Self) bool {
            return self.current_resources == 0;
        }

        /// Get remaining cooldown time
        pub fn getRemainingCooldown(self: *const Self) f32 {
            return self.cooldown_remaining;
        }

        /// Check if currently on cooldown
        pub fn isOnCooldown(self: *const Self) bool {
            return self.cooldown_remaining > 0;
        }

        /// Instantly fill the pool
        pub fn refill(self: *Self) void {
            self.current_resources = self.max_resources;
            self.recharge_accumulator = 0;
        }

        /// Instantly drain the pool
        pub fn drain(self: *Self) void {
            self.current_resources = 0;
        }

        /// Reset cooldown
        pub fn resetCooldown(self: *Self) void {
            self.cooldown_remaining = 0;
        }

        /// Set a specific resource count (clamped to max)
        pub fn setCount(self: *Self, count: u32) void {
            self.current_resources = @min(count, self.max_resources);
        }
    };
}

/// Configuration for a resource pool
pub const PoolConfig = struct {
    max_size: u32,
    recharge_rate: f32, // Resources per second
    fire_cooldown: f32, // Seconds between uses
};

/// Fixed-size object pool for reusable objects
pub fn ObjectPool(comptime T: type, comptime max_objects: u32) type {
    return struct {
        const Self = @This();

        objects: [max_objects]T,
        available: [max_objects]bool,
        next_index: u32,

        pub fn init() Self {
            return .{
                .objects = undefined, // Objects will be initialized when acquired
                .available = [_]bool{true} ** max_objects,
                .next_index = 0,
            };
        }

        /// Acquire an object from the pool, returns null if none available
        pub fn acquire(self: *Self) ?*T {
            // Start from next_index for better distribution
            var i: u32 = 0;
            while (i < max_objects) : (i += 1) {
                const idx = (self.next_index + i) % max_objects;
                if (self.available[idx]) {
                    self.available[idx] = false;
                    self.next_index = (idx + 1) % max_objects;
                    return &self.objects[idx];
                }
            }
            return null;
        }

        /// Return an object to the pool
        pub fn release(self: *Self, obj: *T) void {
            // Find the object in our array
            for (&self.objects, 0..) |*pool_obj, i| {
                if (pool_obj == obj) {
                    self.available[i] = true;
                    return;
                }
            }
            // Object not from this pool - this is a programming error
            std.debug.panic("Attempted to release object not from this pool", .{});
        }

        /// Get count of available objects
        pub fn getAvailableCount(self: *const Self) u32 {
            var count: u32 = 0;
            for (self.available) |available| {
                if (available) count += 1;
            }
            return count;
        }

        /// Get count of used objects
        pub fn getUsedCount(self: *const Self) u32 {
            return max_objects - self.getAvailableCount();
        }

        /// Check if pool is full (no objects available)
        pub fn isFull(self: *const Self) bool {
            return self.getAvailableCount() == 0;
        }

        /// Check if pool is empty (all objects available)
        pub fn isEmpty(self: *const Self) bool {
            return self.getAvailableCount() == max_objects;
        }

        /// Release all objects back to the pool
        pub fn releaseAll(self: *Self) void {
            self.available = [_]bool{true} ** max_objects;
            self.next_index = 0;
        }
    };
}

// Common pool configurations
pub const ProjectilePoolConfig = PoolConfig{
    .max_size = 6,
    .recharge_rate = 2.0,
    .fire_cooldown = 0.15,
};

pub const ManaPoolConfig = PoolConfig{
    .max_size = 100,
    .recharge_rate = 10.0,
    .fire_cooldown = 0.0,
};

pub const StaminaPoolConfig = PoolConfig{
    .max_size = 50,
    .recharge_rate = 5.0,
    .fire_cooldown = 0.1,
};

// Convenience aliases
pub const ProjectilePool = ResourcePool(ProjectilePoolConfig);
pub const ManaPool = ResourcePool(ManaPoolConfig);
pub const StaminaPool = ResourcePool(StaminaPoolConfig);

// Tests
const testing = std.testing;

test "ResourcePool basic functionality" {
    const TestPool = ResourcePool(PoolConfig{
        .max_size = 3,
        .recharge_rate = 1.0, // 1 per second
        .fire_cooldown = 0.5, // 500ms cooldown
    });

    var pool = TestPool.init();

    // Should start full
    try testing.expect(pool.isFull());
    try testing.expectEqual(@as(u32, 3), pool.getCurrentCount());

    // Should be able to use
    try testing.expect(pool.canUse());
    try testing.expect(pool.use());
    try testing.expectEqual(@as(u32, 2), pool.getCurrentCount());

    // Should be on cooldown after use
    try testing.expect(pool.isOnCooldown());
    try testing.expect(!pool.canUse());
}

test "ObjectPool basic functionality" {
    const TestObject = struct {
        value: i32,
        active: bool,
    };

    const TestPool = ObjectPool(TestObject, 3);
    var pool = TestPool.init();

    // Should start empty (all available)
    try testing.expect(pool.isEmpty());
    try testing.expectEqual(@as(u32, 3), pool.getAvailableCount());

    // Acquire objects
    const obj1 = pool.acquire();
    const obj2 = pool.acquire();

    try testing.expect(obj1 != null);
    try testing.expect(obj2 != null);
    try testing.expectEqual(@as(u32, 2), pool.getUsedCount());

    // Release an object
    pool.release(obj1.?);
    try testing.expectEqual(@as(u32, 1), pool.getUsedCount());
}
