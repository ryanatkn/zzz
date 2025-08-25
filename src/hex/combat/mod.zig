/// Hex Combat Module
///
/// Centralized combat systems for the Hex game including damage, projectiles,
/// targeting, and death handling. This module contains Hex-specific implementations
/// that were moved from the generic lib/game system.
pub const damage = @import("damage.zig");
pub const projectiles = @import("projectiles.zig");
pub const targeting = @import("targeting.zig");
pub const death = @import("death.zig");
// Combat constants are in main hex constants.zig (meters/second units)

// Re-export common types for convenience
pub const DamageType = damage.DamageType;
pub const DamageConfig = damage.DamageConfig;
pub const DamageResult = damage.DamageResult;

// Re-export projectile functions
pub const fireProjectile = projectiles.fireProjectile;
pub const fireProjectileAtMouse = projectiles.fireProjectileAtMouse;

// Re-export death handling
pub const handleEntityDeath = death.handleEntityDeath;
pub const killEntity = death.killEntity;
