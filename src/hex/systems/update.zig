const std = @import("std");

// Core capabilities
const math = @import("../../lib/math/mod.zig");
const frame = @import("../../lib/core/frame.zig");

// Game system capabilities
const camera = @import("../../lib/game/camera/camera.zig");

// Hex game modules
const behaviors = @import("../behaviors/mod.zig");
const physics = @import("../physics.zig");
const color_mappings = @import("../color_mappings.zig");
const portals = @import("../portals.zig");
const controlled_entity_mod = @import("../controlled_entity.zig");
const combat = @import("../combat.zig");
const CollisionSystem = @import("collision.zig").CollisionSystem;

// HUD control
const ai_control = @import("../../lib/game/control/mod.zig");

const Vec2 = math.Vec2;
const FrameContext = frame.FrameContext;

/// Update system that consolidates update logic from game.zig
pub const UpdateSystem = struct {
    /// Context-aware update all units function - extracted from game.zig
    pub fn updateUnits(game_state: anytype, frame_ctx: FrameContext) void {
        const world = &game_state.hex_game;

        // Query all units from ECS system
        const zone_storage = world.getZoneStorage();
        var unit_iter = zone_storage.units.entityIterator();
        while (unit_iter.next()) |unit_id| {
            // Skip if entity is not alive
            if (!zone_storage.isAlive(unit_id)) continue;

            // Get components
            if (zone_storage.units.getComponentMut(unit_id, .transform)) |transform| {
                if (zone_storage.units.getComponentMut(unit_id, .health)) |health| {
                    if (!health.alive) continue;

                    if (zone_storage.units.getComponentMut(unit_id, .unit)) |unit_comp| {
                        const old_pos = transform.pos;

                        // Check if this unit is controlled - if so, skip AI behavior
                        const is_controlled = world.getControlledEntity() == unit_id;

                        if (zone_storage.units.getComponentMut(unit_id, .visual)) |visual| {
                            if (!is_controlled) {
                                // Only apply AI behavior to uncontrolled units
                                const aggro_mod: f32 = 1.0;

                                // Get controlled entity position and state for AI behavior
                                const controlled_entity_pos = if (world.getControlledEntity()) |controlled_entity| blk: {
                                    if (zone_storage.units.getComponent(controlled_entity, .transform)) |controlled_transform| {
                                        break :blk controlled_transform.pos;
                                    }
                                    break :blk null;
                                } else null;

                                const controlled_entity_alive = if (world.getControlledEntity()) |controlled_entity| blk: {
                                    if (zone_storage.units.getComponent(controlled_entity, .health)) |controlled_health| {
                                        break :blk controlled_health.alive;
                                    }
                                    break :blk false;
                                } else false;

                                behaviors.updateUnitWithAggroMod(unit_comp, transform, visual, controlled_entity_pos, controlled_entity_alive, aggro_mod, frame_ctx);
                            }

                            // Apply disposition-based color with energy level for brightness
                            visual.color = color_mappings.getDispositionEnergyColor(unit_comp.disposition, unit_comp.energy_level);
                        }

                        // Check collision with terrain
                        if (physics.checkUnitTerrainCollision(world, unit_id, transform, health, old_pos)) {
                            // Collision was handled by the function
                            break;
                        }
                    }
                }
            }
        }
    }

    /// Main game update function - extracted from game.zig updateGame()
    pub fn updateGame(game_state: anytype, cam: *const camera.Camera, deltaTime: f32) void {
        // Reset frame pool for this frame's temporary allocations
        game_state.hex_game.frame_pool.reset();

        // Create minimal frame context
        const frame_allocator = game_state.hex_game.frame_pool.allocator();
        const frame_ctx = FrameContext.init(frame_allocator, deltaTime, game_state.frame_counter, game_state.game_paused);

        const world = &game_state.hex_game;
        const input_state = &game_state.input_state;

        // Increment frame counter
        game_state.frame_counter += 1;

        // Process AI commands if enabled
        if (game_state.ai_enabled and game_state.ai_input != null) {
            if (game_state.ai_input) |mapped| {
                const pending = mapped.buffer.pending();
                if (pending > 0) {
                    game_state.logger.info("ai_process", "Processing {} AI commands at frame {}", .{ pending, game_state.frame_counter });
                }
                ai_control.processCommands(mapped.buffer, &game_state.input_state, game_state.frame_counter);
            }
        }

        // Update HUD system if open
        if (game_state.hud_system) |*h| {
            h.update(deltaTime);
            // Don't update game when HUD is open
            if (h.is_open()) return;
        }

        if (game_state.game_paused) return;

        // Update portal cooldown
        portals.updatePortalCooldown(world, frame_ctx);

        // Update controlled entity (controller system)
        if (world.getControlledEntity()) |controlled_entity| {
            controlled_entity_mod.updateControlledEntity(world, controlled_entity, frame_ctx, input_state, cam);
        }
        // Note: Controller always possesses an entity at startup, so no fallback needed

        // Handle continuous shooting on left-click hold (rhythm mode)
        // Only shoot if Ctrl is NOT held (Ctrl enables mouse movement instead)
        const can_shoot = world.hasLiveControlledEntity() and world.canFireProjectile();
        if (!input_state.isCtrlHeld() and input_state.isLeftMouseHeld() and can_shoot) {
            // Use unified bullet firing with proper coordinate conversion
            const screen_mouse_pos = input_state.getMousePos();
            _ = combat.fireProjectileAtScreenPos(world, screen_mouse_pos, cam, &world.projectile_pool);
        }

        // Update projectile entities using ECS
        world.updateProjectiles(frame_ctx);

        // Update units with context
        updateUnits(game_state, frame_ctx);

        // Check all collision systems
        CollisionSystem.checkAllCollisions(game_state);

        // Update visual effects
        game_state.particle_system.update();

        // Update spell system with context
        game_state.spell_system.update(frame_ctx);

        // Update bullet pool with context
        world.updateProjectilePool(frame_ctx);
    }

    /// Handle fire bullet action - extracted from game.zig
    pub fn handleFireBullet(game_state: anytype, cam: *const camera.Camera) void {
        if (game_state.hex_game.getPlayerAlive() and !game_state.game_paused and game_state.hex_game.canFireBullet()) {
            const screen_mouse_pos = game_state.input_state.getMousePos();
            const world_mouse_pos = cam.screenToWorldSafe(screen_mouse_pos);
            _ = combat.fireBulletAtMouse(&game_state.hex_game, world_mouse_pos, &game_state.hex_game.bullet_pool);
        }
    }
};
