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

        // Save player state from current zone before transfer
        var player_stats: ?struct {
            health_current: f32,
            health_max: f32,
            radius: f32,
            speed: f32,
            disposition: world_state_mod.Disposition,
            energy: constants.EnergyLevel,
        } = null;

        var old_entity_id: ?world_state_mod.EntityId = null;
        const old_zone_index: usize = game.zone_manager.getCurrentZoneIndex();

        // Extract player stats from current controlled entity
        if (game.getControlledEntity()) |controlled_entity| {
            const old_zone = game.getCurrentZone();
            if (old_zone.units.getComponent(controlled_entity, .health)) |health| {
                if (old_zone.units.getComponent(controlled_entity, .transform)) |transform| {
                    if (old_zone.units.getComponent(controlled_entity, .unit)) |unit| {
                        player_stats = .{
                            .health_current = health.current,
                            .health_max = health.max,
                            .radius = transform.radius,
                            .speed = unit.move_speed,
                            .disposition = unit.disposition,
                            .energy = unit.energy_level,
                        };
                        old_entity_id = controlled_entity;

                        game.logger.debug("player_transfer_save", "Saved player stats: health={}/{}, radius={}, speed={}, disposition={s}, energy={s}", .{ health.current, health.max, transform.radius, unit.move_speed, @tagName(unit.disposition), @tagName(unit.energy_level) });
                    }
                }
            }
        }

        // Switch to the new zone
        game.setCurrentZone(zone_index);

        // Create new player entity in the destination zone with preserved stats
        if (player_stats) |stats| {
            const player_config = world_state_mod.PlayerConfig{
                .position = spawn_pos,
                .radius = stats.radius,
                .speed = stats.speed,
                .energy = stats.energy,
                .disposition = stats.disposition,
            };

            const new_player_id = try game.createPlayer(player_config);

            // Restore health
            const new_zone = game.getCurrentZone();
            if (new_zone.units.getComponentMut(new_player_id, .health)) |health| {
                health.current = stats.health_current;
                health.max = stats.health_max;
                health.alive = true;
            }

            // Entity tracking is now handled by the controller system

            // Transfer control to the new entity
            _ = game.primary_controller.possess(game, new_player_id);

            game.logger.info("player_transfer_complete", "Player transferred from zone {} to zone {}, entity {} -> {}", .{ old_zone_index, zone_index, old_entity_id orelse 0, new_player_id });

            // Clean up old entity from old zone
            if (old_entity_id) |old_id| {
                const old_zone = game.zone_manager.getZone(old_zone_index);
                _ = old_zone.units.removeEntity(old_id);
                game.logger.debug("player_cleanup", "Cleaned up old player entity {} from zone {}", .{ old_id, old_zone_index });
            }
        } else {
            game.logger.warn("player_transfer_failed", "No controlled entity found to transfer", .{});
        }

        // Reload portals from new zone into zone travel manager
        loadPortalsIntoTravelManager(game) catch |err| {
            game.logger.err("portal_reload_failed", "Failed to reload portals after zone travel: {}", .{err});
        };
    }

    // Player is now fully transferred via the unified entity system above

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
