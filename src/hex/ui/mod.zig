// UI systems modules - extracted from various files for better organization

pub const EffectsSystem = @import("effects.zig").EffectsSystem;

// Re-export moved UI modules
pub const spellbar = @import("spellbar.zig");
pub const borders = @import("borders.zig");

// Re-export for convenience
pub const effects = @import("effects.zig");
