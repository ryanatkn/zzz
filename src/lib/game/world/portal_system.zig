const std = @import("std");
const math = @import("../../math/mod.zig");
const teleporter = @import("teleporter_interface.zig");
const zone_travel = @import("zone_travel.zig");
const cooldowns = @import("../cooldowns.zig");

const Vec2 = math.Vec2;
const TeleporterInterface = teleporter.TeleporterInterface;
const ZoneTravelInterface = zone_travel.ZoneTravelInterface;

/// Complete portal system combining teleporter mechanics with zone travel
/// This is a high-level system that games can use directly or extend
pub const PortalSystem = struct {
    /// Portal-specific configuration
    pub const PortalConfig = struct {
        collision_radius: f32 = 32.0,
        cooldown_duration: f32 = 1.0,
        auto_activate: bool = true,
        create_effects: bool = true,
        clear_effects_on_travel: bool = true,
    };

    /// Portal entity data combining teleporter and game-specific info
    pub const Portal = struct {
        teleporter_data: TeleporterInterface.TeleporterData,
        portal_config: PortalConfig,
        
        pub fn init(entity_id: u32, position: Vec2, destination_zone: usize) Portal {
            const destination = TeleporterInterface.TeleporterDestination{ .zone_index = destination_zone };
            const teleporter_data = TeleporterInterface.TeleporterData.init(entity_id, position, 32.0, destination);
            
            return .{
                .teleporter_data = teleporter_data,
                .portal_config = PortalConfig{},
            };
        }
        
        pub fn withSpawnPos(entity_id: u32, position: Vec2, destination_zone: usize, spawn_pos: Vec2) Portal {
            const destination = TeleporterInterface.TeleporterDestination.withPosition(destination_zone, spawn_pos);
            const teleporter_data = TeleporterInterface.TeleporterData.init(entity_id, position, 32.0, destination);
            
            return .{
                .teleporter_data = teleporter_data,
                .portal_config = PortalConfig{},
            };
        }
        
        pub fn withConfig(self: Portal, config: PortalConfig) Portal {
            var result = self;
            result.portal_config = config;
            result.teleporter_data.radius = config.collision_radius;
            result.teleporter_data.config.cooldown_duration = config.cooldown_duration;
            result.teleporter_data.config.auto_activate = config.auto_activate;
            result.teleporter_data.config.effect_on_use = config.create_effects;
            return result;
        }
    };

    /// Complete portal manager that handles collision, cooldowns, and travel
    pub fn PortalManager(comptime max_portals: usize) type {
        return struct {
            const Self = @This();
            
            teleporter_manager: TeleporterInterface.TeleporterManager(max_portals),
            travel_manager: ?ZoneTravelInterface.ZoneTransitionManager,
            
            pub fn init(cooldown_duration: f32) Self {
                return .{
                    .teleporter_manager = TeleporterInterface.TeleporterManager(max_portals).init(cooldown_duration),
                    .travel_manager = null,
                };
            }
            
            pub fn setTravelHandler(self: *Self, handler: ZoneTravelInterface.ZoneTravelHandler) void {
                self.travel_manager = ZoneTravelInterface.ZoneTransitionManager.init(handler);
            }
            
            pub fn addPortal(self: *Self, portal: Portal) !void {
                try self.teleporter_manager.addTeleporter(portal.teleporter_data);
            }
            
            pub fn clear(self: *Self) void {
                self.teleporter_manager.clear();
            }
            
            pub fn update(self: *Self, delta_time: f32) void {
                self.teleporter_manager.update(delta_time);
            }
            
            /// Check for portal collisions and execute travel if found
            pub fn checkPortalCollisions(self: *Self, player_pos: Vec2, player_radius: f32) ?ZoneTravelInterface.TravelResult {
                if (self.travel_manager == null) return null;
                
                if (self.teleporter_manager.checkTeleporterCollision(player_pos, player_radius)) |teleporter_result| {
                    if (teleporter_result.activated and teleporter_result.destination != null) {
                        const dest = teleporter_result.destination.?;
                        
                        // Execute travel
                        if (dest.spawn_position) |spawn_pos| {
                            return self.travel_manager.?.travelToZoneWithSpawn(dest.zone_index, spawn_pos, player_pos, player_radius);
                        } else {
                            return self.travel_manager.?.travelToZone(dest.zone_index, player_pos, player_radius);
                        }
                    }
                }
                
                return null;
            }
            
            /// Get current cooldown status
            pub fn getCooldownInfo(self: *const Self) struct { active: bool, remaining: f32 } {
                return .{
                    .active = self.teleporter_manager.isCooldownActive(),
                    .remaining = self.teleporter_manager.getCooldownRemaining(),
                };
            }
        };
    }

    /// Helper to create portals from component data (for integration with ECS)
    pub const PortalComponentAdapter = struct {
        /// Convert generic transform/interactable components to portal data
        pub fn createPortalFromComponents(
            entity_id: u32,
            transform_pos: Vec2,
            transform_radius: f32,
            destination_zone: ?usize,
            spawn_position: ?Vec2,
        ) ?Portal {
            _ = transform_radius; // Currently unused, could be used for collision radius
            const dest_zone = destination_zone orelse return null;
            
            if (spawn_position) |spawn_pos| {
                return Portal.withSpawnPos(entity_id, transform_pos, dest_zone, spawn_pos);
            } else {
                return Portal.init(entity_id, transform_pos, dest_zone);
            }
        }
        
        /// Update portal radius from transform component
        pub fn updatePortalRadius(portal: *Portal, new_radius: f32) void {
            portal.teleporter_data.radius = new_radius;
            portal.portal_config.collision_radius = new_radius;
        }
        
        /// Update portal position from transform component
        pub fn updatePortalPosition(portal: *Portal, new_position: Vec2) void {
            portal.teleporter_data.position = new_position;
        }
    };
};