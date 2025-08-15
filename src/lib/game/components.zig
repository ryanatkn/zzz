const std = @import("std");
const types = @import("../core/types.zig");
pub const Vec2 = types.Vec2;
const Color = types.Color;
const BoundedArray = std.BoundedArray;
const entity = @import("entity.zig");
const EntityId = entity.EntityId;

/// Transform - universal positioning component
/// Dense storage - almost all entities have this
pub const Transform = extern struct {
    pos: Vec2,
    vel: Vec2,
    radius: f32,
    _padding: f32 = 0, // For alignment

    pub fn init(pos: Vec2, radius: f32) Transform {
        return .{
            .pos = pos,
            .vel = Vec2{ .x = 0, .y = 0 },
            .radius = radius,
        };
    }
};

/// Health - life management component
/// Dense storage - most gameplay entities have this
pub const Health = struct {
    current: f32,
    max: f32,
    alive: bool,

    pub fn init(max_health: f32) Health {
        return .{
            .current = max_health,
            .max = max_health,
            .alive = true,
        };
    }

    pub fn damage(self: *Health, amount: f32) void {
        self.current = @max(0, self.current - amount);
        if (self.current <= 0) {
            self.alive = false;
        }
    }

    pub fn heal(self: *Health, amount: f32) void {
        self.current = @min(self.max, self.current + amount);
        if (self.current > 0) {
            self.alive = true;
        }
    }

    pub fn getPercent(self: Health) f32 {
        return if (self.max > 0) self.current / self.max else 0;
    }
};

/// Movement - locomotion properties
/// Dense storage - most moving entities have this
pub const Movement = struct {
    speed: f32,
    walk_speed: f32,
    can_move_freely: bool,

    pub fn init(speed: f32) Movement {
        return .{
            .speed = speed,
            .walk_speed = speed * 0.5,
            .can_move_freely = true,
        };
    }

    pub fn getCurrentSpeed(self: Movement, is_walking: bool) f32 {
        return if (is_walking) self.walk_speed else self.speed;
    }
};

/// Visual - rendering properties
/// Dense storage - all visible entities have this
pub const Visual = struct {
    color: Color,
    scale: f32,
    visible: bool,
    z_order: i32, // For layering

    pub fn init(color: Color) Visual {
        return .{
            .color = color,
            .scale = 1.0,
            .visible = true,
            .z_order = 0,
        };
    }
};

/// Unit - core gameplay entity component
/// Sparse storage - only actual units have this
pub const Unit = struct {
    pub const UnitType = enum {
        player,
        enemy,
        friendly,
        neutral,
    };

    pub const BehaviorState = enum {
        idle,
        chasing,
        attacking,
        fleeing,
        patrolling,
    };

    unit_type: UnitType,
    aggro_range: f32,
    aggro_factor: f32,
    home_pos: Vec2,
    behavior_state: BehaviorState,
    target: ?EntityId,

    pub fn init(unit_type: UnitType, home_pos: Vec2) Unit {
        return .{
            .unit_type = unit_type,
            .aggro_range = switch (unit_type) {
                .enemy => 150.0,
                .friendly => 100.0,
                else => 0.0,
            },
            .aggro_factor = 1.0,
            .home_pos = home_pos,
            .behavior_state = .idle,
            .target = null,
        };
    }
};

/// Combat - offensive capabilities
/// Sparse storage - only combatants have this
pub const Combat = struct {
    damage: f32,
    attack_rate: f32, // Attacks per second
    projectile_speed: f32,
    projectile_lifetime: f32,
    last_attack_time: f32,

    pub fn init(damage: f32, attack_rate: f32) Combat {
        return .{
            .damage = damage,
            .attack_rate = attack_rate,
            .projectile_speed = 300.0,
            .projectile_lifetime = 4.0,
            .last_attack_time = 0,
        };
    }

    pub fn canAttack(self: Combat, current_time: f32) bool {
        return (current_time - self.last_attack_time) >= (1.0 / self.attack_rate);
    }

    pub fn recordAttack(self: *Combat, current_time: f32) void {
        self.last_attack_time = current_time;
    }
};

/// Effects - temporary modifiers that stack
/// Sparse storage - only affected entities have this
pub const Effects = struct {
    pub const ModifierType = enum {
        speed_mult,
        damage_mult,
        aggro_mult,
        cooldown_mult,
        radius_mult,
        health_regen,
        damage_resist,
    };

    pub const StackType = enum {
        replace, // New replaces old
        add, // Values add together
        multiply, // Values multiply
        max, // Take maximum value
        min, // Take minimum value
    };

    pub const Modifier = struct {
        type: ModifierType,
        value: f32,
        duration: f32,
        stack_type: StackType,
        source: EntityId,
    };

    modifiers: BoundedArray(Modifier, 16),

    pub fn init() Effects {
        return .{
            .modifiers = BoundedArray(Modifier, 16).init(0) catch unreachable,
        };
    }

    pub fn addModifier(self: *Effects, modifier: Modifier) !void {
        try self.modifiers.append(modifier);
    }

    pub fn update(self: *Effects, dt: f32) void {
        var i: usize = 0;
        while (i < self.modifiers.len) {
            self.modifiers.buffer[i].duration -= dt;
            if (self.modifiers.buffer[i].duration <= 0) {
                _ = self.modifiers.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    pub fn getModifiedValue(self: Effects, base: f32, modifier_type: ModifierType) f32 {
        var result = base;
        var multiplicative: f32 = 1.0;

        for (self.modifiers.slice()) |mod| {
            if (mod.type != modifier_type) continue;

            switch (mod.stack_type) {
                .replace => result = mod.value,
                .add => result += mod.value - base,
                .multiply => multiplicative *= mod.value,
                .max => result = @max(result, mod.value),
                .min => result = @min(result, mod.value),
            }
        }

        return result * multiplicative;
    }
    
    /// Get aggro multiplier for this entity (1.0 = normal aggro)
    pub fn getAggroMultiplier(self: Effects) f32 {
        return self.getModifiedValue(1.0, .aggro_mult);
    }
};

/// PlayerInput - distinguishes player-controlled entities
/// Sparse storage - only player entities have this
pub const PlayerInput = struct {
    controller_id: u8,

    pub fn init(controller_id: u8) PlayerInput {
        return .{
            .controller_id = controller_id,
        };
    }
};

/// Projectile - for moving projectile entities (bullets, spells, etc.)
/// Sparse storage - only projectiles have this
pub const Projectile = struct {
    owner: EntityId,
    lifetime: f32,
    max_lifetime: f32,
    pierce_count: u8,
    max_pierce: u8,
    
    pub fn init(owner: EntityId, max_lifetime: f32) Projectile {
        return .{
            .owner = owner,
            .lifetime = 0,
            .max_lifetime = max_lifetime,
            .pierce_count = 0,
            .max_pierce = 1,
        };
    }
    
    pub fn update(self: *Projectile, dt: f32) bool {
        self.lifetime += dt;
        return self.lifetime < self.max_lifetime and self.pierce_count < self.max_pierce;
    }
    
    pub fn canPierce(self: Projectile) bool {
        return self.pierce_count < self.max_pierce;
    }
    
    pub fn pierce(self: *Projectile) void {
        self.pierce_count += 1;
    }
};

/// Terrain - for static/semi-static world geometry
/// Sparse storage - only terrain entities have this
pub const Terrain = struct {
    pub const TerrainType = enum {
        wall,
        floor,
        door,
        water,
        pit,
        altar,
    };
    
    solid: bool,
    blocks_sight: bool,
    terrain_type: TerrainType,
    
    pub fn init(terrain_type: TerrainType) Terrain {
        return .{
            .solid = switch (terrain_type) {
                .wall, .door => true,
                else => false,
            },
            .blocks_sight = switch (terrain_type) {
                .wall, .door => true,
                else => false,
            },
            .terrain_type = terrain_type,
        };
    }
};

/// Awakeable - enables terrain/objects to come alive
/// Sparse storage - only potentially living entities have this
pub const Awakeable = struct {
    pub const TriggerType = enum {
        damage_threshold,
        spell_target,
        proximity,
        time_elapsed,
        player_touch,
    };
    
    pub const EntityType = enum {
        basic_creature,
        animated_wall,
        living_floor,
        guardian_statue,
    };
    
    trigger_condition: TriggerType,
    awakened_entity_type: EntityType,
    trigger_value: f32, // Threshold/timer/distance etc.
    current_value: f32,
    
    pub fn init(trigger: TriggerType, entity_type: EntityType, trigger_value: f32) Awakeable {
        return .{
            .trigger_condition = trigger,
            .awakened_entity_type = entity_type,
            .trigger_value = trigger_value,
            .current_value = 0,
        };
    }
    
    pub fn checkTrigger(self: *Awakeable, value: f32) bool {
        self.current_value = value;
        return switch (self.trigger_condition) {
            .damage_threshold, .time_elapsed => value >= self.trigger_value,
            .proximity => value <= self.trigger_value,
            .spell_target, .player_touch => value > 0,
        };
    }
};

/// Interactable - enables entity interactions (deflection, telekinesis, etc.)
/// Sparse storage - only interactive entities have this
pub const Interactable = struct {
    pub const InteractionType = enum {
        deflectable,      // Can be deflected by spells/abilities
        telekinetic,      // Can be moved by telekinesis
        transformable,    // Can be polymorphed
        combinable,       // Can merge with other entities
        splittable,       // Can split into multiple entities
    };
    
    pub const InteractionState = enum {
        normal,
        being_deflected,
        being_moved,
        transforming,
        combining,
        splitting,
    };
    
    interaction_type: InteractionType,
    state: InteractionState,
    interaction_timer: f32,
    interaction_data: union(enum) {
        deflect: struct {
            new_direction: Vec2,
            force: f32,
        },
        telekinesis: struct {
            target_pos: Vec2,
            controller: EntityId,
        },
        transform: struct {
            target_type: Unit.UnitType,
            progress: f32,
        },
        none: void,
    },
    
    pub fn init(interaction_type: InteractionType) Interactable {
        return .{
            .interaction_type = interaction_type,
            .state = .normal,
            .interaction_timer = 0,
            .interaction_data = .none,
        };
    }
    
    pub fn startDeflection(self: *Interactable, direction: Vec2, force: f32) void {
        if (self.interaction_type == .deflectable) {
            self.state = .being_deflected;
            self.interaction_timer = 0.5; // 0.5 second deflection
            self.interaction_data = .{ .deflect = .{ .new_direction = direction, .force = force } };
        }
    }
    
    pub fn update(self: *Interactable, dt: f32) void {
        if (self.state != .normal) {
            self.interaction_timer -= dt;
            if (self.interaction_timer <= 0) {
                self.state = .normal;
                self.interaction_data = .none;
            }
        }
    }
};

// Game-specific components can be added in the game implementation
// These are just the core/common ones that most games would need

test "Transform component" {
    const t = Transform.init(Vec2.new(100, 200), 16);
    try std.testing.expect(t.pos.x == 100);
    try std.testing.expect(t.radius == 16);
}

test "Health component" {
    var h = Health.init(100);
    try std.testing.expect(h.alive);
    h.damage(50);
    try std.testing.expect(h.current == 50);
    h.damage(60);
    try std.testing.expect(!h.alive);
}

test "Effects stacking" {
    var effects = Effects.init();
    try effects.addModifier(.{
        .type = .speed_mult,
        .value = 1.5,
        .duration = 10,
        .stack_type = .multiply,
        .source = EntityId.INVALID,
    });

    const modified = effects.getModifiedValue(100, .speed_mult);
    try std.testing.expect(modified == 150);
}