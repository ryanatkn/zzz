const std = @import("std");
const c = @import("../lib/platform/sdl.zig");

const math = @import("../lib/math/mod.zig");
const constants = @import("constants.zig");
const game_controller = @import("game.zig");
const game_renderer_mod = @import("game_renderer.zig");
const hud = @import("hud.zig");
const combat = @import("combat.zig");
const spells = @import("spells.zig");

const Vec2 = math.Vec2;
const GameState = game_controller.GameState;
const GameRenderer = game_renderer_mod.GameRenderer;
const Hud = hud.Hud;

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
            switch (event.key.scancode) {
                c.sdl.SDL_SCANCODE_ESCAPE => {
                    game_state.requestQuit();
                    return c.sdl.SDL_APP_SUCCESS;
                },
                c.sdl.SDL_SCANCODE_GRAVE => { // Backtick key - toggle HUD/system menu
                    if (game_state.hud_system) |*hud_sys| {
                        hud_sys.toggle();
                    } else {
                        // Fallback to game HUD toggle if system HUD not initialized
                        game_hud.toggle();
                    }
                },
                c.sdl.SDL_SCANCODE_SPACE => { // Space key - pause toggle
                    game_state.togglePause();
                },
                c.sdl.SDL_SCANCODE_T => { // T key - reset current zone units
                    game_state.resetZone();
                },
                c.sdl.SDL_SCANCODE_Y => { // Y key - full game reset
                    game_state.resetGame();
                },
                // Spell slot keybindings (1-4 number keys)
                c.sdl.SDL_SCANCODE_1, c.sdl.SDL_SCANCODE_2, c.sdl.SDL_SCANCODE_3, c.sdl.SDL_SCANCODE_4 => {
                    const slot = event.key.scancode - c.sdl.SDL_SCANCODE_1;
                    game_state.spell_system.setActiveSlot(slot);
                },
                c.sdl.SDL_SCANCODE_Q => game_state.spell_system.setActiveSlot(4),
                c.sdl.SDL_SCANCODE_E => game_state.spell_system.setActiveSlot(5),
                c.sdl.SDL_SCANCODE_R => { // R key - respawn or spell slot 6
                    if (!game_state.hex_game.getPlayerAlive()) {
                        game_controller.handleRespawn(game_state);
                    } else {
                        game_state.spell_system.setActiveSlot(6);
                    }
                },
                c.sdl.SDL_SCANCODE_F => game_state.spell_system.setActiveSlot(7),
                c.sdl.SDL_SCANCODE_G => { // G key - toggle AI control
                    game_state.toggleAIControl();
                },
                else => {},
            }
        },
        c.sdl.SDL_EVENT_KEY_UP => {
            game_state.input_state.handleKeyUp(event.key.scancode);
        },
        c.sdl.SDL_EVENT_MOUSE_MOTION => {
            game_state.input_state.handleMouseMotion(event.motion.x, event.motion.y);
        },
        c.sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => {
            game_state.input_state.handleMouseButtonDown(event.button.button);

            // Don't handle game actions if HUD is open
            if (game_state.hud_system) |*hud_sys| {
                if (hud_sys.is_open()) {
                    return c.sdl.SDL_APP_CONTINUE;
                }
            }

            switch (event.button.button) {
                c.sdl.SDL_BUTTON_LEFT => {
                    // Left-click shooting for single shots (burst mode)
                    game_state.hex_game.logger.info("left_click", "Left click detected at mouse position: {any}", .{game_state.input_state.getMousePos()});
                    if (game_state.hex_game.getPlayerAlive()) {
                        const screen_mouse_pos = game_state.input_state.getMousePos();
                        const world_mouse_pos = game_renderer.camera.screenToWorldSafe(screen_mouse_pos);
                        const result = combat.fireBulletAtMouse(&game_state.hex_game, world_mouse_pos, &game_state.hex_game.bullet_pool);
                        game_state.hex_game.logger.info("bullet_result", "fireBulletAtMouse result: {}", .{result});
                    } else {
                        game_state.hex_game.logger.info("fire_blocked", "Cannot fire: player not alive", .{});
                    }
                },
                c.sdl.SDL_BUTTON_RIGHT => {
                    // Right-click casts spell (self-cast if Ctrl held)
                    if (game_state.hex_game.getPlayerAlive()) {
                        const ctrl_held = game_state.input_state.isCtrlHeld();
                        const screen_mouse_pos = game_state.input_state.getMousePos();
                        const world_mouse_pos = game_renderer.camera.screenToWorldSafe(screen_mouse_pos);
                        const zone = game_state.hex_game.getCurrentZoneConst();

                        _ = game_state.spell_system.castActiveSpell(&game_state.hex_game, zone, world_mouse_pos, &game_state.effect_system, ctrl_held);
                    }
                },
                else => {},
            }
        },
        c.sdl.SDL_EVENT_MOUSE_BUTTON_UP => {
            game_state.input_state.handleMouseButtonUp(event.button.button);
        },
        c.sdl.SDL_EVENT_MOUSE_WHEEL => {
            // Mouse wheel zoom
            const current_zone = game_state.hex_game.getCurrentZone();
            
            if (event.wheel.y > 0) {
                // Zoom in (scroll up)
                current_zone.camera_scale = @min(constants.MAX_ZOOM, current_zone.camera_scale * constants.ZOOM_FACTOR);
            } else if (event.wheel.y < 0) {
                // Zoom out (scroll down)
                current_zone.camera_scale = @max(constants.MIN_ZOOM, current_zone.camera_scale / constants.ZOOM_FACTOR);
            }
        },
        else => {},
    }

    return c.sdl.SDL_APP_CONTINUE;
}
