/// Core layout types shared across all algorithms and implementations
const std = @import("std");
const math = @import("../../math/mod.zig");

pub const Vec2 = math.Vec2;
pub const Rectangle = math.Rectangle;

/// Layout calculation modes
pub const LayoutMode = enum {
    /// Absolute positioning with explicit coordinates
    absolute,
    /// Relative to parent's content area
    relative,
    /// CSS flexbox layout
    flex,
    /// CSS grid layout
    grid,
    /// CSS block layout
    block,
};

/// Content alignment options
pub const Alignment = enum {
    start,
    center,
    end,
    stretch,
    baseline,
};

/// Direction for flex and grid layouts
pub const Direction = enum {
    row,
    column,
    row_reverse,
    column_reverse,
};

/// Flexbox-specific alignment
pub const JustifyContent = enum {
    start,
    center,
    end,
    space_between,
    space_around,
    space_evenly,
};

/// Cross-axis alignment for flexbox
pub const AlignItems = enum {
    start,
    center,
    end,
    stretch,
    baseline,
};

/// Flex wrap behavior
pub const FlexWrap = enum {
    no_wrap,
    wrap,
    wrap_reverse,
};

/// Box sizing mode (CSS box-sizing)
pub const SizingMode = enum {
    /// Width/height includes only content
    content_box,
    /// Width/height includes content + padding + border
    border_box,
};

/// Position mode for elements
pub const PositionMode = enum {
    static,
    relative,
    absolute,
    fixed,
    sticky,
};

/// Text baseline alignment
pub const BaselineMode = enum {
    alphabetic,
    top,
    middle,
    bottom,
    ideographic,
    hanging,
};

/// Spacing values for margins, padding, borders
pub const Spacing = struct {
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,

    pub fn uniform(value: f32) Spacing {
        return Spacing{ .top = value, .right = value, .bottom = value, .left = value };
    }

    pub fn horizontal(value: f32) Spacing {
        return Spacing{ .left = value, .right = value };
    }

    pub fn vertical(value: f32) Spacing {
        return Spacing{ .top = value, .bottom = value };
    }

    pub fn asymmetric(vert: f32, horiz: f32) Spacing {
        return Spacing{ .top = vert, .right = horiz, .bottom = vert, .left = horiz };
    }

    pub fn getHorizontal(self: Spacing) f32 {
        return self.left + self.right;
    }

    pub fn getVertical(self: Spacing) f32 {
        return self.top + self.bottom;
    }
};

/// Offset for positioning
pub const Offset = struct {
    x: f32 = 0,
    y: f32 = 0,

    pub fn add(self: Offset, other: Offset) Offset {
        return Offset{ .x = self.x + other.x, .y = self.y + other.y };
    }
};

/// Layout constraints for sizing
pub const Constraints = struct {
    min_width: f32 = 0,
    max_width: f32 = std.math.inf(f32),
    min_height: f32 = 0,
    max_height: f32 = std.math.inf(f32),
    aspect_ratio: ?f32 = null,

    pub fn constrain(self: Constraints, size: Vec2) Vec2 {
        var result = size;
        result.x = std.math.clamp(result.x, self.min_width, self.max_width);
        result.y = std.math.clamp(result.y, self.min_height, self.max_height);

        // Apply aspect ratio if specified
        if (self.aspect_ratio) |ratio| {
            const current_ratio = result.x / result.y;
            if (current_ratio > ratio) {
                result.x = result.y * ratio;
            } else {
                result.y = result.x / ratio;
            }
        }

        return result;
    }

    pub fn constrainWidth(self: Constraints, width: f32) f32 {
        return std.math.clamp(width, self.min_width, self.max_width);
    }

    pub fn constrainHeight(self: Constraints, height: f32) f32 {
        return std.math.clamp(height, self.min_height, self.max_height);
    }
};

/// Flex-specific constraints
pub const FlexConstraint = struct {
    grow: f32 = 0,
    shrink: f32 = 1,
    basis: ?f32 = null, // null = auto
};

/// Layout calculation result
pub const LayoutResult = struct {
    /// Final position of the element
    position: Vec2,
    /// Final size of the element
    size: Vec2,
    /// Content area (position + padding offset, size - padding)
    content: Rectangle,
    /// Whether this result is valid
    valid: bool = true,
    /// Index of the element this result corresponds to
    element_index: usize = 0,

    pub fn contentArea(self: LayoutResult) Rectangle {
        return self.content;
    }

    pub fn borderArea(self: LayoutResult) Rectangle {
        return Rectangle{
            .position = self.position,
            .size = self.size,
        };
    }
};

/// Layout calculation context
pub const LayoutContext = struct {
    /// Available space for layout
    container_bounds: Rectangle,
    /// Default text size for sizing calculations
    default_font_size: f32 = 16,
    /// Layout algorithm to use
    algorithm: LayoutMode = .block,
    /// Debug mode for validation
    debug_mode: bool = false,
};

/// Dirty flags for incremental layout
pub const DirtyFlags = packed struct(u32) {
    layout: bool = false,
    measure: bool = false,
    constraint: bool = false,
    children: bool = false,
    style: bool = false,
    content: bool = false,
    _reserved: u26 = 0,

    pub fn isClean(self: DirtyFlags) bool {
        return @as(u32, @bitCast(self)) == 0;
    }

    pub fn markAll(self: *DirtyFlags) void {
        self.layout = true;
        self.measure = true;
        self.constraint = true;
        self.children = true;
        self.style = true;
        self.content = true;
    }

    pub fn clear(self: *DirtyFlags) void {
        self.* = DirtyFlags{};
    }
};

// Tests
test "spacing calculations" {
    const testing = std.testing;

    const spacing = Spacing.asymmetric(10, 20);
    try testing.expect(spacing.getVertical() == 20); // top + bottom
    try testing.expect(spacing.getHorizontal() == 40); // left + right
}

test "constraints application" {
    const testing = std.testing;

    const constraints = Constraints{
        .min_width = 100,
        .max_width = 200,
        .min_height = 50,
        .max_height = 150,
    };

    const result = constraints.constrain(Vec2{ .x = 300, .y = 25 });
    try testing.expect(result.x == 200); // Clamped to max
    try testing.expect(result.y == 50); // Clamped to min
}

test "dirty flags" {
    const testing = std.testing;

    var flags = DirtyFlags{};
    try testing.expect(flags.isClean());

    flags.layout = true;
    try testing.expect(!flags.isClean());

    flags.clear();
    try testing.expect(flags.isClean());
}
