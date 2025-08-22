const std = @import("std");
const math = @import("../math/mod.zig");
const shapes = @import("shapes.zig");

const Vec2 = math.Vec2;

// Re-export shape types for backwards compatibility
pub const Shape = shapes.Shape;
pub const Circle = shapes.Circle;
pub const Rectangle = shapes.Rectangle;
pub const Point = shapes.Point;
pub const LineSegment = shapes.LineSegment;

/// Generic collision detection between any two shapes
pub fn checkCollision(shape1: Shape, shape2: Shape) bool {
    return switch (shape1) {
        .circle => |c1| switch (shape2) {
            .circle => |c2| circleCircle(c1, c2),
            .rectangle => |r2| circleRectangle(c1, r2),
            .point => |p2| circlePoint(c1, p2),
            .line => false, // Circle-line collision not implemented yet
        },
        .rectangle => |r1| switch (shape2) {
            .circle => |c2| circleRectangle(c2, r1), // Symmetric
            .rectangle => |r2| rectangleRectangle(r1, r2),
            .point => |p2| rectanglePoint(r1, p2),
            .line => false, // Rectangle-line collision not implemented yet
        },
        .point => |p1| switch (shape2) {
            .circle => |c2| circlePoint(c2, p1), // Symmetric
            .rectangle => |r2| rectanglePoint(r2, p1), // Symmetric
            .point => |p2| pointPoint(p1, p2),
            .line => false, // Point-line collision not implemented yet
        },
        .line => false, // Line segment collisions not implemented yet
    };
}

/// Circle-circle collision detection (optimized with squared distance)
pub fn circleCircle(c1: Circle, c2: Circle) bool {
    const distance_sq = math.distanceSquared(c1.center, c2.center);
    const radius_sum = c1.radius + c2.radius;
    return distance_sq <= radius_sum * radius_sum;
}

/// Simple circle collision check using positions and radii
pub fn checkCircleCollision(pos1: Vec2, radius1: f32, pos2: Vec2, radius2: f32) bool {
    const distance_sq = math.distanceSquared(pos1, pos2);
    const radius_sum = radius1 + radius2;
    return distance_sq < radius_sum * radius_sum;
}

/// Circle-rectangle collision detection
pub fn circleRectangle(circle: Circle, rect: Rectangle) bool {
    // Find closest point on rectangle to circle center
    const closest_x = math.clamp(circle.center.x, rect.position.x, rect.position.x + rect.size.x);
    const closest_y = math.clamp(circle.center.y, rect.position.y, rect.position.y + rect.size.y);

    const closest_point = Vec2{ .x = closest_x, .y = closest_y };
    const distance_sq = math.distanceSquared(circle.center, closest_point);

    return distance_sq <= circle.radius * circle.radius;
}

/// Circle-point collision detection
pub fn circlePoint(circle: Circle, point: Point) bool {
    return math.distanceSquared(circle.center, point) <= circle.radius * circle.radius;
}

/// Rectangle-rectangle collision detection (AABB)
pub fn rectangleRectangle(r1: Rectangle, r2: Rectangle) bool {
    return r1.position.x < r2.position.x + r2.size.x and
        r1.position.x + r1.size.x > r2.position.x and
        r1.position.y < r2.position.y + r2.size.y and
        r1.position.y + r1.size.y > r2.position.y;
}

/// Rectangle-point collision detection
pub fn rectanglePoint(rect: Rectangle, point: Point) bool {
    return rect.contains(point);
}

/// Point-point collision detection (exact match)
pub fn pointPoint(p1: Point, p2: Point) bool {
    return math.vec2_isEqual(p1, p2, 0.001); // Small tolerance for floating point
}

/// Collision result with additional information
pub const CollisionResult = struct {
    collided: bool,
    penetration_depth: f32 = 0.0,
    normal: Vec2 = Vec2.ZERO, // Direction to separate shapes
    contact_point: Vec2 = Vec2.ZERO,
};

/// Advanced collision detection with detailed result information
pub fn checkCollisionDetailed(shape1: Shape, shape2: Shape) CollisionResult {
    return switch (shape1) {
        .circle => |c1| switch (shape2) {
            .circle => |c2| circleCircleDetailed(c1, c2),
            .rectangle => |r2| circleRectangleDetailed(c1, r2),
            .point => |p2| circlePointDetailed(c1, p2),
        },
        .rectangle => |r1| switch (shape2) {
            .circle => |c2| {
                var result = circleRectangleDetailed(c2, r1);
                // Flip normal for symmetric case
                result.normal = math.vec2_multiply(result.normal, -1.0);
                return result;
            },
            .rectangle => |r2| rectangleRectangleDetailed(r1, r2),
            .point => |p2| rectanglePointDetailed(r1, p2),
        },
        .point => |p1| switch (shape2) {
            .circle => |c2| {
                var result = circlePointDetailed(c2, p1);
                result.normal = math.multiply(result.normal, -1.0);
                return result;
            },
            .rectangle => |r2| {
                var result = rectanglePointDetailed(r2, p1);
                result.normal = math.multiply(result.normal, -1.0);
                return result;
            },
            .point => |p2| pointPointDetailed(p1, p2),
        },
    };
}

fn circleCircleDetailed(c1: Shape.Circle, c2: Shape.Circle) CollisionResult {
    const distance = math.distance(c1.center, c2.center);
    const radius_sum = c1.radius + c2.radius;

    if (distance > radius_sum) {
        return CollisionResult{ .collided = false };
    }

    const penetration = radius_sum - distance;
    const normal = if (distance > 0.001)
        math.direction(c1.center, c2.center)
    else
        Vec2{ .x = 1, .y = 0 }; // Default normal if centers overlap

    const contact_point = math.add(c1.center, math.multiply(normal, c1.radius - penetration / 2.0));

    return CollisionResult{
        .collided = true,
        .penetration_depth = penetration,
        .normal = normal,
        .contact_point = contact_point,
    };
}

fn circleRectangleDetailed(circle: Shape.Circle, rect: Shape.Rectangle) CollisionResult {
    const closest_x = math.clamp(circle.center.x, rect.position.x, rect.position.x + rect.size.x);
    const closest_y = math.clamp(circle.center.y, rect.position.y, rect.position.y + rect.size.y);
    const closest_point = Vec2{ .x = closest_x, .y = closest_y };

    const distance = math.distance(circle.center, closest_point);

    if (distance > circle.radius) {
        return CollisionResult{ .collided = false };
    }

    const penetration = circle.radius - distance;
    const normal = if (distance > 0.001)
        math.direction(closest_point, circle.center)
    else
        Vec2{ .x = 0, .y = -1 }; // Default normal from top of rectangle

    return CollisionResult{
        .collided = true,
        .penetration_depth = penetration,
        .normal = normal,
        .contact_point = closest_point,
    };
}

fn circlePointDetailed(circle: Shape.Circle, point: Shape.Point) CollisionResult {
    const distance = math.distance(circle.center, point.position);

    if (distance > circle.radius) {
        return CollisionResult{ .collided = false };
    }

    const penetration = circle.radius - distance;
    const normal = if (distance > 0.001)
        math.direction(point.position, circle.center)
    else
        Vec2{ .x = 1, .y = 0 };

    return CollisionResult{
        .collided = true,
        .penetration_depth = penetration,
        .normal = normal,
        .contact_point = point.position,
    };
}

fn rectangleRectangleDetailed(r1: Shape.Rectangle, r2: Shape.Rectangle) CollisionResult {
    if (!rectangleRectangle(r1, r2)) {
        return CollisionResult{ .collided = false };
    }

    // Calculate overlap amounts
    const overlap_x = @min(r1.position.x + r1.size.x, r2.position.x + r2.size.x) - @max(r1.position.x, r2.position.x);
    const overlap_y = @min(r1.position.y + r1.size.y, r2.position.y + r2.size.y) - @max(r1.position.y, r2.position.y);

    // Use minimum overlap as penetration depth
    const penetration = @min(overlap_x, overlap_y);

    // Normal points from r1 to r2 along minimum separation axis
    const normal = if (overlap_x < overlap_y)
        Vec2{ .x = if (r1.center().x < r2.center().x) @as(f32, -1) else 1, .y = 0 }
    else
        Vec2{ .x = 0, .y = if (r1.center().y < r2.center().y) @as(f32, -1) else 1 };

    const contact_x = @max(r1.position.x, r2.position.x) + overlap_x / 2.0;
    const contact_y = @max(r1.position.y, r2.position.y) + overlap_y / 2.0;

    return CollisionResult{
        .collided = true,
        .penetration_depth = penetration,
        .normal = normal,
        .contact_point = Vec2{ .x = contact_x, .y = contact_y },
    };
}

fn rectanglePointDetailed(rect: Shape.Rectangle, point: Shape.Point) CollisionResult {
    if (!rect.contains(point.position)) {
        return CollisionResult{ .collided = false };
    }

    // Calculate distances to each edge
    const left_dist = point.position.x - rect.position.x;
    const right_dist = (rect.position.x + rect.size.x) - point.position.x;
    const top_dist = point.position.y - rect.position.y;
    const bottom_dist = (rect.position.y + rect.size.y) - point.position.y;

    // Find minimum distance (penetration depth)
    const min_dist = @min(@min(left_dist, right_dist), @min(top_dist, bottom_dist));

    // Normal points away from closest edge
    const normal = if (min_dist == left_dist) Vec2{ .x = -1, .y = 0 } else if (min_dist == right_dist) Vec2{ .x = 1, .y = 0 } else if (min_dist == top_dist) Vec2{ .x = 0, .y = -1 } else Vec2{ .x = 0, .y = 1 };

    return CollisionResult{
        .collided = true,
        .penetration_depth = min_dist,
        .normal = normal,
        .contact_point = point.position,
    };
}

fn pointPointDetailed(p1: Shape.Point, p2: Shape.Point) CollisionResult {
    const distance = math.distance(p1.position, p2.position);
    const tolerance = 0.001;

    if (distance > tolerance) {
        return CollisionResult{ .collided = false };
    }

    return CollisionResult{
        .collided = true,
        .penetration_depth = tolerance - distance,
        .normal = Vec2{ .x = 1, .y = 0 }, // Arbitrary normal for point collision
        .contact_point = p1.position,
    };
}

/// Batch collision detection for multiple shapes
pub const CollisionBatch = struct {
    shapes: []Shape,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !CollisionBatch {
        return CollisionBatch{
            .shapes = try allocator.alloc(Shape, capacity),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CollisionBatch) void {
        self.allocator.free(self.shapes);
    }

    /// Check all pairwise collisions
    pub fn checkAllCollisions(self: *const CollisionBatch, results: []bool) void {
        std.debug.assert(results.len >= self.shapes.len * self.shapes.len);

        for (self.shapes, 0..) |shape1, i| {
            for (self.shapes, 0..) |shape2, j| {
                if (i != j) {
                    results[i * self.shapes.len + j] = checkCollision(shape1, shape2);
                } else {
                    results[i * self.shapes.len + j] = false; // Don't collide with self
                }
            }
        }
    }

    /// Check collision against a single shape
    pub fn checkAgainstShape(self: *const CollisionBatch, target: Shape, results: []bool) void {
        std.debug.assert(results.len >= self.shapes.len);

        for (self.shapes, 0..) |shape, i| {
            results[i] = checkCollision(shape, target);
        }
    }
};

/// Spatial partitioning for efficient collision detection (simple grid)
pub const SpatialGrid = struct {
    grid_size: f32,
    bounds: Shape.Rectangle,
    cells: []std.ArrayList(usize), // Each cell contains indices of shapes
    allocator: std.mem.Allocator,
    width: usize,
    height: usize,

    pub fn init(allocator: std.mem.Allocator, bounds: Shape.Rectangle, grid_size: f32) !SpatialGrid {
        const width = @as(usize, @intFromFloat(@ceil(bounds.size.x / grid_size)));
        const height = @as(usize, @intFromFloat(@ceil(bounds.size.y / grid_size)));
        const total_cells = width * height;

        const cells = try allocator.alloc(std.ArrayList(usize), total_cells);
        for (cells) |*cell| {
            cell.* = std.ArrayList(usize).init(allocator);
        }

        return SpatialGrid{
            .grid_size = grid_size,
            .bounds = bounds,
            .cells = cells,
            .allocator = allocator,
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: *SpatialGrid) void {
        for (self.cells) |*cell| {
            cell.deinit();
        }
        self.allocator.free(self.cells);
    }

    fn getCellIndex(self: *const SpatialGrid, x: usize, y: usize) usize {
        return y * self.width + x;
    }

    fn worldToGrid(self: *const SpatialGrid, world_pos: Vec2) struct { x: usize, y: usize } {
        const relative_x = world_pos.x - self.bounds.position.x;
        const relative_y = world_pos.y - self.bounds.position.y;
        const grid_x = @as(usize, @intFromFloat(@max(0, @min(@as(f32, @floatFromInt(self.width - 1)), relative_x / self.grid_size))));
        const grid_y = @as(usize, @intFromFloat(@max(0, @min(@as(f32, @floatFromInt(self.height - 1)), relative_y / self.grid_size))));
        return .{ .x = grid_x, .y = grid_y };
    }

    pub fn clear(self: *SpatialGrid) void {
        for (self.cells) |*cell| {
            cell.clearRetainingCapacity();
        }
    }

    pub fn addShape(self: *SpatialGrid, shape_index: usize, shape: Shape) !void {
        // Add shape to all cells it overlaps
        const min_pos = switch (shape) {
            .circle => |c| Vec2{ .x = c.center.x - c.radius, .y = c.center.y - c.radius },
            .rectangle => |r| r.position,
            .point => |p| p.position,
        };

        const max_pos = switch (shape) {
            .circle => |c| Vec2{ .x = c.center.x + c.radius, .y = c.center.y + c.radius },
            .rectangle => |r| Vec2{ .x = r.position.x + r.size.x, .y = r.position.y + r.size.y },
            .point => |p| p.position,
        };

        const min_grid = self.worldToGrid(min_pos);
        const max_grid = self.worldToGrid(max_pos);

        var y = min_grid.y;
        while (y <= max_grid.y) : (y += 1) {
            var x = min_grid.x;
            while (x <= max_grid.x) : (x += 1) {
                const cell_index = self.getCellIndex(x, y);
                try self.cells[cell_index].append(shape_index);
            }
        }
    }

    pub fn getNeighbors(self: *const SpatialGrid, shape: Shape, neighbors: *std.ArrayList(usize)) !void {
        neighbors.clearRetainingCapacity();

        const center = switch (shape) {
            .circle => |c| c.center,
            .rectangle => |r| r.center(),
            .point => |p| p.position,
        };

        const grid_pos = self.worldToGrid(center);
        const cell_index = self.getCellIndex(grid_pos.x, grid_pos.y);

        // Add all shapes in the same cell
        for (self.cells[cell_index].items) |shape_index| {
            try neighbors.append(shape_index);
        }

        // Also check adjacent cells for shapes that might overlap
        const adjacent_offsets = [_]struct { dx: i32, dy: i32 }{
            .{ .dx = -1, .dy = -1 }, .{ .dx = 0, .dy = -1 }, .{ .dx = 1, .dy = -1 },
            .{ .dx = -1, .dy = 0 },  .{ .dx = 1, .dy = 0 },  .{ .dx = -1, .dy = 1 },
            .{ .dx = 0, .dy = 1 },   .{ .dx = 1, .dy = 1 },
        };

        for (adjacent_offsets) |offset| {
            const adj_x = @as(i32, @intCast(grid_pos.x)) + offset.dx;
            const adj_y = @as(i32, @intCast(grid_pos.y)) + offset.dy;

            if (adj_x >= 0 and adj_x < self.width and adj_y >= 0 and adj_y < self.height) {
                const adj_cell_index = self.getCellIndex(@intCast(adj_x), @intCast(adj_y));
                for (self.cells[adj_cell_index].items) |shape_index| {
                    try neighbors.append(shape_index);
                }
            }
        }
    }
};

/// Convenience functions for common collision queries
/// Check if a position is safe to move to (no collisions with obstacles)
pub fn isPositionSafe(
    pos: Vec2,
    radius: f32,
    obstacles: []const Shape,
) bool {
    const entity_shape = Shape{ .circle = .{ .center = pos, .radius = radius } };

    for (obstacles) |obstacle| {
        if (checkCollision(entity_shape, obstacle)) {
            return false;
        }
    }
    return true;
}

/// Find the nearest obstacle to a position
pub fn findNearestObstacle(
    pos: Vec2,
    obstacles: []const Shape,
) ?struct { index: usize, distance_sq: f32 } {
    var nearest_index: ?usize = null;
    var nearest_distance_sq: f32 = std.math.inf(f32);

    for (obstacles, 0..) |obstacle, i| {
        const obstacle_center = switch (obstacle) {
            .circle => |c| c.center,
            .rectangle => |r| r.center(),
            .point => |p| p.position,
            .line => continue, // Skip line segments for now
        };

        const dist_sq = math.distanceSquared(pos, obstacle_center);
        if (dist_sq < nearest_distance_sq) {
            nearest_distance_sq = dist_sq;
            nearest_index = i;
        }
    }

    if (nearest_index) |index| {
        return .{ .index = index, .distance_sq = nearest_distance_sq };
    }
    return null;
}

/// Check collision between a moving circle and static obstacles
pub fn checkMovingCircleCollision(
    start_pos: Vec2,
    end_pos: Vec2,
    radius: f32,
    obstacles: []const Shape,
) ?Vec2 {
    // Simple approach: check multiple points along the path
    const step_count = 10;
    const step = end_pos.sub(start_pos).scale(1.0 / @as(f32, @floatFromInt(step_count)));

    var current_pos = start_pos;
    for (0..step_count + 1) |_| {
        if (!isPositionSafe(current_pos, radius, obstacles)) {
            return current_pos; // First collision point
        }
        current_pos = current_pos.add(step);
    }

    return null; // No collision
}

/// Resolve collision by pushing an entity out of an obstacle
pub fn resolveCollision(
    entity_pos: Vec2,
    entity_radius: f32,
    obstacle: Shape,
) ?Vec2 {
    const entity_shape = Shape{ .circle = .{ .center = entity_pos, .radius = entity_radius } };
    const result = checkCollisionDetailed(entity_shape, obstacle);

    if (!result.collided) return null;

    // Push entity out along collision normal
    const push_distance = result.penetration_depth + 0.01; // Small buffer
    const corrected_pos = entity_pos.add(result.normal.scale(push_distance));

    return corrected_pos;
}
