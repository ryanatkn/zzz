/// Simplified portal system using lib/game/world generic patterns
/// This replaces the previous 113-line manual implementation with ~20 lines
const std = @import("std");
const math = @import("../lib/math/mod.zig");
const loggers = @import("../lib/debug/loggers.zig");
const HexGameContext = @import("hex_context.zig").HexGameContext;
const portal_integration = @import("portal_integration.zig");

/// Update portal system (replaces updatePortalCooldown)
pub fn updatePortalCooldown(context: HexGameContext) void {
    const game_state = context.game_state orelse return;
    const world = &game_state.hex_game;
    const contexts = @import("../lib/game/contexts/mod.zig");
    const deltaTime = contexts.ContextUtils.effectiveDeltaTime(context);
    
    world.portal_system.update(deltaTime);
}

/// Check portal collisions using generic system (replaces 80+ lines of manual collision detection)
pub fn checkPortalCollisions(context: HexGameContext) bool {
    const game_state = context.game_state orelse return false;
    const world = &game_state.hex_game;

    if (!world.getPlayerAlive()) {
        return false;
    }

    const player_pos = world.getPlayerPos();
    const player_radius = world.getPlayerRadius();
    
    // Set context for travel handler functions
    portal_integration.setGameContext(world, &game_state.effect_system);
    
    return world.portal_system.checkPortalCollisions(player_pos, player_radius);
}
