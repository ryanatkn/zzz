// Hex-specific status modifiers
// Uses generic StatusSystem from lib/game with hex-specific modifier types

const status_mod = @import("../../lib/game/components/statuses.zig");

/// Hex game modifier types
pub const HexModifierType = enum {
    speed_mult,
    damage_mult,
    aggro_mult,
    cooldown_mult,
    radius_mult,
    health_regen,
    damage_resist,
    charm_resistance, // Hex-specific: resistance to charm spells
    phase_ability, // Hex-specific: ability to phase through walls
    lull_effect, // Hex-specific: reduced aggro from lull spell
};

/// Hex-specific status system (16 max modifiers)
pub const HexStatuses = status_mod.StatusSystem(HexModifierType, 16);

/// Helper functions for common hex status operations
pub const StatusHelpers = struct {
    /// Get aggro multiplier for this entity (1.0 = normal aggro)
    pub fn getAggroMultiplier(statuses: HexStatuses) f32 {
        return statuses.getModifiedValue(1.0, .aggro_mult);
    }

    /// Get speed multiplier for this entity (1.0 = normal speed)
    pub fn getSpeedMultiplier(statuses: HexStatuses) f32 {
        return statuses.getModifiedValue(1.0, .speed_mult);
    }

    /// Get damage multiplier for this entity (1.0 = normal damage)
    pub fn getDamageMultiplier(statuses: HexStatuses) f32 {
        return statuses.getModifiedValue(1.0, .damage_mult);
    }

    /// Check if entity is affected by lull spell
    pub fn hasLullEffect(statuses: HexStatuses) bool {
        for (statuses.modifiers.slice()) |mod| {
            if (std.meta.eql(mod.type, .lull_effect)) {
                return true;
            }
        }
        return false;
    }

    /// Check if entity can phase through walls
    pub fn canPhase(statuses: HexStatuses) bool {
        for (statuses.modifiers.slice()) |mod| {
            if (std.meta.eql(mod.type, .phase_ability)) {
                return true;
            }
        }
        return false;
    }
};

const std = @import("std");
