//! Collision Detection System - Modular Implementation
//!
//! Comprehensive 2D collision detection with support for:
//! - Basic collision queries (boolean results)
//! - Detailed collision analysis (penetration, normals, contact points)
//! - Spatial optimization (grid-based broad phase)
//! - Batch processing for multiple objects
//!
//! ## Quick Start
//! ```zig
//! // Basic collision check
//! const circle = Circle.init(Vec2.init(0, 0), 5);
//! const rect = Rectangle.fromXYWH(3, 3, 4, 4);
//! const hit = checkCollision(.{ .circle = circle }, .{ .rectangle = rect });
//!
//! // Detailed collision for physics
//! const result = checkCollisionDetailed(.{ .circle = circle }, .{ .rectangle = rect });
//! if (result.collided) {
//!     const separation = result.normal.scale(result.penetration_depth);
//!     // Move objects apart using separation vector
//! }
//!
//! // Spatial optimization for many objects
//! var grid = try SpatialGrid.init(allocator, world_bounds, 32.0);
//! // Add shapes, query efficiently
//! ```
//!
//! ## Performance Notes
//! - Uses squared distances to avoid sqrt() calls
//! - Input validation prevents edge cases
//! - Constants extracted for easy tuning
//! - Spatial grid reduces O(N²) to O(N) for sparse scenes

const std = @import("std");

// Core modules
pub const types = @import("types.zig");
pub const primitives = @import("primitives/mod.zig");
pub const detection = @import("detection.zig");
pub const detailed = @import("detailed.zig");
pub const spatial = @import("spatial.zig");
pub const batch = @import("batch.zig");
pub const utils = @import("utils.zig");

// Re-export core types for convenience
pub const Shape = types.Shape;
pub const Circle = types.Circle;
pub const Rectangle = types.Rectangle;
pub const Point = types.Point;
pub const LineSegment = types.LineSegment;
pub const CollisionResult = types.CollisionResult;
pub const Bounds = types.Bounds;

// Re-export constants
pub const LINE_THICKNESS_TOLERANCE = types.LINE_THICKNESS_TOLERANCE;
pub const PARALLEL_LINE_TOLERANCE = types.PARALLEL_LINE_TOLERANCE;
pub const MOVING_COLLISION_STEPS = types.MOVING_COLLISION_STEPS;
pub const COLLISION_RESOLUTION_BUFFER = types.COLLISION_RESOLUTION_BUFFER;
pub const FLOATING_POINT_TOLERANCE = types.FLOATING_POINT_TOLERANCE;

// Re-export main collision functions
pub const checkCollision = detection.checkCollision;
pub const checkCollisionDetailed = detailed.checkCollisionDetailed;

// Re-export primitive collision functions
pub const circleCircle = primitives.circleCircle;
pub const checkCircleCollision = primitives.checkCircleCollision;
pub const circleRectangle = primitives.circleRectangle;
pub const circlePoint = primitives.circlePoint;
pub const circleLine = primitives.circleLine;
pub const rectangleRectangle = primitives.rectangleRectangle;
pub const rectanglePoint = primitives.rectanglePoint;
pub const rectangleLine = primitives.rectangleLine;
pub const pointPoint = primitives.pointPoint;
pub const pointLine = primitives.pointLine;
pub const lineLineIntersect = primitives.lineLineIntersect;

// Re-export advanced features
pub const SpatialGrid = spatial.SpatialGrid;
pub const CollisionBatch = batch.CollisionBatch;

// Re-export utility functions
pub const isPositionSafe = utils.isPositionSafe;
pub const findNearestObstacle = utils.findNearestObstacle;
pub const checkMovingCircleCollision = utils.checkMovingCircleCollision;
pub const resolveCollision = utils.resolveCollision;

// Re-export utility function
pub const vec2Cross = types.vec2Cross;

// Include comprehensive edge case tests
test {
    _ = @import("edge_cases_test.zig");
}

// Include integration tests
test {
    _ = @import("integration_test.zig");
}

// Include property-based tests
test {
    _ = @import("property_test.zig");
}
