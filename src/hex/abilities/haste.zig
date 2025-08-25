// Haste ability implementation - movement speed boost

const math = @import("../../lib/math/mod.zig");
const GameParticleSystem = @import("../../lib/particles/game_particles.zig").GameParticleSystem;
const loggers = @import("../../lib/debug/loggers.zig");
const world_state_mod = @import("../world_state.zig");
const game_abilities = @import("../../lib/game/abilities/mod.zig");
const effect_manager = game_abilities.effect_manager;
const types = @import("types.zig");

const Vec2 = math.Vec2;
const HexGame = world_state_mod.HexGame;
const HexEffectType = types.HexEffectType;
const constants = @import("../constants.zig");
const HexEffectManager = effect_manager.EffectManager(HexEffectType, constants.MAX_LULL_EFFECTS);

/// Haste ability implementation (placeholder)
pub fn use(effect_mgr: *HexEffectManager, game: *HexGame, target_pos: Vec2, effect_system: *GameParticleSystem) bool {
    _ = effect_mgr;
    _ = game;
    _ = target_pos;
    _ = effect_system;

    loggers.getGameLog().info("ability_placeholder", "Haste ability not yet implemented", .{});
    return false;
}
