// Simple Buffer-based Text Layout - stub for layout algorithm integration
// Provides basic text measurement without texture dependencies

const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const font_manager = @import("../font/manager.zig");
const font_config = @import("../font/config.zig");
const alignment = @import("alignment.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;

// Re-export alignment types for layout algorithms
pub const TextAlign = alignment.TextAlign;
pub const TextBaseline = alignment.TextBaseline;

/// Simple text measurement for layout purposes
pub const TextMetrics = struct {
    width: f32,
    height: f32,
    baseline: f32,

    pub fn zero() TextMetrics {
        return TextMetrics{
            .width = 0,
            .height = 0,
            .baseline = 0,
        };
    }
};

/// Buffer-based text layout - minimal implementation
pub const TextLayout = struct {
    allocator: std.mem.Allocator,
    font_manager: *font_manager.FontManager,

    pub fn init(allocator: std.mem.Allocator, font_mgr: *font_manager.FontManager) TextLayout {
        return TextLayout{
            .allocator = allocator,
            .font_manager = font_mgr,
        };
    }

    pub fn deinit(self: *TextLayout) void {
        _ = self;
    }

    /// Measure text for layout algorithms
    pub fn measureText(
        self: *TextLayout,
        text: []const u8,
        font_category: font_config.FontCategory,
        font_size: f32,
    ) !TextMetrics {
        const font_id = try self.font_manager.loadFont(font_category, font_size);

        var width: f32 = 0;
        for (text) |char| {
            if (char < 32 or char > 126) {
                if (char == ' ') {
                    width += font_size * 0.5;
                }
                continue;
            }

            if (self.font_manager.getBasicGlyphMetrics(font_id, char)) |metrics| {
                width += @as(f32, @floatFromInt(metrics.advance_width)) * (font_size / 1000.0);
            } else {
                width += font_size * 0.6;
            }
        }

        return TextMetrics{
            .width = width,
            .height = font_size,
            .baseline = font_size * 0.8, // Rough baseline estimate
        };
    }
};

// Legacy API compatibility for layout algorithms
pub fn calculateTextWidth(text: []const u8, font_size: f32) f32 {
    // Simple fallback calculation
    return @as(f32, @floatFromInt(text.len)) * font_size * 0.6;
}

pub fn calculateTextHeight(font_size: f32) f32 {
    return font_size;
}
