// Dealt - SDL3 Engine with Game Support
// Entry point that can run different game implementations

const std = @import("std");

// Import the hex game implementation
const hex_game = @import("hex/main.zig");

pub fn main() !void {
    // For now, just run the hex game
    // In the future, this could be a game selector or editor
    try hex_game.main();
}
