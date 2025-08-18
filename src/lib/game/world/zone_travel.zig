const std = @import("std");
const math = @import("../../math/mod.zig");

const Vec2 = math.Vec2;

/// Generic zone travel coordination interface
/// Games implement these patterns to handle inter-zone movement
pub const ZoneTravelInterface = struct {
    /// Result of a zone travel attempt
    pub const TravelResult = struct {
        success: bool,
        error_info: ?TravelError = null,

        pub const TravelError = enum {
            invalid_zone_index,
            zone_not_loaded,
            player_transfer_failed,
            effect_system_error,
        };

        pub fn ok() TravelResult {
            return .{ .success = true };
        }

        pub fn failed(error_info: TravelError) TravelResult {
            return .{ .success = false, .error_info = error_info };
        }
    };

    /// Travel request data
    pub const TravelRequest = struct {
        destination_zone: usize,
        spawn_position: ?Vec2 = null, // Use zone default if null
        clear_effects: bool = true, // Whether to clear visual effects on travel
        transfer_player: bool = true, // Whether to move player entity

        pub fn init(destination_zone: usize) TravelRequest {
            return .{ .destination_zone = destination_zone };
        }

        pub fn withSpawn(destination_zone: usize, spawn_pos: Vec2) TravelRequest {
            return .{ .destination_zone = destination_zone, .spawn_position = spawn_pos };
        }

        pub fn withoutEffectClear(self: TravelRequest) TravelRequest {
            var result = self;
            result.clear_effects = false;
            return result;
        }
    };

    /// Interface that games must implement for zone travel
    pub const ZoneTravelHandler = struct {
        /// Validate that a zone index is valid and accessible
        validateZoneFn: *const fn (zone_index: usize) bool,

        /// Get the default spawn position for a zone
        getZoneSpawnFn: *const fn (zone_index: usize) Vec2,

        /// Transfer player entity from current zone to destination zone
        transferPlayerFn: *const fn (destination_zone: usize, spawn_pos: Vec2) TravelResult,

        /// Clear visual effects (optional)
        clearEffectsFn: ?*const fn () void = null,

        /// Create travel effects (optional)
        createTravelEffectsFn: ?*const fn (origin_pos: Vec2, radius: f32) void = null,

        pub fn executeTravel(self: *const ZoneTravelHandler, request: TravelRequest, origin_pos: Vec2, player_radius: f32) TravelResult {
            // Validate destination zone
            if (!self.validateZoneFn(request.destination_zone)) {
                return TravelResult.failed(.invalid_zone_index);
            }

            // Get spawn position
            const spawn_pos = request.spawn_position orelse self.getZoneSpawnFn(request.destination_zone);

            // Create travel effects if requested
            if (self.createTravelEffectsFn) |createEffects| {
                createEffects(origin_pos, player_radius);
            }

            // Transfer player if requested
            if (request.transfer_player) {
                const transfer_result = self.transferPlayerFn(request.destination_zone, spawn_pos);
                if (!transfer_result.success) {
                    return transfer_result;
                }
            }

            // Clear effects if requested
            if (request.clear_effects) {
                if (self.clearEffectsFn) |clearEffects| {
                    clearEffects();
                }
            }

            return TravelResult.ok();
        }
    };

    /// Utility for managing zone transitions with common patterns
    pub const ZoneTransitionManager = struct {
        handler: ZoneTravelHandler,

        pub fn init(handler: ZoneTravelHandler) ZoneTransitionManager {
            return .{ .handler = handler };
        }

        /// Simple zone travel with default spawn
        pub fn travelToZone(self: *const ZoneTransitionManager, destination_zone: usize, origin_pos: Vec2, player_radius: f32) TravelResult {
            const request = TravelRequest.init(destination_zone);
            return self.handler.executeTravel(request, origin_pos, player_radius);
        }

        /// Zone travel with specific spawn position
        pub fn travelToZoneWithSpawn(self: *const ZoneTransitionManager, destination_zone: usize, spawn_pos: Vec2, origin_pos: Vec2, player_radius: f32) TravelResult {
            const request = TravelRequest.withSpawn(destination_zone, spawn_pos);
            return self.handler.executeTravel(request, origin_pos, player_radius);
        }

        /// Zone travel without clearing effects (for seamless transitions)
        pub fn travelToZoneSeamless(self: *const ZoneTransitionManager, destination_zone: usize, origin_pos: Vec2, player_radius: f32) TravelResult {
            const request = TravelRequest.init(destination_zone).withoutEffectClear();
            return self.handler.executeTravel(request, origin_pos, player_radius);
        }
    };
};
