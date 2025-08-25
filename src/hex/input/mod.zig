// Input system modules - Phase 4 extraction from game_loop.zig

pub const InputHandler = @import("handler.zig").InputHandler;
pub const ability_mapping = @import("ability_mapping.zig");

// Re-export for convenience
pub const handler = @import("handler.zig");
