// Shared helper functions for hex abilities
// Extracted from abilities.zig and implementations.zig

const std = @import("std");
const math = @import("../../lib/math/mod.zig");
const types = @import("types.zig");
const world_state_mod = @import("../world_state.zig");
const constants = @import("../constants.zig");

const Vec2 = math.Vec2;
const AbilityType = types.AbilityType;
const HexEffectType = types.HexEffectType;
const ZoneData = world_state_mod.HexGame.ZoneData;
const HexGame = world_state_mod.HexGame;
const EntityId = world_state_mod.EntityId;

/// Simplified ability targeting and validation
pub const AbilityHelpers = struct {
    /// Get targeting type for abilities (area, single, self)
    pub fn getAbilityTargetingType(ability_type: AbilityType) enum { area, single, self } {
        return switch (ability_type) {
            .None => .single,
            .Lull => .area,
            .Blink => .single, // Click to teleport to location
            .Phase => .self, // Self-cast only
            .Charm => .single, // Click to target unit
            .Lethargy => .area, // Area effect
            .Haste => .self, // Self-cast only
            .Dazzle => .area, // Area effect
            .Multishot => .self, // Self-cast projectile spread
        };
    }

    /// Check if ability requires line of sight
    pub fn abilityRequiresLineOfSight(ability_type: AbilityType) bool {
        return switch (ability_type) {
            .None => false,
            .Lull => false, // Area effect doesn't need direct line of sight
            .Blink => false, // Can teleport through walls
            .Phase => false, // Self-cast
            .Charm => true, // Needs to see target to charm
            .Lethargy => false, // Area effect
            .Haste => false, // Self-cast
            .Dazzle => false, // Area effect
            .Multishot => false, // Self-cast projectile spread
        };
    }

    /// Get ability cooldown duration
    pub fn getAbilityCooldown(ability: AbilityType) f32 {
        return switch (ability) {
            .None => 0,
            .Lull => constants.LULL_COOLDOWN,
            .Blink => constants.BLINK_COOLDOWN,
            .Phase => constants.PHASE_COOLDOWN,
            .Charm => constants.CHARM_COOLDOWN,
            .Lethargy => constants.LETHARGY_COOLDOWN,
            .Haste => constants.HASTE_COOLDOWN,
            .Multishot => constants.MULTISHOT_COOLDOWN,
            .Dazzle => constants.DAZZLE_COOLDOWN,
        };
    }
};

/// Shared validation and utility functions for all abilities
pub const ValidationHelpers = struct {
    /// Check if entity can teleport (stub implementation)
    pub fn canTeleport(entity_id: EntityId, zone: *const ZoneData) bool {
        _ = entity_id;
        _ = zone;
        return true; // Player can always teleport
    }

    /// Check if entity can phase through objects (stub implementation)
    pub fn canPhase(entity_id: EntityId, zone: *const ZoneData) bool {
        _ = entity_id;
        _ = zone;
        return false; // Phase not implemented yet
    }

    /// Check if entity can be charmed (stub implementation)
    pub fn canCharm(entity_id: EntityId, zone: *const ZoneData) bool {
        _ = entity_id;
        _ = zone;
        return true; // Most units can be charmed
    }

    /// Validate teleport destination and return clamped position
    pub fn performTeleport(entity_id: EntityId, from_pos: Vec2, to_pos: Vec2, max_range: f32, zone: *const ZoneData, game: *HexGame) ?Vec2 {
        _ = entity_id;
        _ = zone;
        _ = game;

        // Simple range validation - collision checking to be added later
        const distance = from_pos.sub(to_pos).length();
        if (distance > max_range) {
            return null;
        }

        return to_pos;
    }

    /// Apply charm effect to target entity (stub implementation)
    pub fn applyCharmEffect(target_id: EntityId, charmer_id: EntityId, duration: f32, zone: *ZoneData) bool {
        _ = target_id;
        _ = charmer_id;
        _ = duration;
        _ = zone;
        return true;
    }
};
