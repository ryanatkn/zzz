// Basic drawing primitives and utilities

pub const shapes = @import("shapes.zig");
pub const vector_utils = @import("vector_utils.zig");
pub const batching = @import("batching.zig");

// GPU primitive renderers
pub const circles = @import("circles.zig");
pub const rectangles = @import("rectangles.zig");
pub const particles = @import("particles.zig");
pub const text = @import("text.zig");

// Re-export common utilities
pub const Rectangle = shapes.Rectangle;
pub const RectangleLegacy = shapes.RectangleLegacy;
pub const Circle = shapes.Circle;
pub const calculateBorders = shapes.calculateBorders;
pub const centerRectInRect = shapes.centerRectInRect;

// Re-export batching utilities
pub const RectData = batching.RectData;
pub const CircleData = batching.CircleData;
pub const BatchedRenderer = batching.BatchedRenderer;
pub const BatchBuilder = batching.BatchBuilder;
pub const BatchStats = batching.BatchStats;
