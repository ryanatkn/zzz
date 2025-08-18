const std = @import("std");
const math = @import("../../math/mod.zig");
const Vec2 = math.Vec2;

/// Generic spell casting patterns and interfaces
/// Games implement specific spell logic using these patterns
/// Spell targeting types
pub const TargetType = enum {
    none, // No target required
    position, // Target a position on the ground
    self, // Target the caster
    entity, // Target a specific entity
    area, // Area of effect around a position
    direction, // Cast in a direction
    line, // Line from caster in a direction
};

/// Spell targeting configuration
pub const TargetConfig = struct {
    target_type: TargetType,
    max_range: f32 = 1000.0,
    min_range: f32 = 0.0,
    requires_line_of_sight: bool = false,
    can_target_self: bool = true,
    can_target_allies: bool = true,
    can_target_enemies: bool = true,
    area_radius: f32 = 0.0, // For AoE spells
};

/// Spell casting restrictions
pub const CastingRestrictions = struct {
    requires_alive_caster: bool = true,
    requires_mana: f32 = 0.0,
    requires_zone_type: ?ZoneTypeFilter = null,
    blocked_by_silence: bool = true,
    blocked_by_stun: bool = true,
    requires_weapon: bool = false,
    requires_clear_path: bool = false,

    pub const ZoneTypeFilter = enum {
        overworld_only,
        dungeon_only,
        any,
    };
};

/// Spell validation result
pub const ValidationResult = union(enum) {
    valid,
    invalid_range: struct { actual: f32, max: f32 },
    invalid_target,
    blocked_by_obstacle,
    insufficient_mana: f32,
    wrong_zone_type,
    caster_silenced,
    caster_stunned,
    caster_dead,
    no_line_of_sight,
    target_immune,
};

/// Spell targeting patterns
pub const SpellTargeting = struct {
    /// Validate a spell cast attempt
    pub fn validateCast(
        caster_pos: Vec2,
        target_pos: Vec2,
        config: TargetConfig,
        restrictions: CastingRestrictions,
        context: anytype, // Game-specific context
    ) ValidationResult {
        // Range validation
        const distance = caster_pos.distance(target_pos);
        if (distance > config.max_range) {
            return ValidationResult{ .invalid_range = .{ .actual = distance, .max = config.max_range } };
        }
        if (distance < config.min_range) {
            return ValidationResult{ .invalid_range = .{ .actual = distance, .max = config.min_range } };
        }

        // Game-specific validations would go here using context
        _ = restrictions;
        _ = context;

        return ValidationResult.valid;
    }

    /// Calculate area of effect positions
    pub fn calculateAoEPositions(
        center: Vec2,
        radius: f32,
        allocator: std.mem.Allocator,
    ) !std.ArrayList(Vec2) {
        var positions = std.ArrayList(Vec2).init(allocator);

        // Simple circular AoE - games can implement more complex shapes
        const step_size: f32 = 10.0; // 10 unit grid
        const radius_sq = radius * radius;

        var y: f32 = -radius;
        while (y <= radius) : (y += step_size) {
            var x: f32 = -radius;
            while (x <= radius) : (x += step_size) {
                if (x * x + y * y <= radius_sq) {
                    try positions.append(center.add(Vec2.init(x, y)));
                }
            }
        }

        return positions;
    }

    /// Get targets in an area (interface for game implementation)
    pub fn getTargetsInArea(
        center: Vec2,
        radius: f32,
        context: anytype,
        comptime target_filter: anytype,
    ) std.ArrayList(@TypeOf(target_filter).TargetType) {
        return target_filter.getTargetsInArea(center, radius, context);
    }

    /// Calculate spell trajectory for projectile spells
    pub fn calculateTrajectory(
        start_pos: Vec2,
        target_pos: Vec2,
        projectile_speed: f32,
        gravity: f32,
    ) SpellTrajectory {
        const direction = target_pos.sub(start_pos).normalize();
        const distance = start_pos.distance(target_pos);
        const travel_time = distance / projectile_speed;

        return SpellTrajectory{
            .start_pos = start_pos,
            .direction = direction,
            .speed = projectile_speed,
            .gravity = gravity,
            .travel_time = travel_time,
        };
    }
};

/// Spell trajectory data for projectile spells
pub const SpellTrajectory = struct {
    start_pos: Vec2,
    direction: Vec2,
    speed: f32,
    gravity: f32,
    travel_time: f32,

    /// Get position along trajectory at time t
    pub fn getPositionAtTime(self: SpellTrajectory, time: f32) Vec2 {
        const linear_pos = self.start_pos.add(self.direction.scale(self.speed * time));
        const gravity_offset = Vec2.init(0, -0.5 * self.gravity * time * time);
        return linear_pos.add(gravity_offset);
    }
};

/// Spell effect patterns
pub const SpellEffects = struct {
    /// Apply instant damage/healing
    pub fn applyInstantEffect(
        target_pos: Vec2,
        effect_value: f32,
        effect_type: EffectType,
        context: anytype,
    ) void {
        // Game implements the actual effect application
        context.applyInstantEffect(target_pos, effect_value, effect_type);
    }

    /// Apply damage over time
    pub fn applyDurationEffect(
        target_pos: Vec2,
        effect_value: f32,
        duration: f32,
        tick_interval: f32,
        effect_type: EffectType,
        context: anytype,
    ) void {
        // Game implements the duration effect application
        context.applyDurationEffect(target_pos, effect_value, duration, tick_interval, effect_type);
    }

    pub const EffectType = enum {
        damage,
        healing,
        mana_restore,
        buff,
        debuff,
        teleport,
        summon,
        environmental,
    };
};

/// Spell casting interface for games to implement
pub const SpellCastingInterface = struct {
    /// Function signature for spell validation
    pub const ValidateFn = *const fn (caster: anytype, target: anytype, spell_id: anytype) ValidationResult;

    /// Function signature for spell execution
    pub const ExecuteFn = *const fn (caster: anytype, target: anytype, spell_id: anytype) bool;

    /// Function signature for spell effect application
    pub const ApplyEffectFn = *const fn (targets: anytype, effect: anytype) void;
};

/// Example spell implementation pattern
pub fn ExampleSpellImplementation(comptime GameType: type, comptime SpellId: type) type {
    return struct {
        const Self = @This();

        /// Validate if a spell can be cast
        pub fn validateSpell(
            game: *GameType,
            caster_pos: Vec2,
            target_pos: Vec2,
            spell_id: SpellId,
        ) ValidationResult {
            // Game-specific spell validation logic
            _ = game;
            _ = caster_pos;
            _ = target_pos;
            _ = spell_id;
            return ValidationResult.valid;
        }

        /// Execute spell cast
        pub fn castSpell(
            game: *GameType,
            caster_pos: Vec2,
            target_pos: Vec2,
            spell_id: SpellId,
        ) bool {
            // Game-specific spell casting logic
            _ = game;
            _ = caster_pos;
            _ = target_pos;
            _ = spell_id;
            return true;
        }
    };
}
