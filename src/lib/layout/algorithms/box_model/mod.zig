/// Box Model Layout Algorithm
///
/// CSS-like box model layout implementation.
/// Provides content -> padding -> border -> margin layout areas
/// with dirty flag caching and constraint-based sizing.

// Import layout implementation
pub const layout = @import("layout.zig");
pub const factory = @import("factory.zig");

// Re-export main types
pub const BoxModel = layout.BoxModel;
pub const BoxModelAlgorithm = layout.BoxModelAlgorithm;

// Re-export factory functionality
pub const Config = factory.Config;
pub const createAlgorithm = factory.createAlgorithm;

/// Algorithm information
pub const Info = struct {
    pub const name = "Box Model";
    pub const description = "CSS-like box model with content, padding, border, and margin areas";
    pub const supports_nesting = true;
    pub const supports_constraints = true;

    pub const typical_use_cases = [_][]const u8{
        "Simple rectangular layouts",
        "UI panels with padding/margins",
        "Card-based designs",
        "Document flow layouts",
    };
};

// Tests
test "box model info" {
    const std = @import("std");
    const testing = std.testing;

    try testing.expectEqualStrings("Box Model", Info.name);
    // Algorithm info provides all necessary metadata
    try testing.expect(Info.supports_nesting);
    try testing.expect(Info.typical_use_cases.len == 4);
}
