// Reusable shape drawing utilities for rendering system
// Consolidates common shape operations and calculations

const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const constants = @import("../core/constants.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;

/// Common shape properties and utilities
pub const Shapes = struct {
    /// Calculate rectangular border segments for screen edges
    pub fn calculateBorderRects(width: f32, offset: f32) [4]Rectangle {
        const screen_width = constants.SCREEN.BASE_WIDTH;
        const screen_height = constants.SCREEN.BASE_HEIGHT;

        return [4]Rectangle{
            // Top border
            Rectangle{
                .x = 0,
                .y = offset,
                .w = screen_width,
                .h = width,
            },
            // Bottom border
            Rectangle{
                .x = 0,
                .y = screen_height - width - offset,
                .w = screen_width,
                .h = width,
            },
            // Left border
            Rectangle{
                .x = offset,
                .y = 0,
                .w = width,
                .h = screen_height,
            },
            // Right border
            Rectangle{
                .x = screen_width - width - offset,
                .y = 0,
                .w = width,
                .h = screen_height,
            },
        };
    }

    /// Center a rectangle within given bounds
    pub fn centerRect(rect_size: Vec2, bounds_size: Vec2) Vec2 {
        return Vec2{
            .x = (bounds_size.x - rect_size.x) / 2.0,
            .y = (bounds_size.y - rect_size.y) / 2.0,
        };
    }

    /// Calculate progress bar dimensions and position
    pub fn calculateProgressBar(progress: f32, bar_width: f32, bar_height: f32, screen_width: f32, screen_height: f32) ProgressBar {
        const fill_width = bar_width * std.math.clamp(progress, 0.0, 1.0);
        const bar_x = (screen_width - bar_width) / 2.0;
        const bar_y = screen_height * 0.1 - bar_height / 2.0;

        return ProgressBar{
            .background = Rectangle{
                .x = bar_x,
                .y = bar_y,
                .w = bar_width,
                .h = bar_height,
            },
            .fill = Rectangle{
                .x = bar_x,
                .y = bar_y,
                .w = fill_width,
                .h = bar_height,
            },
            .progress = progress,
        };
    }

    /// Calculate dialog box position (centered)
    pub fn calculateDialogBox(dialog_width: f32, dialog_height: f32, screen_width: f32, screen_height: f32) Rectangle {
        return Rectangle{
            .x = (screen_width - dialog_width) / 2.0,
            .y = (screen_height - dialog_height) / 2.0,
            .w = dialog_width,
            .h = dialog_height,
        };
    }
};

/// Rectangle structure for shape calculations
pub const Rectangle = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,

    pub fn center(self: Rectangle) Vec2 {
        return Vec2{
            .x = self.x + self.w / 2.0,
            .y = self.y + self.h / 2.0,
        };
    }

    pub fn size(self: Rectangle) Vec2 {
        return Vec2{ .x = self.w, .y = self.h };
    }

    pub fn position(self: Rectangle) Vec2 {
        return Vec2{ .x = self.x, .y = self.y };
    }

    pub fn contains(self: Rectangle, point: Vec2) bool {
        return point.x >= self.x and point.x <= self.x + self.w and
            point.y >= self.y and point.y <= self.y + self.h;
    }

    pub fn intersects(self: Rectangle, other: Rectangle) bool {
        return !(self.x + self.w < other.x or other.x + other.w < self.x or
            self.y + self.h < other.y or other.y + other.h < self.y);
    }
};

/// Progress bar data structure
pub const ProgressBar = struct {
    background: Rectangle,
    fill: Rectangle,
    progress: f32,
};

/// Circle utilities
pub const Circle = struct {
    center: Vec2,
    radius: f32,

    pub fn contains(self: Circle, point: Vec2) bool {
        const diff = Vec2{ .x = point.x - self.center.x, .y = point.y - self.center.y };
        const distance_squared = diff.x * diff.x + diff.y * diff.y;
        return distance_squared <= self.radius * self.radius;
    }

    pub fn intersectsRect(self: Circle, rect: Rectangle) bool {
        // Find closest point on rectangle to circle center
        const closest_x = std.math.clamp(self.center.x, rect.x, rect.x + rect.w);
        const closest_y = std.math.clamp(self.center.y, rect.y, rect.y + rect.h);

        const diff = Vec2{ .x = self.center.x - closest_x, .y = self.center.y - closest_y };
        const distance_squared = diff.x * diff.x + diff.y * diff.y;

        return distance_squared <= self.radius * self.radius;
    }

    pub fn intersectsCircle(self: Circle, other: Circle) bool {
        const diff = Vec2{ .x = self.center.x - other.center.x, .y = self.center.y - other.center.y };
        const distance_squared = diff.x * diff.x + diff.y * diff.y;
        const combined_radius = self.radius + other.radius;
        return distance_squared <= combined_radius * combined_radius;
    }
};

// Tests for shape utilities
test "rectangle operations" {
    const rect = Rectangle{ .x = 10, .y = 20, .w = 100, .h = 50 };

    // Test center calculation
    const center_point = rect.center();
    try std.testing.expectApproxEqAbs(@as(f32, 60.0), center_point.x, 0.1); // 10 + 100/2
    try std.testing.expectApproxEqAbs(@as(f32, 45.0), center_point.y, 0.1); // 20 + 50/2

    // Test contains
    try std.testing.expect(rect.contains(Vec2{ .x = 50, .y = 30 }));
    try std.testing.expect(!rect.contains(Vec2{ .x = 5, .y = 30 }));
}

test "circle operations" {
    const circle = Circle{ .center = Vec2{ .x = 50, .y = 50 }, .radius = 25 };

    // Test contains
    try std.testing.expect(circle.contains(Vec2{ .x = 60, .y = 60 })); // Inside
    try std.testing.expect(!circle.contains(Vec2{ .x = 100, .y = 100 })); // Outside

    // Test circle intersection
    const other_circle = Circle{ .center = Vec2{ .x = 70, .y = 50 }, .radius = 20 };
    try std.testing.expect(circle.intersectsCircle(other_circle)); // Should intersect
}

test "shape utilities" {
    // Test centering
    const rect_size = Vec2{ .x = 100, .y = 50 };
    const bounds_size = Vec2{ .x = 800, .y = 600 };
    const centered = Shapes.centerRect(rect_size, bounds_size);

    try std.testing.expectApproxEqAbs(@as(f32, 350.0), centered.x, 0.1); // (800-100)/2
    try std.testing.expectApproxEqAbs(@as(f32, 275.0), centered.y, 0.1); // (600-50)/2
}
