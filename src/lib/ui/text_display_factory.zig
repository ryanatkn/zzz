const std = @import("std");
const TextDisplay = @import("text_display_core.zig").TextDisplay;
const TextDisplayStyle = @import("text_display_style.zig").TextDisplayStyle;
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;

/// Factory functions for creating common text display types
/// Create a basic text display with default styling
pub fn createTextDisplay(allocator: std.mem.Allocator, text: []const u8, position: Vec2) !TextDisplay {
    return TextDisplay.init(allocator, text, position, TextDisplayStyle.Presets.default);
}

/// Create a title text display with larger font and center alignment
pub fn createTitle(allocator: std.mem.Allocator, text: []const u8, position: Vec2) !TextDisplay {
    return TextDisplay.init(allocator, text, position, TextDisplayStyle.Presets.title);
}

/// Create a subtitle text display
pub fn createSubtitle(allocator: std.mem.Allocator, text: []const u8, position: Vec2) !TextDisplay {
    return TextDisplay.init(allocator, text, position, TextDisplayStyle.Presets.subtitle);
}

/// Create a small text display for secondary information
pub fn createSmallText(allocator: std.mem.Allocator, text: []const u8, position: Vec2) !TextDisplay {
    return TextDisplay.init(allocator, text, position, TextDisplayStyle.Presets.small);
}

/// Create an error message text display
pub fn createErrorText(allocator: std.mem.Allocator, text: []const u8, position: Vec2) !TextDisplay {
    return TextDisplay.init(allocator, text, position, TextDisplayStyle.Presets.error_text);
}

/// Create a success message text display
pub fn createSuccessText(allocator: std.mem.Allocator, text: []const u8, position: Vec2) !TextDisplay {
    return TextDisplay.init(allocator, text, position, TextDisplayStyle.Presets.success_text);
}

/// Create a warning message text display
pub fn createWarningText(allocator: std.mem.Allocator, text: []const u8, position: Vec2) !TextDisplay {
    return TextDisplay.init(allocator, text, position, TextDisplayStyle.Presets.warning_text);
}

/// Create a text display with custom font size
pub fn createTextWithSize(allocator: std.mem.Allocator, text: []const u8, position: Vec2, font_size: f32) !TextDisplay {
    var style = TextDisplayStyle.Presets.default;
    style.font_size = font_size;
    return TextDisplay.init(allocator, text, position, style);
}

/// Create a text display with custom color
pub fn createTextWithColor(allocator: std.mem.Allocator, text: []const u8, position: Vec2, color: Color) !TextDisplay {
    var style = TextDisplayStyle.Presets.default;
    style.color = color;
    return TextDisplay.init(allocator, text, position, style);
}

/// Create a fully customized text display
pub fn createTextCustom(allocator: std.mem.Allocator, text: []const u8, position: Vec2, style: TextDisplayStyle) !TextDisplay {
    return TextDisplay.init(allocator, text, position, style);
}

/// Create a centered text display within a container
pub fn createCenteredText(allocator: std.mem.Allocator, text: []const u8, container_center: Vec2, font_size: f32) !TextDisplay {
    var style = TextDisplayStyle.Presets.default;
    style.font_size = font_size;
    style.alignment = .center;

    // Position is the center point - the text display will calculate alignment internally
    return TextDisplay.init(allocator, text, container_center, style);
}

// Tests
test "text display factory functions" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const reactive = @import("../reactive/mod.zig");
    try reactive.init(allocator);
    defer reactive.deinit(allocator);

    const pos = Vec2{ .x = 0, .y = 0 };

    // Test basic factory functions
    var basic_display = try createTextDisplay(allocator, "Basic", pos);
    defer basic_display.deinit();

    var title_display = try createTitle(allocator, "Title", pos);
    defer title_display.deinit();

    var error_display = try createErrorText(allocator, "Error", pos);
    defer error_display.deinit();

    // Test customization functions
    var sized_display = try createTextWithSize(allocator, "Sized", pos, 20.0);
    defer sized_display.deinit();

    const blue = Color{ .r = 0, .g = 0, .b = 255, .a = 255 };
    var colored_display = try createTextWithColor(allocator, "Colored", pos, blue);
    defer colored_display.deinit();

    // Verify some properties
    try testing.expect(title_display.style.font_size > basic_display.style.font_size);
    try testing.expectEqual(@as(f32, 20.0), sized_display.style.font_size);
    try testing.expectEqual(blue, colored_display.style.color);
}
