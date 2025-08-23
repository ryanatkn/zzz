/// Platform capability exports - SDL3 integration, window management, input
/// Re-exports for capability-based imports following engine architecture
pub const sdl = @import("sdl.zig");
pub const input = @import("input.zig");
pub const window = @import("window.zig");
pub const resources = @import("resources.zig");

// Common window types for convenience
pub const WindowConfig = window.WindowConfig;
pub const WindowError = window.WindowError;

// Resource management types
pub const SharedFontManager = resources.SharedFontManager;
pub const ResourceError = resources.ResourceError;
// Note: PlatformResources temporarily removed due to WindowGPU cleanup
