const std = @import("std");

// Core capabilities
const math = @import("../../lib/math/mod.zig");

// Physics capabilities
const collision = @import("../../lib/physics/collision/mod.zig");

// Hex game modules
const world_state_mod = @import("../world_state.zig");
const constants = @import("../constants.zig");

const Vec2 = math.Vec2;
const HexGame = world_state_mod.HexGame;

/// Lifestone mechanics system extracted from game.zig
pub const LifestoneSystem = struct {
    /// Check lifestone collisions - extracted from game.zig checkLifestoneCollisions()
    pub fn checkLifestoneCollisions(game_state: anytype) void {
        const world = &game_state.hex_game;

        // Get controlled entity position and radius
        const controlled_entity = world.getControlledEntity() orelse return;
        const zone = world.getCurrentZone();
        const controlled_transform = zone.units.getComponent(controlled_entity, .transform) orelse return;
        const controlled_pos = controlled_transform.pos;
        const controlled_radius = controlled_transform.radius;

        // Check all lifestones in this zone using direct array access like physics.zig does
        for (0..zone.lifestones.count) |i| {
            const entity_id = zone.lifestones.entities[i];
            if (entity_id == std.math.maxInt(u32)) continue;

            const transform = &zone.lifestones.transforms[i];
            const interactable = &zone.lifestones.interactables[i];

            // Lifestones are identified by component composition (having both Transform and Interactable with attunement capability)
            // This is more flexible than checking terrain type

            // Check collision first (allows re-attunement when overlapping)
            if (collision.checkCircleCollision(controlled_pos, controlled_radius, transform.pos, transform.radius)) {
                const was_attuned = interactable.attuned;

                // Attune the lifestone
                interactable.attuned = true;

                // Update visual color for attunement
                const visual = &zone.lifestones.visuals[i];
                visual.color = constants.COLOR_LIFESTONE_ATTUNED;

                // Only log and track stats for new attunements
                if (!was_attuned) {
                    game_state.logger.info("lifestone_attuned", "Lifestone attuned!", .{});

                    // Track lifestone attunement for save system
                    game_state.game_stats.lifestones_attuned += 1;

                    // Check if all lifestones are now attuned
                    if (hasAttunedAllLifestones(game_state)) {
                        game_state.logger.info("achievement", "All lifestones attuned!", .{});
                        game_state.game_stats.all_lifestones_attuned = true;
                    }
                }

                // Add inner effect for newly attuned lifestone
                game_state.particle_system.addLifestoneInnerParticleOnly(transform.pos, transform.radius);
            }
        }
    }

    /// Check if all lifestones across all zones are attuned
    pub fn hasAttunedAllLifestones(game_state: anytype) bool {
        // Direct computation - no complex caching
        var total_lifestones: usize = 0;
        var total_attuned: usize = 0;

        // Check all zones
        for (0..world_state_mod.MAX_ZONES) |zone_idx| {
            const zone = game_state.hex_game.zone_manager.getZoneConst(zone_idx);

            // Count lifestones in this zone
            for (0..zone.lifestones.count) |i| {
                const entity_id = zone.lifestones.entities[i];
                if (entity_id == std.math.maxInt(u32)) continue;

                total_lifestones += 1;

                // Check if attuned
                if (zone.lifestones.getComponent(entity_id, .interactable)) |interactable| {
                    if (interactable.attuned) {
                        total_attuned += 1;
                    }
                }
            }
        }

        return total_lifestones > 0 and total_attuned == total_lifestones;
    }

    /// Get total number of lifestones in the world
    pub fn getTotalLifestones(game_state: anytype) usize {
        var total_lifestones: usize = 0;

        // Check all zones
        for (0..world_state_mod.MAX_ZONES) |zone_idx| {
            const zone = game_state.hex_game.zone_manager.getZoneConst(zone_idx);

            // Count lifestones in this zone
            for (0..zone.lifestones.count) |i| {
                const entity_id = zone.lifestones.entities[i];
                if (entity_id == std.math.maxInt(u32)) continue;
                total_lifestones += 1;
            }
        }

        return total_lifestones;
    }

    /// Get number of attuned lifestones in the world
    pub fn getAttunedLifestones(game_state: anytype) usize {
        var total_attuned: usize = 0;

        // Check all zones
        for (0..world_state_mod.MAX_ZONES) |zone_idx| {
            const zone = game_state.hex_game.zone_manager.getZoneConst(zone_idx);

            // Count attuned lifestones in this zone
            for (0..zone.lifestones.count) |i| {
                const entity_id = zone.lifestones.entities[i];
                if (entity_id == std.math.maxInt(u32)) continue;

                // Check if attuned
                if (zone.lifestones.getComponent(entity_id, .interactable)) |interactable| {
                    if (interactable.attuned) {
                        total_attuned += 1;
                    }
                }
            }
        }

        return total_attuned;
    }
};
