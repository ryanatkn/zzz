const std = @import("std");
const math = @import("../math/mod.zig");
const reactive = @import("../reactive/mod.zig");
const text_renderer = @import("../text/renderer.zig");
const rendering_modes = @import("../rendering/modes.zig");
const TextDisplayStyle = @import("text_display_style.zig").TextDisplayStyle;

const Vec2 = math.Vec2;

/// Core non-interactive text display component
/// For interactive navigation, use Link; for interactive actions, use Button
pub const TextDisplay = struct {
    // Reactive state
    text: reactive.Signal([]const u8),
    position: reactive.Signal(Vec2),
    visible: reactive.Signal(bool),

    // Style properties
    style: TextDisplayStyle,

    // Rendering optimization
    rendering_mode: rendering_modes.RenderingMode,

    // Memory management
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, text: []const u8, position: Vec2, style: TextDisplayStyle) !Self {
        // Estimate change frequency based on text characteristics
        const change_frequency = estimateChangeFrequency(text);
        const mode_profile = rendering_modes.recommendModeByRate(change_frequency);

        return Self{
            .text = try reactive.signal(allocator, []const u8, text),
            .position = try reactive.signal(allocator, Vec2, position),
            .visible = try reactive.signal(allocator, bool, true),
            .style = style,
            .rendering_mode = mode_profile.recommended_mode,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.text.deinit();
        self.position.deinit();
        self.visible.deinit();
    }

    /// Set the text content (triggers re-render if changed)
    pub fn setText(self: *Self, new_text: []const u8) void {
        self.text.set(new_text);

        // Update rendering mode based on new text characteristics
        const change_frequency = estimateChangeFrequency(new_text);
        const mode_profile = rendering_modes.recommendModeByRate(change_frequency);
        self.rendering_mode = mode_profile.recommended_mode;
    }

    /// Get current text (reactive - tracks dependency)
    pub fn getText(self: *Self) []const u8 {
        return self.text.get();
    }

    /// Peek at text without creating reactive dependency
    pub fn peekText(self: *const Self) []const u8 {
        return self.text.peek();
    }

    /// Set text position
    pub fn setPosition(self: *Self, new_position: Vec2) void {
        self.position.set(new_position);
    }

    /// Get current position (reactive)
    pub fn getPosition(self: *Self) Vec2 {
        return self.position.get();
    }

    /// Peek at position without reactive tracking
    pub fn peekPosition(self: *const Self) Vec2 {
        return self.position.peek();
    }

    /// Set visibility
    pub fn setVisible(self: *Self, visible: bool) void {
        self.visible.set(visible);
    }

    /// Check if visible (reactive)
    pub fn isVisible(self: *Self) bool {
        return self.visible.get();
    }

    /// Peek at visibility without reactive tracking
    pub fn peekVisible(self: *const Self) bool {
        return self.visible.peek();
    }

    /// Update the display style
    pub fn setStyle(self: *Self, new_style: TextDisplayStyle) void {
        self.style = new_style;
    }

    /// Get estimated text dimensions
    pub fn getEstimatedSize(self: *const Self) Vec2 {
        const text_content = self.text.peek();
        const estimated_width = @as(f32, @floatFromInt(text_content.len)) * self.style.font_size * 0.6;
        return self.style.getRequiredSize(estimated_width);
    }

    /// Render the text display
    pub fn render(self: *Self, renderer: *text_renderer.TextRenderer, font_manager: anytype, font_category: anytype) !void {
        if (!self.peekVisible()) return;

        const current_text = self.getText(); // Reactive access
        const base_position = self.getPosition(); // Reactive access

        // Calculate actual text position based on alignment
        const estimated_text_width = @as(f32, @floatFromInt(current_text.len)) * self.style.font_size * 0.6;
        const container_width = self.getEstimatedSize().x;
        const text_position = self.style.getTextPosition(base_position, estimated_text_width, container_width);

        // Render background if specified
        if (self.style.background_color) |bg_color| {
            const size = self.getEstimatedSize();
            // Background rendering would go here if renderer supports it
            _ = bg_color;
            _ = size;
        }

        // Render text based on mode
        switch (self.rendering_mode) {
            .immediate => {
                // Use immediate mode for frequently changing content
                const text_result = font_manager.renderTextToTexture(current_text, font_category, self.style.font_size, self.style.color, renderer.device) catch |err| {
                    std.log.err("Failed to render immediate text display: {}", .{err});
                    return;
                };

                renderer.queueTextTexture(text_result.texture, text_position, text_result.width, text_result.height, self.style.color);
            },
            .persistent => {
                // Use persistent mode for stable content
                try renderer.queuePersistentText(current_text, text_position, font_manager, font_category, self.style.font_size, self.style.color);
            },
        }
    }

    /// Check if a point is within the text display bounds (for debugging/testing)
    /// Note: TextDisplay is non-interactive, so this is primarily for development
    pub fn containsPoint(self: *const Self, point: Vec2) bool {
        const pos = self.peekPosition();
        const size = self.getEstimatedSize();

        return point.x >= pos.x and
            point.x <= pos.x + size.x and
            point.y >= pos.y and
            point.y <= pos.y + size.y;
    }
};

/// Estimate how frequently a text display's content might change based on content
fn estimateChangeFrequency(text: []const u8) f32 {
    // Static text patterns
    if (std.mem.indexOf(u8, text, "FPS:") != null) return 60.0; // FPS counter
    if (std.mem.indexOf(u8, text, "Score:") != null) return 10.0; // Game score
    if (std.mem.indexOf(u8, text, "Time:") != null) return 1.0; // Timer
    if (std.mem.indexOf(u8, text, "Level") != null) return 0.1; // Level indicator

    // Default for most text displays - static or infrequent changes
    return 0.5;
}

// Tests
test "text display core functionality" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const reactive_mod = @import("../reactive/mod.zig");
    try reactive_mod.init(allocator);
    defer reactive_mod.deinit(allocator);

    // Create a text display
    var display = try TextDisplay.init(allocator, "Test Display", Vec2{ .x = 10, .y = 20 }, TextDisplayStyle.Presets.default);
    defer display.deinit();

    // Test initial state
    try testing.expect(std.mem.eql(u8, display.peekText(), "Test Display"));
    try testing.expectEqual(Vec2{ .x = 10, .y = 20 }, display.peekPosition());
    try testing.expect(display.peekVisible());

    // Test text change
    display.setText("New Text");
    try testing.expect(std.mem.eql(u8, display.peekText(), "New Text"));

    // Test position change
    const new_pos = Vec2{ .x = 30, .y = 40 };
    display.setPosition(new_pos);
    try testing.expectEqual(new_pos, display.peekPosition());

    // Test visibility toggle
    display.setVisible(false);
    try testing.expect(!display.peekVisible());

    display.setVisible(true);
    try testing.expect(display.peekVisible());
}

test "change frequency estimation" {
    const testing = std.testing;

    // FPS counter should have high frequency
    try testing.expect(estimateChangeFrequency("FPS: 60") > 50.0);

    // Static text should have low frequency
    try testing.expect(estimateChangeFrequency("Settings") < 1.0);

    // Game elements should have moderate frequency
    const score_freq = estimateChangeFrequency("Score: 1000");
    try testing.expect(score_freq > 1.0 and score_freq < 20.0);
}

test "bounds checking" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const reactive_mod = @import("../reactive/mod.zig");
    try reactive_mod.init(allocator);
    defer reactive_mod.deinit(allocator);

    var display = try TextDisplay.init(allocator, "Test", Vec2{ .x = 10, .y = 20 }, TextDisplayStyle.Presets.default);
    defer display.deinit();

    // Test point containment
    try testing.expect(display.containsPoint(Vec2{ .x = 15, .y = 25 })); // Inside
    try testing.expect(!display.containsPoint(Vec2{ .x = 100, .y = 200 })); // Outside
}
