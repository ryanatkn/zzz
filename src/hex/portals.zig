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
    if (portal_cooldown > 0) {
        // Only log this occasionally to avoid spam
        if (@mod(@as(u32, @intFromFloat(portal_cooldown * 10)), 10) == 0) {
            loggers.getGameLog().debug("portal_cooldown", "Portal cooldown active: {d:.1}s remaining", .{portal_cooldown});
        }
        return false;
    }

    if (!world.getPlayerAlive()) {
        loggers.getGameLog().debug("portal_player_dead", "Player not alive, skipping portal checks", .{});
        return false;
    }

    const player_pos = world.getPlayerPos();
    const player_radius = world.getPlayerRadius();
    
    loggers.getGameLog().debug("portal_check", "Checking portal collisions: player at {any} (radius: {d})", .{ player_pos, player_radius });

    // Check collisions with all portal entities using ECS
    const ecs_world = world.getECSWorldMut();
    var portal_iter = ecs_world.portals.entityIterator();
    var portal_count: u32 = 0;
    while (portal_iter.next()) |portal_id| {
        portal_count += 1;
        loggers.getGameLog().debug("portal_found", "Found portal entity: {any}", .{portal_id});
        
        if (!ecs_world.isAlive(portal_id)) {
            loggers.getGameLog().debug("portal_dead", "Portal entity {any} is not alive", .{portal_id});
            continue;
        }

        // Get portal interactable component for destination zone
        if (ecs_world.portals.getComponent(portal_id, .interactable)) |interactable| {
            loggers.getGameLog().debug("portal_interactable", "Portal {any} has interactable component", .{portal_id});
            if (interactable.destination_zone) |destination_zone| {
                loggers.getGameLog().debug("portal_destination", "Portal {any} leads to zone {}", .{ portal_id, destination_zone });
                if (ecs_world.portals.getComponent(portal_id, .transform)) |transform| {
                    loggers.getGameLog().debug("portal_transform", "Portal {any} at pos {any} (radius: {d})", .{ portal_id, transform.pos, transform.radius });
                    
                    const distance = math.distance(player_pos, transform.pos);
                    const collision_distance = player_radius + transform.radius;
                    loggers.getGameLog().debug("portal_distance", "Distance to portal {any}: {d} (collision at: {d})", .{ portal_id, distance, collision_distance });
                    
                    if (physics.checkPlayerPortalCollisionECS(player_pos, player_radius, transform)) {
                        loggers.getGameLog().info("portal_collision_detected", "Portal collision detected! Player at {any}, portal at {any}", .{ player_pos, transform.pos });
                        
                        // Set cooldown and travel
                        portal_cooldown = 1.0; // 1 second cooldown

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
                        loggers.getGameLog().debug("portal_no_collision", "No collision with portal {any} (distance: {d} > collision: {d})", .{ portal_id, distance, collision_distance });
                    }
                } else {
                    loggers.getGameLog().debug("portal_no_transform", "Portal {any} missing transform component", .{portal_id});
                }
            } else {
                loggers.getGameLog().debug("portal_no_destination", "Portal {any} has no destination zone", .{portal_id});
            }
        } else {
            loggers.getGameLog().debug("portal_no_interactable", "Portal {any} missing interactable component", .{portal_id});
        }
    }
    
    if (portal_count == 0) {
        loggers.getGameLog().debug("portal_none_found", "No portal entities found in current zone", .{});
    } else {
        loggers.getGameLog().debug("portal_check_complete", "Checked {} portals, no collision detected", .{portal_count});
    }

    return false;
}