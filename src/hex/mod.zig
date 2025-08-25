// Hex game - Refactored domain-driven structure
// Main barrel import file for the entire hex game

// Core game modules (main files)
pub const HexGame = @import("world_state.zig").HexGame;
pub const GameState = @import("game_loop.zig").GameState;
pub const GameRenderer = @import("game_renderer.zig").GameRenderer;

// Domain-specific modules
pub const entities = @import("entities/mod.zig");
pub const systems = @import("systems/mod.zig");
pub const controllers = @import("controllers/mod.zig");
pub const world = @import("world/mod.zig");
pub const ui = @import("ui/mod.zig");

// Existing modules (unchanged)
pub const behaviors = @import("behaviors/mod.zig");
pub const hud = @import("hud/hud.zig");
pub const reactive_hud = @import("hud/reactive_hud.zig");

// Game-specific modules
pub const combat = @import("combat/mod.zig");
pub const abilities = @import("ability_system.zig");
pub const constants = @import("constants.zig");
pub const physics = @import("physics.zig");
pub const controls = @import("controls.zig");
pub const colors = @import("colors.zig");

// Re-export core types for convenience
pub const EntityId = entities.EntityId;
pub const Vec2 = @import("../lib/math/mod.zig").Vec2;
pub const Color = @import("../lib/core/colors.zig").Color;

// Main entry point
pub const main = @import("main.zig");
