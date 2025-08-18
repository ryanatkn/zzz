const std = @import("std");
const math = @import("../math/mod.zig");

const Vec2 = math.Vec2;

/// Text alignment options
pub const TextAlign = enum {
    left,
    center,
    right,
    justify,
};

/// Vertical text baseline alignment
pub const TextBaseline = enum {
    top,
    middle,
    bottom,
    alphabetic,
};

/// Text measurement for alignment calculations
pub const TextMeasure = struct {
    width: f32,
    height: f32,
    baseline: f32,
};

/// Calculate position offset based on alignment and text measurements
pub fn calculateAlignmentOffset(alignment: TextAlign, text_width: f32) Vec2 {
    return switch (alignment) {
        .left => Vec2{ .x = 0, .y = 0 },
        .center => Vec2{ .x = -text_width / 2.0, .y = 0 },
        .right => Vec2{ .x = -text_width, .y = 0 },
        .justify => Vec2{ .x = 0, .y = 0 }, // Same as left for single lines
    };
}

/// Calculate baseline offset for vertical alignment
pub fn calculateBaselineOffset(baseline: TextBaseline, font_size: f32, line_height: f32) f32 {
    _ = font_size; // font_size may be used in future baseline calculations
    return switch (baseline) {
        .top => 0,
        .middle => line_height / 2.0,
        .bottom => line_height,
        .alphabetic => line_height * 0.8, // Typical alphabetic baseline
    };
}

/// Helper to position text aligned to screen edges
pub const ScreenAlignment = struct {
    /// Calculate position for right-aligned text from right edge of screen
    pub fn rightAlignedFromEdge(screen_width: f32, margin: f32, text_width: f32) Vec2 {
        return Vec2{
            .x = screen_width - margin - text_width,
            .y = 0, // Y should be set separately
        };
    }

    /// Calculate position for left-aligned text from left edge of screen
    pub fn leftAlignedFromEdge(margin: f32) Vec2 {
        return Vec2{
            .x = margin,
            .y = 0, // Y should be set separately
        };
    }

    /// Calculate position for center-aligned text
    pub fn centerAligned(screen_width: f32, text_width: f32) Vec2 {
        return Vec2{
            .x = (screen_width - text_width) / 2.0,
            .y = 0, // Y should be set separately
        };
    }
};

/// Apply alignment offset to a position
pub fn applyAlignment(position: Vec2, alignment: TextAlign, text_width: f32) Vec2 {
    const offset = calculateAlignmentOffset(alignment, text_width);
    return Vec2{
        .x = position.x + offset.x,
        .y = position.y + offset.y,
    };
}

/// Convenience function for right-aligned text
pub fn positionRightAligned(base_position: Vec2, text_width: f32) Vec2 {
    return applyAlignment(base_position, .right, text_width);
}

/// Convenience function for center-aligned text
pub fn positionCenterAligned(base_position: Vec2, text_width: f32) Vec2 {
    return applyAlignment(base_position, .center, text_width);
}

/// Convenience function for left-aligned text (no-op, but for consistency)
pub fn positionLeftAligned(base_position: Vec2, text_width: f32) Vec2 {
    return applyAlignment(base_position, .left, text_width);
}

/// Common UI alignment patterns
pub const UIPatterns = struct {
    /// Create right-aligned FPS counter position
    pub fn createFPSCounterPosition(screen_width: f32, screen_height: f32, margin: f32) Vec2 {
        return Vec2{
            .x = screen_width - margin,
            .y = screen_height - margin,
        };
    }

    /// Create right-aligned status text position (below FPS)
    pub fn createStatusTextPosition(screen_width: f32, screen_height: f32, margin: f32, offset_y: f32) Vec2 {
        return Vec2{
            .x = screen_width - margin,
            .y = screen_height - margin + offset_y,
        };
    }

    /// Create left-aligned file list position
    pub fn createFileListPosition(panel_x: f32, panel_y: f32, margin: f32, line_offset: f32) Vec2 {
        return Vec2{
            .x = panel_x + margin,
            .y = panel_y + margin + line_offset,
        };
    }

    /// Create center-aligned title position
    pub fn createTitlePosition(container_width: f32, container_y: f32, text_width: f32) Vec2 {
        return Vec2{
            .x = (container_width - text_width) / 2.0,
            .y = container_y,
        };
    }
};

/// Text width estimation utilities
pub const TextMeasurement = struct {
    /// Estimate text width using character count and font size
    /// This is a rough approximation - for exact measurements, use proper font metrics
    pub fn estimateWidth(text: []const u8, font_size: f32) f32 {
        return @as(f32, @floatFromInt(text.len)) * font_size * 0.6;
    }

    /// Estimate text height based on font size
    pub fn estimateHeight(font_size: f32) f32 {
        return font_size * 1.2; // Include line height
    }

    /// Estimate text bounds (width and height)
    pub fn estimateBounds(text: []const u8, font_size: f32) Vec2 {
        return Vec2{
            .x = estimateWidth(text, font_size),
            .y = estimateHeight(font_size),
        };
    }
};

/// Common text positioning workflows
pub const TextPositioning = struct {
    /// Position text for right-aligned HUD element (FPS, AI mode, etc.)
    pub fn hudRightAligned(text: []const u8, screen_width: f32, screen_height: f32, font_size: f32, margin: f32, line_offset: f32) Vec2 {
        const text_width = TextMeasurement.estimateWidth(text, font_size);
        const base_position = Vec2{
            .x = screen_width - margin,
            .y = screen_height - margin + line_offset,
        };
        return applyAlignment(base_position, .right, text_width);
    }

    /// Position text for left-aligned panel content (file names, etc.)
    pub fn panelLeftAligned(panel_x: f32, panel_y: f32, margin: f32, line_offset: f32) Vec2 {
        return Vec2{
            .x = panel_x + margin,
            .y = panel_y + margin + line_offset,
        };
    }

    /// Position text for center-aligned titles and headers
    pub fn titleCenterAligned(text: []const u8, container_x: f32, container_y: f32, container_width: f32, font_size: f32) Vec2 {
        const text_width = TextMeasurement.estimateWidth(text, font_size);
        const base_position = Vec2{
            .x = container_x + container_width / 2.0,
            .y = container_y,
        };
        return applyAlignment(base_position, .center, text_width);
    }
};

test "text alignment calculations" {
    const text_width: f32 = 100.0;

    // Test alignment offsets
    const left_offset = calculateAlignmentOffset(.left, text_width);
    try std.testing.expectEqual(@as(f32, 0), left_offset.x);

    const center_offset = calculateAlignmentOffset(.center, text_width);
    try std.testing.expectEqual(@as(f32, -50.0), center_offset.x);

    const right_offset = calculateAlignmentOffset(.right, text_width);
    try std.testing.expectEqual(@as(f32, -100.0), right_offset.x);
}

test "screen alignment helpers" {
    const screen_width: f32 = 1920.0;
    const margin: f32 = 10.0;
    const text_width: f32 = 100.0;

    // Test right alignment from edge
    const right_pos = ScreenAlignment.rightAlignedFromEdge(screen_width, margin, text_width);
    try std.testing.expectEqual(@as(f32, 1810.0), right_pos.x); // 1920 - 10 - 100

    // Test left alignment from edge
    const left_pos = ScreenAlignment.leftAlignedFromEdge(margin);
    try std.testing.expectEqual(@as(f32, 10.0), left_pos.x);

    // Test center alignment
    const center_pos = ScreenAlignment.centerAligned(screen_width, text_width);
    try std.testing.expectEqual(@as(f32, 910.0), center_pos.x); // (1920 - 100) / 2
}

test "position alignment application" {
    const base_pos = Vec2{ .x = 100.0, .y = 50.0 };
    const text_width: f32 = 80.0;

    const right_aligned = positionRightAligned(base_pos, text_width);
    try std.testing.expectEqual(@as(f32, 20.0), right_aligned.x); // 100 - 80
    try std.testing.expectEqual(@as(f32, 50.0), right_aligned.y);

    const center_aligned = positionCenterAligned(base_pos, text_width);
    try std.testing.expectEqual(@as(f32, 60.0), center_aligned.x); // 100 - 40
    try std.testing.expectEqual(@as(f32, 50.0), center_aligned.y);
}

test "text measurement utilities" {
    const text = "Hello World";
    const font_size: f32 = 20.0;

    const width = TextMeasurement.estimateWidth(text, font_size);
    try std.testing.expect(width > 0);
    try std.testing.expectEqual(@as(f32, @floatFromInt(text.len)) * font_size * 0.6, width);

    const height = TextMeasurement.estimateHeight(font_size);
    try std.testing.expectEqual(font_size * 1.2, height);

    const bounds = TextMeasurement.estimateBounds(text, font_size);
    try std.testing.expectEqual(width, bounds.x);
    try std.testing.expectEqual(height, bounds.y);
}

test "UI pattern helpers" {
    const screen_width: f32 = 1920.0;
    const screen_height: f32 = 1080.0;
    const margin: f32 = 10.0;

    // Test FPS counter positioning
    const fps_pos = UIPatterns.createFPSCounterPosition(screen_width, screen_height, margin);
    try std.testing.expectEqual(@as(f32, 1910.0), fps_pos.x);
    try std.testing.expectEqual(@as(f32, 1070.0), fps_pos.y);

    // Test status text positioning
    const status_pos = UIPatterns.createStatusTextPosition(screen_width, screen_height, margin, 30.0);
    try std.testing.expectEqual(@as(f32, 1910.0), status_pos.x);
    try std.testing.expectEqual(@as(f32, 1100.0), status_pos.y); // 1070 + 30
}

test "text positioning workflows" {
    const screen_width: f32 = 1920.0;
    const screen_height: f32 = 1080.0;
    const font_size: f32 = 24.0;
    const margin: f32 = 10.0;

    // Test HUD right alignment
    const text = "FPS: 60";
    const hud_pos = TextPositioning.hudRightAligned(text, screen_width, screen_height, font_size, margin, 0.0);
    try std.testing.expect(hud_pos.x < screen_width); // Should be positioned to the left of the right edge
    try std.testing.expectEqual(@as(f32, 1070.0), hud_pos.y);

    // Test panel left alignment
    const panel_pos = TextPositioning.panelLeftAligned(100.0, 50.0, margin, 20.0);
    try std.testing.expectEqual(@as(f32, 110.0), panel_pos.x); // 100 + 10
    try std.testing.expectEqual(@as(f32, 80.0), panel_pos.y); // 50 + 10 + 20
}
