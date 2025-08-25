// Hex-specific abilities module
// Modular ability implementations with clean separation

// Core types and helpers
pub const types = @import("types.zig");
pub const helpers = @import("helpers.zig");

// Individual ability implementations
pub const lull = @import("lull.zig");
pub const blink = @import("blink.zig");
pub const phase = @import("phase.zig");
pub const charm = @import("charm.zig");
pub const lethargy = @import("lethargy.zig");
pub const haste = @import("haste.zig");
pub const multishot = @import("multishot.zig");
pub const dazzle = @import("dazzle.zig");

// Re-exports for convenience
pub const AbilityType = types.AbilityType;
pub const HexEffectType = types.HexEffectType;
pub const AbilityHelpers = helpers.AbilityHelpers;
pub const ValidationHelpers = helpers.ValidationHelpers;
