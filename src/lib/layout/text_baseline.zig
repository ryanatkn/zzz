const std = @import("std");
const math = @import("../math/mod.zig");
const font_metrics = @import("../font/font_metrics.zig");

const Vec2 = math.Vec2;
const FontMetrics = font_metrics.FontMetrics;
const LineMetrics = font_metrics.LineMetrics;

/// Text baseline calculation utilities for consistent UI text positioning
pub const TextBaseline = struct {
    /// Standard baseline modes matching web/CSS standards
    pub const Mode = enum {
        /// Align to the alphabetic baseline (normal text baseline)
        alphabetic,
        /// Align to the top of the font (top of ascenders)
        top,
        /// Align to the middle of the font (between ascender and descender)
        middle,
        /// Align to the bottom of the font (bottom of descenders)
        bottom,
        /// Align to the ideographic baseline (for CJK characters)
        ideographic,
        /// Align to the hanging baseline (for Devanagari and similar scripts)
        hanging,
    };

    /// Calculate the Y offset needed to position text at a specific baseline
    /// Returns the offset to add to the desired baseline Y position
    pub fn calculateOffset(font_metrics_info: FontMetrics, baseline_mode: Mode, font_size: f32) f32 {
        _ = font_size; // Font size is already baked into the metrics scale

        switch (baseline_mode) {
            .alphabetic => {
                // Alphabetic baseline is at Y=0, so no offset needed
                return 0.0;
            },
            .top => {
                // Move up by the ascender height to align top
                return -font_metrics_info.getBaselineOffset();
            },
            .middle => {
                // Center between ascender and descender
                const ascender_px = @as(f32, @floatFromInt(font_metrics_info.ascender)) * font_metrics_info.scale;
                const descender_px = @as(f32, @floatFromInt(-font_metrics_info.descender)) * font_metrics_info.scale; // Make positive
                return -(ascender_px - descender_px) / 2.0;
            },
            .bottom => {
                // Move down by the descender depth
                const descender_px = @as(f32, @floatFromInt(-font_metrics_info.descender)) * font_metrics_info.scale; // Make positive
                return descender_px;
            },
            .ideographic => {
                // Same as alphabetic for now (could be customized for CJK fonts)
                return 0.0;
            },
            .hanging => {
                // Typically above the alphabetic baseline
                const ascender_px = @as(f32, @floatFromInt(font_metrics_info.ascender)) * font_metrics_info.scale;
                return -ascender_px * 0.8; // Estimate: 80% up toward ascender
            },
        }
    }

    /// Calculate vertical center position for centering text in a container
    /// This is commonly used for centering text in buttons, inputs, etc.
    pub fn calculateVerticalCenter(container_height: f32, font_metrics_info: FontMetrics) f32 {
        const ascender_px = @as(f32, @floatFromInt(font_metrics_info.ascender)) * font_metrics_info.scale;
        const descender_px = @as(f32, @floatFromInt(-font_metrics_info.descender)) * font_metrics_info.scale; // Make positive
        const text_height = ascender_px + descender_px;

        // Center the text height in the container, then adjust to baseline
        const center_y = container_height / 2.0;
        const text_center_to_baseline = descender_px - (text_height / 2.0);

        return center_y - text_center_to_baseline;
    }

    /// Get the effective line height for spacing multiple lines
    pub fn getEffectiveLineHeight(font_metrics_info: FontMetrics, line_spacing: f32) f32 {
        return font_metrics_info.getLineHeight() * line_spacing;
    }

    /// Calculate text position for proper alignment in UI components
    pub fn calculateTextPosition(container_pos: Vec2, container_size: Vec2, font_metrics_info: FontMetrics, baseline_mode: Mode) Vec2 {
        const baseline_offset = calculateOffset(font_metrics_info, baseline_mode, font_metrics_info.scale);

        return Vec2{
            .x = container_pos.x,
            .y = switch (baseline_mode) {
                .top => container_pos.y - baseline_offset,
                .middle => container_pos.y + container_size.y / 2.0 + baseline_offset,
                .bottom => container_pos.y + container_size.y + baseline_offset,
                .alphabetic, .ideographic, .hanging => container_pos.y + container_size.y / 2.0 + baseline_offset,
            },
        };
    }
};

/// Text positioning utilities for consistent UI text rendering
pub const TextPositioning = struct {
    /// Calculate the Y position for text to appear visually centered in a container
    /// This replaces hardcoded offsets like "bounds.size.y / 2 - 6"
    pub fn getCenteredTextY(container_y: f32, container_height: f32, font_metrics_info: FontMetrics) f32 {
        return container_y + TextBaseline.calculateVerticalCenter(container_height, font_metrics_info);
    }

    /// Calculate text position for input fields with proper cursor alignment
    /// Returns the Y position where text should be drawn for proper cursor alignment
    pub fn getInputTextY(input_bounds_y: f32, input_height: f32, font_metrics_info: FontMetrics) f32 {
        return getCenteredTextY(input_bounds_y, input_height, font_metrics_info);
    }

    /// Calculate cursor position that aligns with text baseline
    pub fn getCursorPosition(text_pos: Vec2, cursor_char_index: usize, char_width: f32, font_metrics_info: FontMetrics) Vec2 {
        const cursor_x = text_pos.x + @as(f32, @floatFromInt(cursor_char_index)) * char_width;

        // Cursor should span from slightly above text to the baseline
        const ascender_px = @as(f32, @floatFromInt(font_metrics_info.ascender)) * font_metrics_info.scale;
        const cursor_top = text_pos.y - ascender_px + 2.0; // 2px padding from top

        return Vec2{ .x = cursor_x, .y = cursor_top };
    }

    /// Calculate cursor height for proper text alignment
    pub fn getCursorHeight(font_metrics_info: FontMetrics) f32 {
        const ascender_px = @as(f32, @floatFromInt(font_metrics_info.ascender)) * font_metrics_info.scale;
        const descender_px = @as(f32, @floatFromInt(-font_metrics_info.descender)) * font_metrics_info.scale; // Make positive
        return ascender_px + descender_px - 4.0; // 4px total padding (2px top + 2px bottom)
    }
};

// Tests
test "baseline offset calculations" {
    const testing = std.testing;

    // Create test font metrics: 1000 units/em, 800 ascender, -200 descender, scale=0.048
    const metrics = FontMetrics.init(1000, 800, -200, 100, 0.048);

    // Test alphabetic baseline (should be 0)
    const alphabetic_offset = TextBaseline.calculateOffset(metrics, .alphabetic, 48.0);
    try testing.expect(alphabetic_offset == 0.0);

    // Test top alignment (should be negative, moving up by ascender)
    const top_offset = TextBaseline.calculateOffset(metrics, .top, 48.0);
    try testing.expect(top_offset < 0.0);
    try testing.expect(@abs(top_offset + 38.4) < 0.01); // ascender * scale = 800 * 0.048

    // Test bottom alignment (should be positive, moving down by descender)
    const bottom_offset = TextBaseline.calculateOffset(metrics, .bottom, 48.0);
    try testing.expect(bottom_offset > 0.0);
    try testing.expect(@abs(bottom_offset - 9.6) < 0.01); // -descender * scale = 200 * 0.048

    // Test middle alignment (should center between ascender and descender)
    const middle_offset = TextBaseline.calculateOffset(metrics, .middle, 48.0);
    try testing.expect(@abs(middle_offset + 14.4) < 0.01); // -(38.4 - 9.6) / 2
}

test "vertical center calculation" {
    const testing = std.testing;

    const metrics = FontMetrics.init(1000, 800, -200, 100, 0.048);
    const container_height: f32 = 30.0;

    const center_y = TextBaseline.calculateVerticalCenter(container_height, metrics);

    // Should position text baseline so text appears visually centered
    try testing.expect(center_y > 0.0);
    try testing.expect(center_y < container_height);
}

test "text positioning utilities" {
    const testing = std.testing;

    const metrics = FontMetrics.init(1000, 800, -200, 100, 0.048);
    const container_pos = Vec2{ .x = 10.0, .y = 20.0 };
    const container_size = Vec2{ .x = 100.0, .y = 30.0 };

    // Test centered text positioning
    const text_pos = TextBaseline.calculateTextPosition(container_pos, container_size, metrics, .middle);

    try testing.expect(text_pos.x == container_pos.x);
    try testing.expect(text_pos.y > container_pos.y);
    try testing.expect(text_pos.y < container_pos.y + container_size.y);
}

test "cursor positioning" {
    const testing = std.testing;

    const metrics = FontMetrics.init(1000, 800, -200, 100, 0.048);
    const text_pos = Vec2{ .x = 10.0, .y = 30.0 };
    const cursor_pos = TextPositioning.getCursorPosition(text_pos, 5, 8.0, metrics);

    // Cursor X should advance by character width
    try testing.expect(cursor_pos.x == text_pos.x + 40.0); // 5 * 8.0

    // Cursor Y should be above the baseline
    try testing.expect(cursor_pos.y < text_pos.y);

    // Cursor height should span text height
    const cursor_height = TextPositioning.getCursorHeight(metrics);
    try testing.expect(cursor_height > 0);
}
