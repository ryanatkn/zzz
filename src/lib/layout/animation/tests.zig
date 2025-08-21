/// Tests for layout animation system
///
/// This module contains tests that verify the animation system functionality
/// including type recommendations and manager operations.

const std = @import("std");
const utils = @import("utils.zig");

// Tests
test "animation type recommendations" {
    const testing = std.testing;

    // Should recommend springs for physics-based animations
    try testing.expect(utils.recommendAnimationType(true, false, false) == .spring);

    // Should recommend transitions for precise timing
    try testing.expect(utils.recommendAnimationType(false, true, false) == .transition);

    // Should recommend sequences for coordination
    try testing.expect(utils.recommendAnimationType(false, false, true) == .sequence);

    // Default should be springs
    try testing.expect(utils.recommendAnimationType(false, false, false) == .spring);
}