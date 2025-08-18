const std = @import("std");
const factions = @import("factions.zig");
const components = @import("../lib/game/components/mod.zig");
const constants = @import("constants.zig");
const Disposition = @import("disposition.zig").Disposition;
const UnitType = components.Unit.UnitType;

// Re-export faction types for convenience
pub const EntityFactions = factions.EntityFactions;
pub const FactionTag = factions.FactionTag;
pub const Capabilities = components.Capabilities;

/// Get default faction tags for the player entity
pub fn getPlayerFactions() EntityFactions {
    return EntityFactions.initWithTags(&.{
        .halfling,        // Default player race
        .living,          // Player is a living being
        .kingdom_guard,   // Starting allegiance
    });
}

/// Get default capabilities for the player entity
pub fn getPlayerCapabilities() Capabilities {
    return Capabilities.initPlayer(constants.PLAYER_SPEED, constants.PLAYER_DAMAGE);
}

/// Map existing disposition system to faction tags
/// This provides backward compatibility during the migration
pub fn getUnitFactions(disposition: Disposition, unit_type: UnitType) EntityFactions {
    return switch (disposition) {
        .friendly => EntityFactions.initWithTags(&.{
            .halfling,        // Assume friendly units are same race as player
            .living,
            .kingdom_guard,   // Friendly units serve the kingdom
        }),
        .hostile => switch (unit_type) {
            .enemy => EntityFactions.initWithTags(&.{
                .goblin,          // Default hostile race
                .living,
                .bandit,          // Hostile allegiance
                .territorial,     // Aggressive behavior
            }),
            else => EntityFactions.initWithTags(&.{
                .beast,           // Non-enemy hostiles are beasts
                .living,
                .territorial,     // Defensive of their territory
            }),
        },
        .fearful => EntityFactions.initWithTags(&.{
            .beast,           // Fearful creatures are usually animals
            .living,
            .fleeing,         // Currently in flight mode
        }),
        .neutral => EntityFactions.initWithTags(&.{
            .beast,           // Neutral creatures are typically wildlife
            .living,
            .solitary,        // Keeps to themselves
        }),
    };
}

/// Map existing disposition system to capabilities
/// This provides sensible defaults based on current behavior
pub fn getUnitCapabilities(disposition: Disposition) Capabilities {
    return switch (disposition) {
        .friendly => Capabilities.initFriendlyUnit(constants.UNIT_SPEED),
        .hostile => Capabilities.initHostileUnit(constants.UNIT_SPEED, constants.UNIT_DAMAGE),
        .fearful => .{
            .can_move = true,
            .move_speed = constants.UNIT_SPEED * 1.2, // Faster when fleeing
            .can_be_controlled = true,
            .can_attack = false,  // Too scared to attack
            .attack_damage = 0.0,
            .can_be_damaged = true,
            .can_interact = false, // Too scared to interact
        },
        .neutral => Capabilities.initNeutral(constants.UNIT_SPEED * 0.8), // Slower, more careful
    };
}

/// Create faction tags for specific creature types
/// This allows for more detailed faction combinations
pub fn getCreatureFactions(creature_type: CreatureType) EntityFactions {
    return switch (creature_type) {
        .goblin_warrior => EntityFactions.initWithTags(&.{
            .goblin, .living, .bandit, .pack_hunter, .territorial
        }),
        .goblin_shaman => EntityFactions.initWithTags(&.{
            .goblin, .living, .necromancer_cult, .territorial
        }),
        .forest_wolf => EntityFactions.initWithTags(&.{
            .beast, .living, .pack_hunter, .territorial
        }),
        .dire_bear => EntityFactions.initWithTags(&.{
            .beast, .living, .solitary, .territorial
        }),
        .forest_sprite => EntityFactions.initWithTags(&.{
            .fey, .living, .forest_warden, .guardian
        }),
        .stone_golem => EntityFactions.initWithTags(&.{
            .golem, .construct, .guardian, .territorial
        }),
        .undead_warrior => EntityFactions.initWithTags(&.{
            .halfling, .undead, .necromancer_cult
        }),
        .merchant_guard => EntityFactions.initWithTags(&.{
            .halfling, .living, .merchant_guild, .guardian
        }),
        .kingdom_patrol => EntityFactions.initWithTags(&.{
            .halfling, .living, .kingdom_guard, .guardian
        }),
    };
}

/// Creature type enum for more specific faction assignment
pub const CreatureType = enum {
    goblin_warrior,
    goblin_shaman,
    forest_wolf,
    dire_bear,
    forest_sprite,
    stone_golem,
    undead_warrior,
    merchant_guard,
    kingdom_patrol,
};

/// Get capabilities for specific creature types
pub fn getCreatureCapabilities(creature_type: CreatureType) Capabilities {
    return switch (creature_type) {
        .goblin_warrior => Capabilities.initHostileUnit(100.0, 15.0),
        .goblin_shaman => .{
            .can_move = true,
            .move_speed = 80.0,  // Slower but more dangerous
            .can_be_controlled = true,
            .can_attack = true,
            .attack_damage = 20.0,  // Magic damage
            .can_be_damaged = true,
            .can_interact = false,
        },
        .forest_wolf => Capabilities.initHostileUnit(120.0, 12.0),
        .dire_bear => Capabilities.initHostileUnit(90.0, 25.0),
        .forest_sprite => .{
            .can_move = true,
            .move_speed = 150.0,  // Very fast
            .can_be_controlled = true,
            .can_attack = false,  // Peaceful guardian
            .attack_damage = 0.0,
            .can_be_damaged = true,
            .can_interact = true,
        },
        .stone_golem => .{
            .can_move = true,
            .move_speed = 60.0,   // Slow but powerful
            .can_be_controlled = true,
            .can_attack = true,
            .attack_damage = 30.0,
            .can_be_damaged = true,
            .can_interact = false,
        },
        .undead_warrior => Capabilities.initHostileUnit(90.0, 18.0),
        .merchant_guard => Capabilities.initFriendlyUnit(110.0),
        .kingdom_patrol => Capabilities.initFriendlyUnit(105.0),
    };
}

/// Utility function to modify faction tags at runtime
/// Useful for spells like charm, corruption, etc.
pub fn applyFactionModifier(entity_factions: *EntityFactions, modifier: FactionModifier) void {
    switch (modifier) {
        .charm => {
            entity_factions.removeTag(.hostile);
            entity_factions.addTag(.charmed);
        },
        .corrupt => {
            entity_factions.removeTag(.blessed);
            entity_factions.addTag(.corrupted);
        },
        .bless => {
            entity_factions.removeTag(.corrupted);
            entity_factions.addTag(.blessed);
        },
        .enrage => {
            entity_factions.addTag(.enraged);
        },
        .calm => {
            entity_factions.removeTag(.enraged);
            entity_factions.removeTag(.fleeing);
        },
    }
}

pub const FactionModifier = enum {
    charm,
    corrupt,
    bless,
    enrage,
    calm,
};