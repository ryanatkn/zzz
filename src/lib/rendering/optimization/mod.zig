// Performance optimization and rendering strategies

pub const performance = @import("performance.zig");
pub const modes = @import("modes.zig");

// Re-export main types for convenience
pub const PerformanceMonitor = performance.PerformanceMonitor;
pub const FrameMetrics = performance.FrameMetrics;
pub const Config = performance.Config;
pub const RenderingMode = modes.RenderingMode;
pub const RenderingModeConfig = modes.RenderingModeConfig;
