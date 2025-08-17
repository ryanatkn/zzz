/// Input context for update operations that need input state
const std = @import("std");
const UpdateContext = @import("update_context.zig").UpdateContext;
const platform_input = @import("../../platform/input.zig");
const math = @import("../../math/mod.zig");

const Vec2 = math.Vec2;

/// Mouse button state
pub const MouseButtons = struct {
    left: bool = false,
    right: bool = false,
    middle: bool = false,
    x1: bool = false,
    x2: bool = false,

    pub fn any(self: MouseButtons) bool {
        return self.left or self.right or self.middle or self.x1 or self.x2;
    }

    pub fn primary(self: MouseButtons) bool {
        return self.left;
    }

    pub fn secondary(self: MouseButtons) bool {
        return self.right;
    }
};

/// Keyboard modifier keys
pub const ModifierKeys = struct {
    ctrl: bool = false,
    shift: bool = false,
    alt: bool = false,
    super: bool = false, // Windows/Cmd key

    pub fn any(self: ModifierKeys) bool {
        return self.ctrl or self.shift or self.alt or self.super;
    }
};

/// Set of keyboard keys (simple implementation)
pub const KeySet = struct {
    // Common keys used in games
    w: bool = false,
    a: bool = false,
    s: bool = false,
    d: bool = false,
    space: bool = false,
    enter: bool = false,
    escape: bool = false,
    tab: bool = false,

    // Number keys
    key_1: bool = false,
    key_2: bool = false,
    key_3: bool = false,
    key_4: bool = false,
    key_5: bool = false,
    key_6: bool = false,
    key_7: bool = false,
    key_8: bool = false,
    key_9: bool = false,
    key_0: bool = false,

    // Additional keys
    q: bool = false,
    e: bool = false,
    r: bool = false,
    f: bool = false,
    g: bool = false,
    h: bool = false,

    pub fn any(self: KeySet) bool {
        return self.w or self.a or self.s or self.d or self.space or
            self.enter or self.escape or self.tab or
            self.key_1 or self.key_2 or self.key_3 or self.key_4 or
            self.key_5 or self.key_6 or self.key_7 or self.key_8 or
            self.key_9 or self.key_0 or
            self.q or self.e or self.r or self.f or self.g or self.h;
    }

    /// Check if movement keys are pressed
    pub fn hasMovement(self: KeySet) bool {
        return self.w or self.a or self.s or self.d;
    }

    /// Check if spell keys are pressed
    pub fn hasSpellKeys(self: KeySet) bool {
        return self.key_1 or self.key_2 or self.key_3 or self.key_4 or
            self.q or self.e or self.r or self.f;
    }
};

/// Input context for update operations that need input state
pub const InputContext = struct {
    base: UpdateContext,

    // Mouse state
    mouse_position: Vec2,
    mouse_delta: Vec2,
    mouse_buttons: MouseButtons,
    mouse_wheel: f32,

    // Keyboard state
    keys_pressed: KeySet,
    keys_held: KeySet,
    keys_released: KeySet,

    // Modifiers
    modifiers: ModifierKeys,

    // Integration with platform InputState
    platform_input_state: ?*const platform_input.InputState,

    pub fn init(base_context: UpdateContext) InputContext {
        return .{
            .base = base_context,
            .mouse_position = Vec2.ZERO,
            .mouse_delta = Vec2.ZERO,
            .mouse_buttons = MouseButtons{},
            .mouse_wheel = 0,
            .keys_pressed = KeySet{},
            .keys_held = KeySet{},
            .keys_released = KeySet{},
            .modifiers = ModifierKeys{},
            .platform_input_state = null,
        };
    }

    pub fn withMousePosition(self: InputContext, pos: Vec2) InputContext {
        var result = self;
        result.mouse_position = pos;
        return result;
    }

    pub fn withMouseDelta(self: InputContext, delta: Vec2) InputContext {
        var result = self;
        result.mouse_delta = delta;
        return result;
    }

    pub fn withPlatformInput(self: InputContext, input_state: *const platform_input.InputState) InputContext {
        var result = self;
        result.platform_input_state = input_state;
        // Sync mouse position and button state
        result.mouse_position = input_state.getMousePos();
        result.mouse_buttons.left = input_state.isLeftMouseHeld();
        result.mouse_buttons.right = input_state.isRightMouseHeld();
        return result;
    }

    /// Get movement vector from WASD keys, integrates with platform input if available
    pub fn getMovementVector(self: InputContext) Vec2 {
        if (self.platform_input_state) |platform| {
            return platform.getMovementVector();
        }

        // Fallback to context key state
        var velocity = Vec2.ZERO;
        if (self.keys_held.w) velocity.y -= 1.0;
        if (self.keys_held.s) velocity.y += 1.0;
        if (self.keys_held.a) velocity.x -= 1.0;
        if (self.keys_held.d) velocity.x += 1.0;

        return velocity.normalized();
    }
};