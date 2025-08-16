const std = @import("std");
const hex_world = @import("hex_game.zig");
const hex_game_mod = @import("hex_game.zig");
const behaviors = @import("behaviors.zig");
const physics = @import("physics.zig");
const input = @import("../lib/platform/input.zig");
const math = @import("../lib/math/mod.zig");
const camera = @import("../lib/rendering/camera.zig");
const constants = @import("constants.zig");

const Vec2 = math.Vec2;
const HexWorld = hex_world.HexWorld;
const HexGame = hex_game_mod.HexGame;
const InputState = input.InputState;

const WALK_SPEED_MULT = constants.WALK_SPEED_MULTIPLIER; // Walking speed is 1/4 of normal

/// Player update function
pub fn updatePlayer(game: *HexGame, input_state: *const InputState, cam: *const camera.Camera, deltaTime: f32) void {
    if (!game.getPlayerAlive()) return;

    var keyboard_velocity = Vec2.ZERO;
    var mouse_velocity = Vec2.ZERO;

    // Check modifiers
    const is_walking = input_state.isShiftHeld();
    const ctrl_held = input_state.isCtrlHeld();

    // Speed modifier for walking
    const speed_mult: f32 = if (is_walking) WALK_SPEED_MULT else 1.0;
    const move_speed = constants.PLAYER_SPEED * speed_mult;

    const movement = input_state.getMovementVector();
    keyboard_velocity.x = movement.x * move_speed;
    keyboard_velocity.y = movement.y * move_speed;

    // Get current player position
    const player_pos = game.getPlayerPos();
    const player_radius = game.getPlayerRadius();

    // Only allow mouse movement when Ctrl is held
    if (ctrl_held and input_state.isLeftMouseHeld()) {
        const screen_mouse_pos = input_state.getMousePos();
        const world_mouse_pos = cam.screenToWorldSafe(screen_mouse_pos);
        const to_mouse = world_mouse_pos.sub(player_pos);
        const distance_sq = to_mouse.lengthSquared();
        const radius_sq = player_radius * player_radius;

        if (distance_sq > radius_sq) {
            const direction = to_mouse.normalize();
            mouse_velocity = direction.scale(move_speed);
        }
    }

    var velocity: Vec2 = undefined;
    if (ctrl_held and input_state.isLeftMouseHeld() and (mouse_velocity.x != 0 or mouse_velocity.y != 0)) {
        velocity = mouse_velocity;
    } else {
        velocity = keyboard_velocity;
    }

    // Get current zone
    const zone = game.getCurrentZoneConst();

    // Use screen bounds only in fixed camera mode (overworld)
    const use_screen_bounds = (zone.camera_mode == .fixed);

    // Calculate new position
    var new_pos = Vec2{
        .x = player_pos.x + velocity.x * deltaTime,
        .y = player_pos.y + velocity.y * deltaTime,
    };

    // Apply screen bounds if needed
    if (use_screen_bounds) {
        // Keep player within screen bounds for fixed camera mode
        const margin = player_radius + constants.PLAYER_BOUNDARY_MARGIN;
        if (new_pos.x < margin) new_pos.x = margin;
        if (new_pos.y < margin) new_pos.y = margin;
        if (new_pos.x > constants.SCREEN_WIDTH - margin) new_pos.x = constants.SCREEN_WIDTH - margin;
        if (new_pos.y > constants.SCREEN_HEIGHT - margin) new_pos.y = constants.SCREEN_HEIGHT - margin;
    }

    // Check collision with obstacles before moving
    if (physics.canPlayerMoveTo(game, new_pos, player_radius)) {
        // No collision, safe to move
        game.setPlayerPos(new_pos);
    } else {
        // Collision detected, don't move (or try sliding along walls)
        // For now, just stop movement completely
    }
    game.setPlayerVel(velocity);
}

/// Movement direction getter
pub fn getPlayerMovementDirection(game: *const HexGame) Vec2 {
    return game.getPlayerVelConst().normalize();
}
