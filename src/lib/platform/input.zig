const std = @import("std");
const c = @import("sdl.zig");

const math = @import("../math/mod.zig");
const viewport = @import("../core/viewport.zig");

const Vec2 = math.Vec2;

/// Modifier key state as a packed struct
pub const ModifierKeys = packed struct {
    ctrl: bool = false,
    shift: bool = false,
    alt: bool = false,
};

pub const InputState = struct {
    keys_down: std.StaticBitSet(512),
    mouse_pos: Vec2,
    left_mouse_held: bool,
    right_mouse_held: bool,

    const Self = @This();

    pub fn init() Self {
        return .{
            .keys_down = std.StaticBitSet(512).initEmpty(),
            .mouse_pos = Vec2.ZERO,
            .left_mouse_held = false,
            .right_mouse_held = false,
        };
    }

    pub fn handleKeyDown(self: *Self, scancode: c_uint) void {
        self.keys_down.set(@intCast(scancode));
    }

    pub fn handleKeyUp(self: *Self, scancode: c_uint) void {
        self.keys_down.unset(@intCast(scancode));
    }

    pub fn handleMouseMotion(self: *Self, x: f32, y: f32) void {
        self.mouse_pos.x = x;
        self.mouse_pos.y = y;
    }

    pub fn handleMouseButtonDown(self: *Self, button: u8) void {
        switch (button) {
            c.sdl.SDL_BUTTON_LEFT => self.left_mouse_held = true,
            c.sdl.SDL_BUTTON_RIGHT => self.right_mouse_held = true,
            else => {},
        }
    }

    pub fn handleMouseButtonUp(self: *Self, button: u8) void {
        switch (button) {
            c.sdl.SDL_BUTTON_LEFT => self.left_mouse_held = false,
            c.sdl.SDL_BUTTON_RIGHT => self.right_mouse_held = false,
            else => {},
        }
    }

    pub fn isKeyDown(self: *const Self, scancode: c_uint) bool {
        return self.keys_down.isSet(@intCast(scancode));
    }

    pub fn isLeftMouseHeld(self: *const Self) bool {
        return self.left_mouse_held;
    }

    pub fn isRightMouseHeld(self: *const Self) bool {
        return self.right_mouse_held;
    }

    pub fn getMousePos(self: *const Self) Vec2 {
        return self.mouse_pos;
    }

    pub fn getWorldMousePos(self: *const Self, vp: viewport.Viewport) Vec2 {
        return vp.screenToWorld(self.mouse_pos);
    }

    pub fn getMovementVector(self: *const Self) Vec2 {
        var velocity = Vec2.ZERO;

        const w_pressed = self.isKeyDown(c.sdl.SDL_SCANCODE_W);
        const s_pressed = self.isKeyDown(c.sdl.SDL_SCANCODE_S);
        const a_pressed = self.isKeyDown(c.sdl.SDL_SCANCODE_A);
        const d_pressed = self.isKeyDown(c.sdl.SDL_SCANCODE_D);

        if (w_pressed) {
            velocity.y -= 1.0;
        }
        if (s_pressed) {
            velocity.y += 1.0;
        }
        if (a_pressed) {
            velocity.x -= 1.0;
        }
        if (d_pressed) {
            velocity.x += 1.0;
        }

        const length = velocity.length();
        if (length > 0) {
            velocity.x /= length;
            velocity.y /= length;
        }

        return velocity;
    }

    pub fn isCtrlHeld(self: *const Self) bool {
        return self.isKeyDown(c.sdl.SDL_SCANCODE_LCTRL) or self.isKeyDown(c.sdl.SDL_SCANCODE_RCTRL);
    }

    pub fn isShiftHeld(self: *const Self) bool {
        return self.isKeyDown(c.sdl.SDL_SCANCODE_LSHIFT) or self.isKeyDown(c.sdl.SDL_SCANCODE_RSHIFT);
    }

    pub fn isAltHeld(self: *const Self) bool {
        return self.isKeyDown(c.sdl.SDL_SCANCODE_LALT) or self.isKeyDown(c.sdl.SDL_SCANCODE_RALT);
    }

    /// Get all modifier keys as a packed struct
    pub fn getModifiers(self: *const Self) ModifierKeys {
        return ModifierKeys{
            .ctrl = self.isCtrlHeld(),
            .shift = self.isShiftHeld(),
            .alt = self.isAltHeld(),
        };
    }

    /// Clear all input state (useful for state transitions)
    pub fn clearAllInput(self: *Self) void {
        self.keys_down = std.StaticBitSet(512).initEmpty();
        self.left_mouse_held = false;
        self.right_mouse_held = false;
        self.mouse_pos = Vec2.ZERO;
    }

    pub fn clearMouseHold(self: *Self) void {
        self.left_mouse_held = false;
        self.right_mouse_held = false;
    }
};
