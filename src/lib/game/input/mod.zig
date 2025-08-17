// New action-based input system
pub const actions = @import("actions.zig");
pub const movement = @import("movement.zig");
pub const modifiers = @import("modifiers.zig");
pub const dead_player_handler = @import("dead_player_handler.zig");

// Legacy patterns (preserved for compatibility)
pub const input_patterns = @import("input_patterns.zig");
pub const action_priority = @import("action_priority.zig");
pub const pattern_recognition = @import("pattern_recognition.zig");
