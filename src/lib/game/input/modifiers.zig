const std = @import("std");
const input = @import("../../platform/input.zig");

const InputState = input.InputState;

/// Standard modifier key combinations
pub const Modifiers = packed struct {
    ctrl: bool = false,
    shift: bool = false,
    alt: bool = false,

    /// No modifiers held
    pub fn none() Modifiers {
        return .{};
    }

    /// Only Ctrl held
    pub fn ctrlOnly() Modifiers {
        return .{ .ctrl = true };
    }

    /// Only Shift held
    pub fn shiftOnly() Modifiers {
        return .{ .shift = true };
    }

    /// Only Alt held
    pub fn altOnly() Modifiers {
        return .{ .alt = true };
    }

    /// Ctrl + Shift
    pub fn ctrlShift() Modifiers {
        return .{ .ctrl = true, .shift = true };
    }

    /// Ctrl + Alt
    pub fn ctrlAlt() Modifiers {
        return .{ .ctrl = true, .alt = true };
    }

    /// Shift + Alt
    pub fn shiftAlt() Modifiers {
        return .{ .shift = true, .alt = true };
    }

    /// All modifiers
    pub fn all() Modifiers {
        return .{ .ctrl = true, .shift = true, .alt = true };
    }

    /// Check if this modifier state matches another exactly
    pub fn matches(self: Modifiers, other: Modifiers) bool {
        return std.meta.eql(self, other);
    }

    /// Check if any modifier is held
    pub fn any(self: Modifiers) bool {
        return self.ctrl or self.shift or self.alt;
    }

    /// Check if only the specified modifiers are held (and no others)
    pub fn only(self: Modifiers, required: Modifiers) bool {
        return self.matches(required);
    }

    /// Check if at least the specified modifiers are held (others may also be held)
    pub fn includes(self: Modifiers, required: Modifiers) bool {
        if (required.ctrl and !self.ctrl) return false;
        if (required.shift and !self.shift) return false;
        if (required.alt and !self.alt) return false;
        return true;
    }
};

/// Extract current modifier state from input
pub fn getCurrentModifiers(input_state: *const InputState) Modifiers {
    return Modifiers{
        .ctrl = input_state.isCtrlHeld(),
        .shift = input_state.isShiftHeld(),
        // Alt not implemented in base InputState yet
        .alt = false,
    };
}

/// Common game-specific modifier patterns
pub const ModifierPatterns = struct {
    /// Walking modifier (usually Shift)
    pub fn isWalkModifier(modifiers: Modifiers) bool {
        return modifiers.only(Modifiers.shiftOnly());
    }

    /// Self-cast modifier (usually Ctrl for spells)
    pub fn isSelfCastModifier(modifiers: Modifiers) bool {
        return modifiers.only(Modifiers.ctrlOnly());
    }

    /// Move-to-click modifier (usually Ctrl+click)
    pub fn isMoveToClickModifier(modifiers: Modifiers) bool {
        return modifiers.only(Modifiers.ctrlOnly());
    }

    /// Precision modifier (usually Ctrl for fine movement)
    pub fn isPrecisionModifier(modifiers: Modifiers) bool {
        return modifiers.only(Modifiers.ctrlOnly());
    }

    /// Fast action modifier (usually Shift for running, quick actions)
    pub fn isFastActionModifier(modifiers: Modifiers) bool {
        return modifiers.only(Modifiers.shiftOnly());
    }

    /// Alternative action modifier (usually Alt for alternate mode)
    pub fn isAlternateActionModifier(modifiers: Modifiers) bool {
        return modifiers.only(Modifiers.altOnly());
    }

    /// Debug/admin modifier (usually Ctrl+Shift for debug commands)
    pub fn isDebugModifier(modifiers: Modifiers) bool {
        return modifiers.only(Modifiers.ctrlShift());
    }
};

/// Helper functions for specific input state queries
pub const ModifierHelpers = struct {
    /// Check if walking (slow movement) is active
    pub fn isWalking(input_state: *const InputState) bool {
        const mods = getCurrentModifiers(input_state);
        return ModifierPatterns.isWalkModifier(mods);
    }

    /// Check if self-cast mode is active
    pub fn isSelfCasting(input_state: *const InputState) bool {
        const mods = getCurrentModifiers(input_state);
        return ModifierPatterns.isSelfCastModifier(mods);
    }

    /// Check if move-to-click is active
    pub fn isMoveToClick(input_state: *const InputState) bool {
        const mods = getCurrentModifiers(input_state);
        return ModifierPatterns.isMoveToClickModifier(mods);
    }

    /// Check if precision mode is active
    pub fn isPrecisionMode(input_state: *const InputState) bool {
        const mods = getCurrentModifiers(input_state);
        return ModifierPatterns.isPrecisionModifier(mods);
    }

    /// Check if fast action mode is active
    pub fn isFastAction(input_state: *const InputState) bool {
        const mods = getCurrentModifiers(input_state);
        return ModifierPatterns.isFastActionModifier(mods);
    }

    /// Check if debug mode is active
    pub fn isDebugMode(input_state: *const InputState) bool {
        const mods = getCurrentModifiers(input_state);
        return ModifierPatterns.isDebugModifier(mods);
    }
};

/// Action modifiers for specific input combinations
pub const ActionModifiers = struct {
    /// Mouse click with modifiers
    pub const MouseClickModifiers = struct {
        left_click: bool = false,
        right_click: bool = false,
        middle_click: bool = false,
        modifiers: Modifiers = Modifiers.none(),

        pub fn isLeftClickWith(self: MouseClickModifiers, required_mods: Modifiers) bool {
            return self.left_click and self.modifiers.matches(required_mods);
        }

        pub fn isRightClickWith(self: MouseClickModifiers, required_mods: Modifiers) bool {
            return self.right_click and self.modifiers.matches(required_mods);
        }

        /// Common patterns
        pub fn isCtrlLeftClick(self: MouseClickModifiers) bool {
            return self.isLeftClickWith(Modifiers.ctrl());
        }

        pub fn isShiftLeftClick(self: MouseClickModifiers) bool {
            return self.isLeftClickWith(Modifiers.shift());
        }

        pub fn isCtrlRightClick(self: MouseClickModifiers) bool {
            return self.isRightClickWith(Modifiers.ctrl());
        }
    };

    /// Extract mouse click with modifiers from input state
    pub fn getMouseClickModifiers(input_state: *const InputState) MouseClickModifiers {
        return MouseClickModifiers{
            .left_click = input_state.left_mouse_held,
            .right_click = input_state.right_mouse_held,
            .middle_click = false, // Not implemented in base InputState
            .modifiers = getCurrentModifiers(input_state),
        };
    }
};

/// Modifier-aware input processing
pub const ModifierProcessor = struct {
    /// Process left mouse click based on modifiers
    pub fn processLeftClick(input_state: *const InputState) enum { Normal, MoveToClick, Precision, None } {
        if (!input_state.left_mouse_held) return .None;

        const mods = getCurrentModifiers(input_state);
        if (ModifierPatterns.isMoveToClickModifier(mods)) return .MoveToClick;
        if (ModifierPatterns.isPrecisionModifier(mods)) return .Precision;
        return .Normal;
    }

    /// Process right click based on modifiers
    pub fn processRightClick(input_state: *const InputState) enum { Normal, SelfCast, Alternate, None } {
        if (!input_state.right_mouse_held) return .None;

        const mods = getCurrentModifiers(input_state);
        if (ModifierPatterns.isSelfCastModifier(mods)) return .SelfCast;
        if (ModifierPatterns.isAlternateActionModifier(mods)) return .Alternate;
        return .Normal;
    }

    /// Get movement speed multiplier based on modifiers
    pub fn getMovementSpeedMultiplier(input_state: *const InputState) f32 {
        const mods = getCurrentModifiers(input_state);
        if (ModifierPatterns.isWalkModifier(mods)) return 0.3; // Slow walk
        if (ModifierPatterns.isFastActionModifier(mods)) return 2.0; // Fast run
        if (ModifierPatterns.isPrecisionModifier(mods)) return 0.5; // Precise movement
        return 1.0; // Normal speed
    }
};
