/// Common layout types and enums shared across layout modules
///
/// This module defines the core types used throughout the layout system,
/// providing a single source of truth for layout-related data structures
/// and enumerations.
const std = @import("std");
const math = @import("../math/mod.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;

/// Layout positioning modes (from CSS positioning)
pub const PositionMode = enum {
    /// Normal document flow (CSS static)
    static,
    /// Positioned relative to normal position (CSS relative)
    relative,
    /// Positioned relative to containing block (CSS absolute)
    absolute,
    /// Positioned relative to viewport (CSS fixed)
    fixed,
    /// Positioned based on scroll (CSS sticky)
    sticky,
};

/// Alignment options for positioning and flexbox
pub const Alignment = enum {
    start, // left/top
    center, // center
    end, // right/bottom
    stretch, // fill available space
};

/// Flex direction for flexbox layouts
pub const Direction = enum {
    row, // Left to right
    row_reverse, // Right to left
    column, // Top to bottom
    column_reverse, // Bottom to top
};

/// Main axis justification (CSS justify-content)
pub const JustifyContent = enum {
    flex_start, // Pack to start
    flex_end, // Pack to end
    center, // Pack to center
    space_between, // Distribute evenly, first at start, last at end
    space_around, // Distribute with equal space around each item
    space_evenly, // Distribute with equal space between items
};

/// Cross axis alignment (CSS align-items)
pub const AlignItems = enum {
    flex_start, // Align to start of cross axis
    flex_end, // Align to end of cross axis
    center, // Align to center of cross axis
    stretch, // Stretch to fill cross axis
    baseline, // Align baselines
};

/// Box sizing modes (CSS box-sizing)
pub const SizingMode = enum {
    /// Width/height includes only content (CSS content-box)
    content_box,
    /// Width/height includes content + padding + border (CSS border-box)
    border_box,
};

/// Layout modes for elements
pub const LayoutMode = enum(u32) {
    absolute = 0,
    relative = 1,
    flex = 2,
};

/// Text baseline alignment modes
pub const BaselineMode = enum {
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

/// Flex wrap behavior (CSS flex-wrap)
pub const FlexWrap = enum {
    nowrap, // Single line
    wrap, // Multi-line, cross-start to cross-end
    wrap_reverse, // Multi-line, cross-end to cross-start
};

/// Spacing values for each side (TRBL format)
pub const Spacing = struct {
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,

    /// Create uniform spacing on all sides
    pub fn uniform(value: f32) Spacing {
        return Spacing{ .top = value, .right = value, .bottom = value, .left = value };
    }

    /// Create horizontal spacing (left and right)
    pub fn horizontal(value: f32) Spacing {
        return Spacing{ .left = value, .right = value };
    }

    /// Create vertical spacing (top and bottom)
    pub fn vertical(value: f32) Spacing {
        return Spacing{ .top = value, .bottom = value };
    }

    /// Create asymmetric spacing (vertical, horizontal)
    pub fn asymmetric(vert: f32, horiz: f32) Spacing {
        return Spacing{ .top = vert, .right = horiz, .bottom = vert, .left = horiz };
    }

    /// Get total horizontal spacing (left + right)
    pub fn getHorizontal(self: Spacing) f32 {
        return self.left + self.right;
    }

    /// Get total vertical spacing (top + bottom)
    pub fn getVertical(self: Spacing) f32 {
        return self.top + self.bottom;
    }

    /// Get total spacing as Vec2
    pub fn getTotal(self: Spacing) Vec2 {
        return Vec2{ .x = self.getHorizontal(), .y = self.getVertical() };
    }

    /// Check equality with another spacing
    pub fn eql(self: Spacing, other: Spacing) bool {
        return self.top == other.top and
            self.right == other.right and
            self.bottom == other.bottom and
            self.left == other.left;
    }
};

/// Position offset specification for absolute positioning
pub const Offset = struct {
    top: ?f32 = null,
    right: ?f32 = null,
    bottom: ?f32 = null,
    left: ?f32 = null,

    /// Create offset with uniform values
    pub fn uniform(value: f32) Offset {
        return Offset{ .top = value, .right = value, .bottom = value, .left = value };
    }

    /// Create offset with specific values
    pub fn fromValues(top: ?f32, right: ?f32, bottom: ?f32, left: ?f32) Offset {
        return Offset{ .top = top, .right = right, .bottom = bottom, .left = left };
    }
};

/// Box constraints for flexible sizing
pub const Constraints = struct {
    min_width: f32 = 0,
    max_width: f32 = std.math.inf(f32),
    min_height: f32 = 0,
    max_height: f32 = std.math.inf(f32),

    /// Apply constraints to a size
    pub fn constrain(self: Constraints, size: Vec2) Vec2 {
        return Vec2{
            .x = std.math.clamp(size.x, self.min_width, self.max_width),
            .y = std.math.clamp(size.y, self.min_height, self.max_height),
        };
    }

    /// Check equality with another constraints
    pub fn eql(self: Constraints, other: Constraints) bool {
        return self.min_width == other.min_width and
            self.max_width == other.max_width and
            self.min_height == other.min_height and
            self.max_height == other.max_height;
    }
};

/// Flexible sizing constraint for flex layouts
pub const FlexConstraint = struct {
    /// Minimum size (CSS min-width/min-height)
    min: f32 = 0,
    /// Maximum size (CSS max-width/max-height)
    max: f32 = std.math.inf(f32),
    /// Flex grow factor (CSS flex-grow)
    flex_grow: f32 = 0,
    /// Flex shrink factor (CSS flex-shrink)
    flex_shrink: f32 = 1,
    /// Flex basis (CSS flex-basis)
    flex_basis: ?f32 = null, // null means auto (use content size)

    /// Apply constraint to a size
    pub fn constrain(self: FlexConstraint, size: f32) f32 {
        return std.math.clamp(size, self.min, self.max);
    }
};

/// Layout result containing computed position and size
pub const LayoutResult = struct {
    position: Vec2,
    size: Vec2,
    /// Original element index
    element_index: usize = 0,
};

/// Layout context passed to layout engines
pub const LayoutContext = struct {
    /// Available space for layout
    available_space: Vec2,
    /// Container bounds for clipping
    container_bounds: Rectangle,
    /// Current scale factor
    scale: f32 = 1.0,
    /// Layout direction (for RTL support)
    direction: Direction = .row,
};

/// Dirty flags for layout optimization
pub const DirtyFlags = packed struct(u32) {
    layout: bool = false, // Layout calculation needed
    measure: bool = false, // Measure pass needed
    constraint: bool = false, // Constraint solving needed
    spring: bool = false, // Spring animation active
    _reserved: u28 = 0,
};

// Tests
test "spacing utilities" {
    const testing = std.testing;

    const uniform = Spacing.uniform(10);
    try testing.expect(uniform.top == 10);
    try testing.expect(uniform.getHorizontal() == 20);
    try testing.expect(uniform.getVertical() == 20);

    const asymmetric = Spacing.asymmetric(5, 8);
    try testing.expect(asymmetric.top == 5);
    try testing.expect(asymmetric.right == 8);
    try testing.expect(asymmetric.getHorizontal() == 16);
    try testing.expect(asymmetric.getVertical() == 10);
}

test "constraints application" {
    const testing = std.testing;

    const constraints = Constraints{
        .min_width = 10,
        .max_width = 100,
        .min_height = 20,
        .max_height = 200,
    };

    // Test clamping
    const result1 = constraints.constrain(Vec2{ .x = 5, .y = 15 });
    try testing.expect(result1.x == 10); // Clamped to min
    try testing.expect(result1.y == 20); // Clamped to min

    const result2 = constraints.constrain(Vec2{ .x = 150, .y = 300 });
    try testing.expect(result2.x == 100); // Clamped to max
    try testing.expect(result2.y == 200); // Clamped to max

    const result3 = constraints.constrain(Vec2{ .x = 50, .y = 100 });
    try testing.expect(result3.x == 50); // Within range
    try testing.expect(result3.y == 100); // Within range
}
