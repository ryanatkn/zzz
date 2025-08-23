/// Physics capability exports - collision detection, spatial queries, shapes
/// Re-exports for capability-based imports following engine architecture
pub const collision = @import("collision/mod.zig");
pub const queries = @import("queries.zig");
pub const shapes = @import("shapes.zig");

// Core collision functions for convenience
pub const checkCollision = collision.checkCollision;
pub const checkCollisionDetailed = collision.checkCollisionDetailed;
pub const circleCircle = collision.circleCircle;
pub const circleRectangle = collision.circleRectangle;
pub const rectangleRectangle = collision.rectangleRectangle;
pub const checkCircleCollision = collision.checkCircleCollision;

// Shape types re-exported for convenience
pub const Shape = shapes.Shape;
pub const Circle = shapes.Circle;
pub const Rectangle = shapes.Rectangle;
pub const Point = shapes.Point;
pub const Line = shapes.Line;
pub const LineSegment = shapes.LineSegment;

// Query types and functions
pub const QueryResult = queries.QueryResult;
pub const PhysicsQueries = queries.PhysicsQueries;
pub const ObstacleQueryConfig = queries.ObstacleQueryConfig;

// Advanced collision utilities
pub const CollisionResult = collision.CollisionResult;
pub const SpatialGrid = collision.SpatialGrid;
pub const isPositionSafe = collision.isPositionSafe;
pub const resolveCollision = collision.resolveCollision;
pub const checkMovingCircleCollision = collision.checkMovingCircleCollision;

// Physics extensions
pub const PhysicsExt = shapes.PhysicsExt;
