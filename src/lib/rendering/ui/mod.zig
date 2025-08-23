// UI drawing patterns and components

pub const drawing = @import("drawing.zig");

// Re-export drawing functions for convenience
pub const drawPanel = drawing.drawPanel;
pub const drawButton = drawing.drawButton;
pub const drawProgressBar = drawing.drawProgressBar;
pub const drawOverlay = drawing.drawOverlay;
