const std = @import("std");
const math = @import("../math/mod.zig");
const Vec2 = math.Vec2;
const entity_mod = @import("entity.zig");
const EntityId = entity_mod.EntityId;
const BoundedArray = std.BoundedArray;

/// High-performance bullet pool for projectiles
/// Uses SOA layout for cache efficiency and SIMD-friendly processing
pub const BulletPool = struct {
    pub const MAX_BULLETS = 256;

    // Dense arrays for cache locality
    positions: [MAX_BULLETS]Vec2,
    velocities: [MAX_BULLETS]Vec2,
    lifetimes: [MAX_BULLETS]f32,
    max_lifetimes: [MAX_BULLETS]f32,
    owners: [MAX_BULLETS]EntityId,
    damages: [MAX_BULLETS]f32,
    active: [MAX_BULLETS]bool,

    // Free list management
    free_list: BoundedArray(u16, MAX_BULLETS),
    active_count: u32,

    pub fn init() BulletPool {
        var pool = BulletPool{
            .positions = undefined,
            .velocities = undefined,
            .lifetimes = undefined,
            .max_lifetimes = undefined,
            .owners = undefined,
            .damages = undefined,
            .active = [_]bool{false} ** MAX_BULLETS,
            .free_list = BoundedArray(u16, MAX_BULLETS).init(0) catch |err| {
                std.log.err("Failed to initialize BulletPool free list: {}", .{err});
                @panic("BulletPool initialization failed");
            },
            .active_count = 0,
        };

        // Initialize free list with all indices
        for (0..MAX_BULLETS) |i| {
            pool.free_list.append(@intCast(i)) catch |err| {
                std.log.err("Failed to append to BulletPool free list at index {}: {}", .{ i, err });
                @panic("BulletPool free list initialization failed");
            };
        }

        return pool;
    }

    pub fn spawn(
        self: *BulletPool,
        pos: Vec2,
        vel: Vec2,
        owner: EntityId,
        damage: f32,
        lifetime: f32,
    ) ?u16 {
        const idx = self.free_list.popOrNull() orelse return null;

        self.positions[idx] = pos;
        self.velocities[idx] = vel;
        self.lifetimes[idx] = lifetime;
        self.max_lifetimes[idx] = lifetime;
        self.owners[idx] = owner;
        self.damages[idx] = damage;
        self.active[idx] = true;
        self.active_count += 1;

        return idx;
    }

    pub fn despawn(self: *BulletPool, idx: u16) void {
        if (idx >= MAX_BULLETS or !self.active[idx]) return;

        self.active[idx] = false;
        self.free_list.append(idx) catch {};
        self.active_count -= 1;
    }

    pub fn update(self: *BulletPool, dt: f32) void {
        // SIMD-friendly iteration over all bullets
        for (0..MAX_BULLETS) |i| {
            if (!self.active[i]) continue;

            // Update position
            self.positions[i].x += self.velocities[i].x * dt;
            self.positions[i].y += self.velocities[i].y * dt;

            // Update lifetime
            self.lifetimes[i] -= dt;
            if (self.lifetimes[i] <= 0) {
                self.despawn(@intCast(i));
            }
        }
    }

    pub fn getPosition(self: *const BulletPool, idx: u16) ?Vec2 {
        if (idx >= MAX_BULLETS or !self.active[idx]) return null;
        return self.positions[idx];
    }

    pub fn getOwner(self: *const BulletPool, idx: u16) ?EntityId {
        if (idx >= MAX_BULLETS or !self.active[idx]) return null;
        return self.owners[idx];
    }

    pub fn getDamage(self: *const BulletPool, idx: u16) ?f32 {
        if (idx >= MAX_BULLETS or !self.active[idx]) return null;
        return self.damages[idx];
    }

    pub fn isActive(self: *const BulletPool, idx: u16) bool {
        return idx < MAX_BULLETS and self.active[idx];
    }

    pub fn getActiveCount(self: *const BulletPool) u32 {
        return self.active_count;
    }

    pub fn clear(self: *BulletPool) void {
        // Clear all active bullets
        for (0..MAX_BULLETS) |i| {
            if (self.active[i]) {
                self.despawn(@intCast(i));
            }
        }
    }

    /// Iterator for active bullets
    pub const Iterator = struct {
        pool: *const BulletPool,
        index: u16,

        pub fn next(it: *Iterator) ?struct {
            idx: u16,
            pos: Vec2,
            vel: Vec2,
            owner: EntityId,
            damage: f32,
            lifetime: f32,
        } {
            while (it.index < MAX_BULLETS) {
                const idx = it.index;
                it.index += 1;
                if (it.pool.active[idx]) {
                    return .{
                        .idx = idx,
                        .pos = it.pool.positions[idx],
                        .vel = it.pool.velocities[idx],
                        .owner = it.pool.owners[idx],
                        .damage = it.pool.damages[idx],
                        .lifetime = it.pool.lifetimes[idx],
                    };
                }
            }
            return null;
        }
    };

    pub fn iterator(self: *const BulletPool) Iterator {
        return .{ .pool = self, .index = 0 };
    }
};

/// Particle pool for visual effects (non-gameplay)
/// Even more optimized for bulk processing
pub const ParticlePool = struct {
    pub const MAX_PARTICLES = 1024;

    // Minimal data for particles
    positions: [MAX_PARTICLES]Vec2,
    velocities: [MAX_PARTICLES]Vec2,
    lifetimes: [MAX_PARTICLES]f32,
    colors: [MAX_PARTICLES]u32, // Packed RGBA
    sizes: [MAX_PARTICLES]f32,
    active_mask: [MAX_PARTICLES / 64]u64, // Bit mask for active particles

    active_count: u32,

    pub fn init() ParticlePool {
        return .{
            .positions = undefined,
            .velocities = undefined,
            .lifetimes = undefined,
            .colors = undefined,
            .sizes = undefined,
            .active_mask = [_]u64{0} ** (MAX_PARTICLES / 64),
            .active_count = 0,
        };
    }

    pub fn spawn(
        self: *ParticlePool,
        pos: Vec2,
        vel: Vec2,
        lifetime: f32,
        color: u32,
        size: f32,
    ) ?u16 {
        if (self.active_count >= MAX_PARTICLES) return null;

        // Find first inactive slot using bit manipulation
        for (self.active_mask, 0..) |mask, word_idx| {
            if (mask != ~@as(u64, 0)) {
                const bit_idx = @ctz(~mask);
                const idx = word_idx * 64 + bit_idx;
                if (idx >= MAX_PARTICLES) continue;

                self.positions[idx] = pos;
                self.velocities[idx] = vel;
                self.lifetimes[idx] = lifetime;
                self.colors[idx] = color;
                self.sizes[idx] = size;

                // Set active bit
                self.active_mask[word_idx] |= @as(u64, 1) << @intCast(bit_idx);
                self.active_count += 1;

                return @intCast(idx);
            }
        }
        return null;
    }

    pub fn update(self: *ParticlePool, dt: f32) void {
        // Process particles in chunks of 64 for cache efficiency
        for (self.active_mask, 0..) |*mask, word_idx| {
            if (mask.* == 0) continue;

            const base_idx = word_idx * 64;
            var bits = mask.*;
            while (bits != 0) {
                const bit_idx = @ctz(bits);
                const idx = base_idx + bit_idx;

                // Update particle
                self.positions[idx].x += self.velocities[idx].x * dt;
                self.positions[idx].y += self.velocities[idx].y * dt;
                self.lifetimes[idx] -= dt;

                if (self.lifetimes[idx] <= 0) {
                    // Clear bit
                    mask.* &= ~(@as(u64, 1) << @intCast(bit_idx));
                    self.active_count -= 1;
                }

                // Clear processed bit
                bits &= bits - 1;
            }
        }
    }

    pub fn clear(self: *ParticlePool) void {
        self.active_mask = [_]u64{0} ** (MAX_PARTICLES / 64);
        self.active_count = 0;
    }
};

test "BulletPool operations" {
    var pool = BulletPool.init();

    const owner = EntityId{ .index = 1, .generation = 1 };
    const idx = pool.spawn(
        Vec2.new(100, 200),
        Vec2.new(10, 0),
        owner,
        25,
        2.0,
    );

    try std.testing.expect(idx != null);
    try std.testing.expect(pool.getActiveCount() == 1);
    try std.testing.expect(pool.isActive(idx.?));

    pool.update(0.5);
    const pos = pool.getPosition(idx.?);
    try std.testing.expect(pos.?.x == 105); // 100 + 10 * 0.5

    pool.despawn(idx.?);
    try std.testing.expect(!pool.isActive(idx.?));
    try std.testing.expect(pool.getActiveCount() == 0);
}

test "ParticlePool operations" {
    var pool = ParticlePool.init();

    const idx = pool.spawn(
        Vec2.new(50, 50),
        Vec2.new(1, 1),
        1.0,
        0xFF0000FF,
        5.0,
    );

    try std.testing.expect(idx != null);
    try std.testing.expect(pool.active_count == 1);

    pool.update(0.5);
    try std.testing.expect(pool.active_count == 1);

    pool.update(0.6); // Total 1.1 seconds, particle should expire
    try std.testing.expect(pool.active_count == 0);
}
