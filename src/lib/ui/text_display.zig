/// TextDisplay component system - clean barrel imports
/// Provides non-interactive text display with reactive updates
/// For interactive navigation, use Link; for interactive actions, use Button

// Core implementation
pub const TextDisplay = @import("text_display_core.zig").TextDisplay;

// Style system
pub const TextDisplayStyle = @import("text_display_style.zig").TextDisplayStyle;
pub const TextAlignment = @import("text_display_style.zig").TextAlignment;

// Factory functions (re-exported for convenience)
pub const createTextDisplay = @import("text_display_factory.zig").createTextDisplay;
pub const createTitle = @import("text_display_factory.zig").createTitle;
pub const createSubtitle = @import("text_display_factory.zig").createSubtitle;
pub const createSmallText = @import("text_display_factory.zig").createSmallText;
pub const createErrorText = @import("text_display_factory.zig").createErrorText;
pub const createSuccessText = @import("text_display_factory.zig").createSuccessText;
pub const createWarningText = @import("text_display_factory.zig").createWarningText;
pub const createTextWithSize = @import("text_display_factory.zig").createTextWithSize;
pub const createTextWithColor = @import("text_display_factory.zig").createTextWithColor;
pub const createTextCustom = @import("text_display_factory.zig").createTextCustom;
pub const createCenteredText = @import("text_display_factory.zig").createCenteredText;

// Tests to ensure all modules work together
test "text display system integration" {
    const std = @import("std");
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const reactive = @import("../reactive/mod.zig");
    try reactive.init(allocator);
    defer reactive.deinit(allocator);

    const Vec2 = @import("../math/mod.zig").Vec2;
    const pos = Vec2{ .x = 10, .y = 20 };

    // Test core functionality
    var display = try TextDisplay.init(allocator, "Test", pos, TextDisplayStyle.Presets.default);
    defer display.deinit();

    // Test factory function
    var factory_display = try createTitle(allocator, "Factory Test", pos);
    defer factory_display.deinit();

    // Verify integration
    try testing.expect(std.mem.eql(u8, display.peekText(), "Test"));
    try testing.expect(std.mem.eql(u8, factory_display.peekText(), "Factory Test"));
    try testing.expect(factory_display.style.font_size > display.style.font_size); // Title should be larger
}
