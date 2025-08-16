const std = @import("std");
const math = @import("../lib/math/mod.zig");
const GameEffectSystem = @import("../lib/effects/game_effects.zig").GameEffectSystem;
const constants = @import("constants.zig");
const components = @import("../lib/game/components.zig");
const entity = @import("../lib/game/entity.zig");
const world_mod = @import("../lib/game/world.zig");
const ecs = @import("../lib/game/ecs.zig");
const loggers = @import("../lib/debug/loggers.zig");
const hex_game_mod = @import("hex_game.zig");
const cooldowns = @import("../lib/game/cooldowns.zig");

const Vec2 = math.Vec2;
const ZoneData = hex_game_mod.HexGame.ZoneData;
const HexGame = hex_game_mod.HexGame;
const EntityId = entity.EntityId;
const World = world_mod.World;

// Import spell constants from centralized location

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
    cooldown_timer: cooldowns.Cooldown,

    pub fn init(spell_type: SpellType) SpellSlot {
        return .{
            .spell_type = spell_type,
            .cooldown_timer = cooldowns.Cooldown.init(getSpellCooldown(spell_type)),
        };
    }

    pub fn canCast(self: *const SpellSlot) bool {
        return self.cooldown_timer.isReady() and self.spell_type != .None;
    }

    pub fn startCooldown(self: *SpellSlot) void {
        self.cooldown_timer.start();
    }

    pub fn update(self: *SpellSlot, deltaTime: f32) void {
        self.cooldown_timer.update(deltaTime);
    }

    pub fn getRemainingTime(self: *const SpellSlot) f32 {
        return self.cooldown_timer.getRemaining();
    }

    pub fn getProgress(self: *const SpellSlot) f32 {
        return self.cooldown_timer.getProgress();
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
    lull_effects: [constants.MAX_LULL_EFFECTS]LullEffect,

    pub fn init() SpellSystem {
        var system = SpellSystem{
            .spell_slots = undefined,
            .active_slot = 0,
            .lull_effects = std.mem.zeroes([constants.MAX_LULL_EFFECTS]LullEffect),
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

    pub fn castActiveSpell(self: *SpellSystem, game: *HexGame, zone: *const hex_game_mod.HexGame.ZoneData, target_pos: Vec2, effect_system: *GameEffectSystem, self_cast: bool) bool {
        const slot = &self.spell_slots[self.active_slot];
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
