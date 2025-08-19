/// Font coordinate transformation utilities
/// Provides shader-matching coordinate transformations for testing bitmap output in final coordinate space
const std = @import("std");
const core_coordinates = @import("../core/coordinates.zig");
const Vec2 = @import("../math/vec2.zig").Vec2;

// ========================
// SHADER-MATCHING COORDINATE TRANSFORMATIONS
// ========================

/// Transform screen coordinates to NDC (Normalized Device Coordinates)
/// Uses the proven core coordinate utilities to ensure consistency across the engine
pub fn screenToNDC(screen_x: f32, screen_y: f32, screen_width: f32, screen_height: f32) Vec2 {
    const context = core_coordinates.CoordinateContext.init(screen_width, screen_height);
    return core_coordinates.screenToNDC(Vec2{ .x = screen_x, .y = screen_y }, context);
}

/// Transform NDC coordinates back to screen coordinates  
/// Uses the proven core coordinate utilities for consistency
pub fn ndcToScreen(ndc_x: f32, ndc_y: f32, screen_width: f32, screen_height: f32) Vec2 {
    const context = core_coordinates.CoordinateContext.init(screen_width, screen_height);
    return core_coordinates.ndcToScreen(Vec2{ .x = ndc_x, .y = ndc_y }, context);
}

/// Transform bitmap pixel coordinates to shader coordinate space
/// This allows testing bitmap data in the same coordinate space as final rendering
/// FIXED: Now uses proper font-aware scaling instead of stretching across entire screen
pub fn bitmapToShaderSpace(
    bitmap_x: u32,
    bitmap_y: u32,
    bitmap_width: u32,
    bitmap_height: u32,
    target_screen_width: f32,
    target_screen_height: f32,
) struct { screen: Vec2, ndc: Vec2 } {
    // FIXED: Use font-appropriate scaling instead of stretching bitmap across entire screen
    // For fonts, we want to maintain realistic pixel-to-pixel correspondence
    
    // Note: bitmap_width and bitmap_height are not needed for this fixed scaling approach
    // but are kept for API compatibility
    _ = bitmap_width;
    _ = bitmap_height;
    
    // Scale factor: how much to scale the font for reasonable visibility (adjustable)
    const font_display_scale: f32 = 4.0; // Make font 4x larger for easier visibility
    
    // Position the scaled font in a reasonable screen location (center-left area)
    const base_screen_x: f32 = target_screen_width * 0.25; // 25% from left edge
    const base_screen_y: f32 = target_screen_height * 0.4;  // 40% from top edge
    
    // Convert bitmap coordinates to screen space using realistic scaling
    const screen_x = base_screen_x + (@as(f32, @floatFromInt(bitmap_x)) * font_display_scale);
    const screen_y = base_screen_y + (@as(f32, @floatFromInt(bitmap_y)) * font_display_scale);

    // Create screen position vector
    const screen_pos = Vec2{ .x = screen_x, .y = screen_y };

    // Convert to NDC using core coordinate utilities
    const ndc_pos = screenToNDC(screen_x, screen_y, target_screen_width, target_screen_height);

    return .{
        .screen = screen_pos,
        .ndc = ndc_pos,
    };
}

// ========================
// BITMAP COORDINATE TRANSFORMATION
// ========================

/// Transform bitmap data to match shader coordinate system for visual verification
pub const BitmapTransform = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) BitmapTransform {
        return .{ .allocator = allocator };
    }

    /// Create transformed bitmap that shows post-shader coordinate space (NDC with Y-flip)
    /// 
    /// IMPORTANT: This does NOT show what's sent to the GPU. The GPU receives normal readable 
    /// bitmap textures. The Y-flip transformation happens IN THE VERTEX SHADER during NDC conversion.
    /// 
    /// This visualization shows what the coordinate space looks like AFTER shader transformation,
    /// which is useful for debugging coordinate-related rendering issues.
    pub fn createTransformedBitmap(
        self: *BitmapTransform,
        original_bitmap: []const u8,
        original_width: u32,
        original_height: u32,
        target_screen_width: f32,
        target_screen_height: f32,
        output_width: u32,
        output_height: u32,
    ) ![]u8 {
        _ = target_screen_width;
        _ = target_screen_height;
        
        const transformed_bitmap = try self.allocator.alloc(u8, output_width * output_height);
        @memset(transformed_bitmap, 0);

        // Apply Y-flip transformation to visualize post-shader NDC coordinate space
        // The Y-flip happens in the vertex shader, not in the input texture data
        for (0..output_height) |y| {
            for (0..output_width) |x| {
                // Map output coordinates to source bitmap coordinates
                const src_x = (x * original_width) / output_width;
                const src_y_flipped = ((output_height - 1 - y) * original_height) / output_height; // Y-flip

                // Bounds check
                if (src_x < original_width and src_y_flipped < original_height) {
                    const src_idx = src_y_flipped * original_width + src_x;
                    const dst_idx = y * output_width + x;

                    if (src_idx < original_bitmap.len and dst_idx < transformed_bitmap.len) {
                        transformed_bitmap[dst_idx] = original_bitmap[src_idx];
                    }
                }
            }
        }

        return transformed_bitmap;
    }
};

// ========================
// COORDINATE DEBUGGING UTILITIES
// ========================

/// Debug information for coordinate transformations
pub const CoordinateDebugInfo = struct {
    screen_x: f32,
    screen_y: f32,
    ndc_x: f32,
    ndc_y: f32,
    back_to_screen_x: f32,
    back_to_screen_y: f32,
    transformation_error: f32,
};

/// Generate debug information for coordinate transformation accuracy
pub fn generateDebugInfo(
    screen_x: f32,
    screen_y: f32,
    screen_width: f32,
    screen_height: f32,
) CoordinateDebugInfo {
    const ndc = screenToNDC(screen_x, screen_y, screen_width, screen_height);
    const back_to_screen = ndcToScreen(ndc.x, ndc.y, screen_width, screen_height);

    const error_x = back_to_screen.x - screen_x;
    const error_y = back_to_screen.y - screen_y;
    const transformation_error = @sqrt(error_x * error_x + error_y * error_y);

    return .{
        .screen_x = screen_x,
        .screen_y = screen_y,
        .ndc_x = ndc.x,
        .ndc_y = ndc.y,
        .back_to_screen_x = back_to_screen.x,
        .back_to_screen_y = back_to_screen.y,
        .transformation_error = transformation_error,
    };
}

/// Print coordinate debug information
pub fn printDebugInfo(debug_info: CoordinateDebugInfo) void {
    std.debug.print("🔍 Coordinate Debug Info:\n", .{});
    std.debug.print("  Screen: ({d:.2}, {d:.2})\n", .{ debug_info.screen_x, debug_info.screen_y });
    std.debug.print("  NDC: ({d:.6}, {d:.6})\n", .{ debug_info.ndc_x, debug_info.ndc_y });
    std.debug.print("  Back to Screen: ({d:.2}, {d:.2})\n", .{ debug_info.back_to_screen_x, debug_info.back_to_screen_y });
    std.debug.print("  Transformation Error: {d:.6}\n", .{debug_info.transformation_error});
}

// ========================
// TESTS
// ========================

test "shader coordinate transformation accuracy" {
    // Test common screen resolutions
    const test_cases = [_]struct { width: f32, height: f32 }{
        .{ .width = 1920, .height = 1080 },
        .{ .width = 1280, .height = 720 },
        .{ .width = 800, .height = 600 },
    };

    for (test_cases) |case| {
        // Test center of screen
        const center_x = case.width / 2.0;
        const center_y = case.height / 2.0;

        const ndc = screenToNDC(center_x, center_y, case.width, case.height);
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), ndc.x, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), ndc.y, 0.001);

        // Test corners
        const top_left_ndc = screenToNDC(0, 0, case.width, case.height);
        try std.testing.expectApproxEqAbs(@as(f32, -1.0), top_left_ndc.x, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 1.0), top_left_ndc.y, 0.001);

        const bottom_right_ndc = screenToNDC(case.width, case.height, case.width, case.height);
        try std.testing.expectApproxEqAbs(@as(f32, 1.0), bottom_right_ndc.x, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, -1.0), bottom_right_ndc.y, 0.001);
    }
}

test "coordinate transformation round-trip accuracy" {
    const screen_width: f32 = 1920;
    const screen_height: f32 = 1080;

    // Test various points
    const test_points = [_]struct { x: f32, y: f32 }{
        .{ .x = 0, .y = 0 },
        .{ .x = 960, .y = 540 }, // Center
        .{ .x = 1920, .y = 1080 }, // Bottom right
        .{ .x = 100, .y = 200 },
        .{ .x = 1800, .y = 900 },
    };

    for (test_points) |point| {
        const debug_info = generateDebugInfo(point.x, point.y, screen_width, screen_height);

        // Round-trip error should be minimal (less than 0.001 pixels)
        try std.testing.expect(debug_info.transformation_error < 0.001);
    }
}

test "bitmap coordinate space transformation" {
    const allocator = std.testing.allocator;
    var bitmap_transform = BitmapTransform.init(allocator);

    // Create simple test bitmap (4x4)
    const original_bitmap = [_]u8{
        255, 128, 64,  32,
        200, 150, 100, 50,
        180, 120, 80,  40,
        160, 100, 60,  20,
    };

    const transformed = try bitmap_transform.createTransformedBitmap(
        &original_bitmap,
        4, // original_width
        4, // original_height
        800, // target_screen_width
        600, // target_screen_height
        4, // output_width
        4, // output_height
    );
    defer allocator.free(transformed);

    // Verify transformation produced valid output
    try std.testing.expect(transformed.len == 16);

    // At minimum, should have some non-zero values
    var has_non_zero = false;
    for (transformed) |pixel| {
        if (pixel > 0) {
            has_non_zero = true;
            break;
        }
    }
    try std.testing.expect(has_non_zero);
}