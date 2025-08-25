// Hex-specific ability slot key mappings
// Implements the 1-4, Q, E, R, F pattern for 8-slot ability system

const std = @import("std");
const c = @import("../../lib/platform/sdl.zig");
const game_actions = @import("../../lib/game/input/actions.zig");
const GameAction = game_actions.GameAction;

/// Hex game uses 8-slot ability system with specific key layout:
/// [1] [2] [3] [4]
/// [Q] [E] [R] [F]
pub fn mapHexAbilityKeys(scancode: u32) GameAction {
    return switch (scancode) {
        // Top row: 1-4 keys
        c.sdl.SDL_SCANCODE_1 => .SelectAbility1,
        c.sdl.SDL_SCANCODE_2 => .SelectAbility2,
        c.sdl.SDL_SCANCODE_3 => .SelectAbility3,
        c.sdl.SDL_SCANCODE_4 => .SelectAbility4,

        // Bottom row: Q, E, R, F keys
        c.sdl.SDL_SCANCODE_Q => .SelectAbility5,
        c.sdl.SDL_SCANCODE_E => .SelectAbility6,
        c.sdl.SDL_SCANCODE_R => .SelectAbility7,
        c.sdl.SDL_SCANCODE_F => .SelectAbility8,

        else => .None,
    };
}

/// Check if scancode is a hex ability selection key
pub fn isHexAbilityKey(scancode: u32) bool {
    return mapHexAbilityKeys(scancode) != .None;
}

/// Get ability slot index (0-7) from hex ability key
pub fn getHexAbilitySlot(scancode: u32) ?u8 {
    return switch (mapHexAbilityKeys(scancode)) {
        .SelectAbility1 => 0,
        .SelectAbility2 => 1,
        .SelectAbility3 => 2,
        .SelectAbility4 => 3,
        .SelectAbility5 => 4,
        .SelectAbility6 => 5,
        .SelectAbility7 => 6,
        .SelectAbility8 => 7,
        else => null,
    };
}
