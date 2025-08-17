/// Simplified portal system using direct zone travel manager
/// This replaces the portal_integration layer with direct integration
const std = @import("std");
const math = @import("../lib/math/mod.zig");
const loggers = @import("../lib/debug/loggers.zig");
const frame = @import("../lib/core/frame.zig");
const hex_game_mod = @import("hex_game.zig");

const FrameContext = frame.FrameContext;
const HexGame = hex_game_mod.HexGame;

/// Update portal system with frame context
pub fn updatePortalCooldown(world: *HexGame, frame_ctx: FrameContext) void {
    const deltaTime = frame_ctx.effectiveDelta();
    world.zone_travel_manager.update(deltaTime);
}

/// Check portal collisions using generic system (replaces 80+ lines of manual collision detection)
pub fn checkPortalCollisions(world: *HexGame) bool {

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
