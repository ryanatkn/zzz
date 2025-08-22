const std = @import("std");

const factions = @import("factions.zig");
const faction_presets = @import("faction_presets.zig");
const components = @import("../lib/game/components/mod.zig");
const hex_game_mod = @import("hex_game.zig");
const constants = @import("constants.zig");

const HexGame = hex_game_mod.HexGame;
const EntityId = hex_game_mod.EntityId;
const EntityFactions = factions.EntityFactions;
const FactionRelation = factions.FactionRelation;


/// Helper functions to integrate faction system with existing hex game code
/// Get entity factions from player storage
pub fn getPlayerFactions(game: *const HexGame, entity_id: EntityId) ?EntityFactions {
    const zone = game.getCurrentZoneConst();
    // TODO: When we switch to extended storage, use zone.players.getFactions(entity_id)
    // For now, return default player factions
    if (zone.players.containsEntity(entity_id)) {
        return faction_presets.getPlayerFactions();
    }
    return null;
}

/// Get entity factions from unit storage
pub fn getUnitFactions(game: *const HexGame, entity_id: EntityId) ?EntityFactions {
    const zone = game.getCurrentZoneConst();
    // TODO: When we switch to extended storage, use zone.units.getFactions(entity_id)
    // For now, extract from unit disposition and map to factions
    if (zone.units.getComponent(entity_id, .unit)) |unit| {
        return faction_presets.getUnitFactions(unit.disposition, unit.unitType());
    }
    return null;
}

/// Get entity capabilities from player storage
pub fn getPlayerCapabilities(game: *const HexGame, entity_id: EntityId) ?components.Capabilities {
    const zone = game.getCurrentZoneConst();
    // TODO: When we switch to extended storage, use zone.players.getCapabilities(entity_id)
    // For now, return default player capabilities
    if (zone.players.containsEntity(entity_id)) {
        return faction_presets.getPlayerCapabilities();
    }
    return null;
}

/// Get entity capabilities from unit storage
pub fn getUnitCapabilities(game: *const HexGame, entity_id: EntityId) ?components.Capabilities {
    const zone = game.getCurrentZoneConst();
    // TODO: When we switch to extended storage, use zone.units.getCapabilities(entity_id)
    // For now, extract from unit disposition and map to capabilities
    if (zone.units.getComponent(entity_id, .unit)) |unit| {
        return faction_presets.getUnitCapabilities(unit.disposition);
    }
    return null;
}

/// Get factions for any entity (tries player first, then units)
pub fn getEntityFactions(game: *const HexGame, entity_id: EntityId) ?EntityFactions {
    // Try player storage first
    if (getPlayerFactions(game, entity_id)) |player_factions| {
        return player_factions;
    }

    // Try unit storage
    if (getUnitFactions(game, entity_id)) |unit_factions| {
        return unit_factions;
    }

    return null;
}

/// Get capabilities for any entity (tries player first, then units)
pub fn getEntityCapabilities(game: *const HexGame, entity_id: EntityId) ?components.Capabilities {
    // Try player storage first
    if (getPlayerCapabilities(game, entity_id)) |player_caps| {
        return player_caps;
    }

    // Try unit storage
    if (getUnitCapabilities(game, entity_id)) |unit_caps| {
        return unit_caps;
    }

    return null;
}

/// Calculate faction relationship between two entities
pub fn getEntityRelation(game: *const HexGame, from_entity: EntityId, to_entity: EntityId) ?FactionRelation {
    const from_factions = getEntityFactions(game, from_entity) orelse return null;
    const to_factions = getEntityFactions(game, to_entity) orelse return null;

    return factions.calculateRelation(from_factions, to_factions);
}

/// Check if an entity can attack based on its capabilities
pub fn canEntityAttack(game: *const HexGame, entity_id: EntityId) bool {
    if (getEntityCapabilities(game, entity_id)) |caps| {
        return caps.can_attack;
    }
    return false;
}

/// Get attack damage for an entity
pub fn getEntityAttackDamage(game: *const HexGame, entity_id: EntityId) f32 {
    if (getEntityCapabilities(game, entity_id)) |caps| {
        return caps.attack_damage;
    }
    return 0.0;
}

/// Check if an entity can be damaged
pub fn canEntityBeDamaged(game: *const HexGame, entity_id: EntityId) bool {
    if (getEntityCapabilities(game, entity_id)) |caps| {
        return caps.can_be_damaged;
    }
    return true; // Default to damageable for safety
}

/// Debug logging for faction relationships
pub fn logFactionRelation(game: *const HexGame, from_entity: EntityId, to_entity: EntityId, relation: FactionRelation) void {
    // Cast away const to access logger (logging is considered safe side effect)
    const mutable_game = @constCast(game);
    const logger = &mutable_game.logger;

    const from_factions = getEntityFactions(game, from_entity);
    const to_factions = getEntityFactions(game, to_entity);

    if (from_factions != null and to_factions != null) {
        logger.debug("faction_relation", "Entity {} -> Entity {}: {s}", .{ from_entity, to_entity, @tagName(relation) });

        // Log faction tags for debugging
        if (from_factions) |f| {
            logger.debug("from_factions", "Entity {} factions: {}", .{ from_entity, f.tags.count() });
        }
        if (to_factions) |t| {
            logger.debug("to_factions", "Entity {} factions: {}", .{ to_entity, t.tags.count() });
        }
    }
}

/// Check if two entities share faction allegiance
pub fn shareAllegiance(game: *const HexGame, entity_a: EntityId, entity_b: EntityId) bool {
    const factions_a = getEntityFactions(game, entity_a) orelse return false;
    const factions_b = getEntityFactions(game, entity_b) orelse return false;

    // Check for common allegiance tags
    const allegiances = [_]factions.FactionTag{ .kingdom_guard, .bandit, .merchant_guild, .forest_warden, .necromancer_cult };

    for (allegiances) |allegiance| {
        if (factions_a.hasTag(allegiance) and factions_b.hasTag(allegiance)) {
            return true;
        }
    }

    return false;
}

/// Get friendly entities near a position (for AI assistance, etc.)
pub fn getFriendlyEntitiesNear(game: *const HexGame, center_entity: EntityId, _: f32, allies: []EntityId) usize {
    const zone = game.getCurrentZoneConst();
    const center_factions = getEntityFactions(game, center_entity) orelse return 0;

    var ally_count: usize = 0;

    // Check units in current zone
    var unit_iter = zone.units.entityIterator();
    while (unit_iter.next()) |unit_id| {
        if (unit_id == center_entity) continue; // Skip self
        if (ally_count >= allies.len) break;

        const unit_factions = getUnitFactions(game, unit_id) orelse continue;
        const relation = factions.calculateRelation(center_factions, unit_factions);

        // Only consider friendly or allied entities
        if (relation == .friendly or relation == .allied) {
            // TODO: Add distance check when we have position data
            allies[ally_count] = unit_id;
            ally_count += 1;
        }
    }

    return ally_count;
}

/// Check if an entity can be controlled (for possession mechanics)
pub fn canEntityBeControlled(game: *const HexGame, entity_id: EntityId) bool {
    if (getEntityCapabilities(game, entity_id)) |caps| {
        return caps.can_be_controlled;
    }
    return false;
}

