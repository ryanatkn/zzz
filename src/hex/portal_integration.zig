const std = @import("std");
const math = @import("../lib/math/mod.zig");
const world = @import("../lib/game/world/mod.zig");
const HexGame = @import("hex_game.zig").HexGame;
const constants = @import("constants.zig");
const hex_game_mod = @import("hex_game.zig");
const loggers = @import("../lib/debug/loggers.zig");

const Vec2 = math.Vec2;
const PortalSystem = world.PortalSystem;
const ZoneTravelInterface = world.ZoneTravelInterface;

/// Hex-specific implementation of generic portal system
/// This demonstrates how games can use the lib/game/world patterns
pub const HexPortalIntegration = struct {
    portal_manager: PortalSystem.PortalManager(hex_game_mod.MAX_ENTITIES_PER_ARCHETYPE),
    game_ref: ?*HexGame, // Reference to game for travel operations
    
    pub fn init() HexPortalIntegration {
        return .{
            .portal_manager = PortalSystem.PortalManager(hex_game_mod.MAX_ENTITIES_PER_ARCHETYPE).init(1.0),
            .game_ref = null,
        };
    }
    
    /// Initialize portal system with hex-specific travel handler
    pub fn setupWithGame(self: *HexPortalIntegration, game: *HexGame) void {
        self.game_ref = game;
        
        const travel_handler = ZoneTravelInterface.ZoneTravelHandler{
            .validateZoneFn = validateHexZone,
            .getZoneSpawnFn = getHexZoneSpawnFromGame,
            .transferPlayerFn = struct {
                fn impl(destination_zone: usize, spawn_pos: Vec2) ZoneTravelInterface.TravelResult {
                    // Access game through context - we'll improve this with proper closure pattern
                    // For now, we use the stored game reference
                    return transferHexPlayer(destination_zone, spawn_pos);
                }
            }.impl,
            .clearEffectsFn = clearHexEffects,
            .createTravelEffectsFn = createHexTravelEffects,
        };
        
        self.portal_manager.setTravelHandler(travel_handler);
    }
    
    /// Load portals from hex zone storage into generic portal system
    pub fn loadPortalsFromZone(self: *HexPortalIntegration, game: *HexGame) !void {
        self.portal_manager.clear();
        
        const zone = game.getCurrentZone();
        var portal_iter = zone.portals.entityIterator();
        
        while (portal_iter.next()) |portal_id| {
            // Get components from hex storage
            if (zone.portals.getComponent(portal_id, .transform)) |transform| {
                if (zone.portals.getComponent(portal_id, .interactable)) |interactable| {
                    if (interactable.destination_zone) |dest_zone| {
                        // Convert hex components to generic portal
                        const portal = PortalSystem.PortalComponentAdapter.createPortalFromComponents(
                            portal_id,
                            transform.pos,
                            transform.radius,
                            dest_zone,
                            null, // Use zone default spawn
                        ) orelse continue;
                        
                        try self.portal_manager.addPortal(portal);
                    }
                }
            }
        }
        
        loggers.getGameLog().info("portal_system_loaded", "Loaded {} portals from zone storage for zone {}", .{ self.portal_manager.teleporter_manager.teleporter_count, game.zone_manager.getCurrentZoneIndex() });
    }
    
    /// Update portal system (called from game loop)
    pub fn update(self: *HexPortalIntegration, delta_time: f32) void {
        self.portal_manager.update(delta_time);
    }
    
    /// Check portal collisions using generic system
    pub fn checkPortalCollisions(self: *HexPortalIntegration, player_pos: Vec2, player_radius: f32) bool {
        if (self.portal_manager.checkPortalCollisions(player_pos, player_radius)) |travel_result| {
            if (travel_result.success) {
                loggers.getGameLog().info("portal_travel_success", "Portal travel completed successfully", .{});
                return true;
            } else {
                loggers.getGameLog().err("portal_travel_failed", "Portal travel failed: {?}", .{travel_result.error_info});
                return false;
            }
        }
        return false;
    }
    
    /// Get cooldown status for UI display
    pub fn getCooldownInfo(self: *const HexPortalIntegration) struct { active: bool, remaining: f32 } {
        return self.portal_manager.getCooldownInfo();
    }
};

// Thread-local storage for game context (temporary solution for closure pattern)
var current_game_context: ?*HexGame = null;
var current_effect_system: ?*@import("../lib/effects/game_effects.zig").GameEffectSystem = null;

pub fn setGameContext(game: *HexGame, effects: ?*@import("../lib/effects/game_effects.zig").GameEffectSystem) void {
    current_game_context = game;
    current_effect_system = effects;
}

// Hex-specific implementations of travel handler functions
fn validateHexZone(zone_index: usize) bool {
    return zone_index < hex_game_mod.MAX_ZONES;
}

fn getHexZoneSpawnFromGame(zone_index: usize) Vec2 {
    if (current_game_context) |game| {
        if (zone_index < hex_game_mod.MAX_ZONES) {
            const zone = game.zone_manager.getZoneConst(zone_index);
            return zone.spawn_pos;
        }
    }
    // Fallback to reasonable default
    return Vec2{ .x = constants.SCREEN_CENTER_X, .y = constants.SCREEN_CENTER_Y };
}

fn transferHexPlayer(destination_zone: usize, spawn_pos: Vec2) ZoneTravelInterface.TravelResult {
    if (current_game_context) |game| {
        game.travelToZone(destination_zone, spawn_pos) catch |err| {
            loggers.getGameLog().err("portal_travel_failed", "Zone travel failed: {}", .{err});
            return ZoneTravelInterface.TravelResult.failed(.zone_not_loaded);
        };
        return ZoneTravelInterface.TravelResult.ok();
    }
    return ZoneTravelInterface.TravelResult.failed(.zone_not_loaded);
}

fn clearHexEffects() void {
    if (current_effect_system) |effects| {
        effects.clear();
        loggers.getGameLog().debug("effects_cleared", "Portal travel effects cleared", .{});
    }
}

fn createHexTravelEffects(origin_pos: Vec2, radius: f32) void {
    if (current_effect_system) |effects| {
        effects.addPortalTravelEffect(origin_pos, radius);
        loggers.getGameLog().debug("travel_effects_created", "Portal travel effects created at {any} with radius {}", .{ origin_pos, radius });
    }
}

/// Example of how to migrate from hex portals.zig to generic system
pub const PortalMigrationExample = struct {
    /// This shows how the existing hex portal code could be refactored
    pub fn migratePortalSystem(game: *HexGame) !HexPortalIntegration {
        var integration = HexPortalIntegration.init();
        integration.setupWithGame(game);
        try integration.loadPortalsFromZone(game);
        return integration;
    }
    
    /// Demonstration of how collision checking becomes simpler
    pub fn demonstrateCollisionCheck(integration: *HexPortalIntegration, game: *HexGame) bool {
        const player_pos = game.getPlayerPos();
        const player_radius = game.getPlayerRadius();
        
        // Before: Complex zone storage iteration and component access
        // After: Simple generic system call
        return integration.checkPortalCollisions(player_pos, player_radius);
    }
};