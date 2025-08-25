const std = @import("std");
const c = @import("../lib/platform/sdl.zig");

const math = @import("../lib/math/mod.zig");
const constants = @import("constants.zig");
const game_loop_mod = @import("game_loop.zig");
const camera = @import("../lib/game/camera/camera.zig");
const game_renderer_mod = @import("game_renderer.zig");
const hud = @import("hud.zig");
const combat = @import("combat.zig");

// Import new input system modules
const game_input = @import("../lib/game/input/mod.zig");
const input_actions = game_input.actions;
const input_modifiers = game_input.modifiers;

const Vec2 = math.Vec2;
const GameState = game_loop_mod.GameState;
const GameRenderer = game_renderer_mod.GameRenderer;
const Hud = hud.Hud;
const GameAction = input_actions.GameAction;

/// Extract game action from SDL event
fn extractGameAction(event: *const c.sdl.SDL_Event) GameAction {
    return switch (event.type) {
        c.sdl.SDL_EVENT_KEY_DOWN => input_actions.mapScancodeToAction(event.key.scancode),
        c.sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => input_actions.mapMouseButtonToAction(event.button.button),
        c.sdl.SDL_EVENT_MOUSE_WHEEL => input_actions.mapMouseWheelToAction(event.wheel.y),
        else => .None,
    };
}

pub fn handleSDLEvent(
    game_state: *GameState,
    game_renderer: *GameRenderer,
    game_hud: *Hud,
    event: *c.sdl.SDL_Event,
) !c.sdl.SDL_AppResult {
    // Mouse wheel scroll detection via motion events
    // Some systems deliver wheel data through mouse motion events instead of wheel events
    // Let HUD handle events first if it's open
    if (game_state.hud_system) |*hud_sys| {
        const handled = try hud_sys.handleEvent(event.*);
        if (handled) return c.sdl.SDL_APP_CONTINUE;
    }

    switch (event.type) {
        c.sdl.SDL_EVENT_QUIT => {
            game_state.requestQuit();
            return c.sdl.SDL_APP_SUCCESS;
        },
        c.sdl.SDL_EVENT_KEY_DOWN => {
            game_state.input_state.handleKeyDown(event.key.scancode);

            // Extract action from keypress
            const action = extractGameAction(event);

            // Create action context - check if controlled entity is alive
            const controlled_entity_alive = if (game_state.hex_game.getControlledEntity()) |controlled_entity| blk: {
                const zone = game_state.hex_game.getCurrentZoneConst();
                if (zone.units.getComponent(controlled_entity, .health)) |health| {
                    break :blk health.alive;
                }
                break :blk false;
            } else false;

            const action_context = input_actions.ActionContext.init()
                .withPlayerState(controlled_entity_alive)
                .withMenuState(if (game_state.hud_system) |*hud_sys| hud_sys.is_open() else false)
                .withPauseState(game_state.game_paused);

            // Check if action should be processed
            const priority = input_actions.getActionPriority(action);
            if (!action_context.shouldAllowAction(action, priority)) {
                return c.sdl.SDL_APP_CONTINUE;
            }

            // Process the action
            switch (action) {
                .Quit => {
                    game_state.requestQuit();
                    return c.sdl.SDL_APP_SUCCESS;
                },
                .ToggleMenu => {
                    if (game_state.hud_system) |*hud_sys| {
                        hud_sys.toggle();
                    } else {
                        // Fallback to game HUD toggle if system HUD not initialized
                        game_hud.toggle();
                    }
                },
                .TogglePause => {
                    game_state.togglePause();
                },
                .ResetZone => {
                    game_state.resetZone();
                },
                .ResetGame => {
                    game_state.resetGame();
                },
                .Respawn => {
                    game_loop_mod.handleRespawn(game_state);
                },
                .ToggleAI => {
                    game_state.toggleAIControl();
                },
                .CyclePossession => {
                    game_state.cyclePossessionTarget();
                },
                .ReleaseControl => {
                    game_state.releaseControl();
                },
                // Spell selection actions
                .SelectSpell1, .SelectSpell2, .SelectSpell3, .SelectSpell4, .SelectSpell5, .SelectSpell6, .SelectSpell7, .SelectSpell8 => {
                    if (input_actions.getSpellSlotFromAction(action)) |slot| {
                        game_state.spell_system.setActiveSlot(slot);
                    }
                },
                // Camera zoom actions
                .ZoomIn => {
                    game_renderer.camera.zoomIn();
                },
                .ZoomOut => {
                    game_renderer.camera.zoomOut();
                },
                else => {},
            }
        },
        c.sdl.SDL_EVENT_KEY_UP => {
            game_state.input_state.handleKeyUp(event.key.scancode);
        },
        c.sdl.SDL_EVENT_MOUSE_MOTION => {
            game_state.input_state.handleMouseMotion(event.motion.x, event.motion.y);

            // Note: Mouse wheel events not working on this system - using keyboard zoom (- and = keys)

            // Update spellbar hover state
            const mouse_pos = game_state.input_state.mouse_pos;
            game_state.spellbar_ui.updateHover(mouse_pos);
        },
        c.sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => {
            std.log.info("MOUSE_BUTTON_DOWN: button={} (1=left, 2=middle, 3=right, 4/5=wheel?)", .{event.button.button});
            game_state.input_state.handleMouseButtonDown(event.button.button);

            // Don't handle game actions if HUD is open
            if (game_state.hud_system) |*hud_sys| {
                if (hud_sys.is_open()) {
                    return c.sdl.SDL_APP_CONTINUE;
                }
            }

            // Extract action from mouse button
            const action = extractGameAction(event);

            // Handle dead controlled entity actions - simplified inline logic
            const controlled_entity_alive = if (game_state.hex_game.getControlledEntity()) |controlled_entity| blk: {
                const zone = game_state.hex_game.getCurrentZoneConst();
                if (zone.units.getComponent(controlled_entity, .health)) |health| {
                    break :blk health.alive;
                }
                break :blk false;
            } else false;

            if (!controlled_entity_alive) {
                switch (action) {
                    // Respawn actions
                    .PrimaryAttack, .Respawn => {
                        game_state.hex_game.logger.info("respawn_click", "Dead player action respawn triggered", .{});
                        game_loop_mod.handleRespawn(game_state);
                        return c.sdl.SDL_APP_CONTINUE;
                    },
                    // System actions always allowed
                    .ToggleMenu, .TogglePause, .Quit => {}, // Continue with normal processing
                    // Block all other actions when dead
                    else => return c.sdl.SDL_APP_CONTINUE,
                }
            }

            // Process action for living player
            switch (action) {
                .PrimaryAttack => {
                    // Check if controlled entity is alive for primary attack
                    const attack_entity_alive = if (game_state.hex_game.getControlledEntity()) |controlled_entity| blk: {
                        const zone = game_state.hex_game.getCurrentZoneConst();
                        if (zone.units.getComponent(controlled_entity, .health)) |health| {
                            break :blk health.alive;
                        }
                        break :blk false;
                    } else false;

                    if (attack_entity_alive) {
                        const screen_mouse_pos = game_state.input_state.mouse_pos;

                        // Check if click is on spellbar first
                        if (game_state.spellbar_ui.getSlotAtPosition(screen_mouse_pos)) |slot_index| {
                            // Left-click on spellbar slot = select spell
                            game_state.spell_system.setActiveSlot(slot_index);
                            return c.sdl.SDL_APP_CONTINUE;
                        }

                        // Check if this should be move-to-click instead of shooting
                        if (input_modifiers.ModifierHelpers.isMoveToClick(&game_state.input_state)) {
                            // Move-to-click not implemented yet - just ignore Ctrl+click for now
                            return c.sdl.SDL_APP_CONTINUE;
                        }

                        // Single-click shooting - immediate firing (skill-based, bypasses 150ms cooldown)
                        const result = combat.fireProjectileAtScreenPos(&game_state.hex_game, screen_mouse_pos, &game_renderer.camera, &game_state.hex_game.projectile_pool, true);
                        if (result) {
                            game_state.hex_game.logger.info("single_click_shot", "Single-click shot fired (skill-based)", .{});
                        }
                    }
                },
                .SecondaryAttack => {
                    // Check if controlled entity is alive for secondary attack
                    const secondary_entity_alive = if (game_state.hex_game.getControlledEntity()) |controlled_entity| blk: {
                        const zone = game_state.hex_game.getCurrentZoneConst();
                        if (zone.units.getComponent(controlled_entity, .health)) |health| {
                            break :blk health.alive;
                        }
                        break :blk false;
                    } else false;

                    if (secondary_entity_alive) {
                        const screen_mouse_pos = game_state.input_state.mouse_pos;

                        // Check if right-click is on spellbar first
                        if (game_state.spellbar_ui.getSlotAtPosition(screen_mouse_pos)) |slot_index| {
                            // Right-click on spellbar slot = select and cast immediately
                            game_state.spell_system.setActiveSlot(slot_index);

                            // Cast the spell at controlled entity position (self-cast since clicked on slot)
                            const zone = game_state.hex_game.getCurrentZoneConst();
                            // Spell system will handle getting controlled entity position internally
                            _ = game_state.spell_system.castActiveSpell(&game_state.hex_game, zone, Vec2.ZERO, &game_state.particle_system, true);
                            return c.sdl.SDL_APP_CONTINUE;
                        }

                        // Check if this should be self-cast
                        const self_cast = input_modifiers.ModifierHelpers.isSelfCasting(&game_state.input_state);

                        const world_mouse_pos = game_renderer.camera.screenToWorldSafe(screen_mouse_pos);
                        const zone = game_state.hex_game.getCurrentZoneConst();

                        _ = game_state.spell_system.castActiveSpell(&game_state.hex_game, zone, world_mouse_pos, &game_state.particle_system, self_cast);
                    }
                },
                else => {},
            }
        },
        c.sdl.SDL_EVENT_MOUSE_BUTTON_UP => {
            game_state.input_state.handleMouseButtonUp(event.button.button);
        },
        c.sdl.SDL_EVENT_MOUSE_WHEEL => {
            // TODO I'm not receiving this event on Linux
            // Maybe related: https://github.com/libsdl-org/SDL/pull/13453
            std.log.info("mouse_wheel event detected! y={d:.2} x={d:.2}", .{ event.wheel.y, event.wheel.x });

            // Direct zoom based on wheel direction
            if (event.wheel.y > 0) {
                std.log.info("zoom_in_triggered calling camera.zoomIn()", .{});
                game_renderer.camera.zoomIn();
            } else if (event.wheel.y < 0) {
                std.log.info("zoom_out_triggered calling camera.zoomOut()", .{});
                game_renderer.camera.zoomOut();
            }
        },
        else => {},
    }

    return c.sdl.SDL_APP_CONTINUE;
}
