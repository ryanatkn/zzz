// Basic drawing primitives and utilities

pub const shapes = @import("shapes.zig");
pub const vector_utils = @import("vector_utils.zig");

// Re-export common utilities
pub const Rectangle = shapes.Rectangle;
pub const RectangleLegacy = shapes.RectangleLegacy;
pub const Circle = shapes.Circle;
pub const calculateBorders = shapes.calculateBorders;
pub const centerRectInRect = shapes.centerRectInRect;
