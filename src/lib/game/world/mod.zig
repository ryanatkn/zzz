pub const portal_system = @import("portal_system.zig");
pub const teleporter_interface = @import("teleporter_interface.zig");
pub const zone_travel = @import("zone_travel.zig");

// Re-export key types
pub const PortalSystem = portal_system.PortalSystem;
pub const TeleporterInterface = teleporter_interface.TeleporterInterface;
pub const ZoneTravelInterface = zone_travel.ZoneTravelInterface;