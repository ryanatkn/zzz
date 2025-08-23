// World management modules - Phase 3 extractions from world_state.zig

pub const EntityManager = @import("entity_manager.zig").EntityManager;
pub const ZoneTransitions = @import("zone_transitions.zig").ZoneTransitions;
pub const Respawn = @import("respawn.zig").Respawn;

// Existing world management modules
pub const ZoneManager = @import("zones.zig").ZoneManager;
pub const TravelSystem = @import("travel.zig").TravelSystem;

// Re-export existing world-related modules for compatibility
pub const loader = @import("../loader.zig");
pub const save_data = @import("../save_data.zig");

// Re-export for convenience
pub const entity_manager = @import("entity_manager.zig");
pub const zone_transitions = @import("zone_transitions.zig");
pub const respawn = @import("respawn.zig");
pub const zones = @import("zones.zig");
pub const travel = @import("travel.zig");
