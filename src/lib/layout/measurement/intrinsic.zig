/// Intrinsic size calculation utilities
///
/// This module provides utilities for calculating the intrinsic (natural) sizes
/// of elements based on their content, children, and layout properties.

const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../types.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;
const Constraints = types.Constraints;
const FlexConstraint = types.FlexConstraint;
const Spacing = types.Spacing;

/// Intrinsic size calculation utilities
pub const IntrinsicSizing = struct {
    /// Calculate intrinsic width based on content and constraints
    pub fn calculateIntrinsicWidth(content_width: f32, padding: Spacing, border: Spacing, constraints: Constraints) f32 {
        const min_content_width = content_width + padding.getHorizontal() + border.getHorizontal();
        return std.math.clamp(min_content_width, constraints.min_width, constraints.max_width);
    }

    /// Calculate intrinsic height based on content and constraints  
    pub fn calculateIntrinsicHeight(content_height: f32, padding: Spacing, border: Spacing, constraints: Constraints) f32 {
        const min_content_height = content_height + padding.getVertical() + border.getVertical();
        return std.math.clamp(min_content_height, constraints.min_height, constraints.max_height);
    }

    /// Calculate intrinsic size (both width and height)
    pub fn calculateIntrinsicSize(content_size: Vec2, padding: Spacing, border: Spacing, constraints: Constraints) Vec2 {
        return Vec2{
            .x = calculateIntrinsicWidth(content_size.x, padding, border, constraints),
            .y = calculateIntrinsicHeight(content_size.y, padding, border, constraints),
        };
    }

    /// Calculate minimum intrinsic size (content cannot be smaller)
    pub fn calculateMinIntrinsicSize(min_content_size: Vec2, padding: Spacing, border: Spacing) Vec2 {
        return Vec2{
            .x = min_content_size.x + padding.getHorizontal() + border.getHorizontal(),
            .y = min_content_size.y + padding.getVertical() + border.getVertical(),
        };
    }

    /// Calculate maximum intrinsic size (preferred maximum)
    pub fn calculateMaxIntrinsicSize(max_content_size: Vec2, padding: Spacing, border: Spacing, constraints: Constraints) Vec2 {
        const total_size = Vec2{
            .x = max_content_size.x + padding.getHorizontal() + border.getHorizontal(),
            .y = max_content_size.y + padding.getVertical() + border.getVertical(),
        };

        return Vec2{
            .x = @min(total_size.x, constraints.max_width),
            .y = @min(total_size.y, constraints.max_height),
        };
    }
};

/// Content size calculation based on different content types
pub const ContentSizing = struct {
    /// Text content sizing information
    pub const TextContentSize = struct {
        min_width: f32, // Minimum width (single longest word)
        max_width: f32, // Maximum width (all text on one line)
        height: f32, // Height for given width
    };

    /// Calculate size for text content
    pub fn calculateTextSize(text: []const u8, font_size: f32, line_height: f32, max_width: ?f32) TextContentSize {
        // TODO: Implement actual text measurement using font system
        
        // Placeholder implementation
        const estimated_char_width = font_size * 0.6;
        const estimated_text_width = @as(f32, @floatFromInt(text.len)) * estimated_char_width;
        
        const lines_needed = if (max_width) |max_w| @max(1, @ceil(estimated_text_width / max_w)) else 1;
        
        return TextContentSize{
            .min_width = estimated_char_width * 10, // Estimate longest word
            .max_width = estimated_text_width,
            .height = lines_needed * line_height,
        };
    }

    /// Calculate size for image content
    pub fn calculateImageSize(natural_size: Vec2, max_size: ?Vec2, maintain_aspect: bool) Vec2 {
        const max = max_size orelse return natural_size;
        
        if (!maintain_aspect) {
            return Vec2{
                .x = @min(natural_size.x, max.x),
                .y = @min(natural_size.y, max.y),
            };
        }
        
        // Maintain aspect ratio while fitting in max bounds
        const scale_x = max.x / natural_size.x;
        const scale_y = max.y / natural_size.y;
        const scale = @min(scale_x, scale_y);
        
        if (scale >= 1.0) return natural_size;
        
        return Vec2{
            .x = natural_size.x * scale,
            .y = natural_size.y * scale,
        };
    }

    /// Calculate size for replaced content (images, videos, etc.)
    pub fn calculateReplacedSize(natural_size: Vec2, constraints: Constraints, aspect_ratio: ?f32) Vec2 {
        var result = natural_size;
        
        // Apply constraints
        result = constraints.constrain(result);
        
        // Apply aspect ratio if specified
        if (aspect_ratio) |ratio| {
            if (ratio > 0) {
                // Choose dimension that maintains aspect ratio within constraints
                const width_from_height = result.y * ratio;
                const height_from_width = result.x / ratio;
                
                if (width_from_height <= constraints.max_width and width_from_height >= constraints.min_width) {
                    result.x = width_from_height;
                } else if (height_from_width <= constraints.max_height and height_from_width >= constraints.min_height) {
                    result.y = height_from_width;
                }
            }
        }
        
        return result;
    }
};

/// Child-based size calculation
pub const ChildBasedSizing = struct {
    /// Calculate container size based on children (block layout)
    pub fn calculateBlockContainerSize(children_sizes: []const Vec2, spacing: f32) Vec2 {
        if (children_sizes.len == 0) return Vec2.ZERO;
        
        var max_width: f32 = 0;
        var total_height: f32 = 0;
        
        for (children_sizes, 0..) |size, i| {
            max_width = @max(max_width, size.x);
            total_height += size.y;
            
            // Add spacing between children
            if (i > 0) {
                total_height += spacing;
            }
        }
        
        return Vec2{ .x = max_width, .y = total_height };
    }

    /// Calculate container size based on children (inline layout)
    pub fn calculateInlineContainerSize(children_sizes: []const Vec2, spacing: f32, line_height: f32) Vec2 {
        if (children_sizes.len == 0) return Vec2.ZERO;
        
        var total_width: f32 = 0;
        var max_height: f32 = line_height;
        
        for (children_sizes, 0..) |size, i| {
            total_width += size.x;
            max_height = @max(max_height, size.y);
            
            // Add spacing between children
            if (i > 0) {
                total_width += spacing;
            }
        }
        
        return Vec2{ .x = total_width, .y = max_height };
    }

    /// Calculate container size for flexbox children
    pub fn calculateFlexContainerSize(
        children_sizes: []const Vec2,
        direction: types.Direction,
        gap: f32,
    ) Vec2 {
        if (children_sizes.len == 0) return Vec2.ZERO;
        
        const is_row = direction == .row or direction == .row_reverse;
        
        if (is_row) {
            var total_width: f32 = 0;
            var max_height: f32 = 0;
            
            for (children_sizes, 0..) |size, i| {
                total_width += size.x;
                max_height = @max(max_height, size.y);
                
                if (i > 0) {
                    total_width += gap;
                }
            }
            
            return Vec2{ .x = total_width, .y = max_height };
        } else {
            var max_width: f32 = 0;
            var total_height: f32 = 0;
            
            for (children_sizes, 0..) |size, i| {
                max_width = @max(max_width, size.x);
                total_height += size.y;
                
                if (i > 0) {
                    total_height += gap;
                }
            }
            
            return Vec2{ .x = max_width, .y = total_height };
        }
    }
};

/// Flex-specific intrinsic sizing
pub const FlexIntrinsicSizing = struct {
    /// Calculate intrinsic size respecting flex constraints
    pub fn calculateFlexIntrinsicSize(preferred_size: f32, constraint: FlexConstraint) f32 {
        const basis_size = constraint.flex_basis orelse preferred_size;
        return constraint.constrain(basis_size);
    }

    /// Calculate minimum size for flex item
    pub fn calculateFlexMinSize(content_size: f32, constraint: FlexConstraint) f32 {
        return @max(constraint.min, content_size * 0.1); // At least 10% of content
    }

    /// Calculate maximum size for flex item
    pub fn calculateFlexMaxSize(content_size: f32, constraint: FlexConstraint) f32 {
        return @min(constraint.max, content_size * 3.0); // At most 300% of content
    }
};

// Tests
test "intrinsic size calculation" {
    const testing = std.testing;
    
    const content_size = Vec2{ .x = 100, .y = 50 };
    const padding = Spacing.uniform(10);
    const border = Spacing.uniform(2);
    const constraints = Constraints{
        .min_width = 50,
        .max_width = 200,
        .min_height = 30,
        .max_height = 150,
    };
    
    const intrinsic_size = IntrinsicSizing.calculateIntrinsicSize(content_size, padding, border, constraints);
    
    // Content (100x50) + padding (20x20) + border (4x4) = 124x74
    try testing.expect(intrinsic_size.x == 124);
    try testing.expect(intrinsic_size.y == 74);
}

test "content size calculation" {
    const testing = std.testing;
    
    const text_size = ContentSizing.calculateTextSize("Hello World", 16, 20, 200);
    try testing.expect(text_size.height == 20); // Single line
    try testing.expect(text_size.max_width > text_size.min_width);
    
    const natural_image_size = Vec2{ .x = 800, .y = 600 };
    const max_image_size = Vec2{ .x = 400, .y = 300 };
    const image_size = ContentSizing.calculateImageSize(natural_image_size, max_image_size, true);
    
    // Should maintain aspect ratio (4:3) while fitting in 400x300
    try testing.expect(image_size.x == 400);
    try testing.expect(image_size.y == 300);
}

test "child-based sizing" {
    const testing = std.testing;
    
    const children = [_]Vec2{
        Vec2{ .x = 50, .y = 30 },
        Vec2{ .x = 80, .y = 20 },
        Vec2{ .x = 60, .y = 40 },
    };
    
    const block_size = ChildBasedSizing.calculateBlockContainerSize(&children, 10);
    try testing.expect(block_size.x == 80); // Max width
    try testing.expect(block_size.y == 110); // 30+20+40 + 2*10 spacing
    
    const inline_size = ChildBasedSizing.calculateInlineContainerSize(&children, 5, 25);
    try testing.expect(inline_size.x == 205); // 50+80+60 + 2*5 spacing
    try testing.expect(inline_size.y == 40); // Max height (40 > line_height 25)
    
    const flex_size = ChildBasedSizing.calculateFlexContainerSize(&children, .row, 8);
    try testing.expect(flex_size.x == 206); // 50+80+60 + 2*8 gap
    try testing.expect(flex_size.y == 40); // Max height
}