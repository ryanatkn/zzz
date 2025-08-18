const std = @import("std");
const c = @import("../lib/platform/sdl.zig");

const math = @import("../lib/math/mod.zig");
const constants = @import("constants.zig");
const game_controller = @import("game.zig");
const coordinates = @import("../lib/core/coordinates.zig");
const camera = @import("../lib/rendering/camera.zig");
const game_renderer_mod = @import("game_renderer.zig");
const hud = @import("hud.zig");
const combat = @import("combat.zig");

// Import new input system modules
const game_input = @import("../lib/game/input/mod.zig");
const input_actions = game_input.actions;
const input_modifiers = game_input.modifiers;
const dead_player_handler = game_input.dead_player_handler;

const Vec2 = math.Vec2;
const GameState = game_controller.GameState;
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

/// Create coordinate context from camera state
fn createCoordinateContext(cam: *const camera.Camera) coordinates.CoordinateContext {
    return coordinates.CoordinateContext.init(cam.screen_width, cam.screen_height)
        .withCamera(math.Vec2{ .x = cam.view_x + cam.view_width / 2.0, .y = cam.view_y + cam.view_height / 2.0 }, cam.scale);
}

pub fn handleSDLEvent(
    game_state: *GameState,
    game_renderer: *GameRenderer,
    game_hud: *Hud,
    event: *c.sdl.SDL_Event,
) !c.sdl.SDL_AppResult {
    // Let HUD handle events first if it's open
    if (game_state.hud_system) |*hud_sys| {
        const handled = try hud_sys.handleEvent(event.*);
        if (handled) return c.sdl.SDL_APP_CONTINUE;
    }

    // Legacy HUD doesn't block events - it's just a display overlay

    switch (event.type) {
        c.sdl.SDL_EVENT_QUIT => {
            game_state.requestQuit();
            return c.sdl.SDL_APP_SUCCESS;
        },
        c.sdl.SDL_EVENT_KEY_DOWN => {
            game_state.input_state.handleKeyDown(event.key.scancode);

            // Extract action from keypress
            const action = extractGameAction(event);

            // Create action context
            const action_context = input_actions.ActionContext.init()
                .withPlayerState(game_state.hex_game.getPlayerAlive())
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
                    game_controller.handleRespawn(game_state);
                },
                .ToggleAI => {
                    game_state.toggleAIControl();
                },
                // Spell selection actions
                .SelectSpell1, .SelectSpell2, .SelectSpell3, .SelectSpell4, .SelectSpell5, .SelectSpell6, .SelectSpell7, .SelectSpell8 => {
                    if (input_actions.getSpellSlotFromAction(action)) |slot| {
                        game_state.spell_system.setActiveSlot(slot);
                    }
                },
                else => {},
            }
        },
        c.sdl.SDL_EVENT_KEY_UP => {
            game_state.input_state.handleKeyUp(event.key.scancode);
        },
        c.sdl.SDL_EVENT_MOUSE_MOTION => {
            game_state.input_state.handleMouseMotion(event.motion.x, event.motion.y);

            // Update spellbar hover state
            const mouse_pos = game_state.input_state.getMousePos();
            game_state.spellbar_ui.updateHover(mouse_pos);
        },
        c.sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => {
            game_state.input_state.handleMouseButtonDown(event.button.button);

            // Don't handle game actions if HUD is open
            if (game_state.hud_system) |*hud_sys| {
                if (hud_sys.is_open()) {
                    return c.sdl.SDL_APP_CONTINUE;
                }
            }

            // Extract action from mouse button
            const action = extractGameAction(event);

            // Handle dead player actions
            if (!game_state.hex_game.getPlayerAlive()) {
                const dead_result = dead_player_handler.DeadPlayerHandler.handleDeadPlayerAction(action);
                switch (dead_result) {
                    .Respawn => {
                        game_state.hex_game.logger.info("respawn_click", "Dead player action respawn triggered", .{});
                        game_controller.handleRespawn(game_state);
                        return c.sdl.SDL_APP_CONTINUE;
                    },
                    .Block => return c.sdl.SDL_APP_CONTINUE,
                    .Allow => {}, // Continue with normal processing for system actions
                }
            }

            // Process action for living player
            switch (action) {
                .PrimaryAttack => {
                    if (game_state.hex_game.getPlayerAlive()) {
                        const screen_mouse_pos = game_state.input_state.getMousePos();

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

                        // Left-click shooting for single shots (burst mode)
                        game_state.hex_game.logger.info("primary_attack", "Primary attack at mouse position: {any}", .{screen_mouse_pos});

                        const coord_context = createCoordinateContext(&game_renderer.camera);
                        const world_mouse_pos = coordinates.screenToWorld(screen_mouse_pos, coord_context);
                        const result = combat.fireBulletAtMouse(&game_state.hex_game, world_mouse_pos, &game_state.hex_game.bullet_pool);
                        game_state.hex_game.logger.info("bullet_result", "fireBulletAtMouse result: {}", .{result});
                    }
                },
                .SecondaryAttack => {
                    if (game_state.hex_game.getPlayerAlive()) {
                        const screen_mouse_pos = game_state.input_state.getMousePos();

                        // Check if right-click is on spellbar first
                        if (game_state.spellbar_ui.getSlotAtPosition(screen_mouse_pos)) |slot_index| {
                            // Right-click on spellbar slot = select and cast immediately
                            game_state.spell_system.setActiveSlot(slot_index);

                            // Cast the spell at mouse position (self-cast since clicked on slot)
                            const zone = game_state.hex_game.getCurrentZoneConst();
                            const player_pos = game_state.hex_game.getPlayerPos();
                            _ = game_state.spell_system.castActiveSpell(&game_state.hex_game, zone, player_pos, &game_state.particle_system, true);
                            return c.sdl.SDL_APP_CONTINUE;
                        }

                        // Check if this should be self-cast
                        const self_cast = input_modifiers.ModifierHelpers.isSelfCasting(&game_state.input_state);

                        const coord_context = createCoordinateContext(&game_renderer.camera);
                        const world_mouse_pos = coordinates.screenToWorld(screen_mouse_pos, coord_context);
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
            const action = extractGameAction(event);
            const current_zone = game_state.hex_game.getCurrentZone();

            switch (action) {
                .ZoomIn => {
                    current_zone.camera_scale = @min(constants.MAX_ZOOM, current_zone.camera_scale * constants.ZOOM_FACTOR);
                },
                .ZoomOut => {
                    current_zone.camera_scale = @max(constants.MIN_ZOOM, current_zone.camera_scale / constants.ZOOM_FACTOR);
                },
                else => {},
            }
        },
        else => {},
    }

    return c.sdl.SDL_APP_CONTINUE;
}
