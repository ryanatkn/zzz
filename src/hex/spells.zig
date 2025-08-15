const std = @import("std");
const types = @import("../lib/core/types.zig");
const entities = @import("entities.zig");
const effects = @import("effects.zig");
const constants = @import("constants.zig");

const Vec2 = types.Vec2;
const Zone = entities.Zone;
const HexWorld = @import("hex_world.zig").HexWorld;

// Spell constants
const LULL_RADIUS = 150.0; // Base AoE radius - can be upgraded
const LULL_DURATION = 12.0; // Effect duration in seconds
const LULL_AGGRO_MULT = 0.2; // Reduce aggro to 20%
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
        switch (spell) {
            .None => return false,

            .Lull => {
                // Find an inactive lull effect slot
                for (0..self.lull_effects.len) |i| {
                    if (!self.lull_effects[i].active) {
                        self.lull_effects[i] = .{
                            .pos = target_pos,
                            .radius = LULL_RADIUS,
                            .duration = LULL_DURATION,
                            .active = true,
                        };

                        // Add area of effect visual indicator that matches the actual effect
                        effect_system.addLullAreaEffect(target_pos, LULL_RADIUS, LULL_DURATION);

                        std.debug.print("Lull cast at ({d:.0}, {d:.0}) - AoE aggro reduction for {d}s\n", .{ target_pos.x, target_pos.y, LULL_DURATION });
                        return true;
                    }
                }
                std.debug.print("Max lull effects active\n", .{});
                return false;
            },

            .Blink => {
                // Only works in dungeons (follow camera mode)
                if (zone.camera_mode != entities.CameraMode.follow) {
                    std.debug.print("Blink only works in dungeons\n", .{});
                    return false;
                }

                // Teleport player to target position
                const player_pos = world.getPlayerPos();
                const dx = target_pos.x - player_pos.x;
                const dy = target_pos.y - player_pos.y;
                const distance = @sqrt(dx * dx + dy * dy);

                if (distance > BLINK_MAX_DISTANCE) {
                    // Limit blink distance
                    const scale = BLINK_MAX_DISTANCE / distance;
                    const new_pos = Vec2{
                        .x = player_pos.x + dx * scale,
                        .y = player_pos.y + dy * scale,
                    };
                    world.setPlayerPos(new_pos);
                } else {
                    world.setPlayerPos(target_pos);
                }

                // Visual effects
                effect_system.addPortalTravelEffect(world.getPlayerPos(), world.getPlayerRadius());
                std.debug.print("Blink teleport\n", .{});
                return true;
            },

            else => {
                std.debug.print("Spell {} not implemented yet\n", .{spell});
                return false;
            },
        }
    }

    pub fn getAggroMultiplierForUnit(self: *const SpellSystem, unit_pos: Vec2) f32 {
        // Check if unit is within any active lull effect
        for (0..self.lull_effects.len) |i| {
            if (self.lull_effects[i].active) {
                const dx = unit_pos.x - self.lull_effects[i].pos.x;
                const dy = unit_pos.y - self.lull_effects[i].pos.y;
                const dist_sq = dx * dx + dy * dy;
                const radius_sq = self.lull_effects[i].radius * self.lull_effects[i].radius;

                if (dist_sq <= radius_sq) {
                    return LULL_AGGRO_MULT;
                }
            }
        }
        return 1.0;
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
