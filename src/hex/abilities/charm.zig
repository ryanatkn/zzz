// Charm ability implementation - control target unit

const std = @import("std");
const math = @import("../../lib/math/mod.zig");
const GameParticleSystem = @import("../../lib/particles/game_particles.zig").GameParticleSystem;
const constants = @import("../constants.zig");
const loggers = @import("../../lib/debug/loggers.zig");
const world_state_mod = @import("../world_state.zig");
const game_abilities = @import("../../lib/game/abilities/mod.zig");
const effect_manager = game_abilities.effect_manager;
const types = @import("types.zig");
const helpers = @import("helpers.zig");

const Vec2 = math.Vec2;
const HexGame = world_state_mod.HexGame;
const EntityId = world_state_mod.EntityId;
const HexEffectType = types.HexEffectType;
const HexEffectManager = effect_manager.EffectManager(HexEffectType, constants.MAX_LULL_EFFECTS);
const ValidationHelpers = helpers.ValidationHelpers;

/// Charm ability implementation
pub fn use(effect_mgr: *HexEffectManager, game: *HexGame, target_pos: Vec2, effect_system: *GameParticleSystem) bool {
    _ = effect_mgr;
    _ = effect_system;

    // Find closest unit to target position that can be charmed
    const search_zone = game.getCurrentZone();
    var closest_unit: ?struct { entity_id: EntityId, distance_sq: f32 } = null;
    const charm_max_range = constants.CHARM_RANGE;
    const max_range_sq = charm_max_range * charm_max_range;

    for (0..search_zone.units.count) |i| {
        const entity_id = search_zone.units.entities[i];
        if (entity_id == std.math.maxInt(u32)) continue;

        const health = &search_zone.units.healths[i];
        if (!health.alive) continue;

        const transform = &search_zone.units.transforms[i];
        const distance_sq = target_pos.sub(transform.pos).lengthSquared();
        if (distance_sq > max_range_sq) continue;

        if (closest_unit == null or distance_sq < closest_unit.?.distance_sq) {
            closest_unit = .{ .entity_id = entity_id, .distance_sq = distance_sq };
        }
    }

    if (closest_unit == null) {
        loggers.getGameLog().info("charm_failed", "No valid target found", .{});
        return false;
    }

    const target_unit = closest_unit.?;
    const controlled_entity = game.getControlledEntity() orelse return false;

    // Check if target can be charmed (simplified check)
    if (!ValidationHelpers.canCharm(target_unit.entity_id, search_zone)) {
        loggers.getGameLog().info("charm_failed", "Target cannot be charmed", .{});
        return false;
    }

    const charm_duration = constants.CHARM_DURATION;
    if (!ValidationHelpers.applyCharmEffect(target_unit.entity_id, controlled_entity, charm_duration, @constCast(search_zone))) {
        loggers.getGameLog().info("charm_failed", "Failed to apply charm effect", .{});
        return false;
    }

    loggers.getGameLog().info("charm_success", "Charmed entity {} for {}s", .{ target_unit.entity_id, charm_duration });
    return true;
}
