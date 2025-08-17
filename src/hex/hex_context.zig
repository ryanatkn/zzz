/// Hex game specific context type
const std = @import("std");
const contexts = @import("../lib/game/contexts/mod.zig");
const HexGame = @import("hex_game.zig").HexGame;
const GameState = @import("game.zig").GameState;
const camera = @import("../lib/rendering/camera.zig");

/// Hex-specific game context that combines all needed state
pub const HexGameContext = contexts.GameContext(GameState, HexGame, camera.Camera);

/// Create a hex game context from the components
pub fn createHexContext(
    update_ctx: contexts.UpdateContext,
    input_ctx: contexts.InputContext,
    graphics_ctx: contexts.GraphicsContext,
    physics_ctx: contexts.PhysicsContext,
    game_state: *GameState,
    hex_game: *HexGame,
    cam: *const camera.Camera,
) HexGameContext {
    return HexGameContext.init(update_ctx, input_ctx, graphics_ctx, physics_ctx)
        .withGameState(game_state)
        .withGameWorld(hex_game)
        .withCamera(cam);
}