/// Generic combat systems for projectile-based games
/// Engine provides interfaces, games provide implementations

// Core combat systems
pub const combat_actions = @import("combat_actions.zig");
pub const damage_system = @import("damage_system.zig");
pub const targeting = @import("targeting.zig");

// Re-export key types for convenience
pub const CombatActions = combat_actions.CombatActions;
pub const TargetingInterface = combat_actions.TargetingInterface;
pub const ResourcePoolInterface = combat_actions.ResourcePoolInterface;
pub const CombatResult = combat_actions.CombatResult;

pub const DamageSystem = damage_system.DamageSystem;
pub const DeathHandling = damage_system.DeathHandling;

pub const Targeting = targeting.Targeting;
pub const TargetSelection = targeting.TargetSelection;
pub const AoETargeting = targeting.AoETargeting;


// Commonly used types
pub const ShootConfig = combat_actions.CombatActions.ShootConfig;
pub const DamageConfig = damage_system.DamageSystem.DamageConfig;
pub const DamageResult = damage_system.DamageSystem.DamageResult;
pub const TargetResult = targeting.TargetSelection.TargetResult;
pub const AoEConfig = targeting.AoETargeting.AoEConfig;