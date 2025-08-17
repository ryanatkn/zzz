pub const teleporter_interface = @import("teleporter_interface.zig");
pub const zone_travel = @import("zone_travel.zig");
pub const zone_travel_manager = @import("zone_travel_manager.zig");

// Re-export key types
pub const TeleporterInterface = teleporter_interface.TeleporterInterface;
pub const ZoneTravelInterface = zone_travel.ZoneTravelInterface;
pub const ZoneTravelManager = zone_travel_manager.ZoneTravelManager;