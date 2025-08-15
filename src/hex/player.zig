const std = @import("std");

const types = @import("../lib/core/types.zig");
const entities = @import("entities.zig");
const hex_world = @import("hex_world.zig");
const behaviors = @import("behaviors.zig");
const physics = @import("physics.zig");
const input = @import("../lib/platform/input.zig");
const maths = @import("../lib/core/maths.zig");
const camera = @import("../lib/rendering/camera.zig");
const viewport = @import("../lib/core/viewport.zig");
const constants = @import("constants.zig");

const Vec2 = types.Vec2;
const HexWorld = hex_world.HexWorld;
const InputState = input.InputState;

const WALK_SPEED_MULT = 0.25; // Walking speed is 1/4 of normal

/// ECS-compatible player update function
pub fn updatePlayerECS(world: *HexWorld, input_state: *const InputState, cam: *const camera.Camera, deltaTime: f32) void {
    if (!world.getPlayerAlive()) return;

    var keyboard_velocity = Vec2{ .x = 0, .y = 0 };
    var mouse_velocity = Vec2{ .x = 0, .y = 0 };

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
    const player_pos = world.getPlayerPos();
    const player_radius = world.getPlayerRadius();

    // Only allow mouse movement when Ctrl is held
    if (ctrl_held and input_state.isLeftMouseHeld()) {
        const screen_mouse_pos = input_state.getMousePos();
        const world_mouse_pos = cam.screenToWorldSafe(screen_mouse_pos);
        const dx = world_mouse_pos.x - player_pos.x;
        const dy = world_mouse_pos.y - player_pos.y;
        const distance_sq = dx * dx + dy * dy;
        const radius_sq = player_radius * player_radius;

        if (distance_sq > radius_sq) {
            const distance = @sqrt(distance_sq);
            const dir_x = dx / distance;
            const dir_y = dy / distance;
            mouse_velocity.x = dir_x * move_speed;
            mouse_velocity.y = dir_y * move_speed;
        }
    }

    var velocity: Vec2 = undefined;
    if (ctrl_held and input_state.isLeftMouseHeld() and (mouse_velocity.x != 0 or mouse_velocity.y != 0)) {
        velocity = mouse_velocity;
    } else {
        velocity = keyboard_velocity;
    }


    // Get current zone
    const zone = world.getCurrentZoneConst();
    
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
        const margin = player_radius + 10;
        if (new_pos.x < margin) new_pos.x = margin;
        if (new_pos.y < margin) new_pos.y = margin;
        if (new_pos.x > constants.SCREEN_WIDTH - margin) new_pos.x = constants.SCREEN_WIDTH - margin;
        if (new_pos.y > constants.SCREEN_HEIGHT - margin) new_pos.y = constants.SCREEN_HEIGHT - margin;
    }

    // TODO: Check collision with obstacles
    // For now, just update position
    world.setPlayerPos(new_pos);
    world.setPlayerVel(velocity);
}


/// ECS-compatible movement direction getter
pub fn getPlayerMovementDirectionECS(world: *const HexWorld) Vec2 {
    return maths.vec2_normalize(world.getPlayerVelConst());
}

