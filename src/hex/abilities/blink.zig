// Blink ability implementation - teleport to target location

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
const HexEffectType = types.HexEffectType;
const HexEffectManager = effect_manager.EffectManager(HexEffectType, constants.MAX_LULL_EFFECTS);
const ValidationHelpers = helpers.ValidationHelpers;

/// Blink ability implementation
pub fn use(effect_mgr: *HexEffectManager, game: *HexGame, target_pos: Vec2, effect_system: *GameParticleSystem) bool {
    _ = effect_mgr;
    const controlled_entity = game.getControlledEntity() orelse return false;

    // Check if entity can teleport (simplified check - player always can)
    const zone = game.getCurrentZone();
    if (!ValidationHelpers.canTeleport(controlled_entity, zone)) {
        loggers.getGameLog().info("blink_failed", "Entity cannot teleport", .{});
        return false;
    }

    const player_transform = zone.units.getComponent(controlled_entity, .transform) orelse return false;
    const player_pos = player_transform.pos;

    const final_pos = ValidationHelpers.performTeleport(controlled_entity, player_pos, target_pos, constants.BLINK_MAX_DISTANCE, zone, game) orelse {
        loggers.getGameLog().info("blink_failed", "Teleportation validation failed", .{});
        return false;
    };

    // Update player position
    if (game.getCurrentZone().units.getComponentMut(controlled_entity, .transform)) |transform| {
        transform.pos = final_pos;
        loggers.getGameLog().info("blink_success", "Teleported to {},{}", .{ final_pos.x, final_pos.y });

        _ = effect_system;

        return true;
    }

    return false;
}
