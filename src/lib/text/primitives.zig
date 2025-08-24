// Simple Buffer-based Text Primitives - pure GPU rendering without textures
// Provides basic text rendering capabilities using buffer approach

const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const font_manager = @import("../font/manager.zig");
const font_config = @import("../font/config.zig");
const loggers = @import("../debug/loggers.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;

/// Simple text measurement utilities for buffer-based rendering
pub const TextMeasurement = struct {
    width: f32,
    height: f32,

    pub fn zero() TextMeasurement {
        return TextMeasurement{ .width = 0, .height = 0 };
    }
};

/// Buffer-based text primitives - no texture dependencies
pub const BufferTextPrimitives = struct {
    allocator: std.mem.Allocator,
    font_manager: *font_manager.FontManager,

    pub fn init(allocator: std.mem.Allocator, font_mgr: *font_manager.FontManager) BufferTextPrimitives {
        return BufferTextPrimitives{
            .allocator = allocator,
            .font_manager = font_mgr,
        };
    }

    pub fn deinit(self: *BufferTextPrimitives) void {
        _ = self; // No resources to clean up
    }

    /// Measure text dimensions for layout purposes
    pub fn measureText(
        self: *BufferTextPrimitives,
        text: []const u8,
        font_category: font_config.FontCategory,
        font_size: f32,
    ) !TextMeasurement {
        const font_id = try self.font_manager.loadFont(font_category, font_size);

        var width: f32 = 0;
        for (text) |char| {
            if (char < 32 or char > 126) {
                if (char == ' ') {
                    width += font_size * 0.5; // Space width
                }
                continue;
            }

            if (self.font_manager.getBasicGlyphMetrics(font_id, char)) |metrics| {
                width += @as(f32, @floatFromInt(metrics.advance_width)) * (font_size / 1000.0);
            } else {
                width += font_size * 0.6; // Fallback character width
            }
        }

        return TextMeasurement{
            .width = width,
            .height = font_size, // Simple height calculation
        };
    }

    /// Check if text fits within given dimensions
    pub fn textFits(
        self: *BufferTextPrimitives,
        text: []const u8,
        max_size: Vec2,
        font_category: font_config.FontCategory,
        font_size: f32,
    ) !bool {
        const measurement = try self.measureText(text, font_category, font_size);
        return measurement.width <= max_size.x and measurement.height <= max_size.y;
    }

    /// Calculate recommended font size to fit text in given area
    pub fn getFittingFontSize(
        self: *BufferTextPrimitives,
        text: []const u8,
        max_size: Vec2,
        font_category: font_config.FontCategory,
        min_size: f32,
        max_size_font: f32,
    ) !f32 {
        var font_size = max_size_font;

        while (font_size >= min_size) {
            if (try self.textFits(text, max_size, font_category, font_size)) {
                return font_size;
            }
            font_size -= 1.0;
        }

        return min_size;
    }
};

// Tests
test "buffer text primitives basic functionality" {
    const testing = std.testing;

    var font_mgr = try font_manager.FontManager.init(testing.allocator);
    defer font_mgr.deinit();

    var primitives = BufferTextPrimitives.init(testing.allocator, &font_mgr);
    defer primitives.deinit();

    // Test that primitives initialize correctly
    try testing.expect(primitives.allocator.ptr == testing.allocator.ptr);
}

test "text measurement zero case" {
    const measurement = TextMeasurement.zero();
    try std.testing.expect(measurement.width == 0);
    try std.testing.expect(measurement.height == 0);
}
