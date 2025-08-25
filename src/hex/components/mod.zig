// Hex-specific components module
// Game-specific component implementations moved from lib/game

// Status system
pub const hex_statuses = @import("hex_statuses.zig");
pub const HexStatuses = hex_statuses.HexStatuses;
pub const HexModifierType = hex_statuses.HexModifierType;
pub const StatusHelpers = hex_statuses.StatusHelpers;

// Magic system components
pub const Charmable = @import("charmable.zig").Charmable;
pub const Phaseable = @import("phaseable.zig").Phaseable;
pub const Teleportable = @import("teleportable.zig").Teleportable;
pub const MagicTarget = @import("magic_target.zig").MagicTarget;

// Behavior components
pub const Awakeable = @import("awakeable.zig").Awakeable;
pub const Interactable = @import("interactable.zig").Interactable;
pub const Hazard = @import("hazard.zig").Hazard;
