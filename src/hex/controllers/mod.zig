// Controller systems modules - extracted from game.zig and controller.zig

pub const PlayerController = @import("player.zig").PlayerController;
pub const AIController = @import("ai.zig").AIController;

// Re-export existing controller module for compatibility
pub const controller = @import("../controller.zig");
pub const controlled_entity = @import("../controlled_entity.zig");
pub const controls = @import("../controls.zig");

// Re-export for convenience
pub const player = @import("player.zig");
pub const ai = @import("ai.zig");
