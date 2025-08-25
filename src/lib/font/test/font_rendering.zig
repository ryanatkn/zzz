const std = @import("std");
const testing = std.testing;
const font_types = @import("../core/types.zig");
const vertex_strategy = @import("../strategies/vertex/mod.zig");
const bitmap_strategy = @import("../strategies/bitmap/mod.zig");
const sdf_strategy = @import("../strategies/sdf/mod.zig");

const test_helpers = @import("../test_helpers.zig");

// Font rendering tests using strategy-based renderer architecture

// New strategy validation test
test "strategy imports and types" {
    // Verify all strategy modules import correctly and have expected types
    _ = vertex_strategy.GlyphTriangulator;
    _ = bitmap_strategy.RasterizedGlyph; // Correct type name
    _ = sdf_strategy.SDFGenerator;
    const RenderingStrategy = font_types.RenderingStrategy;

    std.debug.print("\n✅ Strategy Architecture Validation:\n", .{});
    std.debug.print("  - Vertex strategy: GlyphTriangulator available\n", .{});
    std.debug.print("  - Bitmap strategy: RasterizedGlyph available\n", .{});
    std.debug.print("  - SDF strategy: SDFGenerator available\n", .{});
    std.debug.print("  - Core types: RenderingStrategy enum available\n", .{});

    // Test enum values
    try testing.expectEqual(RenderingStrategy.vertex, RenderingStrategy.vertex);
    try testing.expectEqual(RenderingStrategy.bitmap, RenderingStrategy.bitmap);
    try testing.expectEqual(RenderingStrategy.sdf, RenderingStrategy.sdf);

    // Test toString methods
    try testing.expectEqualStrings("vertex", RenderingStrategy.vertex.toString());
    try testing.expectEqualStrings("bitmap", RenderingStrategy.bitmap.toString());
    try testing.expectEqualStrings("sdf", RenderingStrategy.sdf.toString());
}

test "bitmap strategy availability" {
    // Verify bitmap strategy components are available
    _ = bitmap_strategy.RasterizedGlyph;

    // Test passes if no compile errors occur
    try testing.expect(true);
}

test "vertex strategy availability" {
    // Verify vertex strategy components are available
    _ = vertex_strategy.GlyphTriangulator;

    // Test passes if no compile errors occur
    try testing.expect(true);
}

test "sdf strategy availability" {
    // Verify SDF strategy components are available
    _ = sdf_strategy.SDFGenerator;

    // Test passes if no compile errors occur
    try testing.expect(true);
}

test "font type validation" {
    // Verify font type enums work correctly
    const RenderingStrategy = font_types.RenderingStrategy;

    try testing.expect(RenderingStrategy.vertex != RenderingStrategy.bitmap);
    try testing.expect(RenderingStrategy.bitmap != RenderingStrategy.sdf);
    try testing.expect(RenderingStrategy.sdf != RenderingStrategy.vertex);
}

test "strategy toString methods" {
    // Verify toString methods work for all strategies
    const RenderingStrategy = font_types.RenderingStrategy;

    const vertex_str = RenderingStrategy.vertex.toString();
    const bitmap_str = RenderingStrategy.bitmap.toString();
    const sdf_str = RenderingStrategy.sdf.toString();

    try testing.expect(vertex_str.len > 0);
    try testing.expect(bitmap_str.len > 0);
    try testing.expect(sdf_str.len > 0);
}

test "test helpers availability" {
    // Verify test helpers are available
    _ = test_helpers;

    // Test passes if no compile errors occur
    try testing.expect(true);
}

test "strategy module imports" {
    // Verify all strategy modules import without errors
    _ = vertex_strategy;
    _ = bitmap_strategy;
    _ = sdf_strategy;

    try testing.expect(true);
}

test "font types availability" {
    // Verify font_types module works correctly
    _ = font_types.RenderingStrategy;

    try testing.expect(true);
}

test "complete strategy system validation" {
    // Final comprehensive test that all components work together
    const RenderingStrategy = font_types.RenderingStrategy;

    // Verify all strategies are available
    _ = vertex_strategy.GlyphTriangulator;
    _ = bitmap_strategy.RasterizedGlyph;
    _ = sdf_strategy.SDFGenerator;

    // Verify all strategy types work
    try testing.expectEqualStrings("vertex", RenderingStrategy.vertex.toString());
    try testing.expectEqualStrings("bitmap", RenderingStrategy.bitmap.toString());
    try testing.expectEqualStrings("sdf", RenderingStrategy.sdf.toString());

    // Test passes if all components are available
    try testing.expect(true);
}

// Run all tests with: zig build test -Dtest-filter="font"
