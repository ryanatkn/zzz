const std = @import("std");
const timer = @import("timer.zig");

/// Generic resource pool for projectiles, mana, stamina, etc.
/// Provides rate-limited resource management with automatic regeneration
pub fn ResourcePool(comptime ResourceType: type) type {
    return struct {
        const Self = @This();

        current: ResourceType,
        maximum: ResourceType,
        recharge_timer: timer.RechargeTimer,

        pub fn init(max_resources: ResourceType, recharge_rate: f32) Self {
            return .{
                .current = max_resources,
                .maximum = max_resources,
                .recharge_timer = timer.RechargeTimer.init(recharge_rate),
            };
        }

        /// Check if resource can be consumed
        pub fn canConsume(self: *const Self, amount: ResourceType) bool {
            return self.current >= amount;
        }

        /// Try to consume resources, returns true if successful
        pub fn tryConsume(self: *Self, amount: ResourceType) bool {
            if (self.canConsume(amount)) {
                self.current -= amount;
                return true;
            }
            return false;
        }

        /// Force consume resources (can go negative)
        pub fn forceConsume(self: *Self, amount: ResourceType) void {
            self.current -= amount;
        }

        /// Add resources (up to maximum)
        pub fn addResources(self: *Self, amount: ResourceType) void {
            self.current = @min(self.current + amount, self.maximum);
        }

        /// Set current resources directly
        pub fn setResources(self: *Self, amount: ResourceType) void {
            self.current = @min(amount, self.maximum);
        }

        /// Update resource regeneration
        pub fn update(self: *Self, delta_time: f32) void {
            if (self.current < self.maximum) {
                const units_to_add = self.recharge_timer.update(delta_time);
                self.addResources(@intCast(units_to_add));
            }
        }

        /// Get current resource amount
        pub fn getCurrent(self: *const Self) ResourceType {
            return self.current;
        }

        /// Get maximum resource amount
        pub fn getMaximum(self: *const Self) ResourceType {
            return self.maximum;
        }

        /// Get resource percentage (0.0 to 1.0)
        pub fn getPercentage(self: *const Self) f32 {
            if (self.maximum == 0) return 0.0;
            return @as(f32, @floatFromInt(self.current)) / @as(f32, @floatFromInt(self.maximum));
        }

        /// Check if resources are full
        pub fn isFull(self: *const Self) bool {
            return self.current >= self.maximum;
        }

        /// Check if resources are empty
        pub fn isEmpty(self: *const Self) bool {
            return self.current == 0;
        }

        /// Set maximum resources (adjusts current if needed)
        pub fn setMaximum(self: *Self, new_max: ResourceType) void {
            self.maximum = new_max;
            if (self.current > self.maximum) {
                self.current = self.maximum;
            }
        }

        /// Set recharge rate
        pub fn setRechargeRate(self: *Self, new_rate: f32) void {
            self.recharge_timer = timer.RechargeTimer.init(new_rate);
        }

        /// Instantly fill to maximum
        pub fn refillToMax(self: *Self) void {
            self.current = self.maximum;
        }

        /// Drain all resources
        pub fn drain(self: *Self) void {
            self.current = 0;
        }
    };
}

/// Specialized resource pools for common game resources
/// Projectile pool for weapons/combat
pub const ProjectilePool = ResourcePool(u32);

/// Mana pool for magic systems
pub const ManaPool = ResourcePool(u32);

/// Stamina pool for actions
pub const StaminaPool = ResourcePool(u32);

/// Health pool (typically doesn't auto-regenerate)
pub const HealthPool = struct {
    current: u32,
    maximum: u32,

    pub fn init(max_health: u32) HealthPool {
        return .{
            .current = max_health,
            .maximum = max_health,
        };
    }

    pub fn takeDamage(self: *HealthPool, damage: u32) void {
        if (damage >= self.current) {
            self.current = 0;
        } else {
            self.current -= damage;
        }
    }

    pub fn heal(self: *HealthPool, amount: u32) void {
        self.current = @min(self.current + amount, self.maximum);
    }

    pub fn isAlive(self: *const HealthPool) bool {
        return self.current > 0;
    }

    pub fn isDead(self: *const HealthPool) bool {
        return self.current == 0;
    }

    pub fn getPercentage(self: *const HealthPool) f32 {
        if (self.maximum == 0) return 0.0;
        return @as(f32, @floatFromInt(self.current)) / @as(f32, @floatFromInt(self.maximum));
    }

    pub fn getCurrent(self: *const HealthPool) u32 {
        return self.current;
    }

    pub fn getMaximum(self: *const HealthPool) u32 {
        return self.maximum;
    }

    pub fn setMaximum(self: *HealthPool, new_max: u32) void {
        self.maximum = new_max;
        if (self.current > self.maximum) {
            self.current = self.maximum;
        }
    }

    pub fn refillToMax(self: *HealthPool) void {
        self.current = self.maximum;
    }
};

/// Multi-resource manager for complex resource systems
pub fn MultiResourceManager(comptime ResourceSet: type) type {
    return struct {
        const Self = @This();

        resources: ResourceSet,

        pub fn init(initial_resources: ResourceSet) Self {
            return .{ .resources = initial_resources };
        }

        /// Update all resource pools
        pub fn updateAll(self: *Self, delta_time: f32) void {
            const fields = @typeInfo(ResourceSet).@"struct".fields;
            inline for (fields) |field| {
                const resource = &@field(self.resources, field.name);
                if (@hasDecl(@TypeOf(resource.*), "update")) {
                    resource.update(delta_time);
                }
            }
        }

        /// Get a specific resource pool
        pub fn getResource(self: *Self, comptime resource_name: []const u8) *@TypeOf(@field(self.resources, resource_name)) {
            return &@field(self.resources, resource_name);
        }
    };
}

/// Example resource set for an RPG
pub const RPGResources = struct {
    health: HealthPool,
    mana: ManaPool,
    stamina: StaminaPool,
    projectiles: ProjectilePool,
};

test "ResourcePool basic functionality" {
    var pool = ProjectilePool.init(6, 2.0); // 6 max projectiles, 2/sec recharge

    // Initial state
    try std.testing.expectEqual(@as(u32, 6), pool.getCurrent());
    try std.testing.expect(pool.isFull());
    try std.testing.expect(pool.canConsume(1));

    // Consume resources
    try std.testing.expect(pool.tryConsume(3));
    try std.testing.expectEqual(@as(u32, 3), pool.getCurrent());
    try std.testing.expect(!pool.isFull());

    // Try to consume more than available
    try std.testing.expect(!pool.tryConsume(5));
    try std.testing.expectEqual(@as(u32, 3), pool.getCurrent()); // Should be unchanged

    // Update for regeneration (0.5 seconds = 1 projectile)
    pool.update(0.5);
    try std.testing.expectEqual(@as(u32, 4), pool.getCurrent());

    // Update for full regeneration (1.0 second = 2 projectiles)
    pool.update(1.0);
    try std.testing.expectEqual(@as(u32, 6), pool.getCurrent());
    try std.testing.expect(pool.isFull());
}

test "HealthPool functionality" {
    var health = HealthPool.init(100);

    // Initial state
    try std.testing.expectEqual(@as(u32, 100), health.getCurrent());
    try std.testing.expect(health.isAlive());
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), health.getPercentage(), 0.01);

    // Take damage
    health.takeDamage(30);
    try std.testing.expectEqual(@as(u32, 70), health.getCurrent());
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), health.getPercentage(), 0.01);

    // Heal
    health.heal(20);
    try std.testing.expectEqual(@as(u32, 90), health.getCurrent());

    // Take fatal damage
    health.takeDamage(100);
    try std.testing.expectEqual(@as(u32, 0), health.getCurrent());
    try std.testing.expect(health.isDead());
    try std.testing.expect(!health.isAlive());
}

test "MultiResourceManager functionality" {
    const TestResources = struct {
        projectiles: ProjectilePool,
        mana: ManaPool,
    };

    var manager = MultiResourceManager(TestResources).init(.{
        .projectiles = ProjectilePool.init(6, 2.0),
        .mana = ManaPool.init(100, 10.0),
    });

    // Access individual resources
    var projectiles = manager.getResource("projectiles");
    var mana = manager.getResource("mana");

    try std.testing.expect(projectiles.tryConsume(3));
    try std.testing.expect(mana.tryConsume(50));

    try std.testing.expectEqual(@as(u32, 3), projectiles.getCurrent());
    try std.testing.expectEqual(@as(u32, 50), mana.getCurrent());

    // Update all resources
    manager.updateAll(0.5);

    // Should have regenerated
    try std.testing.expectEqual(@as(u32, 4), projectiles.getCurrent()); // +1 projectile
    try std.testing.expectEqual(@as(u32, 55), mana.getCurrent()); // +5 mana
}
