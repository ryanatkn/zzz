const std = @import("std");
const math = @import("../../math/mod.zig");
const components = @import("../components/mod.zig");

const Vec2 = math.Vec2;

/// Generic combat action interface for projectile-based combat
/// Games implement these interfaces for their specific combat mechanics
pub const CombatActions = struct {
    /// Configuration for shooting actions
    pub const ShootConfig = struct {
        shooter_pos: Vec2,
        target_pos: Vec2,
        projectile_speed: f32,
        projectile_radius: f32,
        projectile_lifetime: f32,
        damage: f32,
        can_shoot: bool = true,

        pub fn fromShooterToTarget(shooter_pos: Vec2, target_pos: Vec2, speed: f32, radius: f32, lifetime: f32, damage: f32) ShootConfig {
            return .{
                .shooter_pos = shooter_pos,
                .target_pos = target_pos,
                .projectile_speed = speed,
                .projectile_radius = radius,
                .projectile_lifetime = lifetime,
                .damage = damage,
            };
        }
    };

    /// Generic shooting calculation - direction and velocity
    pub fn calculateProjectileVelocity(config: ShootConfig) Vec2 {
        const direction = config.target_pos.sub(config.shooter_pos).normalize();
        return direction.scale(config.projectile_speed);
    }

    /// Check if shooting is possible
    pub fn canShoot(config: ShootConfig) bool {
        return config.can_shoot;
    }
};

/// Generic targeting interface for combat systems
pub const TargetingInterface = struct {
    /// Mouse position to world position conversion
    /// Games implement this based on their camera system
    pub const MouseToWorldFn = *const fn (mouse_pos: Vec2, camera: anytype) Vec2;

    /// Player position getter interface
    /// Games implement this to provide current player position
    pub const GetPlayerPosFn = *const fn (game: anytype) Vec2;

    /// Player alive checker interface
    /// Games implement this to check if player can perform actions
    pub const IsPlayerAliveFn = *const fn (game: anytype) bool;

    /// Targeting helper functions
    pub const TargetingHelpers = struct {
        /// Calculate direction from shooter to target
        pub fn getShootDirection(shooter_pos: Vec2, target_pos: Vec2) Vec2 {
            return target_pos.sub(shooter_pos).normalize();
        }

        /// Calculate distance between shooter and target
        pub fn getTargetDistance(shooter_pos: Vec2, target_pos: Vec2) f32 {
            return shooter_pos.distance(target_pos);
        }

        /// Calculate squared distance (for performance)
        pub fn getTargetDistanceSquared(shooter_pos: Vec2, target_pos: Vec2) f32 {
            return shooter_pos.distanceSquared(target_pos);
        }
    };
};

/// Resource pool interface for rate-limited actions
pub const ResourcePoolInterface = struct {
    /// Generic resource pool checker
    /// Games implement this for their specific resource types (ammo, mana, etc.)
    pub const CanUseFn = *const fn (pool: anytype) bool;

    /// Generic resource consumer
    /// Games implement this to consume resources when actions are performed
    pub const ConsumeFn = *const fn (pool: anytype) void;

    /// Resource pool helpers
    pub const PoolHelpers = struct {
        /// Check if action can be performed and consume resource if possible
        pub fn tryConsume(pool: anytype, can_use_fn: CanUseFn, consume_fn: ConsumeFn) bool {
            if (can_use_fn(pool)) {
                consume_fn(pool);
                return true;
            }
            return false;
        }
    };
};

/// Generic combat action result
pub const CombatResult = struct {
    success: bool,
    entity_id: ?u32 = null,
    error_info: ?[]const u8 = null,

    pub fn ok(entity_id: u32) CombatResult {
        return .{ .success = true, .entity_id = entity_id };
    }

    pub fn failed(error_info: []const u8) CombatResult {
        return .{ .success = false, .error_info = error_info };
    }
};
