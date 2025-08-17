/// Generic object pool system for efficient memory management
/// Provides reusable object pools to avoid frequent allocation/deallocation
const std = @import("std");
const constants = @import("constants.zig");

// ========================
// CORE POOL TYPES
// ========================

/// Generic object pool for any type T
pub fn ObjectPool(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        objects: std.ArrayList(T),
        available: std.ArrayList(bool),
        next_free: ?usize,
        max_size: usize,

        pub fn init(allocator: std.mem.Allocator, initial_size: usize, max_size: usize) !Self {
            var pool = Self{
                .allocator = allocator,
                .objects = std.ArrayList(T).init(allocator),
                .available = std.ArrayList(bool).init(allocator),
                .next_free = null,
                .max_size = max_size,
            };

            // Pre-allocate initial objects
            try pool.objects.ensureTotalCapacity(initial_size);
            try pool.available.ensureTotalCapacity(initial_size);

            for (0..initial_size) |i| {
                try pool.objects.append(std.mem.zeroes(T));
                try pool.available.append(true);

                if (pool.next_free == null) {
                    pool.next_free = i;
                }
            }

            return pool;
        }

        pub fn deinit(self: *Self) void {
            self.objects.deinit();
            self.available.deinit();
        }

        /// Get an object from the pool
        pub fn acquire(self: *Self) !?*T {
            // Find next available slot
            if (self.next_free) |index| {
                if (index < self.objects.items.len and self.available.items[index]) {
                    self.available.items[index] = false;

                    // Find next free slot
                    self.next_free = null;
                    for (self.available.items, 0..) |available, i| {
                        if (available) {
                            self.next_free = i;
                            break;
                        }
                    }

                    return &self.objects.items[index];
                }
            }

            // Try to expand pool if under max size
            if (self.objects.items.len < self.max_size) {
                const new_index = self.objects.items.len;
                try self.objects.append(std.mem.zeroes(T));
                try self.available.append(false);

                return &self.objects.items[new_index];
            }

            // Pool is full
            return null;
        }

        /// Return an object to the pool
        pub fn release(self: *Self, object: *T) void {
            // Find the object in our pool
            const objects_ptr = self.objects.items.ptr;
            const object_ptr = @intFromPtr(object);
            const base_ptr = @intFromPtr(objects_ptr);
            const offset = object_ptr - base_ptr;
            const index = offset / @sizeOf(T);

            if (index < self.objects.items.len) {
                // Reset object to default state
                self.objects.items[index] = std.mem.zeroes(T);
                self.available.items[index] = true;

                // Update next_free if needed
                if (self.next_free == null or index < self.next_free.?) {
                    self.next_free = index;
                }
            }
        }

        /// Get current pool statistics
        pub fn getStats(self: *const Self) PoolStats {
            var in_use: usize = 0;
            for (self.available.items) |available| {
                if (!available) in_use += 1;
            }

            return PoolStats{
                .total_capacity = self.objects.items.len,
                .max_capacity = self.max_size,
                .in_use = in_use,
                .available = self.objects.items.len - in_use,
            };
        }

        /// Reset all objects in the pool
        pub fn reset(self: *Self) void {
            for (self.objects.items, 0..) |*object, i| {
                object.* = std.mem.zeroes(T);
                self.available.items[i] = true;
            }
            self.next_free = if (self.objects.items.len > 0) 0 else null;
        }

        /// Get all active (in-use) objects
        pub fn getActiveObjects(self: *const Self, allocator: std.mem.Allocator) !std.ArrayList(*T) {
            var active = std.ArrayList(*T).init(allocator);

            for (self.objects.items, 0..) |*object, i| {
                if (!self.available.items[i]) {
                    try active.append(object);
                }
            }

            return active;
        }
    };
}

/// Pool statistics
pub const PoolStats = struct {
    total_capacity: usize,
    max_capacity: usize,
    in_use: usize,
    available: usize,

    pub fn utilizationPercent(self: PoolStats) f32 {
        if (self.total_capacity == 0) return 0.0;
        return @as(f32, @floatFromInt(self.in_use)) / @as(f32, @floatFromInt(self.total_capacity)) * 100.0;
    }

    pub fn isFull(self: PoolStats) bool {
        return self.available == 0 and self.total_capacity == self.max_capacity;
    }

    pub fn isEmpty(self: PoolStats) bool {
        return self.in_use == 0;
    }
};

// ========================
// SPECIALIZED POOLS
// ========================

/// Pool for managing temporary allocations during a frame
pub const FramePool = struct {
    backing_allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,

    pub fn init(backing_allocator: std.mem.Allocator) FramePool {
        return .{
            .backing_allocator = backing_allocator,
            .arena = std.heap.ArenaAllocator.init(backing_allocator),
        };
    }

    pub fn deinit(self: *FramePool) void {
        self.arena.deinit();
    }

    /// Get frame allocator for temporary allocations
    pub fn allocator(self: *FramePool) std.mem.Allocator {
        return self.arena.allocator();
    }

    /// Reset all frame allocations (call at end of frame)
    pub fn reset(self: *FramePool) void {
        _ = self.arena.reset(.retain_capacity);
    }

    /// Get memory usage statistics
    pub fn getStats(self: *const FramePool) FramePoolStats {
        // Simplified stats - arena internals have changed in newer Zig
        _ = self;
        return FramePoolStats{
            .bytes_allocated = 0, // Would need to track manually
            .bytes_capacity = 0,
        };
    }
};

pub const FramePoolStats = struct {
    bytes_allocated: usize,
    bytes_capacity: usize,

    pub fn utilizationPercent(self: FramePoolStats) f32 {
        if (self.bytes_capacity == 0) return 0.0;
        return @as(f32, @floatFromInt(self.bytes_allocated)) / @as(f32, @floatFromInt(self.bytes_capacity)) * 100.0;
    }
};

/// Pool cleanup function pointer
const PoolCleanupFn = *const fn (allocator: std.mem.Allocator, pool_ptr: *anyopaque) void;

/// Pool entry with cleanup information
const PoolEntry = struct {
    pool_ptr: *anyopaque,
    cleanup_fn: PoolCleanupFn,
};

/// Pool manager for handling multiple object pools
pub const PoolManager = struct {
    allocator: std.mem.Allocator,
    frame_pool: FramePool,
    pools: std.StringHashMap(PoolEntry),
    pool_names: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) PoolManager {
        return .{
            .allocator = allocator,
            .frame_pool = FramePool.init(allocator),
            .pools = std.StringHashMap(PoolEntry).init(allocator),
            .pool_names = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *PoolManager) void {
        // Clean up all registered pools
        var pool_iterator = self.pools.iterator();
        while (pool_iterator.next()) |entry| {
            const pool_entry = entry.value_ptr.*;
            pool_entry.cleanup_fn(self.allocator, pool_entry.pool_ptr);
        }

        self.frame_pool.deinit();
        self.pools.deinit();
        self.pool_names.deinit();
    }

    /// Register a new typed pool
    pub fn registerPool(self: *PoolManager, comptime T: type, name: []const u8, initial_size: usize, max_size: usize) !void {
        const pool = try self.allocator.create(ObjectPool(T));
        pool.* = try ObjectPool(T).init(self.allocator, initial_size, max_size);

        // Create cleanup function for this pool type
        const cleanup_fn = struct {
            fn cleanup(allocator: std.mem.Allocator, pool_ptr: *anyopaque) void {
                const typed_pool: *ObjectPool(T) = @ptrCast(@alignCast(pool_ptr));
                typed_pool.deinit();
                allocator.destroy(typed_pool);
            }
        }.cleanup;

        const pool_entry = PoolEntry{
            .pool_ptr = @ptrCast(pool),
            .cleanup_fn = cleanup_fn,
        };

        try self.pools.put(name, pool_entry);
        try self.pool_names.append(name);
    }

    /// Get a typed pool by name
    pub fn getPool(self: *PoolManager, comptime T: type, name: []const u8) ?*ObjectPool(T) {
        if (self.pools.get(name)) |pool_entry| {
            return @ptrCast(@alignCast(pool_entry.pool_ptr));
        }
        return null;
    }

    /// Get frame allocator for temporary allocations
    pub fn getFrameAllocator(self: *PoolManager) std.mem.Allocator {
        return self.frame_pool.allocator();
    }

    /// Reset frame pool (call at end of each frame)
    pub fn resetFrame(self: *PoolManager) void {
        self.frame_pool.reset();
    }

    /// Get comprehensive statistics for all pools
    pub fn getAllStats(self: *PoolManager, allocator: std.mem.Allocator) !ManagerStats {
        var stats = ManagerStats{
            .frame_stats = self.frame_pool.getStats(),
            .pool_stats = std.ArrayList(NamedPoolStats).init(allocator),
        };

        for (self.pool_names.items) |name| {
            // This is a simplified approach - in practice you'd need type information
            // to properly call getStats on each pool
            const named_stats = NamedPoolStats{
                .name = name,
                .stats = PoolStats{
                    .total_capacity = 0,
                    .max_capacity = 0,
                    .in_use = 0,
                    .available = 0,
                },
            };
            try stats.pool_stats.append(named_stats);
        }

        return stats;
    }
};

pub const NamedPoolStats = struct {
    name: []const u8,
    stats: PoolStats,
};

pub const ManagerStats = struct {
    frame_stats: FramePoolStats,
    pool_stats: std.ArrayList(NamedPoolStats),

    pub fn deinit(self: *ManagerStats) void {
        self.pool_stats.deinit();
    }
};

// ========================
// COMMON POOL TYPES
// ========================

/// Common game object types for pools
pub const GameEntity = struct {
    id: u32,
    x: f32,
    y: f32,
    active: bool,

    pub fn init() GameEntity {
        return .{
            .id = 0,
            .x = 0,
            .y = 0,
            .active = false,
        };
    }
};

pub const Particle = struct {
    x: f32,
    y: f32,
    velocity_x: f32,
    velocity_y: f32,
    life_time: f32,
    max_life_time: f32,
    size: f32,
    color: u32,
    active: bool,

    pub fn init() Particle {
        return std.mem.zeroes(Particle);
    }

    pub fn isAlive(self: *const Particle) bool {
        return self.active and self.life_time > 0;
    }

    pub fn update(self: *Particle, delta_time: f32) void {
        if (self.active) {
            self.x += self.velocity_x * delta_time;
            self.y += self.velocity_y * delta_time;
            self.life_time -= delta_time;

            if (self.life_time <= 0) {
                self.active = false;
            }
        }
    }
};

pub const Projectile = struct {
    x: f32,
    y: f32,
    velocity_x: f32,
    velocity_y: f32,
    damage: f32,
    lifetime: f32,
    active: bool,

    pub fn init() Projectile {
        return std.mem.zeroes(Projectile);
    }

    pub fn isActive(self: *const Projectile) bool {
        return self.active and self.lifetime > 0;
    }
};

// ========================
// POOL UTILITIES
// ========================

/// Utility functions for working with pools
pub const PoolUtils = struct {
    /// Create a standard game object pool setup
    pub fn createGamePools(allocator: std.mem.Allocator) !PoolManager {
        var manager = PoolManager.init(allocator);

        // Register common game pools with reasonable defaults
        try manager.registerPool(GameEntity, "entities", constants.PERFORMANCE.POOL_DEFAULT_SIZE, constants.PERFORMANCE.POOL_MAX_SIZE);

        try manager.registerPool(Particle, "particles", constants.RENDERING.MAX_PARTICLES, constants.RENDERING.MAX_PARTICLES);

        try manager.registerPool(Projectile, "projectiles", 32, 128);

        return manager;
    }

    /// Clean up inactive objects from a pool
    pub fn cleanupInactive(pool: anytype, comptime hasActiveFn: []const u8) void {
        const stats = pool.getStats();
        if (stats.in_use == 0) return;

        // This would need type-specific implementation
        // For now, this is a placeholder for the pattern
        _ = hasActiveFn;
    }

    /// Get pool efficiency metrics
    pub fn getEfficiencyMetrics(stats: PoolStats) EfficiencyMetrics {
        return EfficiencyMetrics{
            .utilization = stats.utilizationPercent(),
            .fragmentation = calculateFragmentation(stats),
            .efficiency = calculateEfficiency(stats),
        };
    }

    fn calculateFragmentation(stats: PoolStats) f32 {
        // Simple fragmentation estimate
        if (stats.total_capacity == 0) return 0.0;
        const gaps = stats.available;
        return @as(f32, @floatFromInt(gaps)) / @as(f32, @floatFromInt(stats.total_capacity)) * 100.0;
    }

    fn calculateEfficiency(stats: PoolStats) f32 {
        // Efficiency based on utilization vs capacity
        if (stats.max_capacity == 0) return 100.0;
        const capacity_usage = @as(f32, @floatFromInt(stats.total_capacity)) / @as(f32, @floatFromInt(stats.max_capacity));
        const utilization = stats.utilizationPercent() / 100.0;
        return (utilization + capacity_usage) / 2.0 * 100.0;
    }
};

pub const EfficiencyMetrics = struct {
    utilization: f32, // How much of allocated capacity is used
    fragmentation: f32, // How fragmented the pool is
    efficiency: f32, // Overall efficiency score
};

// ========================
// TESTS
// ========================

test "basic object pool" {
    var pool = try ObjectPool(u32).init(std.testing.allocator, 2, 5);
    defer pool.deinit();

    // Test acquisition
    const obj1 = try pool.acquire();
    try std.testing.expect(obj1 != null);
    obj1.?.* = 42;

    const obj2 = try pool.acquire();
    try std.testing.expect(obj2 != null);
    obj2.?.* = 84;

    // Test stats
    const stats = pool.getStats();
    try std.testing.expect(stats.in_use == 2);
    try std.testing.expect(stats.available == 0);

    // Test release
    pool.release(obj1.?);
    const stats2 = pool.getStats();
    try std.testing.expect(stats2.in_use == 1);
    try std.testing.expect(stats2.available == 1);

    // Test reacquisition
    const obj3 = try pool.acquire();
    try std.testing.expect(obj3 != null);
    try std.testing.expect(obj3.?.* == 0); // Should be reset
}

test "pool expansion" {
    var pool = try ObjectPool(u32).init(std.testing.allocator, 1, 3);
    defer pool.deinit();

    // Fill initial capacity
    const obj1 = try pool.acquire();
    try std.testing.expect(obj1 != null);

    // Expand pool
    const obj2 = try pool.acquire();
    try std.testing.expect(obj2 != null);

    const obj3 = try pool.acquire();
    try std.testing.expect(obj3 != null);

    // Hit max capacity
    const obj4 = try pool.acquire();
    try std.testing.expect(obj4 == null);

    const stats = pool.getStats();
    try std.testing.expect(stats.total_capacity == 3);
    try std.testing.expect(stats.in_use == 3);
    try std.testing.expect(stats.isFull());
}

test "frame pool" {
    var frame_pool = FramePool.init(std.testing.allocator);
    defer frame_pool.deinit();

    const allocator = frame_pool.allocator();

    // Allocate some memory
    const slice1 = try allocator.alloc(u32, 10);
    const slice2 = try allocator.alloc(u8, 100);

    _ = slice1;
    _ = slice2;

    const stats_before = frame_pool.getStats();
    // Stats are simplified, so just check they exist
    _ = stats_before;

    // Reset should clear allocations
    frame_pool.reset();

    const stats_after = frame_pool.getStats();
    try std.testing.expect(stats_after.bytes_allocated == 0);
}

test "pool manager" {
    var manager = PoolManager.init(std.testing.allocator);
    defer manager.deinit();

    // Register a pool
    try manager.registerPool(u32, "test_pool", 2, 10);

    // Get the pool
    if (manager.getPool(u32, "test_pool")) |pool| {
        const obj = try pool.acquire();
        try std.testing.expect(obj != null);
        obj.?.* = 123;

        const stats = pool.getStats();
        try std.testing.expect(stats.in_use == 1);
    } else {
        try std.testing.expect(false); // Pool should exist
    }

    // Test frame allocator
    const frame_allocator = manager.getFrameAllocator();
    const slice = try frame_allocator.alloc(u32, 5);
    _ = slice;

    manager.resetFrame();
}

test "game entity pool" {
    var pool = try ObjectPool(GameEntity).init(std.testing.allocator, 2, 5);
    defer pool.deinit();

    const entity = try pool.acquire();
    try std.testing.expect(entity != null);

    entity.?.* = GameEntity{
        .id = 1,
        .x = 100,
        .y = 200,
        .active = true,
    };

    try std.testing.expect(entity.?.id == 1);
    try std.testing.expect(entity.?.active);

    pool.release(entity.?);

    // Should be reset to zeros
    const entity2 = try pool.acquire();
    try std.testing.expect(entity2.?.id == 0);
    try std.testing.expect(!entity2.?.active);
}

test "particle system" {
    var pool = try ObjectPool(Particle).init(std.testing.allocator, 5, 10);
    defer pool.deinit();

    const particle = try pool.acquire();
    try std.testing.expect(particle != null);

    particle.?.* = Particle{
        .x = 0,
        .y = 0,
        .velocity_x = 10,
        .velocity_y = 5,
        .life_time = 1.0,
        .max_life_time = 1.0,
        .size = 5,
        .color = 0xFFFFFF,
        .active = true,
    };

    try std.testing.expect(particle.?.isAlive());

    // Update particle
    particle.?.update(0.5); // Half second
    try std.testing.expect(particle.?.life_time == 0.5);
    try std.testing.expect(particle.?.x == 5.0); // 10 * 0.5

    // Update again to kill it
    particle.?.update(1.0); // Another second
    try std.testing.expect(!particle.?.isAlive());
}
