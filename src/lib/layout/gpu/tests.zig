/// Tests for GPU layout data structures and engine
///
/// This module contains tests that verify GPU data structure sizes, alignment,
/// and basic functionality to ensure compatibility with compute shaders.
const std = @import("std");
const math = @import("../../math/mod.zig");
const structures = @import("structures.zig");

const Vec2 = math.Vec2;
const UIElement = structures.UIElement;
const LayoutConstraint = structures.LayoutConstraint;
const SpringState = structures.SpringState;

test "UIElement struct size and alignment" {
    // Verify UIElement is exactly 64 bytes as required for GPU compatibility
    try std.testing.expect(@sizeOf(UIElement) == 64);
    try std.testing.expect(@alignOf(UIElement) >= 4); // Minimum alignment for GPU

    // Verify field offsets match expected layout
    const elem = UIElement.init(Vec2.ZERO, Vec2.ZERO);
    _ = elem;
}

test "constraint struct size" {
    // Verify LayoutConstraint is exactly 32 bytes
    try std.testing.expect(@sizeOf(LayoutConstraint) == 32);
}

test "spring state struct size" {
    // Verify SpringState is exactly 32 bytes
    try std.testing.expect(@sizeOf(SpringState) == 32);
}

test "dirty flag manipulation" {
    var elem = UIElement.init(Vec2.ZERO, Vec2.ZERO);

    // Initially should have layout dirty flag set
    try std.testing.expect(elem.isDirty(.layout));

    // Clear and test
    elem.clearDirty(.layout);
    try std.testing.expect(!elem.isDirty(.layout));

    // Set different flag
    elem.markDirty(.spring);
    try std.testing.expect(elem.isDirty(.spring));
    try std.testing.expect(!elem.isDirty(.layout));
}
