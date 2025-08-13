const std = @import("std");

const types = @import("../lib/types.zig");
const entities = @import("entities.zig");
const behaviors = @import("behaviors.zig");
const physics = @import("physics.zig");
const input = @import("../lib/input.zig");
const maths = @import("../lib/maths.zig");
const camera = @import("../lib/camera.zig");
const constants = @import("constants.zig");

const Vec2 = types.Vec2;
const Player = entities.Player;
const Zone = entities.Zone;
const InputState = input.InputState;

const WALK_SPEED_MULT = 0.25; // Walking speed is 1/4 of normal

pub fn updatePlayer(player: *Player, input_state: *const InputState, zone: *const Zone, cam: *const camera.Camera, deltaTime: f32) void {
    if (!player.alive) return;

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

    // Only allow mouse movement when Ctrl is held
    if (ctrl_held and input_state.isLeftMouseHeld()) {
        const world_mouse_pos = input_state.getWorldMousePos(cam);
        const dx = world_mouse_pos.x - player.pos.x;
        const dy = world_mouse_pos.y - player.pos.y;
        const distance_sq = dx * dx + dy * dy;
        const radius_sq = player.radius * player.radius;

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

    const old_pos = player.pos;

    // Use screen bounds only in fixed camera mode (overworld)
    const use_screen_bounds = (zone.camera_mode == entities.CameraMode.fixed);
    behaviors.updatePlayer(player, velocity, deltaTime, use_screen_bounds);

    if (physics.wouldCollideWithObstacle(player.pos, player.radius, zone)) {
        player.pos = old_pos;
    }
}

pub fn getPlayerMovementDirection(player: *const Player) Vec2 {
    return maths.vec2_normalize(player.vel);
}
