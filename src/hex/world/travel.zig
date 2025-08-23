const std = @import("std");

// Core capabilities
const math = @import("../../lib/math/mod.zig");

// Game system capabilities
const world = @import("../../lib/game/world/mod.zig");
const GameParticleSystem = @import("../../lib/particles/game_particles.zig").GameParticleSystem;

// Debug capabilities
const loggers = @import("../../lib/debug/loggers.zig");

// Hex game modules
const world_state_mod = @import("../world_state.zig");
const constants = @import("../constants.zig");

const Vec2 = math.Vec2;

/// Zone travel system functionality extracted from hex_game.zig
pub const TravelSystem = struct {
    /// Hex-specific travel interface implementations for the generic zone travel manager
    pub const HexTravelInterface = struct {
        pub fn validateZone(zone_index: usize) bool {
            return zone_index < world_state_mod.MAX_ZONES;
        }

        pub fn getZoneSpawn(game: *world_state_mod.HexGame, zone_index: usize) Vec2 {
            if (zone_index < world_state_mod.MAX_ZONES) {
                const zone = game.zone_manager.getZoneConst(zone_index);
                return zone.spawn_pos;
            }
            // Fallback to screen center
            return Vec2.screenCenter(constants.SCREEN_WIDTH, constants.SCREEN_HEIGHT);
        }

        pub fn transferPlayer(game: *world_state_mod.HexGame, destination_zone: usize, spawn_pos: Vec2) world.ZoneTravelInterface.TravelResult {
            game.travelToZone(destination_zone, spawn_pos) catch |err| {
                loggers.getGameLog().err("zone_travel_failed", "Zone travel failed: {}", .{err});
                return world.ZoneTravelInterface.TravelResult.failed(.zone_not_loaded);
            };
            return world.ZoneTravelInterface.TravelResult.ok();
        }

        pub fn clearParticles(game: *world_state_mod.HexGame) void {
            if (game.particle_system_ref) |particle_system| {
                particle_system.clear();
                loggers.getGameLog().debug("particles_cleared", "Travel particles cleared", .{});
            } else {
                loggers.getGameLog().debug("particles_cleared", "Travel particles cleared (no particle system available)", .{});
            }
        }

        pub fn createTravelParticles(game: *world_state_mod.HexGame, origin_pos: Vec2, radius: f32) void {
            if (game.particle_system_ref) |particle_system| {
                particle_system.addPortalTravelParticle(origin_pos, radius);
                loggers.getGameLog().debug("travel_particles_created", "Travel particles created at {any} with radius {}", .{ origin_pos, radius });
            } else {
                loggers.getGameLog().debug("travel_particles_created", "Travel particles created at {any} with radius {} (no particle system available)", .{ origin_pos, radius });
            }
        }
    };

    /// Initialize zone travel manager for hex game
    pub fn createZoneTravelManager() world.ZoneTravelManager(world_state_mod.HexGame, world_state_mod.MAX_ENTITIES_PER_ARCHETYPE) {
        return world.ZoneTravelManager(world_state_mod.HexGame, world_state_mod.MAX_ENTITIES_PER_ARCHETYPE).init(1.0, // 1 second cooldown
            world.zone_travel_manager.TravelInterfaceHelpers.createTravelInterface(
                world_state_mod.HexGame,
                HexTravelInterface.validateZone,
                HexTravelInterface.getZoneSpawn,
                HexTravelInterface.transferPlayer,
                HexTravelInterface.clearParticles,
                HexTravelInterface.createTravelParticles,
            ));
    }

    /// Travel to a zone with optional spawn position
    pub fn travelToZone(game: *world_state_mod.HexGame, zone_index: usize, spawn_pos: Vec2) !void {
        if (zone_index >= world_state_mod.MAX_ZONES) return;

        // Clear projectiles in all zones (bullets should not persist across zone travel)
        for (&game.zone_manager.zones) |*zone| {
            zone.projectiles.clear();
        }

        // Move player if exists
        if (game.player_entity) |player_entity| {
            if (game.player_zone != zone_index) {
                // Perform actual entity transfer between zones
                try transferPlayerToZone(game, player_entity, game.player_zone, zone_index, spawn_pos);
                game.player_zone = zone_index;

                game.logger.info("player_travel", "Player traveled from zone {} to zone {}", .{ game.zone_manager.getCurrentZoneIndex(), zone_index });
            }
        }

        game.setCurrentZone(zone_index);

        // Reload portals from new zone into zone travel manager
        loadPortalsIntoTravelManager(game) catch |err| {
            game.logger.err("portal_reload_failed", "Failed to reload portals after zone travel: {}", .{err});
        };

        // Update player position in new zone if no transfer was needed
        if (game.player_entity) |player| {
            if (game.player_zone == zone_index) {
                const zone = game.getCurrentZone();
                if (zone.players.getComponentMut(player, .transform)) |transform| {
                    transform.pos = spawn_pos;
                    transform.vel = Vec2.ZERO;
                }
            }
        }
    }

    /// Helper method for proper entity transfer between zones
    fn transferPlayerToZone(game: *world_state_mod.HexGame, player_entity: world_state_mod.EntityId, source_zone: usize, dest_zone: usize, new_pos: Vec2) !void {
        if (source_zone >= world_state_mod.MAX_ZONES or dest_zone >= world_state_mod.MAX_ZONES) return;

        const source = game.zone_manager.getZone(source_zone);
        const dest = game.zone_manager.getZone(dest_zone);

        // Extract player components from source zone
        const transform = source.players.getComponent(player_entity, .transform);
        const health = source.players.getComponent(player_entity, .health);
        const visual = source.players.getComponent(player_entity, .visual); // We need mutable to copy

        if (transform == null or health == null or visual == null) {
            game.logger.err("transfer_failed", "transferPlayerToZone: Player entity missing required components", .{});
            return;
        }

        // Create new player data with updated position
        const new_transform = world_state_mod.Transform.init(new_pos, transform.?.radius);
        const new_health = health.?.*;
        const player_input = world_state_mod.PlayerInput.init(0); // Reset input state
        const new_visual = visual.?.*;

        // Remove from source zone
        source.players.removeEntity(player_entity);
        source.entity_count -%= 1;

        // Add to destination zone
        const movement = world_state_mod.Movement.init(constants.PLAYER_SPEED);
        try dest.players.addEntity(player_entity, new_transform, new_health, player_input, new_visual, movement);
        dest.entity_count += 1;

        game.logger.debug("player_transferred", "Player entity {} transferred from zone {} to zone {}", .{ player_entity, source_zone, dest_zone });
    }

    /// Load portals from current zone into the zone travel manager
    fn loadPortalsIntoTravelManager(game: *world_state_mod.HexGame) !void {
        game.zone_travel_manager.clear();

        const zone = game.getCurrentZone();
        var portal_iter = zone.portals.entityIterator();

        while (portal_iter.next()) |portal_id| {
            // Get components from hex storage
            if (zone.portals.getComponent(portal_id, .transform)) |transform| {
                if (zone.portals.getComponent(portal_id, .interactable)) |interactable| {
                    if (interactable.destination_zone) |dest_zone| {
                        // Add portal to zone travel manager
                        try game.zone_travel_manager.addTeleporter(transform.pos, transform.radius, dest_zone, null // Use zone default spawn
                        );
                    }
                }
            }
        }

        game.logger.info("portals_loaded", "Loaded {} portals into zone travel manager for zone {}", .{ game.zone_travel_manager.getTeleporterCount(), game.zone_manager.getCurrentZoneIndex() });
    }
};
