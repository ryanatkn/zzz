/// Simplified portal system using direct zone travel manager
/// This replaces the portal_integration layer with direct integration
const std = @import("std");
const math = @import("../lib/math/mod.zig");
const loggers = @import("../lib/debug/loggers.zig");
const frame = @import("../lib/core/frame.zig");
const world_state_mod = @import("world_state.zig");

const FrameContext = frame.FrameContext;
const HexGame = world_state_mod.HexGame;

/// Update portal system with frame context
pub fn updatePortalCooldown(world: *HexGame, frame_ctx: FrameContext) void {
    const deltaTime = frame_ctx.effectiveDelta();
    world.zone_travel_manager.update(deltaTime);
}

/// Check portal collisions using generic system (replaces 80+ lines of manual collision detection)
pub fn checkPortalCollisions(world: *HexGame) bool {
    // Get controlled entity for portal collision
    const controlled_entity = world.getControlledEntity() orelse return false;
    const zone = world.getCurrentZoneConst();
    const controlled_transform = zone.units.getComponent(controlled_entity, .transform) orelse return false;
    const controlled_health = zone.units.getComponent(controlled_entity, .health) orelse return false;

    if (!controlled_health.alive) {
        return false;
    }

    const controlled_pos = controlled_transform.pos;
    const controlled_radius = controlled_transform.radius;

    // Check for portal collisions and execute travel directly
    if (world.zone_travel_manager.checkTeleporterCollisions(world, controlled_pos, controlled_radius)) |result| {
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
