const std = @import("std");
const math = @import("../lib/math/mod.zig");
const ecs = @import("../lib/game/ecs.zig");
const physics = @import("physics.zig");
const constants = @import("constants.zig");
const loggers = @import("../lib/debug/loggers.zig");
const cooldowns = @import("../lib/game/cooldowns.zig");

// Portal cooldown to prevent re-triggering after travel
var portal_cooldown = cooldowns.Cooldown.init(1.0); // 1 second cooldown

// Update portal cooldown timer
pub fn updatePortalCooldown(deltaTime: f32) void {
    portal_cooldown.update(deltaTime);
}

pub fn checkPortalCollisions(game_state: anytype) bool {
    const world = &game_state.hex_game;

    // Skip portal checks during cooldown
    if (!portal_cooldown.isReady()) {
        // Only log this occasionally to avoid spam
        const remaining_time = portal_cooldown.getRemaining();
        if (@mod(@as(u32, @intFromFloat(remaining_time * 10)), 10) == 0) {
            // Portal cooldown active but not logging to reduce spam
        }
        return false;
    }

    if (!world.getPlayerAlive()) {
        // Player not alive, skipping portal checks
        return false;
    }

    const player_pos = world.getPlayerPos();
    const player_radius = world.getPlayerRadius();
    
    // Checking portal collisions

    // Check collisions with all portal entities using ECS
    const zone_storage = world.getZoneStorage();
    var portal_iter = zone_storage.portals.entityIterator();
    var portal_count: u32 = 0;
    while (portal_iter.next()) |portal_id| {
        portal_count += 1;
        // Found portal entity
        
        if (!zone_storage.isAlive(portal_id)) {
            // Portal entity is not alive
            continue;
        }

        // Get portal interactable component for destination zone
        if (zone_storage.portals.getComponent(portal_id, .interactable)) |interactable| {
            // Portal has interactable component
            if (interactable.destination_zone) |destination_zone| {
                // Portal leads to destination zone
                if (zone_storage.portals.getComponent(portal_id, .transform)) |transform| {
                    // Portal transform found - check collision
                    
                    if (physics.checkPlayerPortalCollision(player_pos, player_radius, transform)) {
                        loggers.getGameLog().info("portal_collision_detected", "Portal collision detected! Player at {any}, portal at {any}", .{ player_pos, transform.pos });
                        
                        // Set cooldown and travel
                        portal_cooldown.start(); // Start 1 second cooldown

                        // Add portal travel effect
                        game_state.effect_system.addPortalTravelEffect(player_pos, player_radius);

                        // Travel to destination zone
                        const zone = &world.zones[destination_zone];
                        loggers.getGameLog().info("portal_travel", "Portal activated: traveling to zone {} at pos {any}", .{ destination_zone, zone.spawn_pos });
                        
                        world.travelToZone(destination_zone, zone.spawn_pos) catch |err| {
                            loggers.getGameLog().err("portal_travel_error", "Error: Failed to travel to zone {}: {}", .{ destination_zone, err });
                            return false;
                        };
                        
                        // Verify player still exists after travel
                        if (world.getPlayer() == null) {
                            loggers.getGameLog().err("portal_travel_player_lost", "Critical error: Player entity lost during portal travel!", .{});
                        } else {
                            loggers.getGameLog().info("portal_travel_success", "Successfully traveled to zone {}", .{destination_zone});
                        }

                        return true;
                    } else {
                        // No collision with portal
                    }
                } else {
                    // Portal missing transform component
                }
            } else {
                // Portal has no destination zone
            }
        } else {
            // Portal missing interactable component
        }
    }
    
    if (portal_count == 0) {
        loggers.getGameLog().debug("portal_none_found", "No portal entities found in current zone", .{});
    } else {
        loggers.getGameLog().debug("portal_check_complete", "Checked {} portals, no collision detected", .{portal_count});
    }

    return false;
}