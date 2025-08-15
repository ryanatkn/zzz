// Hex game effects system - now using lib/effects
const effects = @import("../lib/effects/mod.zig");

// Re-export types for compatibility
pub const MAX_EFFECTS = effects.MAX_EFFECTS;
pub const EffectType = effects.EffectType;
pub const Effect = effects.Effect;
pub const EffectSystem = effects.GameEffectSystem; // Use the game-specific extension
