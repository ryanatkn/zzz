const std = @import("std");

// Platform capabilities
const input = @import("../../lib/platform/input.zig");

// Hex game modules
const controls = @import("../controls.zig");

const InputState = input.InputState;

/// Input handling functionality
pub const InputController = struct {
    /// Get mouse position from input state
    pub fn getMousePos(input_state: *const InputState) @import("../../lib/math/mod.zig").Vec2 {
        return input_state.getMousePos();
    }

    /// Check if left mouse button is held
    pub fn isLeftMouseHeld(input_state: *const InputState) bool {
        return input_state.isLeftMouseHeld();
    }

    /// Check if Ctrl key is held
    pub fn isCtrlHeld(input_state: *const InputState) bool {
        return input_state.isCtrlHeld();
    }

    /// Check if Shift key is held
    pub fn isShiftHeld(input_state: *const InputState) bool {
        return input_state.isShiftHeld();
    }

    /// Initialize input state
    pub fn initInputState() InputState {
        return InputState.init();
    }

    /// Process game controls
    pub fn processGameControls(input_state: *const InputState, game_state: anytype) void {
        // Delegate to controls module for game-specific input handling
        _ = input_state;
        _ = game_state;
        // TODO: Extract control handling from main.zig or game.zig as needed
    }
};
