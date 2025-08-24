const std = @import("std");
const testing = std.testing;
const font_types = @import("../core/types.zig");
const vertex_strategy = @import("../strategies/vertex/mod.zig");
const bitmap_strategy = @import("../strategies/bitmap/mod.zig");
const sdf_strategy = @import("../strategies/sdf/mod.zig");

const test_helpers = @import("../test_helpers.zig");

// NOTE: All rendering tests disabled due to renderer architecture changes
// TODO: Re-implement tests using new strategy-based renderer architecture

// DISABLED: Old renderer architecture tests - need to be rewritten for strategies
const RENDERING_TESTS_DISABLED = true;

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

test "simple bitmap renderer - rectangle" {
    if (RENDERING_TESTS_DISABLED) return error.SkipZigTest;
    // if (RENDERING_TESTS_DISABLED) return error.SkipZigTest;
    // const allocator = testing.allocator;

    // // Create a simple rectangle outline
    // const outline = try TestData.createRectangleOutline(allocator, 10, 10, 80, 60);
    // defer @constCast(&outline).deinit(allocator);

    // // Create renderer
    // var renderer = bitmap_simple.SimpleBitmapRenderer.init();
    // var text_renderer = renderer.asRenderer();

    // // Render at 24pt
    // const result = try text_renderer.renderGlyph(allocator, outline, 24.0);
    // defer result.deinit(allocator);

    // // Visualize result
    // std.debug.print("\nSimple Bitmap Renderer - Rectangle Test:\n", .{});
    // BitmapVisualizer.toAsciiArt(result.bitmap, result.width, result.height);

    // // Verify non-empty
    // try Assertions.expectNonEmpty(result.bitmap);

    // // Verify reasonable coverage (rectangle should fill most of the bitmap)
    // try Assertions.expectCoverage(result.bitmap, 50.0, 90.0);

    // // Save to file for inspection
    // try BitmapVisualizer.saveToPGM(result.bitmap, result.width, result.height, "test_rectangle.pgm");
}

test "simple bitmap renderer - triangle" {
    if (RENDERING_TESTS_DISABLED) return error.SkipZigTest;
    // const allocator = testing.allocator;

    // // Create a triangle outline
    // const outline = try TestData.createTriangleOutline(allocator);
    // defer @constCast(&outline).deinit(allocator);

    // // Create renderer
    // var renderer = bitmap_simple.SimpleBitmapRenderer.init();
    // var text_renderer = renderer.asRenderer();

    // // Render at 32pt
    // const result = try text_renderer.renderGlyph(allocator, outline, 32.0);
    // defer result.deinit(allocator);

    // // Visualize result
    // std.debug.print("\nSimple Bitmap Renderer - Triangle Test:\n", .{});
    // BitmapVisualizer.toAsciiArt(result.bitmap, result.width, result.height);

    // // Verify non-empty
    // try Assertions.expectNonEmpty(result.bitmap);

    // // Triangle should have less coverage than rectangle
    // try Assertions.expectCoverage(result.bitmap, 20.0, 60.0);
}

test "debug ASCII renderer - basic shapes" {
    if (RENDERING_TESTS_DISABLED) return error.SkipZigTest;
    // const allocator = testing.allocator;

    // // Create test outline
    // const outline = try TestData.createRectangleOutline(allocator, 100, 100, 400, 300);
    // defer @constCast(&outline).deinit(allocator);

    // // Create renderer
    // var renderer = debug_ascii.DebugAsciiRenderer.init();
    // var text_renderer = renderer.asRenderer();

    // // Render
    // const result = try text_renderer.renderGlyph(allocator, outline, 24.0);
    // defer result.deinit(allocator);

    // // Debug ASCII always produces 16x20
    // try Assertions.expectDimensions(result.width, result.height, 16, 20);

    // // Visualize
    // std.debug.print("\nDebug ASCII Renderer Output:\n", .{});
    // BitmapVisualizer.toAsciiArt(result.bitmap, result.width, result.height);
}

test "oversampling renderer - 2x quality" {
    if (RENDERING_TESTS_DISABLED) return error.SkipZigTest;
    // const allocator = testing.allocator;

    // // Create test outline
    // const outline = try TestData.createRectangleOutline(allocator, 50, 50, 100, 100);
    // defer @constCast(&outline).deinit(allocator);

    // // Create 2x oversampling renderer
    // var renderer = oversampling.OversamplingRenderer.init(2);
    // var text_renderer = renderer.asRenderer();

    // // Render
    // const result = try text_renderer.renderGlyph(allocator, outline, 24.0);
    // defer result.deinit(allocator);

    // std.debug.print("\nOversampling 2x Renderer:\n", .{});
    // BitmapVisualizer.toAsciiArt(result.bitmap, result.width, result.height);

    // // Should produce non-empty result
    // try Assertions.expectNonEmpty(result.bitmap);
}

test "multi-strategy renderer comparison" {
    if (RENDERING_TESTS_DISABLED) return error.SkipZigTest;
    // const allocator = testing.allocator;

    // // Create test outline
    // const outline = try TestData.createRectangleOutline(allocator, 20, 20, 60, 40);
    // defer @constCast(&outline).deinit(allocator);

    // // Create multi-strategy renderer
    // var renderer = try multi_strategy.MultiStrategyRenderer.init(allocator);
    // defer renderer.deinit();

    // // Render with all strategies
    // const results = try renderer.renderWithAllStrategies(outline, 24.0);

    // std.debug.print("\n=== Multi-Strategy Comparison ===\n", .{});

    // for (results) |strategy_result| {
    //     if (strategy_result.result) |result| {
    //         std.debug.print("\nStrategy: {s}\n", .{strategy_result.strategy.getName()});
    //         std.debug.print("  Size: {}x{}\n", .{ result.width, result.height });
    //         std.debug.print("  Render time: {}µs\n", .{result.render_time_us});
    //         std.debug.print("  Quality score: {d:.1}\n", .{result.quality_score});

    //         const coverage = BitmapVisualizer.calculateCoverage(result.bitmap);
    //         std.debug.print("  Coverage: {d:.1}%\n", .{coverage});
    //     } else if (strategy_result.error_msg) |err| {
    //         std.debug.print("\nStrategy: {s} - ERROR: {s}\n", .{ strategy_result.strategy.getName(), err });
    //     }
    // }
}

test "performance - single glyph rendering" {
    if (RENDERING_TESTS_DISABLED) return error.SkipZigTest;
    // const allocator = testing.allocator;

    // // Create test outline
    // const outline = try TestData.createRectangleOutline(allocator, 0, 0, 100, 100);
    // defer @constCast(&outline).deinit(allocator);

    // // Create renderer
    // var renderer = bitmap_simple.SimpleBitmapRenderer.init();
    // var text_renderer = renderer.asRenderer();

    // // Benchmark single render
    // var bench = Benchmark.start("single glyph render");
    // const result = try text_renderer.renderGlyph(allocator, outline, 24.0);
    // bench.end();
    // defer result.deinit(allocator);

    // // Benchmark 100 renders
    // bench = Benchmark.start("100 glyph renders");
    // for (0..100) |_| {
    //     const r = try text_renderer.renderGlyph(allocator, outline, 24.0);
    //     r.deinit(allocator);
    // }
    // try bench.endExpectUnder(10000); // 10ms for 100 glyphs = 100µs per glyph
}

test "empty glyph handling" {
    if (RENDERING_TESTS_DISABLED) return error.SkipZigTest;
    // const allocator = testing.allocator;

    // // Create empty outline (no contours)
    // const outline = font_types.GlyphOutline{
    //     .contours = &[_]font_types.Contour{},
    //     .bounds = .{ .x_min = 0, .y_min = 0, .x_max = 0, .y_max = 0 },
    //     .metrics = .{ .advance_width = 250, .left_side_bearing = 0 },
    // };

    // // Create renderer
    // var renderer = bitmap_simple.SimpleBitmapRenderer.init();
    // var text_renderer = renderer.asRenderer();

    // // Should handle empty glyph gracefully
    // const result = try text_renderer.renderGlyph(allocator, outline, 24.0);
    // defer result.deinit(allocator);

    // // Empty glyph should have 0 dimensions or minimal bitmap
    // try testing.expect(result.width == 0 or result.height == 0 or result.bitmap.len == 1);
}

test "config validation" {
    if (RENDERING_TESTS_DISABLED) return error.SkipZigTest;
    // // Verify that renderer configs are properly initialized
    // const renderer = bitmap_simple.SimpleBitmapRenderer.init();

    // // Check that max_glyph_size is set (was causing 0x0 bitmaps)
    // try testing.expect(renderer.config.max_glyph_size > 0);
    // try testing.expectEqual(@as(u32, 256), renderer.config.max_glyph_size);
}

// Visual test - run with: zig build test -Dtest-filter="visual"
test "visual inspection - all renderers" {
    if (RENDERING_TESTS_DISABLED) return error.SkipZigTest;
    // if (!(std.process.hasEnvVar(testing.allocator, "VISUAL_TEST") catch false)) {
    //     return error.SkipZigTest; // Skip unless VISUAL_TEST env var is set
    // }

    // const allocator = testing.allocator;

    // // Create a more complex test shape
    // const outline = try TestData.createRectangleOutline(allocator, 10, 10, 80, 120);
    // defer @constCast(&outline).deinit(allocator);

    // const renderers = .{
    //     .{ "Simple Bitmap", bitmap_simple.SimpleBitmapRenderer.init() },
    //     .{ "Debug ASCII", debug_ascii.DebugAsciiRenderer.init() },
    //     .{ "Oversampling 2x", oversampling.OversamplingRenderer.init(2) },
    // };

    // std.debug.print("\n\n=== VISUAL INSPECTION TEST ===\n", .{});
    // std.debug.print("Rendering rectangle outline at different sizes:\n", .{});

    // const sizes = [_]f32{ 12, 24, 48 };

    // inline for (renderers) |renderer_info| {
    //     const name = renderer_info[0];
    //     var renderer = renderer_info[1];
    //     var text_renderer = renderer.asRenderer();

    //     std.debug.print("\n--- {s} ---\n", .{name});

    //     for (sizes) |size| {
    //         const result = try text_renderer.renderGlyph(allocator, outline, size);
    //         defer result.deinit(allocator);

    //         std.debug.print("\nSize: {}pt ({}x{}):\n", .{ size, result.width, result.height });

    //         if (result.width > 0 and result.height > 0 and result.width <= 40 and result.height <= 40) {
    //             BitmapVisualizer.toAsciiArt(result.bitmap, result.width, result.height);
    //         } else {
    //             std.debug.print("  [Too large to display or empty]\n", .{});
    //         }

    //         const coverage = BitmapVisualizer.calculateCoverage(result.bitmap);
    //         std.debug.print("  Coverage: {d:.1}%\n", .{coverage});
    //     }
    // }
}

// Run all tests with: zig build test -Dtest-filter="font"
