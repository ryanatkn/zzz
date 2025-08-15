const std = @import("std");
const math = @import("../lib/math/mod.zig");
const ecs = @import("../lib/game/ecs.zig");
const physics = @import("physics.zig");
const constants = @import("constants.zig");
const loggers = @import("../lib/debug/loggers.zig");

// Portal cooldown to prevent re-triggering after travel
var portal_cooldown: f32 = 0;

// Update portal cooldown timer
pub fn updatePortalCooldown(deltaTime: f32) void {
    if (portal_cooldown > 0) {
        portal_cooldown = @max(0, portal_cooldown - deltaTime);
    }
}

pub fn checkPortalCollisions(game_state: anytype) bool {
    const world = &game_state.world;

    // Skip portal checks during cooldown
    if (portal_cooldown > 0) return false;

    if (!world.getPlayerAlive()) return false;

    const player_pos = world.getPlayerPos();
    const player_radius = world.getPlayerRadius();

    // Check collisions with all portal entities using ECS
    const ecs_world = world.getECSWorldMut();
    var portal_iter = ecs_world.portals.entityIterator();
    while (portal_iter.next()) |portal_id| {
        if (!ecs_world.isAlive(portal_id)) continue;

        // Get portal interactable component for destination zone
        if (ecs_world.portals.getComponent(portal_id, .interactable)) |interactable| {
            if (interactable.destination_zone) |destination_zone| {
                if (ecs_world.portals.getComponent(portal_id, .transform)) |transform| {
                    if (physics.checkPlayerPortalCollisionECS(player_pos, player_radius, transform)) {
                        // Set cooldown and travel
                        portal_cooldown = 1.0; // 1 second cooldown

                        // Add portal travel effect
                        game_state.effect_system.addPortalTravelEffect(player_pos, player_radius);

                        // Travel to destination zone
                        const zone = &world.zones[destination_zone];
                        world.travelToZone(destination_zone, zone.spawn_pos) catch {
                            loggers.getGameLog().err("portal_travel_error", "Error: Failed to travel to zone {}", .{destination_zone});
                            return false;
                        };

                        return true;
                    }
                }
            }
        }
    }

    return false;
}