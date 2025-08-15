/// Effects system module
/// 
/// Core effects system for visual effects and particle systems
/// with game-specific extensions for ECS integration

pub const core = @import("core.zig");
pub const game_effects = @import("game_effects.zig");

// Re-export core types
pub const Effect = core.Effect;
pub const EffectType = core.EffectType;
pub const EffectSystem = core.EffectSystem;
pub const MAX_EFFECTS = core.MAX_EFFECTS;

// Re-export game-specific types
pub const GameEffectSystem = game_effects.GameEffectSystem;