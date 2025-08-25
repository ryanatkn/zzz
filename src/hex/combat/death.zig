const std = @import("std");

const loggers = @import("../../lib/debug/loggers.zig");
const math = @import("../../lib/math/mod.zig");
const game_systems = @import("../../lib/game/systems/mod.zig");
const world_state_mod = @import("../world_state.zig");
const game_loop_mod = @import("../game_loop.zig");
const entity_queries = @import("../entity_queries.zig");
const physics = @import("../physics.zig");
const constants = @import("../constants.zig");
const damage = @import("damage.zig");

const Vec2 = math.Vec2;
const HexGame = world_state_mod.HexGame;
const EntityId = world_state_mod.EntityId;
const GameState = game_loop_mod.GameState;

/// Convert hex lifestone to generic checkpoint data
fn lifestoneToCheckpoint(lifestone_result: physics.LifestoneResult) game_systems.respawn.RespawnInterface.CheckpointData {
    return game_systems.respawn.RespawnInterface.CheckpointData
        .init(lifestone_result.pos)
        .withZone(lifestone_result.zone_index);
}

/// Find best respawn checkpoint using generic patterns applied to hex lifestones
fn findBestRespawnCheckpoint(game: *HexGame) ?game_systems.respawn.RespawnInterface.CheckpointResult {
    const entity_pos = if (game.getControlledEntity()) |entity_id| blk: {
        break :blk entity_queries.getEntityPos(game, entity_id) orelse return null;
    } else return null;

    // Use hex-specific lifestone search
    if (physics.findNearestAttunedLifestone(game)) |lifestone_result| {
        const checkpoint = lifestoneToCheckpoint(lifestone_result);
        return game_systems.respawn.RespawnInterface.CheckpointResult.init(checkpoint, entity_pos);
    }

    return null;
}

/// Handle entity death with visual and state updates
pub fn handleEntityDeath(entity_id: EntityId, game: *HexGame, death_type: damage.DamageType) void {
    const zone = game.getCurrentZone();

    if (zone.units.getComponentMut(entity_id, .health)) |health| {
        // Use fatal damage for all death types (instant death)
        const damage_config = damage.DamageConfig.fatal();

        const result = damage.applyDamage(health, damage_config);

        if (result.target_killed) {
            // Update visual to show death
            if (zone.units.getComponentMut(entity_id, .visual)) |visual| {
                visual.color = constants.COLOR_DEAD;
            }

            const death_type_str = switch (death_type) {
                .environmental => "hazard",
                .collision => "collision",
                .projectile => "projectile",
                .spell => "spell",
            };

            loggers.getGameLog().info("entity_death", "Entity {} died from {}!", .{ entity_id, death_type_str });
        }
    }
}

/// Kill an entity instantly (for things like pit falls)
pub fn killEntity(entity_id: EntityId, game: *HexGame) void {
    handleEntityDeath(entity_id, game, .environmental);
}

/// Handle player death
pub fn handlePlayerDeath(game: *HexGame, death_type: damage.DamageType) void {
    if (game.getControlledEntity()) |controlled_entity| {
        handleEntityDeath(controlled_entity, game, death_type);
    }

    game.setPlayerAlive(false);
    loggers.getGameLog().info("player_death", "Player died! Press R or click to respawn", .{});
}

/// Handle player death on hazard
pub fn handlePlayerDeathOnHazard(game: *HexGame) void {
    handlePlayerDeath(game, .environmental);
}

/// Handle unit death on hazard
pub fn handleUnitDeathOnHazard(unit_entity: EntityId, game: *HexGame) void {
    handleEntityDeath(unit_entity, game, .environmental);
}

/// Respawn the player at the best checkpoint
pub fn respawnPlayer(game_state: *GameState) void {
    const world = &game_state.hex_game;
    const particle_system = &game_state.particle_system;

    // Find best respawn checkpoint
    const checkpoint_result = findBestRespawnCheckpoint(world);
    var respawn_pos: Vec2 = undefined;

    if (checkpoint_result) |result| {
        const checkpoint = result.checkpoint;
        respawn_pos = checkpoint.position;

        // Handle zone travel if checkpoint is in different zone
        if (checkpoint.zone_index) |target_zone| {
            if (target_zone != world.getCurrentZoneIndex()) {
                loggers.getGameLog().info("respawn_travel", "Respawning: traveling to zone {} for checkpoint at {any}", .{ target_zone, respawn_pos });

                game_state.travelToZoneWithSpawn(target_zone, respawn_pos) catch |err| {
                    loggers.getGameLog().err("respawn_travel_failed", "Failed to travel to zone {} for respawn: {}", .{ target_zone, err });
                };
            }
        }
    } else {
        // No checkpoints found - use fallback respawn logic
        if (world.getCurrentZoneIndex() != 0) {
            loggers.getGameLog().info("respawn_overworld", "No checkpoints found, returning to overworld spawn", .{});
            game_state.travelToZone(0) catch |err| {
                loggers.getGameLog().err("respawn_overworld_failed", "Failed to travel to overworld for respawn: {}", .{err});
            };
        }
        respawn_pos = Vec2.screenCenter(constants.SCREEN_WIDTH, constants.SCREEN_HEIGHT);
    }

    // Get controlled entity radius for respawn effect
    const controlled_radius = if (world.getControlledEntity()) |controlled_entity| blk: {
        const zone = world.getCurrentZoneConst();
        if (zone.units.getComponent(controlled_entity, .transform)) |transform| {
            break :blk transform.radius;
        }
        break :blk 0.7; // Default radius
    } else 0.7;

    const respawn_effect = game_systems.respawn.RespawnVisuals.RespawnVisualData.init(respawn_pos, controlled_radius);

    // Restore controlled entity to full health and set position
    if (world.getControlledEntity()) |controlled_entity| {
        const zone = world.getCurrentZone();
        if (zone.units.getComponentMut(controlled_entity, .transform)) |transform| {
            transform.pos = respawn_pos;
        }
        if (zone.units.getComponentMut(controlled_entity, .health)) |health| {
            damage.healToFull(health);
        }
        if (zone.units.getComponentMut(controlled_entity, .visual)) |visual| {
            visual.color = constants.COLOR_PLAYER_ALIVE;
        }
    }

    particle_system.addPlayerSpawnParticle(respawn_effect.position, respawn_effect.radius);
    loggers.getGameLog().info("player_respawn", "Player respawned at checkpoint!", .{});
}
