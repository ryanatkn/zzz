const std = @import("std");
const math = @import("../lib/math/mod.zig");
const GameEffectSystem = @import("../lib/effects/game_effects.zig").GameEffectSystem;
const constants = @import("constants.zig");
const ecs = @import("../lib/game/ecs.zig");
const loggers = @import("../lib/debug/loggers.zig");
const hex_game_mod = @import("hex_game.zig");
const game_abilities = @import("../lib/game/abilities/mod.zig");
const HexGameContext = @import("hex_context.zig").HexGameContext;

const Vec2 = math.Vec2;
const ZoneData = hex_game_mod.HexGame.ZoneData;
const HexGame = hex_game_mod.HexGame;
const EntityId = hex_game_mod.EntityId;

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

// Use generic spell slot system from lib/game
const SpellSlotSystem = game_abilities.spell_slots.SpellSlotSystem(SpellType, 8);
pub const SpellSlot = game_abilities.spell_slots.SpellSlot(SpellType);

pub const LullEffect = struct {
    pos: Vec2,
    radius: f32,
    duration: f32,
    active: bool,
};

pub const SpellSystem = struct {
    // Use generic spell slot system
    slot_system: SpellSlotSystem,

    // Active Lull effects (support multiple)
    lull_effects: [constants.MAX_LULL_EFFECTS]LullEffect,

    pub fn init() SpellSystem {
        var system = SpellSystem{
            .slot_system = SpellSlotSystem.init(),
            .lull_effects = std.mem.zeroes([constants.MAX_LULL_EFFECTS]LullEffect),
        };

        // Initialize spell slots with specific spells and cooldowns
        system.slot_system.setSpell(0, .Lull, getSpellCooldown(.Lull)); // Slot 1
        system.slot_system.setSpell(1, .Blink, getSpellCooldown(.Blink)); // Slot 2
        // Slots 2-7 remain as .None (default)

        return system;
    }

    /// Context-aware spell system update function
    pub fn update(self: *SpellSystem, context: HexGameContext) void {
        const contexts = @import("../lib/game/contexts/mod.zig");
        const deltaTime = contexts.ContextUtils.effectiveDeltaTime(context);
        
        // Update all spell cooldowns using generic system
        self.slot_system.update(deltaTime);

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
        self.slot_system.setActiveSlot(slot);
    }

    // Compatibility accessors for existing hex code
    pub fn getSlot(self: *const SpellSystem, slot_index: usize) ?*const SpellSlot {
        return self.slot_system.getSlot(slot_index);
    }

    pub fn getSlotMut(self: *SpellSystem, slot_index: usize) ?*SpellSlot {
        return self.slot_system.getSlotMut(slot_index);
    }

    pub fn getActiveSlot(self: *const SpellSystem) *const SpellSlot {
        return self.slot_system.getActiveSlot();
    }

    pub fn castActiveSpell(self: *SpellSystem, game: *HexGame, zone: *const hex_game_mod.HexGame.ZoneData, target_pos: Vec2, effect_system: *GameEffectSystem, self_cast: bool) bool {
        const slot = self.slot_system.getActiveSlotMut();
        if (!slot.canCast()) return false;

        // If self-cast, target player position
        const actual_target = if (self_cast) game.getPlayerPos() else target_pos;

        const success = self.castSpell(slot.spell_type, game, zone, actual_target, effect_system);
        if (success) {
            slot.startCooldown();
        }
        return success;
    }

    pub fn castSpell(self: *SpellSystem, spell: SpellType, game: *HexGame, zone: *const hex_game_mod.HexGame.ZoneData, target_pos: Vec2, effect_system: *GameEffectSystem) bool {
        _ = self;
        switch (spell) {
            .None => return false,

            .Lull => {
                // Apply lull effect to all units in area using ECS Effects
                applyLullEffectToUnitsInArea(game, target_pos, constants.LULL_RADIUS, constants.LULL_DURATION, effect_system);

                // Add area of effect visual indicator
                effect_system.addLullAreaEffect(target_pos, constants.LULL_RADIUS, constants.LULL_DURATION);

                loggers.getGameLog().info("lull_cast", "Lull cast at ({d:.0}, {d:.0}) - AoE aggro reduction for {d}s", .{ target_pos.x, target_pos.y, constants.LULL_DURATION });
                return true;
            },

            .Blink => {
                // Only works in dungeons (follow camera mode)
                if (zone.camera_mode != constants.CameraMode.follow) {
                    loggers.getGameLog().info("blink_dungeon_only", "Blink only works in dungeons", .{});
                    return false;
                }

                // Teleport player to target position
                const player_pos = game.getPlayerPos();
                const to_target = target_pos.sub(player_pos);
                const distance = to_target.length();

                if (distance > constants.BLINK_MAX_DISTANCE) {
                    // Limit blink distance
                    const direction = to_target.normalize();
                    const new_pos = player_pos.add(direction.scale(constants.BLINK_MAX_DISTANCE));
                    game.setPlayerPos(new_pos);
                } else {
                    game.setPlayerPos(target_pos);
                }

                // Visual effects
                effect_system.addPortalTravelEffect(game.getPlayerPos(), game.getPlayerRadius());
                loggers.getGameLog().info("blink_teleport", "Blink teleport", .{});
                return true;
            },

            else => {
                loggers.getGameLog().info("unimplemented_spell", "Spell {} not implemented yet", .{spell});
                return false;
            },
        }
    }

    /// Apply lull effect to all units in the specified area using simplified HexGame storage
    fn applyLullEffectToUnitsInArea(game: *HexGame, center_pos: Vec2, radius: f32, duration: f32, effect_system: *GameEffectSystem) void {
        const zone = game.getCurrentZone();
        const radius_sq = radius * radius;

        // Check all units in current zone
        for (0..zone.units.count) |i| {
            const transform = &zone.units.transforms[i];
            const health = &zone.units.healths[i];
            const unit = &zone.units.units[i];

            // Skip if unit is not alive
            if (!health.alive) continue;

            // Check if unit is within the lull area
            const to_center = transform.pos.sub(center_pos);
            const dist_sq = to_center.lengthSquared();

            if (dist_sq <= radius_sq) {
                // Unit is in area - apply lull effect by reducing aggro factor
                unit.aggro_factor = 0.2; // 20% aggro as per constants

                // Add visual effect for this unit (optional)
                effect_system.addUnitEffectAura(transform.pos, transform.radius, duration);

                loggers.getGameLog().info("lull_unit_affected", "Unit at ({d:.0}, {d:.0}) affected by lull", .{ transform.pos.x, transform.pos.y });
            }
        }
    }

    /// Get aggro multiplier for a specific unit
    pub fn getAggroMultiplierForUnit(unit_id: hex_game_mod.EntityId, zone_storage: *const hex_game_mod.HexGame.ZoneData) f32 {
        // For now, return 1.0 (no modification)
        // Lull effect checking for units (implemented with aggro modifier)
        _ = unit_id;
        _ = zone_storage;
        return 1.0;
    }
};

fn getSpellCooldown(spell: SpellType) f32 {
    return switch (spell) {
        .None => 0,
        .Lull => constants.LULL_COOLDOWN,
        .Blink => constants.BLINK_COOLDOWN,
        .Shield => 15.0, // Future
        .Haste => 20.0, // Future
        .Multishot => 8.0, // Future
        .Drain => 12.0, // Future
        .Freeze => 10.0, // Future
        .Fireball => 6.0, // Future
    };
}
