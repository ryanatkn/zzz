const std = @import("std");
const math = @import("../math/mod.zig");
const collision = @import("collision.zig");

const Vec2 = math.Vec2;

/// Generic result for spatial queries
pub const QueryResult = struct {
    found: bool,
    position: Vec2 = Vec2.ZERO,
    index: usize = 0,
    distance_squared: f32 = 0.0,
};

/// Configuration for obstacle queries
pub const ObstacleQueryConfig = struct {
    check_solid_only: bool = true,
    check_deadly_only: bool = false,
};

/// Generic obstacle data for queries
pub const ObstacleData = struct {
    position: Vec2,
    size: Vec2,
    is_solid: bool,
    is_deadly: bool,
};

/// Generic entity data for queries
pub const EntityData = struct {
    position: Vec2,
    radius: f32,
    is_alive: bool,
};

/// Physics query utilities for spatial searches and collision detection
pub const PhysicsQueries = struct {
    /// Check if a circle collides with any obstacles in a list
    pub fn checkCircleObstacleCollision(
        circle_pos: Vec2,
        circle_radius: f32,
        obstacles: []const ObstacleData,
        config: ObstacleQueryConfig,
    ) QueryResult {
        for (obstacles, 0..) |obstacle, i| {
            // Apply filtering
            if (config.check_solid_only and !obstacle.is_solid) continue;
            if (config.check_deadly_only and !obstacle.is_deadly) continue;

            const circle = collision.Shape{ .circle = .{ .center = circle_pos, .radius = circle_radius } };
            const rect = collision.Shape{ .rectangle = .{ .position = obstacle.position, .size = obstacle.size } };

            if (collision.checkCollision(circle, rect)) {
                return QueryResult{
                    .found = true,
                    .position = obstacle.position,
                    .index = i,
                    .distance_squared = math.distanceSquared(circle_pos, obstacle.position),
                };
            }
        }

        return QueryResult{ .found = false };
    }

    /// Check if a circle collides with any entities in a list
    pub fn checkCircleEntityCollision(
        circle_pos: Vec2,
        circle_radius: f32,
        entities: []const EntityData,
        check_alive_only: bool,
    ) QueryResult {
        for (entities, 0..) |entity, i| {
            if (check_alive_only and !entity.is_alive) continue;

            if (collision.checkCircleCollision(circle_pos, circle_radius, entity.position, entity.radius)) {
                return QueryResult{
                    .found = true,
                    .position = entity.position,
                    .index = i,
                    .distance_squared = math.distanceSquared(circle_pos, entity.position),
                };
            }
        }

        return QueryResult{ .found = false };
    }

    /// Find the nearest entity to a position
    pub fn findNearestEntity(
        search_pos: Vec2,
        entities: []const EntityData,
        check_alive_only: bool,
    ) QueryResult {
        var nearest_distance_sq: f32 = std.math.inf(f32);
        var nearest_result = QueryResult{ .found = false };

        for (entities, 0..) |entity, i| {
            if (check_alive_only and !entity.is_alive) continue;

            const distance_sq = math.distanceSquared(search_pos, entity.position);
            if (distance_sq < nearest_distance_sq) {
                nearest_distance_sq = distance_sq;
                nearest_result = QueryResult{
                    .found = true,
                    .position = entity.position,
                    .index = i,
                    .distance_squared = distance_sq,
                };
            }
        }

        return nearest_result;
    }

    /// Find the nearest obstacle to a position
    pub fn findNearestObstacle(
        search_pos: Vec2,
        obstacles: []const ObstacleData,
        config: ObstacleQueryConfig,
    ) QueryResult {
        var nearest_distance_sq: f32 = std.math.inf(f32);
        var nearest_result = QueryResult{ .found = false };

        for (obstacles, 0..) |obstacle, i| {
            // Apply filtering
            if (config.check_solid_only and !obstacle.is_solid) continue;
            if (config.check_deadly_only and !obstacle.is_deadly) continue;

            const distance_sq = math.distanceSquared(search_pos, obstacle.position);
            if (distance_sq < nearest_distance_sq) {
                nearest_distance_sq = distance_sq;
                nearest_result = QueryResult{
                    .found = true,
                    .position = obstacle.position,
                    .index = i,
                    .distance_squared = distance_sq,
                };
            }
        }

        return nearest_result;
    }

    /// Check if a position is safe (no collision with deadly obstacles)
    pub fn isPositionSafe(
        pos: Vec2,
        radius: f32,
        obstacles: []const ObstacleData,
    ) bool {
        const config = ObstacleQueryConfig{ .check_deadly_only = true };
        const result = checkCircleObstacleCollision(pos, radius, obstacles, config);
        return !result.found;
    }

    /// Check if movement to a position is valid
    pub fn canMoveTo(
        to_pos: Vec2,
        radius: f32,
        obstacles: []const ObstacleData,
    ) bool {
        const config = ObstacleQueryConfig{ .check_solid_only = true };
        const result = checkCircleObstacleCollision(to_pos, radius, obstacles, config);
        return !result.found;
    }

    /// Find entities within a radius
    pub fn findEntitiesInRadius(
        allocator: std.mem.Allocator,
        search_pos: Vec2,
        radius: f32,
        entities: []const EntityData,
        check_alive_only: bool,
    ) !std.ArrayList(usize) {
        var results = std.ArrayList(usize).init(allocator);
        const radius_sq = radius * radius;

        for (entities, 0..) |entity, i| {
            if (check_alive_only and !entity.is_alive) continue;

            const distance_sq = math.distanceSquared(search_pos, entity.position);
            if (distance_sq <= radius_sq) {
                try results.append(i);
            }
        }

        return results;
    }

    /// Get all entities within a rectangular area
    pub fn findEntitiesInRect(
        allocator: std.mem.Allocator,
        rect_pos: Vec2,
        rect_size: Vec2,
        entities: []const EntityData,
        check_alive_only: bool,
    ) !std.ArrayList(usize) {
        var results = std.ArrayList(usize).init(allocator);

        const min_x = rect_pos.x - rect_size.x / 2.0;
        const max_x = rect_pos.x + rect_size.x / 2.0;
        const min_y = rect_pos.y - rect_size.y / 2.0;
        const max_y = rect_pos.y + rect_size.y / 2.0;

        for (entities, 0..) |entity, i| {
            if (check_alive_only and !entity.is_alive) continue;

            if (entity.position.x >= min_x and entity.position.x <= max_x and
                entity.position.y >= min_y and entity.position.y <= max_y)
            {
                try results.append(i);
            }
        }

        return results;
    }
};

test "obstacle collision detection" {
    const obstacles = [_]ObstacleData{
        .{ .position = Vec2{ .x = 0, .y = 0 }, .size = Vec2{ .x = 10, .y = 10 }, .is_solid = true, .is_deadly = false },
        .{ .position = Vec2{ .x = 50, .y = 50 }, .size = Vec2{ .x = 10, .y = 10 }, .is_solid = false, .is_deadly = true },
    };

    const config_solid = ObstacleQueryConfig{ .check_solid_only = true, .check_deadly_only = false };
    const config_deadly = ObstacleQueryConfig{ .check_solid_only = false, .check_deadly_only = true };

    // Test collision with solid obstacle
    const result1 = PhysicsQueries.checkCircleObstacleCollision(Vec2{ .x = 5, .y = 5 }, 2.0, &obstacles, config_solid);
    try std.testing.expect(result1.found);

    // Test no collision with non-solid obstacle when checking solid only
    const result2 = PhysicsQueries.checkCircleObstacleCollision(Vec2{ .x = 50, .y = 50 }, 2.0, &obstacles, config_solid);
    try std.testing.expect(!result2.found);

    // Test collision with deadly obstacle
    const result3 = PhysicsQueries.checkCircleObstacleCollision(Vec2{ .x = 50, .y = 50 }, 2.0, &obstacles, config_deadly);
    try std.testing.expect(result3.found);
}

test "entity queries" {
    const entities = [_]EntityData{
        .{ .position = Vec2{ .x = 0, .y = 0 }, .radius = 5.0, .is_alive = true },
        .{ .position = Vec2{ .x = 10, .y = 10 }, .radius = 3.0, .is_alive = false },
        .{ .position = Vec2{ .x = 20, .y = 20 }, .radius = 4.0, .is_alive = true },
    };

    // Test finding nearest alive entity
    const nearest = PhysicsQueries.findNearestEntity(Vec2{ .x = 1, .y = 1 }, &entities, true);
    try std.testing.expect(nearest.found);
    try std.testing.expect(nearest.index == 0);

    // Test collision detection
    const collision_result = PhysicsQueries.checkCircleEntityCollision(Vec2{ .x = 2, .y = 2 }, 4.0, &entities, true);
    try std.testing.expect(collision_result.found);
    try std.testing.expect(collision_result.index == 0);
}

test "area queries" {
    const allocator = std.testing.allocator;

    const entities = [_]EntityData{
        .{ .position = Vec2{ .x = 0, .y = 0 }, .radius = 1.0, .is_alive = true },
        .{ .position = Vec2{ .x = 5, .y = 5 }, .radius = 1.0, .is_alive = true },
        .{ .position = Vec2{ .x = 15, .y = 15 }, .radius = 1.0, .is_alive = true },
    };

    // Test radius query
    var results = try PhysicsQueries.findEntitiesInRadius(allocator, Vec2{ .x = 0, .y = 0 }, 8.0, &entities, true);
    defer results.deinit();

    try std.testing.expect(results.items.len == 2); // Should find entities at (0,0) and (5,5)

    // Test rectangular area query - rectangle from (2.5,2.5) to (17.5,17.5) to include (5,5) and (15,15) but not (0,0)
    var rect_results = try PhysicsQueries.findEntitiesInRect(allocator, Vec2{ .x = 10, .y = 10 }, Vec2{ .x = 15, .y = 15 }, &entities, true);
    defer rect_results.deinit();

    try std.testing.expect(rect_results.items.len == 2); // Should find entities at (5,5) and (15,15)
}
