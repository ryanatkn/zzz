/// Simplified portal system using direct zone travel manager
/// This replaces the portal_integration layer with direct integration
const std = @import("std");
const math = @import("../lib/math/mod.zig");
const loggers = @import("../lib/debug/loggers.zig");
const HexGameContext = @import("hex_context.zig").HexGameContext;

/// Update portal system (replaces updatePortalCooldown)
pub fn updatePortalCooldown(context: HexGameContext) void {
    const game_state = context.game_state orelse return;
    const world = &game_state.hex_game;
    const contexts = @import("../lib/game/contexts/mod.zig");
    const deltaTime = contexts.ContextUtils.effectiveDeltaTime(context);
    
    world.zone_travel_manager.update(deltaTime);
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
    
    // Check for portal collisions and execute travel directly
    if (world.zone_travel_manager.checkTeleporterCollisions(world, player_pos, player_radius)) |result| {
        if (result.success) {
            loggers.getGameLog().info("portal_travel_success", "Portal travel completed successfully", .{});
            return true;
        } else {
            loggers.getGameLog().err("portal_travel_failed", "Portal travel failed: {?}", .{result.error_info});
            return false;
        }
    }
    
    return false;
}
