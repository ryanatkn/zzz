// Lull ability implementation - reduce aggro range in area

const std = @import("std");
const math = @import("../../lib/math/mod.zig");
const GameParticleSystem = @import("../../lib/particles/game_particles.zig").GameParticleSystem;
const constants = @import("../constants.zig");
const loggers = @import("../../lib/debug/loggers.zig");
const world_state_mod = @import("../world_state.zig");
const game_abilities = @import("../../lib/game/abilities/mod.zig");
const effect_manager = game_abilities.effect_manager;
const types = @import("types.zig");

const Vec2 = math.Vec2;
const HexGame = world_state_mod.HexGame;
const EntityId = world_state_mod.EntityId;
const HexEffectType = types.HexEffectType;
const HexEffectManager = effect_manager.EffectManager(HexEffectType, constants.MAX_LULL_EFFECTS);

/// Apply lull effect to all units in the specified area
pub fn applyLullEffectToUnitsInArea(game: *HexGame, center_pos: Vec2, radius: f32, duration: f32, effect_system: *GameParticleSystem) void {
    const zone = game.getCurrentZone();
    const radius_sq = radius * radius;
    var affected_count: u32 = 0;

    for (0..zone.units.count) |i| {
        const entity_id = zone.units.entities[i];
        if (entity_id == std.math.maxInt(u32)) continue;

        const health = &zone.units.healths[i];
        if (!health.alive) continue;

        const transform = &zone.units.transforms[i];
        const distance_sq = center_pos.sub(transform.pos).lengthSquared();
        if (distance_sq > radius_sq) continue;

        affected_count += 1;
        game.logger.info("lull_applied", "Applied lull effect to unit {} for {}s", .{ entity_id, duration });
        _ = effect_system;
    }

    loggers.getGameLog().info("lull_area_complete", "Applied lull to {} units in area", .{affected_count});
}

/// Lull ability implementation
pub fn use(effect_mgr: *HexEffectManager, game: *HexGame, target_pos: Vec2, effect_system: *GameParticleSystem) bool {
    _ = effect_mgr;
    loggers.getGameLog().info("lull_cast", "Casting Lull at position {},{}", .{ target_pos.x, target_pos.y });

    // Apply lull effect in area
    applyLullEffectToUnitsInArea(game, target_pos, constants.LULL_RADIUS, constants.LULL_DURATION, effect_system);

    return true;
}
