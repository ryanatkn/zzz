const std = @import("std");

const types = @import("../lib/core/types.zig");
const entities = @import("entities.zig");
const behaviors = @import("behaviors.zig");
const maths = @import("../lib/core/maths.zig");
const physics = @import("physics.zig");
const player_controller = @import("player.zig");
const input = @import("../lib/platform/input.zig");
const constants = @import("constants.zig");
const ecs = @import("../lib/game/ecs.zig");
const effects = @import("effects.zig");

const Vec2 = types.Vec2;
const HexWorld = @import("hex_world.zig").HexWorld;
const Portal = entities.Portal;

pub fn handlePortalTravel(game_state: anytype, portal: *const Portal) void {
    const world = &game_state.world;
    const effect_system = &game_state.effect_system;
    game_state.input_state.clearMouseHold();

    const movement_direction = player_controller.getPlayerMovementDirectionECS(world);
    const player_radius = world.getPlayerRadius();

    const origin_zone = world.current_zone;
    const destination_zone = portal.destination_zone;
    
    std.debug.print("Portal travel! Entering zone {} from zone {}\n", .{ destination_zone, origin_zone });

    const new_zone = &world.zones[destination_zone];
    var spawn_pos = Vec2{ .x = constants.SCREEN_CENTER_X, .y = constants.SCREEN_CENTER_Y }; // Default fallback
    
    // Find return portal and calculate spawn position
    for (0..new_zone.portal_count) |i| {
        const return_portal = &new_zone.portals.items[i];
        if (return_portal.active and return_portal.destination_zone == origin_zone) {
            const offset_distance = return_portal.radius + player_radius + constants.PORTAL_SPAWN_OFFSET;

            if (movement_direction.x != 0 or movement_direction.y != 0) {
                spawn_pos = Vec2{
                    .x = return_portal.pos.x + movement_direction.x * offset_distance,
                    .y = return_portal.pos.y + movement_direction.y * offset_distance,
                };
            } else {
                spawn_pos = Vec2{
                    .x = return_portal.pos.x,
                    .y = return_portal.pos.y + offset_distance,
                };
            }

            // Clamp spawn position to screen bounds
            spawn_pos.x = std.math.clamp(spawn_pos.x, player_radius, constants.SCREEN_WIDTH - player_radius);
            spawn_pos.y = std.math.clamp(spawn_pos.y, player_radius, constants.SCREEN_HEIGHT - player_radius);

            // Add portal travel effect on the player's current position
            effect_system.addPortalTravelEffect(world.getPlayerPos(), player_radius);

            // Travel to destination zone with calculated spawn position
            world.travelToZone(destination_zone, spawn_pos) catch {
                std.debug.print("Error: Failed to travel to zone {}\n", .{destination_zone});
                return;
            };

            // Add portal ripple effect on the portal itself in the new zone
            effect_system.addPortalRippleEffect(return_portal.pos, return_portal.radius);
            return;
        }
    }

    // Fallback: no return portal found, spawn at center
    world.travelToZone(destination_zone, spawn_pos) catch {
        std.debug.print("Error: Failed to travel to zone {} (fallback)\n", .{destination_zone});
        return;
    };

    // Add portal travel effect for fallback spawn
    effect_system.addPortalTravelEffect(spawn_pos, player_radius);
}

pub fn checkPortalCollisions(game_state: anytype) bool {
    const world = &game_state.world;

    if (!world.getPlayerAlive()) return false;
    
    const player_pos = world.getPlayerPos();
    const player_radius = world.getPlayerRadius();

    // Check collision with all portals using ECS queries
    const ecs_world = world.getECSWorld();
    var terrain_iter = @constCast(&ecs_world.terrains).iterator();
    
    while (terrain_iter.next()) |entry| {
        const entity_id = entry.key_ptr.*;
        const terrain = entry.value_ptr.*;
        
        // Only check portals (door terrain with interactable component)
        if (terrain.terrain_type != .door) continue;
        if (!ecs_world.interactables.has(entity_id)) continue;
        
        // Get components
        if (ecs_world.transforms.getConst(entity_id)) |transform| {
            if (ecs_world.interactables.getConst(entity_id)) |interactable| {
                if (physics.checkPlayerPortalCollisionECS(player_pos, player_radius, transform)) {
                    handlePortalTravelECS(game_state, entity_id, interactable);
                    return true;
                }
            }
        }
    }
    
    return false;
}

// Handle portal travel using ECS components
fn handlePortalTravelECS(game_state: anytype, portal_id: ecs.EntityId, interactable: *const ecs.components.Interactable) void {
    _ = portal_id; // Unused for now
    if (interactable.destination_zone) |destination| {
        std.debug.print("Portal travel! Entering zone {} from zone {}\n", .{ destination, game_state.world.current_zone });
        game_state.travelToZone(destination);
    } else {
        std.debug.print("Portal has no destination zone!\n", .{});
    }
}
