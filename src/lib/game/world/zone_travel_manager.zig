const std = @import("std");
const math = @import("../../math/mod.zig");
const zone_travel = @import("zone_travel.zig");
const teleporter_interface = @import("teleporter_interface.zig");

const Vec2 = math.Vec2;

/// Generic zone travel manager that combines teleporter mechanics with zone travel
/// This eliminates the need for separate portal integration layers
pub fn ZoneTravelManager(comptime GameType: type, comptime max_teleporters: usize) type {
    return struct {
        const Self = @This();
        
        // Core teleporter functionality
        teleporter_manager: teleporter_interface.TeleporterInterface.TeleporterManager(max_teleporters),
        
        // Game-specific interfaces (injected by game)
        travel_interface: TravelInterface,
        
        pub const TravelInterface = struct {
            // Zone validation
            validateZoneFn: *const fn (zone_index: usize) bool,
            
            // Zone spawn position retrieval
            getZoneSpawnFn: *const fn (game: *GameType, zone_index: usize) Vec2,
            
            // Player transfer between zones
            transferPlayerFn: *const fn (game: *GameType, destination_zone: usize, spawn_pos: Vec2) zone_travel.ZoneTravelInterface.TravelResult,
            
            // Effects management
            clearEffectsFn: *const fn (game: *GameType) void,
            createTravelEffectsFn: *const fn (game: *GameType, origin_pos: Vec2, radius: f32) void,
        };
        
        pub fn init(cooldown_duration: f32, travel_interface: TravelInterface) Self {
            return .{
                .teleporter_manager = teleporter_interface.TeleporterInterface.TeleporterManager(max_teleporters).init(cooldown_duration),
                .travel_interface = travel_interface,
            };
        }
        
        /// Add a teleporter/portal to the system
        pub fn addTeleporter(self: *Self, pos: Vec2, radius: f32, destination_zone: usize, spawn_pos: ?Vec2) !void {
            const teleporter = teleporter_interface.TeleporterInterface.TeleporterData{
                .entity_id = 0, // Dummy entity ID for now
                .position = pos,
                .radius = radius,
                .destination = teleporter_interface.TeleporterInterface.TeleporterDestination{
                    .zone_index = destination_zone,
                    .spawn_position = spawn_pos,
                },
                .config = teleporter_interface.TeleporterInterface.TeleporterConfig{},
            };
            try self.teleporter_manager.addTeleporter(teleporter);
        }
        
        /// Load teleporters from game-specific storage
        pub fn loadTeleportersFromGame(self: *Self, game: *GameType, loader_fn: *const fn (*GameType, *Self) anyerror!void) !void {
            self.teleporter_manager.clear();
            try loader_fn(game, self);
        }
        
        /// Check for teleporter collisions and execute travel
        pub fn checkTeleporterCollisions(self: *Self, game: *GameType, player_pos: Vec2, player_radius: f32) ?zone_travel.ZoneTravelInterface.TravelResult {
            // Check for collisions
            if (self.teleporter_manager.checkTeleporterCollision(player_pos, player_radius)) |teleporter_result| {
                if (!teleporter_result.activated) {
                    // Teleporter blocked (cooldown, etc.) - map to player transfer failed
                    return zone_travel.ZoneTravelInterface.TravelResult.failed(.player_transfer_failed);
                }
                
                if (teleporter_result.destination) |destination| {
                    // Validate destination zone
                    if (!self.travel_interface.validateZoneFn(destination.zone_index)) {
                        return zone_travel.ZoneTravelInterface.TravelResult.failed(.zone_not_loaded);
                    }
                    
                    // Get spawn position (use teleporter's spawn or zone default)
                    const spawn_pos = destination.spawn_position orelse 
                        self.travel_interface.getZoneSpawnFn(game, destination.zone_index);
                    
                    // Clear effects before travel
                    self.travel_interface.clearEffectsFn(game);
                    
                    // Create travel effects (need to find teleporter position - simplified for now)
                    self.travel_interface.createTravelEffectsFn(game, player_pos, player_radius);
                    
                    // Execute the travel
                    const result = self.travel_interface.transferPlayerFn(game, destination.zone_index, spawn_pos);
                    
                    return result;
                } else {
                    return zone_travel.ZoneTravelInterface.TravelResult.failed(.zone_not_loaded);
                }
            }
            
            return null;
        }
        
        /// Update the travel manager (cooldowns, etc.)
        pub fn update(self: *Self, delta_time: f32) void {
            self.teleporter_manager.update(delta_time);
        }
        
        /// Get cooldown information for UI
        pub fn getCooldownInfo(self: *const Self) struct { active: bool, remaining: f32 } {
            return self.teleporter_manager.getCooldownInfo();
        }
        
        /// Clear all teleporters
        pub fn clear(self: *Self) void {
            self.teleporter_manager.clear();
        }
        
        /// Get teleporter count
        pub fn getTeleporterCount(self: *const Self) usize {
            return self.teleporter_manager.teleporter_count;
        }
        
        /// Check if a specific teleporter exists
        pub fn hasTeleporterAt(self: *const Self, pos: Vec2, radius: f32) bool {
            return self.teleporter_manager.findTeleporterAt(pos, radius) != null;
        }
    };
}

/// Helper functions for creating travel interfaces
pub const TravelInterfaceHelpers = struct {
    /// Create a travel interface for a game type
    pub fn createTravelInterface(
        comptime GameType: type,
        validate_fn: *const fn (zone_index: usize) bool,
        spawn_fn: *const fn (game: *GameType, zone_index: usize) Vec2,
        transfer_fn: *const fn (game: *GameType, destination_zone: usize, spawn_pos: Vec2) zone_travel.ZoneTravelInterface.TravelResult,
        clear_effects_fn: *const fn (game: *GameType) void,
        create_effects_fn: *const fn (game: *GameType, origin_pos: Vec2, radius: f32) void,
    ) ZoneTravelManager(GameType, 0).TravelInterface {
        return .{
            .validateZoneFn = validate_fn,
            .getZoneSpawnFn = spawn_fn,
            .transferPlayerFn = transfer_fn,
            .clearEffectsFn = clear_effects_fn,
            .createTravelEffectsFn = create_effects_fn,
        };
    }
};