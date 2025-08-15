/// Projectile systems module
/// 
/// Provides bullet pools and projectile management systems
/// for rate-limited firing and resource management

pub const bullet_pool = @import("bullet_pool.zig");

// Re-export core types
pub const BulletPool = bullet_pool.BulletPool;