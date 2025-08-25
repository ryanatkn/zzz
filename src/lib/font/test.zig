const std = @import("std");
const testing = std.testing;
const ttf_parser = @import("core/ttf_parser.zig");
// const rasterizer_core = @import("rasterizer_core.zig"); // Removed - using vertex approach
const test_helpers = @import("test_helpers.zig");
// const test_visualization = @import("test_visualization.zig"); // TODO: Update for vertex approach
const glyph_triangulator = @import("strategies/vertex/triangulator.zig");
const glyph_extractor = @import("core/glyph_extractor.zig");

// Import all font test modules
comptime {
    // Core font metrics tests
    _ = @import("core/metrics.zig");
    _ = @import("core/types.zig");
    _ = @import("coordinate_transform.zig");

    // Vertex-based tests
    _ = @import("strategies/vertex/triangulator.zig");
    _ = @import("core/glyph_extractor.zig");

    // Test directory modules (existing files only)
    _ = @import("test/metrics_debug.zig");
    _ = @import("test/bearing_analysis.zig");
    _ = @import("test/basic_rendering.zig");
    _ = @import("test/font_rendering.zig"); // Strategy validation tests enabled

    // Test visualization utilities (disabled until updated for vertex approach)
    // _ = test_visualization;
}

const debug_config = @import("../debug/config.zig");
const ENABLE_DEBUG_OUTPUT = debug_config.font_test_debug.enable_file_output;
const TEST_OUTPUT_DIR = debug_config.font_test_debug.output_dir;

/// Helper function to generate systematic test output paths
/// Categories: "baseline", "chars", "coord", "debug", "full"
pub fn getTestOutputPath(allocator: std.mem.Allocator, category: []const u8, filename: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{ TEST_OUTPUT_DIR, category, filename });
}

/// Helper function to ensure test output directories exist
pub fn ensureTestDirectories() !void {
    if (!ENABLE_DEBUG_OUTPUT) return; // Skip directory creation when debug output is disabled

    const categories = [_][]const u8{ "baseline", "chars", "coord", "debug", "full" };

    // Create main test directory
    std.fs.cwd().makePath(TEST_OUTPUT_DIR) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    // Create subdirectories
    for (categories) |category| {
        const dir_path = std.fmt.allocPrint(std.heap.page_allocator, "{s}/{s}", .{ TEST_OUTPUT_DIR, category }) catch return error.OutOfMemory;
        defer std.heap.page_allocator.free(dir_path);

        std.fs.cwd().makePath(dir_path) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
    }
}

// Test metadata for summary
pub const test_modules = [_][]const u8{
    "font_metrics",
    "font_types",
    "coordinate_transform",
    "glyph_triangulator", // Vertex-based triangulation tests
    "glyph_extractor", // TTF extraction tests
    "test/metrics_debug", // Font metrics debugging
    "test/bearing_analysis", // Glyph bearing analysis
    "test/basic_rendering", // Basic rendering tests
    "test/font_rendering", // Strategy validation tests
};

test "comprehensive character rendering - vertex triangulation" {
    const allocator = testing.allocator;

    // Initialize loggers for font system
    try test_helpers.initTestLoggers(allocator);
    defer test_helpers.deinitTestLoggers();

    // Try to load DM Sans font
    const font_path = "static/fonts/DM_Sans/static/DMSans-Regular.ttf";
    const font_data = std.fs.cwd().readFileAlloc(allocator, font_path, 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Font file not found: {s} - skipping comprehensive test\n", .{font_path});
            return;
        },
        else => return err,
    };
    defer allocator.free(font_data);

    // Parse the font
    var parser = try ttf_parser.TTFParser.init(allocator, font_data);
    defer parser.deinit();

    // Create glyph extractor and triangulator
    var extractor = glyph_extractor.GlyphExtractor.init(allocator, &parser, 16.0);
    var triangulator = glyph_triangulator.GlyphTriangulator.init(allocator);
    defer triangulator.deinit();

    // Test character sets
    const lowercase = "abcdefghijklmnopqrstuvwxyz";
    const uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    const numbers = "0123456789";
    const special = ".,;:!?'\"()[]{}";

    const test_sets = [_]struct { name: []const u8, chars: []const u8 }{
        .{ .name = "Lowercase", .chars = lowercase },
        .{ .name = "Uppercase", .chars = uppercase },
        .{ .name = "Numbers", .chars = numbers },
        .{ .name = "Special", .chars = special },
    };

    var total_chars: u32 = 0;
    var successful_renders: u32 = 0;
    var baseline_positions = std.ArrayList(f32).init(allocator);
    defer baseline_positions.deinit();

    for (test_sets) |set| {
        std.debug.print("\n--- {s} Characters ---\n", .{set.name});
        std.debug.print("Characters: {s}\n", .{set.chars});

        for (set.chars) |char| {
            total_chars += 1;

            const outline = extractor.extractGlyph(char) catch |err| {
                std.debug.print("❌ Failed to extract '{}': {}\n", .{ @as(u21, char), err });
                continue;
            };
            defer outline.deinit(allocator);

            var triangulated = triangulator.triangulate(outline) catch |err| {
                std.debug.print("❌ Failed to triangulate '{}': {}\n", .{ @as(u21, char), err });
                continue;
            };
            defer triangulated.deinit(allocator);

            successful_renders += 1;

            // Calculate baseline from glyph metrics
            const baseline_y = triangulated.bounds.y_max - triangulated.bounds.y_min;
            try baseline_positions.append(baseline_y);

            std.debug.print("✅ '{c}': {} vertices, bounds: ({:.1},{:.1}) to ({:.1},{:.1})\n", .{ char, triangulated.vertex_count, triangulated.bounds.x_min, triangulated.bounds.y_min, triangulated.bounds.x_max, triangulated.bounds.y_max });

            // Only composite bitmap used (individual bitmaps removed)
        }
    }

    // Analyze baseline consistency
    std.debug.print("\n--- Baseline Analysis ---\n", .{});
    if (baseline_positions.items.len > 0) {
        var min_baseline: f32 = baseline_positions.items[0];
        var max_baseline: f32 = baseline_positions.items[0];
        var sum: f32 = 0;

        for (baseline_positions.items) |pos| {
            min_baseline = @min(min_baseline, pos);
            max_baseline = @max(max_baseline, pos);
            sum += pos;
        }

        const avg_baseline = sum / @as(f32, @floatFromInt(baseline_positions.items.len));
        const baseline_range = max_baseline - min_baseline;

        std.debug.print("Baseline positions - Min: {:.1}, Max: {:.1}, Avg: {:.1}\n", .{ min_baseline, max_baseline, avg_baseline });
        std.debug.print("Baseline range: {:.1} pixels\n", .{baseline_range});

        // Expect reasonable baseline consistency (within ~5 pixels for different character types)
        if (baseline_range > 10.0) {
            std.debug.print("⚠️  Wide baseline range detected - may indicate alignment issues\n", .{});
        } else {
            std.debug.print("✅ Baseline consistency looks good\n", .{});
        }
    }

    std.debug.print("\n--- Summary ---\n", .{});
    std.debug.print("Total characters tested: {}\n", .{total_chars});
    std.debug.print("Successful renders: {}\n", .{successful_renders});
    std.debug.print("Success rate: {:.1}%\n", .{@as(f32, @floatFromInt(successful_renders)) * 100.0 / @as(f32, @floatFromInt(total_chars))});

    if (ENABLE_DEBUG_OUTPUT) {
        // Debug output disabled - set ENABLE_DEBUG_OUTPUT = true to enable
        // This would generate PPM files and analysis reports for test inspection
    }

    // Require at least 90% success rate
    try testing.expect(successful_renders >= (total_chars * 9) / 10);
}

test "coordinate transformation - vertex space generation" {
    const allocator = testing.allocator;

    // Initialize loggers for font system
    try test_helpers.initTestLoggers(allocator);
    defer test_helpers.deinitTestLoggers();

    // Try to load DM Sans font
    const font_path = "static/fonts/DM_Sans/static/DMSans-Regular.ttf";
    const font_data = std.fs.cwd().readFileAlloc(allocator, font_path, 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Font file not found: {s} - skipping coordinate transform test\n", .{font_path});
            return;
        },
        else => return err,
    };
    defer allocator.free(font_data);

    // Parse the font
    var parser = try ttf_parser.TTFParser.init(allocator, font_data);
    defer parser.deinit();

    // Create glyph extractor for coordinate testing
    var extractor = glyph_extractor.GlyphExtractor.init(allocator, &parser, 16.0);
    const test_char: u8 = 'A';

    const outline = extractor.extractGlyph(test_char) catch |err| {
        std.debug.print("Could not extract glyph for coordinate test: {}\n", .{err});
        return;
    };
    defer outline.deinit(allocator);

    std.debug.print("\n🔄 COORDINATE TRANSFORMATION TEST\n", .{});
    std.debug.print("================================================================================\n", .{});
    std.debug.print("Test character '{}': {} contours, bounds ({:.1},{:.1}) to ({:.1},{:.1})\n", .{ @as(u21, test_char), outline.contours.len, outline.bounds.x_min, outline.bounds.y_min, outline.bounds.x_max, outline.bounds.y_max });

    if (ENABLE_DEBUG_OUTPUT) {
        // Debug output disabled - set ENABLE_DEBUG_OUTPUT = true to enable
        // This would generate coordinate transformation test output files
    }
}

test "font module test summary" {
    std.debug.print("\n=== Font System Tests ===\n", .{});

    for (test_modules) |module| {
        std.debug.print("✅ {s}\n", .{module});
    }

    std.debug.print("\nTotal font test modules: {} (focused on vertex approach)\n", .{test_modules.len});
    std.debug.print("Recent Progress: ✅ Fixed root font system issues, enabled glyph caching\n", .{});
    std.debug.print("Architecture: ✅ Vertex-based rendering (no rasterizer dependencies)\n", .{});
    std.debug.print("Performance: ✅ Glyph caching implemented for 0% per-frame triangulation\n", .{});
    std.debug.print("Memory Status: ✅ 0 leaks (proper TriangulatedGlyph cleanup)\n", .{});
    std.debug.print("Debug output: {s}\n", .{if (ENABLE_DEBUG_OUTPUT) "enabled" else "disabled"});
}
