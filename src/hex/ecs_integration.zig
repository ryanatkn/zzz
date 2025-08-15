/// Example integration of the new ECS system with the hex game
/// This shows how to migrate from the old entity system to the new component-based approach

const std = @import("std");
const ecs = @import("../lib/game/ecs.zig");
const pools = @import("../lib/game/pools.zig");
const math = @import("../lib/math/mod.zig");

const EntityId = ecs.EntityId;
const World = ecs.World;
const Transform = ecs.Transform;
const Health = ecs.Health;
const Movement = ecs.Movement;
const Unit = ecs.Unit;
const Combat = ecs.Combat;
const BulletPool = pools.BulletPool;
const Vec2 = math.Vec2;

/// Extended world for the hex game with specialized pools
pub const HexWorld = struct {
    // Core ECS world
    ecs_world: World,

    // Specialized pools for high-frequency objects
    bullets: BulletPool,
    
    // Game-specific data
    current_zone: u32,
    player_entity: EntityId,

    pub fn init(allocator: std.mem.Allocator) !HexWorld {
        return .{
            .ecs_world = try World.init(allocator, 10000),
            .bullets = BulletPool.init(),
            .current_zone = 0,
            .player_entity = EntityId.INVALID,
        };
    }

    pub fn deinit(self: *HexWorld) void {
        self.ecs_world.deinit();
    }

    /// Create the player entity
    pub fn createPlayer(self: *HexWorld, pos: Vec2) !EntityId {
        const player = try self.ecs_world.createEntity();
        
        try self.ecs_world.transforms.add(player, Transform.init(pos, 8));
        try self.ecs_world.healths.add(player, Health.init(100));
        try self.ecs_world.movements.add(player, Movement.init(150));
        try self.ecs_world.units.add(player, Unit.init(.player, pos));
        try self.ecs_world.combats.add(player, Combat.init(25, 10)); // 25 damage, 10 shots/sec
        
        self.player_entity = player;
        return player;
    }

    /// Create an enemy unit
    pub fn createEnemy(self: *HexWorld, pos: Vec2, enemy_type: EnemyType) !EntityId {
        const enemy = try self.ecs_world.createEntity();
        
        const radius = switch (enemy_type) {
            .small => @as(f32, 6),
            .medium => @as(f32, 10),
            .large => @as(f32, 16),
        };
        
        const health = switch (enemy_type) {
            .small => @as(f32, 50),
            .medium => @as(f32, 100),
            .large => @as(f32, 200),
        };
        
        try self.ecs_world.transforms.add(enemy, Transform.init(pos, radius));
        try self.ecs_world.healths.add(enemy, Health.init(health));
        try self.ecs_world.movements.add(enemy, Movement.init(100));
        
        var unit = Unit.init(.enemy, pos);
        unit.aggro_range = 150;
        try self.ecs_world.units.add(enemy, unit);
        
        if (enemy_type != .small) {
            try self.ecs_world.combats.add(enemy, Combat.init(10, 2));
        }
        
        return enemy;
    }

    /// Fire a bullet
    pub fn fireBullet(self: *HexWorld, from: Vec2, to: Vec2, owner: EntityId) ?u16 {
        const dir = to.sub(from).normalize();
        const speed: f32 = 300;
        const vel = dir.scale(speed);
        
        // Get damage from owner's combat component
        const damage = if (self.ecs_world.combats.get(owner)) |combat|
            combat.damage
        else
            10; // Default damage
        
        return self.bullets.spawn(from, vel, owner, damage, 4.0);
    }

    pub const EnemyType = enum {
        small,
        medium,
        large,
    };
};

/// System for updating unit AI behaviors
pub fn updateUnitAI(world: *HexWorld, dt: f32) void {
    const player_pos = world.ecs_world.transforms.get(world.player_entity).?.pos;
    
    var iter = world.ecs_world.units.iterator();
    while (iter.next()) |entry| {
        const unit = entry.value;
        if (unit.unit_type != .enemy) continue;
        
        const transform = world.ecs_world.transforms.get(entry.key) orelse continue;
        const movement = world.ecs_world.movements.get(entry.key) orelse continue;
        
        const dist = transform.pos.distance(player_pos);
        
        // Update behavior state based on distance
        if (dist < unit.aggro_range * unit.aggro_factor) {
            entry.value.behavior_state = .chasing;
            entry.value.target = world.player_entity;
            
            // Move towards player
            const dir = player_pos.sub(transform.pos).normalize();
            transform.vel = dir.scale(movement.speed);
        } else {
            entry.value.behavior_state = .idle;
            entry.value.target = null;
            
            // Return to home position
            const home_dist = transform.pos.distance(unit.home_pos);
            if (home_dist > 10) {
                const dir = unit.home_pos.sub(transform.pos).normalize();
                transform.vel = dir.scale(movement.walk_speed);
            } else {
                transform.vel = Vec2.zero();
            }
        }
    }
}

/// System for updating combat
pub fn updateCombat(world: *HexWorld, current_time: f32) void {
    var iter = world.ecs_world.combats.iterator();
    while (iter.next()) |entry| {
        const combat = entry.value;
        const unit = world.ecs_world.units.get(entry.key) orelse continue;
        
        if (unit.behavior_state == .chasing and unit.target) |target| {
            if (combat.canAttack(current_time)) {
                const from = world.ecs_world.transforms.get(entry.key).?.pos;
                const to = world.ecs_world.transforms.get(target).?.pos;
                
                _ = world.fireBullet(from, to, entry.key);
                combat.recordAttack(current_time);
            }
        }
    }
}

/// System for updating physics/movement
pub fn updatePhysics(world: *HexWorld, dt: f32) void {
    // Update entity positions
    var iter = world.ecs_world.transforms.iterator();
    while (iter.next()) |entry| {
        const transform = entry.component;
        transform.pos.x += transform.vel.x * dt;
        transform.pos.y += transform.vel.y * dt;
        
        // TODO: Add collision detection
        // TODO: Add bounds checking based on zone
    }
    
    // Update bullet positions
    world.bullets.update(dt);
    
    // Check bullet collisions
    var bullet_iter = world.bullets.iterator();
    while (bullet_iter.next()) |bullet| {
        var entity_iter = world.ecs_world.transforms.iterator();
        while (entity_iter.next()) |entry| {
            // Skip self
            if (entry.entity.eql(bullet.owner)) continue;
            
            const dist = entry.component.pos.distance(bullet.pos);
            if (dist < entry.component.radius) {
                // Hit detected
                if (world.ecs_world.healths.get(entry.entity)) |health| {
                    health.damage(bullet.damage);
                    
                    // Destroy entity if dead
                    if (!health.alive) {
                        world.ecs_world.destroyEntity(entry.entity) catch {};
                    }
                }
                
                // Destroy bullet
                world.bullets.despawn(bullet.idx);
                break;
            }
        }
    }
}

/// Example of how to use the new ECS in a game loop
pub fn exampleGameLoop(world: *HexWorld, dt: f32, current_time: f32) !void {
    // Update systems in order
    updateUnitAI(world, dt);
    updateCombat(world, current_time);
    updatePhysics(world, dt);
    
    // Update effects
    var effects_iter = world.ecs_world.effects.iterator();
    while (effects_iter.next()) |entry| {
        entry.value.update(dt);
    }
    
    // Clean up dead entities
    // TODO: Implement proper cleanup system
}

test "HexWorld integration" {
    var world = try HexWorld.init(std.testing.allocator);
    defer world.deinit();
    
    const player = try world.createPlayer(Vec2.new(100, 100));
    try std.testing.expect(player.isValid());
    
    const enemy = try world.createEnemy(Vec2.new(200, 200), .medium);
    try std.testing.expect(enemy.isValid());
    
    const bullet_idx = world.fireBullet(
        Vec2.new(100, 100),
        Vec2.new(200, 200),
        player,
    );
    try std.testing.expect(bullet_idx != null);
}