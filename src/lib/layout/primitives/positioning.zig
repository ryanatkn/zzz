const std = @import("std");
const math = @import("../../math/mod.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;

/// Position calculation utilities for layout primitives
pub const PositioningUtils = struct {
    /// CSS-like position modes
    pub const PositionMode = enum {
        /// Normal document flow (CSS static)
        static,
        /// Positioned relative to normal position (CSS relative)
        relative,
        /// Positioned relative to containing block (CSS absolute)
        absolute,
        /// Positioned relative to viewport (CSS fixed)
        fixed,
        /// Positioned based on scroll (CSS sticky) - basic implementation
        sticky,
    };

    /// Alignment options for positioning
    pub const Alignment = enum {
        start, // left/top
        center, // center
        end, // right/bottom
        stretch, // fill available space
    };

    /// Position offset specification
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

    /// Calculate absolute position based on containing block and offset
    pub fn calculateAbsolutePosition(
        containing_block: Rectangle,
        size: Vec2,
        offset: Offset,
    ) Vec2 {
        var position = containing_block.position;

        // Apply left/right positioning
        if (offset.left) |left| {
            position.x = containing_block.position.x + left;
        } else if (offset.right) |right| {
            position.x = containing_block.position.x + containing_block.size.x - right - size.x;
        }

        // Apply top/bottom positioning
        if (offset.top) |top| {
            position.y = containing_block.position.y + top;
        } else if (offset.bottom) |bottom| {
            position.y = containing_block.position.y + containing_block.size.y - bottom - size.y;
        }

        return position;
    }

    /// Calculate aligned position within a container
    pub fn calculateAlignedPosition(
        container: Rectangle,
        size: Vec2,
        horizontal_align: Alignment,
        vertical_align: Alignment,
    ) Vec2 {
        const x = switch (horizontal_align) {
            .start => container.position.x,
            .center => container.position.x + (container.size.x - size.x) / 2.0,
            .end => container.position.x + container.size.x - size.x,
            .stretch => container.position.x, // X position for stretch (caller handles size)
        };

        const y = switch (vertical_align) {
            .start => container.position.y,
            .center => container.position.y + (container.size.y - size.y) / 2.0,
            .end => container.position.y + container.size.y - size.y,
            .stretch => container.position.y, // Y position for stretch (caller handles size)
        };

        return Vec2{ .x = x, .y = y };
    }

    /// Calculate size when using stretch alignment
    pub fn calculateStretchSize(
        container: Rectangle,
        original_size: Vec2,
        horizontal_align: Alignment,
        vertical_align: Alignment,
    ) Vec2 {
        const width = if (horizontal_align == .stretch) container.size.x else original_size.x;
        const height = if (vertical_align == .stretch) container.size.y else original_size.y;

        return Vec2{ .x = width, .y = height };
    }

    /// Calculate relative position offset from normal position
    pub fn calculateRelativeOffset(base_position: Vec2, offset: Offset) Vec2 {
        var position = base_position;

        // Apply relative offsets
        if (offset.left) |left| {
            position.x += left;
        }
        if (offset.right) |right| {
            position.x -= right; // right offset moves left
        }
        if (offset.top) |top| {
            position.y += top;
        }
        if (offset.bottom) |bottom| {
            position.y -= bottom; // bottom offset moves up
        }

        return position;
    }

    /// Calculate stacking order position (z-index simulation)
    pub fn calculateStackingOrder(base_z: f32, z_index: ?i32) f32 {
        if (z_index) |z| {
            return base_z + @as(f32, @floatFromInt(z));
        }
        return base_z;
    }

    /// Clip position and size to fit within bounds
    pub fn clipToBounds(position: Vec2, size: Vec2, bounds: Rectangle) struct { position: Vec2, size: Vec2, clipped: bool } {
        var clipped_pos = position;
        var clipped_size = size;
        var was_clipped = false;

        // Clip to left edge
        if (position.x < bounds.position.x) {
            const diff = bounds.position.x - position.x;
            clipped_pos.x = bounds.position.x;
            clipped_size.x = @max(0, size.x - diff);
            was_clipped = true;
        }

        // Clip to top edge
        if (position.y < bounds.position.y) {
            const diff = bounds.position.y - position.y;
            clipped_pos.y = bounds.position.y;
            clipped_size.y = @max(0, size.y - diff);
            was_clipped = true;
        }

        // Clip to right edge
        const right_edge = position.x + size.x;
        const bounds_right = bounds.position.x + bounds.size.x;
        if (right_edge > bounds_right) {
            clipped_size.x = @max(0, bounds_right - clipped_pos.x);
            was_clipped = true;
        }

        // Clip to bottom edge
        const bottom_edge = position.y + size.y;
        const bounds_bottom = bounds.position.y + bounds.size.y;
        if (bottom_edge > bounds_bottom) {
            clipped_size.y = @max(0, bounds_bottom - clipped_pos.y);
            was_clipped = true;
        }

        return .{
            .position = clipped_pos,
            .size = clipped_size,
            .clipped = was_clipped,
        };
    }

    /// Check if two rectangles overlap
    pub fn rectanglesOverlap(rect1: Rectangle, rect2: Rectangle) bool {
        return !(rect1.position.x + rect1.size.x <= rect2.position.x or
            rect2.position.x + rect2.size.x <= rect1.position.x or
            rect1.position.y + rect1.size.y <= rect2.position.y or
            rect2.position.y + rect2.size.y <= rect1.position.y);
    }

    /// Calculate overlap area between two rectangles
    pub fn calculateOverlapArea(rect1: Rectangle, rect2: Rectangle) f32 {
        if (!rectanglesOverlap(rect1, rect2)) return 0;

        const left = @max(rect1.position.x, rect2.position.x);
        const right = @min(rect1.position.x + rect1.size.x, rect2.position.x + rect2.size.x);
        const top = @max(rect1.position.y, rect2.position.y);
        const bottom = @min(rect1.position.y + rect1.size.y, rect2.position.y + rect2.size.y);

        return (right - left) * (bottom - top);
    }
};

// Tests
test "absolute positioning" {
    const testing = std.testing;

    const container = Rectangle{ .position = Vec2{ .x = 10, .y = 20 }, .size = Vec2{ .x = 200, .y = 100 } };
    const item_size = Vec2{ .x = 50, .y = 30 };

    // Top-left positioning
    const offset1 = PositioningUtils.Offset.fromValues(10, null, null, 15);
    const pos1 = PositioningUtils.calculateAbsolutePosition(container, item_size, offset1);
    try testing.expect(pos1.x == 25); // 10 + 15
    try testing.expect(pos1.y == 30); // 20 + 10

    // Bottom-right positioning
    const offset2 = PositioningUtils.Offset.fromValues(null, 10, 5, null);
    const pos2 = PositioningUtils.calculateAbsolutePosition(container, item_size, offset2);
    try testing.expect(pos2.x == 150); // 10 + 200 - 10 - 50
    try testing.expect(pos2.y == 85); // 20 + 100 - 5 - 30
}

test "aligned positioning" {
    const testing = std.testing;

    const container = Rectangle{ .position = Vec2{ .x = 10, .y = 20 }, .size = Vec2{ .x = 200, .y = 100 } };
    const item_size = Vec2{ .x = 50, .y = 30 };

    // Center alignment
    const center_pos = PositioningUtils.calculateAlignedPosition(container, item_size, .center, .center);
    try testing.expect(center_pos.x == 85); // 10 + (200-50)/2
    try testing.expect(center_pos.y == 55); // 20 + (100-30)/2

    // End alignment
    const end_pos = PositioningUtils.calculateAlignedPosition(container, item_size, .end, .end);
    try testing.expect(end_pos.x == 160); // 10 + 200 - 50
    try testing.expect(end_pos.y == 90); // 20 + 100 - 30
}

test "stretch sizing" {
    const testing = std.testing;

    const container = Rectangle{ .position = Vec2{ .x = 10, .y = 20 }, .size = Vec2{ .x = 200, .y = 100 } };
    const original_size = Vec2{ .x = 50, .y = 30 };

    const stretched_size = PositioningUtils.calculateStretchSize(container, original_size, .stretch, .center);

    try testing.expect(stretched_size.x == 200); // Stretched to container width
    try testing.expect(stretched_size.y == 30); // Original height
}

test "clipping to bounds" {
    const testing = std.testing;

    const bounds = Rectangle{ .position = Vec2{ .x = 10, .y = 10 }, .size = Vec2{ .x = 100, .y = 80 } };

    // Item partially outside left edge
    const result = PositioningUtils.clipToBounds(Vec2{ .x = 5, .y = 20 }, // position
        Vec2{ .x = 20, .y = 10 }, // size
        bounds);

    try testing.expect(result.clipped);
    try testing.expect(result.position.x == 10); // Clipped to bounds
    try testing.expect(result.size.x == 15); // Reduced size
}

test "rectangle overlap detection" {
    const testing = std.testing;

    const rect1 = Rectangle{ .position = Vec2{ .x = 0, .y = 0 }, .size = Vec2{ .x = 50, .y = 50 } };
    const rect2 = Rectangle{ .position = Vec2{ .x = 25, .y = 25 }, .size = Vec2{ .x = 50, .y = 50 } };
    const rect3 = Rectangle{ .position = Vec2{ .x = 100, .y = 100 }, .size = Vec2{ .x = 50, .y = 50 } };

    try testing.expect(PositioningUtils.rectanglesOverlap(rect1, rect2)); // Overlapping
    try testing.expect(!PositioningUtils.rectanglesOverlap(rect1, rect3)); // Not overlapping

    const overlap_area = PositioningUtils.calculateOverlapArea(rect1, rect2);
    try testing.expect(overlap_area == 25 * 25); // 25x25 overlap
}
