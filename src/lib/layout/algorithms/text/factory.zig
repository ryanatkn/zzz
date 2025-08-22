/// Text layout algorithm factory - simplified without VTable wrappers
const std = @import("std");
const core = @import("../../core/types.zig");
const interface = @import("../../core/interface.zig");
const layout = @import("layout.zig");

/// Text algorithm configuration
pub const Config = struct {
    /// Enable debug validation
    debug_mode: bool = false,
};

/// Create a text layout algorithm instance (simplified)
pub fn createAlgorithm(
    allocator: std.mem.Allocator,
    config: Config,
    _: ?*anyopaque,
) !interface.LayoutAlgorithm {
    _ = allocator; // No longer needed - algorithms are stateless
    _ = config; // TODO: Use config.debug_mode when implementation supports it

    return interface.LayoutAlgorithm{
        .algorithm_type = .block, // Text layout uses block for now
    };
}
