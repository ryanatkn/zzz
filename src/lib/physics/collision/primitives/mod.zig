//! Primitive collision detection functions
//!
//! Shape-specific collision detection organized by primary shape type.
//! Each module contains all collision functions for a specific shape type.

pub const circle = @import("circle.zig");
pub const rectangle = @import("rectangle.zig");
pub const line = @import("line.zig");
pub const point = @import("point.zig");

// Re-export individual collision functions for convenience
pub const circleCircle = circle.circleCircle;
pub const checkCircleCollision = circle.checkCircleCollision;
pub const circleRectangle = circle.circleRectangle;
pub const circlePoint = circle.circlePoint;
pub const circleLine = circle.circleLine;

pub const rectangleRectangle = rectangle.rectangleRectangle;
pub const rectanglePoint = rectangle.rectanglePoint;
pub const rectangleLine = rectangle.rectangleLine;

pub const lineLineIntersect = line.lineLineIntersect;

pub const pointPoint = point.pointPoint;
pub const pointLine = point.pointLine;

// Detailed collision functions
pub const circleCircleDetailed = circle.circleCircleDetailed;
pub const circleRectangleDetailed = circle.circleRectangleDetailed;
pub const circlePointDetailed = circle.circlePointDetailed;
pub const circleLineDetailed = circle.circleLineDetailed;

pub const rectangleRectangleDetailed = rectangle.rectangleRectangleDetailed;
pub const rectanglePointDetailed = rectangle.rectanglePointDetailed;
pub const rectangleLineDetailed = rectangle.rectangleLineDetailed;

pub const lineLineDetailed = line.lineLineDetailed;

pub const pointPointDetailed = point.pointPointDetailed;
pub const pointLineDetailed = point.pointLineDetailed;
