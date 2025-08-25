const std = @import("std");
const math = @import("../lib/math/mod.zig");
const GameParticleSystem = @import("../lib/particles/game_particles.zig").GameParticleSystem;
const constants = @import("constants.zig");
const loggers = @import("../lib/debug/loggers.zig");
const world_state_mod = @import("world_state.zig");
const frame = @import("../lib/core/frame.zig");
const game_abilities = @import("../lib/game/abilities/mod.zig");
const effect_manager = game_abilities.effect_manager;

// Import modular ability implementations
const abilities = @import("abilities/mod.zig");

const Vec2 = math.Vec2;
const ZoneData = world_state_mod.HexGame.ZoneData;
const HexGame = world_state_mod.HexGame;
const FrameContext = frame.FrameContext;

// Import types from abilities module
pub const AbilityType = abilities.AbilityType;

// Use generic ability slot system from lib/game
const AbilitySlotSystem = game_abilities.ability_slots.AbilitySlotSystem(AbilityType, 8);
pub const AbilitySlot = game_abilities.ability_slots.AbilitySlot(AbilityType);

// Import effect types from abilities module
pub const HexEffectType = abilities.HexEffectType;

// Use generic effect manager for hex effects
const HexEffectManager = effect_manager.EffectManager(HexEffectType, constants.MAX_LULL_EFFECTS);

// Use helpers from abilities module
const AbilityHelpers = abilities.AbilityHelpers;

pub const AbilitySystem = struct {
    // Use generic ability slot system
    slot_system: AbilitySlotSystem,

    // Use generic effect manager for all ability effects
    effect_manager: HexEffectManager,

    pub fn init() AbilitySystem {
        var system = AbilitySystem{
            .slot_system = AbilitySlotSystem.init(),
            .effect_manager = HexEffectManager.init(),
        };

        // Initialize ability slots with specific abilities and cooldowns
        system.slot_system.setAbility(0, .Lethargy, AbilityHelpers.getAbilityCooldown(.Lethargy)); // Slot 1 (key: 1)
        system.slot_system.setAbility(1, .Haste, AbilityHelpers.getAbilityCooldown(.Haste)); // Slot 2 (key: 2)
        system.slot_system.setAbility(2, .Phase, AbilityHelpers.getAbilityCooldown(.Phase)); // Slot 3 (key: 3)
        system.slot_system.setAbility(3, .Charm, AbilityHelpers.getAbilityCooldown(.Charm)); // Slot 4 (key: 4)
        system.slot_system.setAbility(4, .Lull, AbilityHelpers.getAbilityCooldown(.Lull)); // Slot 5 (key: Q)
        system.slot_system.setAbility(5, .Blink, AbilityHelpers.getAbilityCooldown(.Blink)); // Slot 6 (key: E)
        system.slot_system.setAbility(6, .Dazzle, AbilityHelpers.getAbilityCooldown(.Dazzle)); // Slot 7 (key: R)
        system.slot_system.setAbility(7, .Multishot, AbilityHelpers.getAbilityCooldown(.Multishot)); // Slot 8 (key: F)

        return system;
    }

    /// Ability system update function with frame context
    pub fn update(self: *AbilitySystem, frame_ctx: FrameContext) void {
        const deltaTime = frame_ctx.effectiveDelta();
        // Update all ability cooldowns using generic system
        self.slot_system.update(deltaTime);

        // Update all ability effects using generic effect manager
        self.effect_manager.updateAll(deltaTime);
    }

    pub fn setActiveSlot(self: *AbilitySystem, slot: usize) void {
        self.slot_system.setActiveSlot(slot);
    }

    pub fn useActiveAbility(self: *AbilitySystem, game: *HexGame, target_pos: Vec2, effect_system: *GameParticleSystem, self_cast: bool) bool {
        const slot = self.slot_system.getActiveSlotMut();
        if (!slot.canCast()) return false;

        const ability_type = slot.ability_type;

        // Get controlled entity position for ability casting
        const controlled_entity = game.getControlledEntity() orelse return false;
        const controlled_zone = game.getCurrentZone();
        const controlled_transform = controlled_zone.units.getComponent(controlled_entity, .transform) orelse return false;
        const controlled_pos = controlled_transform.pos;

        // Determine actual target based on ability targeting type and self-cast preference
        const targeting_type = AbilityHelpers.getAbilityTargetingType(ability_type);
        const actual_target = switch (targeting_type) {
            .self => controlled_pos, // Always self-target
            .area, .single => if (self_cast) controlled_pos else target_pos, // Allow both modes
        };

        const success = self.useAbility(ability_type, game, actual_target, effect_system);
        if (success) {
            slot.startCooldown();
        }
        return success;
    }

    pub fn useAbility(self: *AbilitySystem, ability: AbilityType, game: *HexGame, target_pos: Vec2, effect_system: *GameParticleSystem) bool {
        switch (ability) {
            .None => return false,

            .Lull => return abilities.lull.use(&self.effect_manager, game, target_pos, effect_system),

            .Blink => return abilities.blink.use(&self.effect_manager, game, target_pos, effect_system),

            .Phase => return abilities.phase.use(&self.effect_manager, game, target_pos, effect_system),

            .Charm => return abilities.charm.use(&self.effect_manager, game, target_pos, effect_system),

            .Lethargy => return abilities.lethargy.use(&self.effect_manager, game, target_pos, effect_system),

            .Haste => return abilities.haste.use(&self.effect_manager, game, target_pos, effect_system),

            .Multishot => return abilities.multishot.use(&self.effect_manager, game, target_pos, effect_system),

            .Dazzle => return abilities.dazzle.use(&self.effect_manager, game, target_pos, effect_system),
        }
    }
};
