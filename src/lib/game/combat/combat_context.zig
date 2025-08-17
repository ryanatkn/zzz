const std = @import("std");
const math = @import("../../math/mod.zig");
const contexts = @import("../contexts/mod.zig");
const combat_actions = @import("combat_actions.zig");
const targeting = @import("targeting.zig");

const Vec2 = math.Vec2;

/// Combat-specific context that combines targeting, actions, and game state
/// This provides a cleaner interface for combat operations than generic game context
pub fn CombatContext(comptime GameType: type, comptime PoolType: type) type {
    return struct {
        const Self = @This();
        
        // Core context data
        base_context: contexts.UpdateContext,
        input_context: contexts.InputContext,
        graphics_context: contexts.GraphicsContext,
        
        // Combat-specific data
        game: *GameType,
        resource_pool: *PoolType,
        targeting_config: targeting.Targeting.ScreenToWorldConfig,
        
        pub fn init(
            base: contexts.UpdateContext,
            input: contexts.InputContext,
            graphics: contexts.GraphicsContext,
            game: *GameType,
            pool: *PoolType,
            targeting_cfg: targeting.Targeting.ScreenToWorldConfig,
        ) Self {
            return .{
                .base_context = base,
                .input_context = input,
                .graphics_context = graphics,
                .game = game,
                .resource_pool = pool,
                .targeting_config = targeting_cfg,
            };
        }
        
        /// Get mouse world position using the combat context's targeting config
        pub fn getMouseWorldPos(self: *const Self) Vec2 {
            return targeting.Targeting.screenToWorld(self.input_context.mouse_position, self.targeting_config);
        }
        
        /// Check if the resource pool allows an action
        pub fn canUseResource(self: *const Self) bool {
            // This would use the resource pool interface
            // For now, assume the pool has a canFire() method
            return @hasDecl(PoolType, "canFire") and self.resource_pool.canFire();
        }
        
        /// Consume from the resource pool
        pub fn consumeResource(self: *Self) void {
            // This would use the resource pool interface
            // For now, assume the pool has a fire() method
            if (@hasDecl(PoolType, "fire")) {
                self.resource_pool.fire();
            }
        }
        
        /// Get delta time from base context
        pub fn getDeltaTime(self: *const Self) f32 {
            return self.base_context.delta_time;
        }
        
        /// Check if mouse button is pressed
        pub fn isMousePressed(self: *const Self, button: contexts.MouseButtons) bool {
            return self.input_context.mouse_buttons.isPressed(button);
        }
        
        /// Check if mouse button was just clicked
        pub fn isMouseJustClicked(self: *const Self, button: contexts.MouseButtons) bool {
            return self.input_context.mouse_buttons.wasJustPressed(button);
        }
    };
}

/// Combat action builder that uses combat context
pub const CombatActionBuilder = struct {
    /// Build a shoot configuration from combat context and game interfaces
    pub fn buildShootConfig(
        comptime GameType: type,
        comptime PoolType: type,
        context: *const CombatContext(GameType, PoolType),
        get_player_pos_fn: *const fn (*GameType) Vec2,
        is_player_alive_fn: *const fn (*GameType) bool,
        speed: f32,
        radius: f32,
        lifetime: f32,
        damage: f32,
    ) combat_actions.CombatActions.ShootConfig {
        const player_pos = get_player_pos_fn(context.game);
        const target_pos = context.getMouseWorldPos();
        const can_shoot = is_player_alive_fn(context.game) and context.canUseResource();
        
        return combat_actions.CombatActions.ShootConfig{
            .shooter_pos = player_pos,
            .target_pos = target_pos,
            .projectile_speed = speed,
            .projectile_radius = radius,
            .projectile_lifetime = lifetime,
            .damage = damage,
            .can_shoot = can_shoot,
        };
    }
    
    /// Execute a shooting action using the combat context
    pub fn executeShoot(
        comptime GameType: type,
        comptime PoolType: type,
        context: *CombatContext(GameType, PoolType),
        config: combat_actions.CombatActions.ShootConfig,
        create_projectile_fn: *const fn (*GameType, Vec2, Vec2, f32, f32, f32) anyerror!u32,
    ) combat_actions.CombatActions.CombatResult {
        if (!combat_actions.CombatActions.canShoot(config)) {
            return combat_actions.CombatActions.CombatResult.failed("Cannot shoot");
        }
        
        const velocity = combat_actions.CombatActions.calculateProjectileVelocity(config);
        
        // Attempt to create projectile
        const projectile_id = create_projectile_fn(
            context.game,
            config.shooter_pos,
            velocity,
            config.projectile_radius,
            config.projectile_lifetime,
            config.damage,
        ) catch {
            return combat_actions.CombatActions.CombatResult.failed("Failed to create projectile");
        };
        
        // Consume resource after successful creation
        context.consumeResource();
        
        return combat_actions.CombatActions.CombatResult.ok(projectile_id);
    }
};

/// Combat helper functions for common operations
pub const CombatHelpers = struct {
    /// Create targeting config from graphics context
    pub fn targetingConfigFromGraphics(graphics: contexts.GraphicsContext, camera_pos: Vec2, camera_scale: f32) targeting.Targeting.ScreenToWorldConfig {
        return targeting.Targeting.ScreenToWorldConfig.init(
            graphics.screen_width,
            graphics.screen_height,
            camera_pos,
        ).withScale(camera_scale);
    }
    
    /// Check if position is on screen using graphics context
    pub fn isOnScreen(graphics: contexts.GraphicsContext, world_pos: Vec2, camera_pos: Vec2, camera_scale: f32) bool {
        const config = targetingConfigFromGraphics(graphics, camera_pos, camera_scale);
        return targeting.Targeting.isPositionOnScreen(world_pos, config);
    }
};