/// Box model algorithm factory - simplified without VTable wrappers
const std = @import("std");
const interface = @import("../../core/interface.zig");
const core = @import("../../core/types.zig");
const layout = @import("layout.zig");

/// Box model configuration
pub const Config = struct {
    /// Enable layout caching
    enable_caching: bool = true,
    /// Debug validation
    debug_mode: bool = false,
};

/// Create box model algorithm (simplified - no longer needed with direct calls)
/// Kept for backward compatibility but now just returns a simple LayoutAlgorithm
pub fn createAlgorithm(
    allocator: std.mem.Allocator,
    config: Config,
    _: ?*anyopaque,
) !interface.LayoutAlgorithm {
    _ = allocator; // No longer needed - algorithms are stateless
    _ = config; // TODO: Use config fields when implementation supports them

    return interface.LayoutAlgorithm{
        .algorithm_type = .block, // Default to block layout
    };
}

// Tests
test "box model algorithm creation" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = Config{};
    const algorithm = try createAlgorithm(allocator, config, null);

    const capabilities = algorithm.getCapabilities();
    try testing.expectEqualStrings("Box Model", capabilities.name);
    // Capabilities provide all necessary information for algorithm selection
    try testing.expect(capabilities.features.nesting == true);
    try testing.expect(capabilities.features.spacing == true);
}
