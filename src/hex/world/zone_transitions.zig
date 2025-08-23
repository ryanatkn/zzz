// Zone Transitions - Phase 3 extraction from world_state.zig
// Handles portal and zone switching logic, delegating to existing TravelSystem

const std = @import("std");

// Core capabilities
const math = @import("../../lib/math/mod.zig");

// Hex game modules
const world_state_mod = @import("../world_state.zig");
const travel_mod = @import("travel.zig");

const Vec2 = math.Vec2;
const HexGame = world_state_mod.HexGame;

/// Zone transition management - extracted from world_state.zig
/// This module provides a clean interface for zone travel while
/// delegating to the existing TravelSystem to avoid duplication
pub const ZoneTransitions = struct {
    /// Travel to a zone with optional spawn position
    /// Delegates to the existing TravelSystem implementation
    pub fn travelToZone(game: *HexGame, zone_index: usize, spawn_pos: Vec2) !void {
        return travel_mod.TravelSystem.travelToZone(game, zone_index, spawn_pos);
    }

    /// Load portals from current zone into the zone travel manager
    /// This functionality is handled internally by TravelSystem.travelToZone
    /// but exposed here for explicit portal reloading if needed
    pub fn reloadPortals(game: *HexGame) !void {
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
