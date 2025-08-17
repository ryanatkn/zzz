const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const text_renderer = @import("../text/renderer.zig");
const font_manager = @import("../font/manager.zig");
const drawing = @import("../rendering/drawing.zig");
const font_config = @import("../font/config.zig");
const loggers = @import("../debug/loggers.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const Rectangle = drawing.Rectangle;

/// Standard menu text configurations using dynamic font config
pub const MenuTextStyles = struct {
    pub const button = struct {
        pub fn font_size() f32 {
            return font_config.getGlobalConfig().buttonFontSize();
        }
        pub const normal_color = Color{ .r = 200, .g = 200, .b = 200, .a = 255 };
        pub const hovered_color = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
        pub fn char_width() f32 {
            return font_config.getGlobalConfig().buttonCharWidth();
        }
    };

    pub const navigation = struct {
        pub fn font_size() f32 {
            return font_config.getGlobalConfig().navigationFontSize();
        }
        pub const color = Color{ .r = 180, .g = 190, .b = 200, .a = 255 };
        pub fn char_width() f32 {
            return font_config.getGlobalConfig().navigationCharWidth();
        }
    };

    pub const header = struct {
        pub fn font_size() f32 {
            return font_config.getGlobalConfig().headerFontSize();
        }
        pub const color = Color{ .r = 230, .g = 230, .b = 230, .a = 255 };
        pub fn char_width() f32 {
            return font_config.getGlobalConfig().headerCharWidth();
        }
    };
};

/// Menu text utility for consistent text rendering in UI elements
pub const MenuTextRenderer = struct {
    text_renderer: *text_renderer.TextRenderer,
    font_manager: *font_manager.FontManager,

    const Self = @This();

    pub fn init(renderer: *text_renderer.TextRenderer, fm: *font_manager.FontManager) Self {
        return Self{
            .text_renderer = renderer,
            .font_manager = fm,
        };
    }

    /// Queue button text centered within a rectangle
    pub fn queueButtonText(self: *Self, text: []const u8, rect: Rectangle, is_hovered: bool) void {
        self.queueAlignedButtonText(text, rect, is_hovered, .center);
    }

    /// Queue button text with specified alignment
    pub fn queueAlignedButtonText(self: *Self, text: []const u8, rect: Rectangle, is_hovered: bool, alignment: enum { left, center, right }) void {
        // Skip empty text to prevent crashes
        if (text.len == 0) {
            loggers.getUILog().debug("empty_button", "Skipping empty button text", .{});
            return;
        }

        const style = MenuTextStyles.button;
        const text_color = if (is_hovered) style.hovered_color else style.normal_color;

        const text_pos = switch (alignment) {
            .center => drawing.getCenteredTextPos(rect, text, style.char_width(), style.font_size()),
            .left => drawing.getLeftAlignedTextPos(rect, text, style.char_width(), style.font_size(), 8.0), // 8px padding
            .right => drawing.getRightAlignedTextPos(rect, text, style.char_width(), style.font_size(), 8.0), // 8px padding
        };

        // Debug logging disabled to reduce spam
        // loggers.getUILog().debug("queue_button", "Queueing button text: '{s}' at ({d:.1}, {d:.1}) size {d:.1}x{d:.1}", .{ text, text_pos.x, text_pos.y, rect.size.x, rect.size.y });

        self.text_renderer.queuePersistentText(text, text_pos, self.font_manager, .sans, style.font_size(), text_color) catch |err| {
            loggers.getUILog().err("button_error", "Failed to queue button text '{s}': {}", .{ text, err });
        };
    }

    /// Queue navigation text (like address bar path)
    pub fn queueNavigationText(self: *Self, text: []const u8, position: Vec2) void {
        // Skip empty text to prevent crashes
        if (text.len == 0) {
            loggers.getUILog().debug("empty_nav", "Skipping empty navigation text", .{});
            return;
        }

        const style = MenuTextStyles.navigation;

        // Debug logging disabled to reduce spam

        self.text_renderer.queuePersistentText(text, position, self.font_manager, .sans, style.font_size(), style.color) catch |err| {
            loggers.getUILog().err("nav_error", "Failed to queue navigation text '{s}': {}", .{ text, err });
        };
    }

    /// Queue header text centered within a rectangle
    pub fn queueHeaderText(self: *Self, text: []const u8, rect: Rectangle) void {
        const style = MenuTextStyles.header;

        const text_pos = drawing.getCenteredTextPos(rect, text, style.char_width(), style.font_size());

        self.text_renderer.queuePersistentText(text, text_pos, self.font_manager, .sans, style.font_size(), style.color) catch |err| {
            loggers.getUILog().err("header_error", "Failed to queue header text '{s}': {}", .{ text, err });
        };
    }

    /// Queue text at a specific position with custom style
    pub fn queueCustomText(self: *Self, text: []const u8, position: Vec2, font_size: f32, color: Color) void {
        self.text_renderer.queuePersistentText(text, position, self.font_manager, .sans, font_size, color) catch |err| {
            loggers.getUILog().err("custom_error", "Failed to queue custom text '{s}': {}", .{ text, err });
        };
    }
};

/// Helper functions for text sizing and positioning
pub const TextUtils = struct {
    /// Estimate text width for a given font size
    pub fn estimateTextWidth(text: []const u8, char_width: f32) f32 {
        return @as(f32, @floatFromInt(text.len)) * char_width;
    }

    /// Get button rectangle that fits text with standard padding
    pub fn getButtonRectForText(text: []const u8, position: Vec2) Rectangle {
        const char_width = font_config.getGlobalConfig().buttonCharWidth();
        const text_width = estimateTextWidth(text, char_width);
        return drawing.Sizes.button(position, text_width);
    }

    /// Check if text fits within a given width
    pub fn textFitsWidth(text: []const u8, width: f32, char_width: f32) bool {
        return estimateTextWidth(text, char_width) <= width;
    }

    /// Truncate text to fit within a given width (adds "..." if truncated)
    pub fn truncateTextToFit(allocator: std.mem.Allocator, text: []const u8, width: f32, char_width: f32) ![]const u8 {
        if (textFitsWidth(text, width, char_width)) {
            return text; // Return original if it fits
        }

        const ellipsis = "...";
        const ellipsis_width = estimateTextWidth(ellipsis, char_width);
        const available_width = width - ellipsis_width;

        if (available_width <= 0) {
            return ellipsis; // Can't fit anything, just return ellipsis
        }

        const max_chars = @as(usize, @intFromFloat(available_width / char_width));
        if (max_chars == 0) {
            return ellipsis;
        }

        const truncated_text = text[0..@min(max_chars, text.len)];
        return try std.fmt.allocPrint(allocator, "{s}{s}", .{ truncated_text, ellipsis });
    }
};

/// Performance analysis for menu text rendering
pub const PerformanceAnalysis = struct {
    /// Menu text is ideal for persistent mode:
    /// - Static content that rarely changes
    /// - High reuse potential (same buttons, labels)
    /// - Predictable memory usage
    pub const recommended_mode = "persistent";

    /// Expected cache hit rate for menu text
    /// Most menu text is static, leading to excellent cache efficiency
    pub const expected_cache_hit_rate = 0.90;

    /// Memory usage per text element
    /// Typical button text ~= width*height*4 bytes (RGBA)
    /// Average button "Settings" at 16pt ~= 80x16 pixels = 5KB
    pub const estimated_memory_per_button = 5 * 1024;
};
