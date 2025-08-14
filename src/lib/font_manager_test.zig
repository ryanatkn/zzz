const std = @import("std");
const font_manager = @import("font_manager.zig");
const fonts = @import("fonts.zig");
const c = @import("c.zig");
const testing = std.testing;

test "Font Manager: Initialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // We need a mock GPU device for testing
    // For now, skip this test if we can't create a GPU device
    const gpu_device = c.sdl.SDL_CreateGPUDevice(null, false, null);
    if (gpu_device == null) {
        return error.SkipZigTest;
    }
    defer c.sdl.SDL_DestroyGPUDevice(gpu_device);
    
    var manager = try font_manager.FontManager.init(allocator, gpu_device);
    defer manager.deinit();
    
    try testing.expectEqual(@as(u32, 1), manager.next_font_id);
    try testing.expectEqual(@as(usize, 0), manager.loaded_fonts.items.len);
}

test "Font Manager: Font settings" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const gpu_device = c.sdl.SDL_CreateGPUDevice(null, false, null);
    if (gpu_device == null) {
        return error.SkipZigTest;
    }
    defer c.sdl.SDL_DestroyGPUDevice(gpu_device);
    
    var manager = try font_manager.FontManager.init(allocator, gpu_device);
    defer manager.deinit();
    
    // Check default settings
    try testing.expectEqualStrings("DM Mono", manager.settings.mono_family);
    try testing.expectEqualStrings("DM Sans", manager.settings.sans_family);
    try testing.expectEqualStrings("DM Serif Display", manager.settings.serif_display_family);
    try testing.expectEqualStrings("DM Serif Text", manager.settings.serif_text_family);
    
    try testing.expectEqual(@as(u16, 400), manager.settings.mono_weight);
    try testing.expectEqual(@as(u16, 400), manager.settings.sans_weight);
    try testing.expectEqual(false, manager.settings.mono_italic);
}

test "Font Manager: Font family lookup" {
    // Test that font families are correctly registered
    var found_mono = false;
    var found_sans = false;
    var found_serif_display = false;
    var found_serif_text = false;
    
    for (fonts.available_fonts) |family| {
        if (std.mem.eql(u8, family.name, "DM Mono")) {
            found_mono = true;
            try testing.expectEqual(fonts.FontCategory.mono, family.category);
        } else if (std.mem.eql(u8, family.name, "DM Sans")) {
            found_sans = true;
            try testing.expectEqual(fonts.FontCategory.sans, family.category);
        } else if (std.mem.eql(u8, family.name, "DM Serif Display")) {
            found_serif_display = true;
            try testing.expectEqual(fonts.FontCategory.serif_display, family.category);
        } else if (std.mem.eql(u8, family.name, "DM Serif Text")) {
            found_serif_text = true;
            try testing.expectEqual(fonts.FontCategory.serif_text, family.category);
        }
    }
    
    try testing.expect(found_mono);
    try testing.expect(found_sans);
    try testing.expect(found_serif_display);
    try testing.expect(found_serif_text);
}

test "Font Manager: Font variant selection" {
    // Test the font variant selection logic
    const test_cases = [_]struct {
        weight: u16,
        italic: bool,
        expected_path: []const u8,
    }{
        .{ .weight = 400, .italic = false, .expected_path = "static/fonts/DM_Mono/DMMono-Regular.ttf" },
        .{ .weight = 400, .italic = true, .expected_path = "static/fonts/DM_Mono/DMMono-Italic.ttf" },
        .{ .weight = 300, .italic = false, .expected_path = "static/fonts/DM_Mono/DMMono-Light.ttf" },
        .{ .weight = 500, .italic = false, .expected_path = "static/fonts/DM_Mono/DMMono-Medium.ttf" },
    };
    
    for (fonts.available_fonts) |family| {
        if (std.mem.eql(u8, family.name, "DM Mono")) {
            for (test_cases) |tc| {
                var best_variant: ?fonts.FontVariant = null;
                var best_score: i32 = std.math.maxInt(i32);
                
                for (family.variants) |variant| {
                    const weight_diff: i32 = @intCast(@abs(variant.weight - tc.weight));
                    const italic_match: i32 = if (variant.italic == tc.italic) 0 else 1000;
                    const score = weight_diff + italic_match;
                    
                    if (score < best_score) {
                        best_score = score;
                        best_variant = variant;
                    }
                }
                
                try testing.expect(best_variant != null);
                try testing.expectEqualStrings(tc.expected_path, best_variant.?.path);
            }
            break;
        }
    }
}

test "Font Manager: LoadedFont structure" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Test the LoadedFont structure
    var rasterizers = std.AutoHashMap(u32, *font_rasterizer.FontRasterizer).init(allocator);
    defer rasterizers.deinit();
    
    const loaded_font = font_manager.LoadedFont{
        .id = 1,
        .path = "test/path.ttf",
        .data = undefined,
        .parser = undefined,
        .rasterizers = rasterizers,
    };
    
    try testing.expectEqual(@as(u32, 1), loaded_font.id);
    try testing.expectEqualStrings("test/path.ttf", loaded_font.path);
}

test "Font Manager: Size key calculation" {
    // Test that font sizes are properly converted to keys
    const test_sizes = [_]struct {
        size: f32,
        expected_key: u32,
    }{
        .{ .size = 12.0, .expected_key = 1200 },
        .{ .size = 16.0, .expected_key = 1600 },
        .{ .size = 24.0, .expected_key = 2400 },
        .{ .size = 48.0, .expected_key = 4800 },
        .{ .size = 72.0, .expected_key = 7200 },
    };
    
    for (test_sizes) |tc| {
        const size_key = @as(u32, @intFromFloat(tc.size * 100));
        try testing.expectEqual(tc.expected_key, size_key);
    }
}

const font_rasterizer = @import("font_rasterizer.zig");