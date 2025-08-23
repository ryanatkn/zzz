// State management modules - Phase 4 extraction from game_loop.zig

pub const PauseManager = @import("pause.zig").PauseManager;
pub const StatisticsManager = @import("statistics.zig").StatisticsManager;

// Re-export for convenience
pub const pause = @import("pause.zig");
pub const statistics = @import("statistics.zig");
