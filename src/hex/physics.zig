const std = @import("std");
const math = @import("../lib/math/mod.zig");
const collision = @import("../lib/physics/collision/mod.zig");
const queries = @import("../lib/physics/queries.zig");
const world_state_mod = @import("world_state.zig");
const HexGame = world_state_mod.HexGame;
const constants = @import("constants.zig");
const components = @import("../lib/game/components/mod.zig");
const faction_integration = @import("faction_integration.zig");
const factions = @import("factions.zig");
const entity_queries = @import("entity_queries.zig");

// TODO heavily refactor for performance

/// Component-based approach to identify deadly terrain
/// This centralizes the logic and makes it easier to extend with Hazard components later
fn isDeadlyTerrain(terrain: *const components.Terrain) bool {
    // For now, use terrain type as bridge to component-based approach
    // Future: Check for presence of Hazard component with deadly=true
    return terrain.terrain_type == .pit;
}

// Check if entity can move to position (obstacle collision) - generic version
pub fn canEntityMoveTo(game: *HexGame, entity_id: world_state_mod.EntityId, new_pos: math.Vec2) bool {
    const entity_radius = entity_queries.getEntityRadius(game, entity_id) orelse 0.2; // 20cm default radius
    return canEntityMoveToWithRadius(game, new_pos, entity_radius);
}

// Check if player can move to position (obstacle collision) - legacy compatibility
pub fn canControlledEntityMoveTo(game: *HexGame, new_pos: math.Vec2) bool {
    const controlled_entity = game.getControlledEntity() orelse return false;
    const zone_storage = game.getZoneStorage();
    const controlled_transform = zone_storage.units.getComponent(controlled_entity, .transform) orelse return false;
    return canEntityMoveToWithRadius(game, new_pos, controlled_transform.radius);
}

// Internal helper for obstacle collision checking
fn canEntityMoveToWithRadius(game: *HexGame, new_pos: math.Vec2, entity_radius: f32) bool {
    const zone = game.getCurrentZone();

    // Convert zone terrain to query format using ECS iteration
    var obstacles: [constants.MAX_TERRAIN]queries.ObstacleData = undefined;
    var obstacle_count: usize = 0;

    var terrain_iter = game.iterateTerrainInCurrentZone();
    while (terrain_iter.next()) |terrain_id| {
        if (zone.terrain.getComponent(terrain_id, .terrain)) |terrain| {
            if (zone.terrain.getComponent(terrain_id, .transform)) |transform| {
                if (obstacle_count < obstacles.len) {
                    obstacles[obstacle_count] = queries.ObstacleData{
                        .position = transform.pos,
                        .size = terrain.size,
                        .is_solid = terrain.solid,
                        .is_deadly = terrain.deadly,
                    };
                    obstacle_count += 1;
                }
            }
        }
    }

    const config = queries.ObstacleQueryConfig{ .check_solid_only = true };
    const result = queries.PhysicsQueries.checkCircleObstacleCollision(new_pos, entity_radius, obstacles[0..obstacle_count], config);

    return !result.found;
}

// Controlled entity-unit collision check using faction-based relationships
pub fn checkControlledEntityUnitCollision(world: *world_state_mod.HexGame) bool {
    const controlled_entity = world.getControlledEntity() orelse return false;
    const zone_storage = world.getZoneStorage();

    // Get controlled entity position and radius
    const controlled_transform = zone_storage.units.getComponent(controlled_entity, .transform) orelse return false;
    const controlled_pos = controlled_transform.pos;
    const controlled_radius = controlled_transform.radius;

    // Use idiomatic Zig iterator pattern
    var unit_iter = world.iterateUnitsInCurrentZone();
    while (unit_iter.next()) |entity_id| {
        // Skip self-collision
        if (entity_id == controlled_entity) continue;

        if (zone_storage.units.getComponent(entity_id, .transform)) |transform| {
            if (zone_storage.units.getComponent(entity_id, .health)) |health| {
                // Only check alive units
                if (!health.alive) continue;

                // Check physical collision first
                if (collision.checkCircleCollision(controlled_pos, controlled_radius, transform.pos, transform.radius)) {
                    // Check faction relationship to determine if this should cause damage
                    if (faction_integration.getEntityRelation(world, entity_id, controlled_entity)) |relation| {
                        // Only hostile or suspicious entities with attack capability cause damage collision
                        if ((relation == .hostile or relation == .suspicious) and faction_integration.canEntityAttack(world, entity_id)) {
                            faction_integration.logFactionRelation(world, entity_id, controlled_entity, relation);
                            return true;
                        }
                        // Friendly/neutral units don't cause damage collision
                        faction_integration.logFactionRelation(world, entity_id, controlled_entity, relation);
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
pub fn checkPlayerPortalCollision(player_pos: math.Vec2, player_radius: f32, portal_transform: *const world_state_mod.Transform) bool {
    return collision.checkCircleCollision(player_pos, player_radius, portal_transform.pos, portal_transform.radius);
}

// Unit-terrain collision check
pub fn checkUnitTerrainCollision(world: *world_state_mod.HexGame, unit_id: world_state_mod.EntityId, unit_transform: *world_state_mod.Transform, unit_health: *world_state_mod.Health, old_pos: math.Vec2) bool {
    const zone_storage = world.getZoneStorage();

    // Use idiomatic Zig iterator pattern
    var terrain_iter = world.iterateTerrainInCurrentZone();
    while (terrain_iter.next()) |entity_id| {
        if (zone_storage.terrain.getComponent(entity_id, .terrain)) |terrain| {
            if (zone_storage.terrain.getComponent(entity_id, .transform)) |transform| {
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

// Check hostile-friendly unit collisions - hostiles die when touching friendlies
pub fn checkHostileFriendlyUnitCollision(world: *world_state_mod.HexGame) bool {
    const zone_storage = world.getZoneStorage();
    var collision_occurred = false;

    // Use idiomatic Zig iterator pattern for outer loop (potential hostiles)
    var hostile_iter = world.iterateUnitsInCurrentZone();
    while (hostile_iter.next()) |hostile_id| {
        if (zone_storage.units.getComponent(hostile_id, .transform)) |hostile_transform| {
            if (zone_storage.units.getComponentMut(hostile_id, .health)) |hostile_health| {
                if (!hostile_health.alive) continue;

                if (zone_storage.units.getComponent(hostile_id, .unit)) |hostile_unit| {
                    // Only check hostile units
                    if (hostile_unit.disposition != .hostile) continue;

                    // Check collision with all other units
                    var friendly_iter = world.iterateUnitsInCurrentZone();
                    while (friendly_iter.next()) |friendly_id| {
                        // Skip self-collision
                        if (hostile_id == friendly_id) continue;

                        if (zone_storage.units.getComponent(friendly_id, .transform)) |friendly_transform| {
                            if (zone_storage.units.getComponent(friendly_id, .health)) |friendly_health| {
                                // Only check alive units
                                if (!friendly_health.alive) continue;

                                if (zone_storage.units.getComponent(friendly_id, .unit)) |friendly_unit| {
                                    // Only check friendly units
                                    if (friendly_unit.disposition != .friendly) continue;

                                    // Check physical collision
                                    if (collision.checkCircleCollision(hostile_transform.pos, hostile_transform.radius, friendly_transform.pos, friendly_transform.radius)) {
                                        // Kill the hostile unit
                                        hostile_health.alive = false;
                                        collision_occurred = true;

                                        // Set visual to dead color
                                        if (zone_storage.units.getComponentMut(hostile_id, .visual)) |hostile_visual| {
                                            hostile_visual.color = constants.COLOR_DEAD;
                                        }

                                        // Log the collision
                                        world.logger.info("hostile_death", "Hostile unit {} killed by friendly collision with {}", .{ hostile_id, friendly_id });

                                        break; // Exit inner loop once hostile is dead
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    return collision_occurred;
}

// Lifestone search result
pub const LifestoneResult = struct {
    pos: math.Vec2,
    zone_index: u32,
};

// Find nearest attuned lifestone across all zones
pub fn findNearestAttunedLifestone(game: *HexGame) ?LifestoneResult {
    // Get controlled entity position for lifestone search
    const controlled_pos = if (game.getControlledEntity()) |controlled_entity| blk: {
        const zone = game.getCurrentZoneConst();
        if (zone.units.getComponent(controlled_entity, .transform)) |transform| {
            break :blk transform.pos;
        }
        break :blk math.Vec2.ZERO;
    } else math.Vec2.ZERO;

    // Collect all attuned lifestones across zones
    var lifestones: [world_state_mod.MAX_ZONES * constants.MAX_LIFESTONES]queries.EntityData = undefined;
    var zone_indices: [world_state_mod.MAX_ZONES * constants.MAX_LIFESTONES]u32 = undefined;
    var lifestone_count: usize = 0;

    // Search all zones for attuned lifestones
    for (0..world_state_mod.MAX_ZONES) |zone_index| {
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

    const result = queries.PhysicsQueries.findNearestEntity(controlled_pos, lifestones[0..lifestone_count], true);

    if (!result.found) return null;

    return LifestoneResult{
        .pos = result.position,
        .zone_index = zone_indices[result.index],
    };
}
