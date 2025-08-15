const std = @import("std");

const c = @import("../lib/platform/sdl.zig");

const math = @import("../lib/math/mod.zig");
const constants = @import("constants.zig");
const game_controller = @import("game.zig");
const game_renderer_mod = @import("game_renderer.zig");
const hud = @import("hud.zig");
const combat = @import("combat.zig");
const spells = @import("spells.zig");
const viewport = @import("../lib/core/viewport.zig");

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
                    if (!game_state.world.getPlayerAlive()) {
                        game_controller.handleRespawn(game_state);
                    } else {
                        game_state.spell_system.setActiveSlot(6);
                    }
                },
                c.sdl.SDL_SCANCODE_F => game_state.spell_system.setActiveSlot(7),
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
                    std.debug.print("Mouse click blocked - HUD is open\n", .{});
                    return c.sdl.SDL_APP_CONTINUE;
                }
                std.debug.print("HUD system exists but is closed - allowing game input\n", .{});
            } else {
                std.debug.print("No HUD system - allowing game input\n", .{});
            }
            
            switch (event.button.button) {
                c.sdl.SDL_BUTTON_LEFT => {
                    if (!game_state.world.getPlayerAlive()) {
                        game_controller.handleRespawn(game_state);
                    } else {
                        // Left-click shooting is handled in continuous shooting (mouse hold)
                        // Single-click shooting is disabled to prevent double-shooting
                    }
                },
                c.sdl.SDL_BUTTON_RIGHT => {
                    // Right-click casts spell (self-cast if Ctrl held)
                    if (game_state.world.getPlayerAlive()) {
                        const ctrl_held = game_state.input_state.isCtrlHeld();
                        const screen_mouse_pos = game_state.input_state.getMousePos();
                        const world_mouse_pos = game_renderer.camera.screenToWorldSafe(screen_mouse_pos);
                        const zone = game_state.world.getCurrentZoneConst();
                        
                        _ = game_state.spell_system.castActiveSpell(
                            &game_state.world,
                            zone,
                            world_mouse_pos,
                            &game_state.effect_system,
                            ctrl_held
                        );
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
            const current_zone = game_state.world.getCurrentZoneMut();
            const zoom_factor = 1.1; // 10% zoom per wheel tick

            if (event.wheel.y > 0) {
                // Zoom in (scroll up)
                current_zone.camera_scale = @min(10.0, current_zone.camera_scale * zoom_factor);
            } else if (event.wheel.y < 0) {
                // Zoom out (scroll down)
                current_zone.camera_scale = @max(0.1, current_zone.camera_scale / zoom_factor);
            }
        },
        else => {},
    }

    return c.sdl.SDL_APP_CONTINUE;
}
