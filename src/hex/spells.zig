const std = @import("std");
const math = @import("../lib/math/mod.zig");
const effects = @import("effects.zig");
const constants = @import("constants.zig");
const components = @import("../lib/game/components.zig");
const entity = @import("../lib/game/entity.zig");
const world_mod = @import("../lib/game/world.zig");
const log_throttle = @import("../lib/debug/log_throttle.zig");

const Vec2 = math.Vec2;
const Zone = @import("hex_world.zig").HexWorld.Zone;
const HexWorld = @import("hex_world.zig").HexWorld;
const EntityId = entity.EntityId;
const World = world_mod.World;

// Spell constants
const LULL_RADIUS = 150.0; // Base AoE radius - can be upgraded
const LULL_DURATION = 12.0; // Effect duration in seconds
const LULL_AGGRO_MULT = 0.3; // Reduce aggro to 30%
const LULL_COOLDOWN = 10.0;

const BLINK_MAX_DISTANCE = 200.0;
const BLINK_COOLDOWN = 3.0;

const MAX_LULL_EFFECTS = 10;

pub const SpellType = enum {
    None,
    Lull, // Reduce aggro range
    Blink, // Teleport (dungeon only)
    Shield, // Future: damage reduction
    Haste, // Future: movement speed boost
    Multishot, // Future: fire multiple bullets
    Drain, // Future: life steal
    Freeze, // Future: slow enemies
    Fireball, // Future: AoE damage
};

pub const SpellSlot = struct {
    spell_type: SpellType,
    cooldown: f32,
    cooldown_remaining: f32,

    pub fn init(spell_type: SpellType) SpellSlot {
        return .{
            .spell_type = spell_type,
            .cooldown = getSpellCooldown(spell_type),
            .cooldown_remaining = 0,
        };
    }

    pub fn canCast(self: *const SpellSlot) bool {
        return self.cooldown_remaining <= 0 and self.spell_type != .None;
    }

    pub fn startCooldown(self: *SpellSlot) void {
        self.cooldown_remaining = self.cooldown;
    }

    pub fn update(self: *SpellSlot, deltaTime: f32) void {
        if (self.cooldown_remaining > 0) {
            self.cooldown_remaining -= deltaTime;
        }
    }
};

pub const LullEffect = struct {
    pos: Vec2,
    radius: f32,
    duration: f32,
    active: bool,
};

pub const SpellSystem = struct {
    // Player has 8 spell slots (1-4, Q, E, R, F)
    spell_slots: [8]SpellSlot,
    active_slot: usize,

    // Active Lull effects (support multiple)
    lull_effects: [MAX_LULL_EFFECTS]LullEffect,

    pub fn init() SpellSystem {
        var system = SpellSystem{
            .spell_slots = undefined,
            .active_slot = 0,
            .lull_effects = std.mem.zeroes([MAX_LULL_EFFECTS]LullEffect),
        };

        // Initialize spell slots
        system.spell_slots[0] = SpellSlot.init(.Lull); // Slot 1
        system.spell_slots[1] = SpellSlot.init(.Blink); // Slot 2
        for (2..8) |i| {
            system.spell_slots[i] = SpellSlot.init(.None); // Empty slots
        }

        return system;
    }

    pub fn update(self: *SpellSystem, deltaTime: f32) void {
        // Update all spell cooldowns
        for (0..8) |i| {
            self.spell_slots[i].update(deltaTime);
        }

        // Update lull effects
        for (0..self.lull_effects.len) |i| {
            if (self.lull_effects[i].active) {
                self.lull_effects[i].duration -= deltaTime;
                if (self.lull_effects[i].duration <= 0) {
                    self.lull_effects[i].active = false;
                }
            }
        }
    }

    pub fn setActiveSlot(self: *SpellSystem, slot: usize) void {
        if (slot < 8) {
            self.active_slot = slot;
        }
    }

    pub fn castActiveSpell(self: *SpellSystem, world: *HexWorld, zone: *const Zone, target_pos: Vec2, effect_system: *effects.EffectSystem, self_cast: bool) bool {
        const slot = &self.spell_slots[self.active_slot];
        if (!slot.canCast()) return false;

        // If self-cast, target player position
        const actual_target = if (self_cast) world.getPlayerPos() else target_pos;

        const success = self.castSpell(slot.spell_type, world, zone, actual_target, effect_system);
        if (success) {
            slot.startCooldown();
        }
        return success;
    }

    pub fn castSpell(self: *SpellSystem, spell: SpellType, world: *HexWorld, zone: *const Zone, target_pos: Vec2, effect_system: *effects.EffectSystem) bool {
        _ = self;
        switch (spell) {
            .None => return false,

            .Lull => {
                // Apply lull effect to all units in area using ECS Effects
                applyLullEffectToUnitsInArea(world, target_pos, LULL_RADIUS, LULL_DURATION, effect_system);

                // Add area of effect visual indicator
                effect_system.addLullAreaEffect(target_pos, LULL_RADIUS, LULL_DURATION);

                log_throttle.logInfo("lull_cast", "Lull cast at ({d:.0}, {d:.0}) - AoE aggro reduction for {d}s", .{ target_pos.x, target_pos.y, LULL_DURATION });
                return true;
            },

            .Blink => {
                // Only works in dungeons (follow camera mode)
                if (zone.camera_mode != constants.CameraMode.follow) {
                    log_throttle.logInfo("blink_dungeon_only", "Blink only works in dungeons", .{});
                    return false;
                }

                // Teleport player to target position
                const player_pos = world.getPlayerPos();
                const to_target = target_pos.sub(player_pos);
                const distance = to_target.length();

                if (distance > BLINK_MAX_DISTANCE) {
                    // Limit blink distance
                    const direction = to_target.normalize();
                    const new_pos = player_pos.add(direction.scale(BLINK_MAX_DISTANCE));
                    world.setPlayerPos(new_pos);
                } else {
                    world.setPlayerPos(target_pos);
                }

                // Visual effects
                effect_system.addPortalTravelEffect(world.getPlayerPos(), world.getPlayerRadius());
                log_throttle.logInfo("blink_teleport", "Blink teleport", .{});
                return true;
            },

            else => {
                log_throttle.logInfo("unimplemented_spell", "Spell {} not implemented yet", .{spell});
                return false;
            },
        }
    }

    /// Apply lull effect to all units in the specified area using ECS Effects
    fn applyLullEffectToUnitsInArea(world: *HexWorld, center_pos: Vec2, radius: f32, duration: f32, effect_system: *effects.EffectSystem) void {
        const ecs_world = world.getECSWorld();

        // Query all units and check if they're in the area
        var unit_iter = @constCast(&ecs_world.units).iterator();
        while (unit_iter.next()) |entry| {
            const unit_id = entry.key_ptr.*;

            // Skip if unit is not alive
            var ecs_world_mut = @constCast(ecs_world);
            if (!ecs_world_mut.isAlive(unit_id)) continue;

            // Get unit position
            if (ecs_world.transforms.getConst(unit_id)) |transform| {
                // Check if unit is within the lull area
                const to_center = transform.pos.sub(center_pos);
                const dist_sq = to_center.lengthSquared();
                const radius_sq = radius * radius;

                if (dist_sq <= radius_sq) {
                    // Unit is in area - apply lull effect
                    applyLullEffectToUnit(ecs_world_mut, unit_id, duration, transform.pos, transform.radius, effect_system);
                }
            }
        }
    }

    /// Apply lull effect to a specific unit using ECS Effects component
    fn applyLullEffectToUnit(ecs_world: *World, unit_id: EntityId, duration: f32, unit_pos: Vec2, unit_radius: f32, effect_system: *effects.EffectSystem) void {

        // Get or create Effects component for this unit
        const effects_component = ecs_world.effects.get(unit_id) orelse blk: {
            // Create new Effects component
            const new_effects = @import("../lib/game/components.zig").Effects.init();
            ecs_world.effects.add(unit_id, new_effects) catch return;
            break :blk ecs_world.effects.get(unit_id).?;
        };

        // Add lull modifier
        const lull_modifier = @import("../lib/game/components.zig").Effects.Modifier{
            .type = .aggro_mult,
            .value = LULL_AGGRO_MULT,
            .duration = duration,
            .stack_type = .replace, // New lull replaces old
            .source = unit_id, // Self-applied for now
        };

        effects_component.addModifier(lull_modifier) catch return;

        // Add visual effect aura around the affected unit
        effect_system.addUnitEffectAura(unit_pos, unit_radius, duration);
    }

    pub fn getAggroMultiplierForUnit(self: *const SpellSystem, unit_pos: Vec2) f32 {
        _ = self; // Legacy method - no longer uses SpellSystem state
        _ = unit_pos; // Position-based lookup is deprecated
        return 1.0; // Fallback - ECS method should be used instead
    }

    /// Get aggro multiplier for a unit using ECS Effects component
    pub fn getAggroMultiplierForUnitECS(unit_id: EntityId, ecs_world: *const World) f32 {
        // Get Effects component for this unit
        if (ecs_world.effects.getConst(unit_id)) |effects_component| {
            // Check for aggro multiplier effects
            return effects_component.getAggroMultiplier();
        }
        return 1.0; // No effects, normal aggro
    }
};

fn getSpellCooldown(spell: SpellType) f32 {
    return switch (spell) {
        .None => 0,
        .Lull => LULL_COOLDOWN,
        .Blink => BLINK_COOLDOWN,
        .Shield => 15.0, // Future
        .Haste => 20.0, // Future
        .Multishot => 8.0, // Future
        .Drain => 12.0, // Future
        .Freeze => 10.0, // Future
        .Fireball => 6.0, // Future
    };
}
