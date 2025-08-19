const std = @import("std");
const math = @import("../lib/math/mod.zig");
const collision = @import("../lib/physics/collision.zig");
const queries = @import("../lib/physics/queries.zig");
const hex_game_mod = @import("hex_game.zig");
const HexGame = hex_game_mod.HexGame;
const constants = @import("constants.zig");
const components = @import("../lib/game/components/mod.zig");
const faction_integration = @import("faction_integration.zig");
const factions = @import("factions.zig");
const entity_queries = @import("entity_queries.zig");

/// Component-based approach to identify deadly terrain
/// This centralizes the logic and makes it easier to extend with Hazard components later
fn isDeadlyTerrain(terrain: *const components.Terrain) bool {
    // For now, use terrain type as bridge to component-based approach
    // Future: Check for presence of Hazard component with deadly=true
    return terrain.terrain_type == .pit;
}

// Check if entity can move to position (obstacle collision) - generic version
pub fn canEntityMoveTo(game: *HexGame, entity_id: hex_game_mod.EntityId, new_pos: math.Vec2) bool {
    const entity_radius = entity_queries.getEntityRadius(game, entity_id) orelse 20.0;
    return canEntityMoveToWithRadius(game, new_pos, entity_radius);
}

// Check if player can move to position (obstacle collision) - legacy compatibility
pub fn canPlayerMoveTo(game: *HexGame, new_pos: math.Vec2, player_radius: f32) bool {
    return canEntityMoveToWithRadius(game, new_pos, player_radius);
}

// Internal helper for obstacle collision checking
fn canEntityMoveToWithRadius(game: *HexGame, new_pos: math.Vec2, entity_radius: f32) bool {
    const zone = game.getCurrentZone();

    // Convert zone obstacles to query format
    var obstacles: [constants.MAX_OBSTACLES]queries.ObstacleData = undefined;
    var obstacle_count: usize = 0;

    for (0..zone.obstacles.count) |i| {
        const terrain = &zone.obstacles.terrains[i];
        const transform = &zone.obstacles.transforms[i];

        obstacles[obstacle_count] = queries.ObstacleData{
            .position = transform.pos,
            .size = terrain.size,
            .is_solid = terrain.solid,
            .is_deadly = isDeadlyTerrain(terrain),
        };
        obstacle_count += 1;
    }

    const config = queries.ObstacleQueryConfig{ .check_solid_only = true };
    const result = queries.PhysicsQueries.checkCircleObstacleCollision(new_pos, entity_radius, obstacles[0..obstacle_count], config);

    return !result.found;
}

// Player-unit collision check using faction-based relationships
pub fn checkPlayerUnitCollision(world: *hex_game_mod.HexGame) bool {
    const player_pos = world.getPlayerPos();
    const player_radius = world.getPlayerRadius();
    const zone_storage = world.getZoneStorage();

    // Get player entity ID for faction checking
    const player_entity = world.getPlayer() orelse return false;

    // Use idiomatic Zig iterator pattern
    var unit_iter = world.iterateUnitsInCurrentZone();
    while (unit_iter.next()) |entity_id| {
        if (zone_storage.units.getComponent(entity_id, .transform)) |transform| {
            if (zone_storage.units.getComponent(entity_id, .health)) |health| {
                // Only check alive units
                if (!health.alive) continue;

                // Check physical collision first
                if (collision.checkCircleCollision(player_pos, player_radius, transform.pos, transform.radius)) {
                    // Check faction relationship to determine if this should cause damage
                    if (faction_integration.getEntityRelation(world, entity_id, player_entity)) |relation| {
                        // Only hostile or suspicious entities with attack capability cause damage collision
                        if ((relation == .hostile or relation == .suspicious) and faction_integration.canEntityAttack(world, entity_id)) {
                            faction_integration.logFactionRelation(world, entity_id, player_entity, relation);
                            return true;
                        }
                        // Friendly/allied/neutral units don't cause damage collision
                        faction_integration.logFactionRelation(world, entity_id, player_entity, relation);
                    } else {
                        // Fallback to old behavior if faction data is missing
                        // TODO: Remove this fallback once all entities have faction data
                        if (zone_storage.units.getComponent(entity_id, .unit)) |unit| {
                            if (unit.disposition == .hostile) {
                                return true;
                            }
                        }
                    }
                }
            }
        }
    }
    return false;
}

// Portal collision check
pub fn checkPlayerPortalCollision(player_pos: math.Vec2, player_radius: f32, portal_transform: *const hex_game_mod.Transform) bool {
    return collision.checkCircleCollision(player_pos, player_radius, portal_transform.pos, portal_transform.radius);
}

// Unit-obstacle collision check
pub fn checkUnitObstacleCollision(world: *hex_game_mod.HexGame, unit_id: hex_game_mod.EntityId, unit_transform: *hex_game_mod.Transform, unit_health: *hex_game_mod.Health, old_pos: math.Vec2) bool {
    const zone_storage = world.getZoneStorage();

    // Use idiomatic Zig iterator pattern
    var obstacle_iter = world.iterateObstaclesInCurrentZone();
    while (obstacle_iter.next()) |entity_id| {
        if (zone_storage.obstacles.getComponent(entity_id, .terrain)) |terrain| {
            if (zone_storage.obstacles.getComponent(entity_id, .transform)) |transform| {
                const circle = collision.Shape{ .circle = .{ .center = unit_transform.pos, .radius = unit_transform.radius } };
                const rect = collision.Shape{ .rectangle = .{ .position = transform.pos, .size = terrain.size } };

                if (collision.checkCollision(circle, rect)) {
                    // Check if it's a deadly obstacle using component-based approach
                    if (isDeadlyTerrain(terrain)) {
                        unit_health.alive = false;
                        if (zone_storage.units.getComponentMut(unit_id, .visual)) |unit_visual| {
                            unit_visual.color = constants.COLOR_DEAD;
                        }
                    } else {
                        // Non-deadly obstacle - revert position
                        unit_transform.pos = old_pos;
                        unit_transform.vel = math.Vec2.ZERO;
                    }
                    return true;
                }
            }
        }
    }
    return false;
}

// Check if position collides with deadly obstacles
pub fn collidesWithDeadlyObstacle(pos: math.Vec2, radius: f32, world: *hex_game_mod.HexGame) bool {
    const zone = world.getCurrentZone();

    // Convert zone obstacles to query format (only deadly ones)
    var obstacles: [constants.MAX_OBSTACLES]queries.ObstacleData = undefined;
    var obstacle_count: usize = 0;

    for (0..zone.obstacles.count) |i| {
        const terrain = &zone.obstacles.terrains[i];
        const transform = &zone.obstacles.transforms[i];

        // Only include deadly obstacles using component-based approach
        if (isDeadlyTerrain(terrain)) {
            obstacles[obstacle_count] = queries.ObstacleData{
                .position = transform.pos,
                .size = terrain.size,
                .is_solid = terrain.solid,
                .is_deadly = true,
            };
            obstacle_count += 1;
        }
    }

    const config = queries.ObstacleQueryConfig{ .check_deadly_only = true };
    const result = queries.PhysicsQueries.checkCircleObstacleCollision(pos, radius, obstacles[0..obstacle_count], config);

    return result.found;
}

// Lifestone search result
pub const LifestoneResult = struct {
    pos: math.Vec2,
    zone_index: u32,
};

// Find nearest attuned lifestone across all zones
pub fn findNearestAttunedLifestone(game: *HexGame) ?LifestoneResult {
    const player_pos = game.getPlayerPos();

    // Collect all attuned lifestones across zones
    var lifestones: [hex_game_mod.MAX_ZONES * constants.MAX_LIFESTONES]queries.EntityData = undefined;
    var zone_indices: [hex_game_mod.MAX_ZONES * constants.MAX_LIFESTONES]u32 = undefined;
    var lifestone_count: usize = 0;

    // Search all zones for attuned lifestones
    for (0..hex_game_mod.MAX_ZONES) |zone_index| {
        const zone = game.zone_manager.getZone(zone_index);

        // Check all lifestones in this zone
        for (0..zone.lifestones.count) |i| {
            const interactable = &zone.lifestones.interactables[i];
            const transform = &zone.lifestones.transforms[i];

            // Check if lifestone is attuned (component-based identification)
            if (interactable.attuned) {
                lifestones[lifestone_count] = queries.EntityData{
                    .position = transform.pos,
                    .radius = transform.radius,
                    .is_alive = true, // attuned lifestones are "alive"
                };
                zone_indices[lifestone_count] = @intCast(zone_index);
                lifestone_count += 1;
            }
        }
    }

    if (lifestone_count == 0) return null;

    const result = queries.PhysicsQueries.findNearestEntity(player_pos, lifestones[0..lifestone_count], true);

    if (!result.found) return null;

    return LifestoneResult{
        .pos = result.position,
        .zone_index = zone_indices[result.index],
    };
}
