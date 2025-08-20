const std = @import("std");
const math = @import("../../math/mod.zig");
const input = @import("../../platform/input.zig");
const actions = @import("actions.zig");
const c = @import("../../platform/sdl.zig");

const Vec2 = math.Vec2;
const InputState = input.InputState;
const GameAction = actions.GameAction;

/// Movement direction patterns
pub const MovementDirection = enum {
    None,
    North,
    NorthEast,
    East,
    SouthEast,
    South,
    SouthWest,
    West,
    NorthWest,

    /// Get normalized direction vector
    pub fn toVector(self: MovementDirection) Vec2 {
        return switch (self) {
            .None => Vec2.ZERO,
            .North => Vec2{ .x = 0, .y = -1 },
            .NorthEast => Vec2{ .x = 0.707, .y = -0.707 },
            .East => Vec2{ .x = 1, .y = 0 },
            .SouthEast => Vec2{ .x = 0.707, .y = 0.707 },
            .South => Vec2{ .x = 0, .y = 1 },
            .SouthWest => Vec2{ .x = -0.707, .y = 0.707 },
            .West => Vec2{ .x = -1, .y = 0 },
            .NorthWest => Vec2{ .x = -0.707, .y = -0.707 },
        };
    }

    /// Get direction from movement actions
    pub fn fromActions(up: bool, down: bool, left: bool, right: bool) MovementDirection {
        if (up and right) return .NorthEast;
        if (up and left) return .NorthWest;
        if (down and right) return .SouthEast;
        if (down and left) return .SouthWest;
        if (up) return .North;
        if (down) return .South;
        if (left) return .West;
        if (right) return .East;
        return .None;
    }
};

/// Movement style modifiers
pub const MovementStyle = struct {
    walk: bool = false, // Slower movement (Shift)
    precise: bool = false, // Precise movement (Ctrl)
    strafe: bool = false, // Strafe movement (Alt)

    /// Apply style modifiers to speed
    pub fn applyToSpeed(self: MovementStyle, base_speed: f32) f32 {
        var speed = base_speed;
        if (self.walk) speed *= 0.3; // Walk is 30% speed
        if (self.precise) speed *= 0.5; // Precise is 50% speed
        return speed;
    }
};

/// Movement input processor
pub const MovementProcessor = struct {
    /// Extract movement vector from input state using WASD keys
    pub fn getMovementVector(input_state: *const InputState) Vec2 {
        const up = input_state.isKeyDown(c.sdl.SDL_SCANCODE_W);
        const down = input_state.isKeyDown(c.sdl.SDL_SCANCODE_S);
        const left = input_state.isKeyDown(c.sdl.SDL_SCANCODE_A);
        const right = input_state.isKeyDown(c.sdl.SDL_SCANCODE_D);

        const direction = MovementDirection.fromActions(up, down, left, right);
        return direction.toVector();
    }

    /// Extract movement vector from actions (for AI or custom mapping)
    pub fn getMovementVectorFromActions(move_up: bool, move_down: bool, move_left: bool, move_right: bool) Vec2 {
        const direction = MovementDirection.fromActions(move_up, move_down, move_left, move_right);
        return direction.toVector();
    }

    /// Get movement style from input modifiers
    pub fn getMovementStyle(input_state: *const InputState) MovementStyle {
        return MovementStyle{
            .walk = input_state.isShiftHeld(),
            .precise = input_state.isCtrlHeld(),
            // Alt not implemented in base InputState yet
            .strafe = false,
        };
    }

    /// Get final movement vector with style applied
    pub fn getFinalMovementVector(input_state: *const InputState, base_speed: f32) Vec2 {
        const movement = getMovementVector(input_state);
        const style = getMovementStyle(input_state);
        const final_speed = style.applyToSpeed(base_speed);

        return Vec2{
            .x = movement.x * final_speed,
            .y = movement.y * final_speed,
        };
    }
};

/// 4-way movement (no diagonals)
pub const FourWayMovement = struct {
    pub fn getMovementVector(input_state: *const InputState) Vec2 {
        const up = input_state.isKeyDown(c.sdl.SDL_SCANCODE_W);
        const down = input_state.isKeyDown(c.sdl.SDL_SCANCODE_S);
        const left = input_state.isKeyDown(c.sdl.SDL_SCANCODE_A);
        const right = input_state.isKeyDown(c.sdl.SDL_SCANCODE_D);

        // Priority: vertical over horizontal
        if (up) return Vec2{ .x = 0, .y = -1 };
        if (down) return Vec2{ .x = 0, .y = 1 };
        if (left) return Vec2{ .x = -1, .y = 0 };
        if (right) return Vec2{ .x = 1, .y = 0 };

        return Vec2.ZERO;
    }
};

/// Tank-style movement (forward/back + turn left/right)
pub const TankMovement = struct {
    pub const TankInput = struct {
        forward: f32 = 0, // -1 to 1
        turn: f32 = 0, // -1 to 1
    };

    pub fn getTankInput(input_state: *const InputState) TankInput {
        var tank_input = TankInput{};

        if (input_state.isKeyDown(c.sdl.SDL_SCANCODE_W)) tank_input.forward += 1;
        if (input_state.isKeyDown(c.sdl.SDL_SCANCODE_S)) tank_input.forward -= 1;
        if (input_state.isKeyDown(c.sdl.SDL_SCANCODE_A)) tank_input.turn -= 1;
        if (input_state.isKeyDown(c.sdl.SDL_SCANCODE_D)) tank_input.turn += 1;

        return tank_input;
    }
};

/// Mouse-relative movement (RTS-style)
pub const MouseMovement = struct {
    /// Get movement vector toward mouse position
    pub fn getMovementTowardMouse(player_pos: Vec2, mouse_pos: Vec2, max_distance: f32) Vec2 {
        const diff = Vec2{
            .x = mouse_pos.x - player_pos.x,
            .y = mouse_pos.y - player_pos.y,
        };

        const distance = diff.length();
        if (distance < max_distance) {
            return Vec2.ZERO; // Close enough
        }

        // Normalize and return direction
        return Vec2{
            .x = diff.x / distance,
            .y = diff.y / distance,
        };
    }

    /// Check if mouse click should move player (Ctrl+click pattern)
    pub fn shouldMoveToMouse(input_state: *const InputState) bool {
        return input_state.isCtrlHeld() and input_state.isLeftMouseHeld();
    }
};

/// Common movement patterns for different game types
pub const MovementPatterns = struct {
    /// Standard WASD with diagonal movement (Action RPG style)
    pub fn getActionRPGMovement(input_state: *const InputState, base_speed: f32) Vec2 {
        return MovementProcessor.getFinalMovementVector(input_state, base_speed);
    }

    /// Grid-based movement (Roguelike style)
    pub fn getGridMovement(input_state: *const InputState) MovementDirection {
        const up = input_state.isKeyDown(c.sdl.SDL_SCANCODE_W);
        const down = input_state.isKeyDown(c.sdl.SDL_SCANCODE_S);
        const left = input_state.isKeyDown(c.sdl.SDL_SCANCODE_A);
        const right = input_state.isKeyDown(c.sdl.SDL_SCANCODE_D);

        return MovementDirection.fromActions(up, down, left, right);
    }

    /// Platformer movement (only horizontal + jump)
    pub fn getPlatformerMovement(input_state: *const InputState) struct { horizontal: f32, jump: bool } {
        var horizontal: f32 = 0;
        if (input_state.isKeyDown(c.sdl.SDL_SCANCODE_A)) horizontal -= 1;
        if (input_state.isKeyDown(c.sdl.SDL_SCANCODE_D)) horizontal += 1;

        const jump = input_state.isKeyDown(c.sdl.SDL_SCANCODE_SPACE);

        return .{ .horizontal = horizontal, .jump = jump };
    }
};
