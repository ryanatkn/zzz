//! Spatial partitioning for efficient collision detection
//!
//! Provides SpatialGrid for accelerating broad-phase collision detection
//! by dividing 2D space into a grid structure.

const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("types.zig");

const Vec2 = math.Vec2;
const Shape = types.Shape;
const Rectangle = types.Rectangle;

/// Spatial partitioning for efficient collision detection (simple grid)
///
/// Divides 2D space into a grid to accelerate broad-phase collision detection.
/// Instead of checking all N*(N-1)/2 pairs (O(N²)), only check objects
/// in nearby grid cells, reducing complexity significantly.
///
/// Best for:
/// - Large numbers of objects (100+)
/// - Objects roughly similar in size
/// - Objects distributed across space
///
/// Grid size should be ~2x the size of typical objects.
///
/// Example:
/// ```zig
/// var grid = try SpatialGrid.init(allocator, bounds, 32.0);
/// defer grid.deinit();
///
/// // Add shapes to grid
/// try grid.addShape(0, .{ .circle = player_circle });
/// try grid.addShape(1, .{ .rectangle = wall_rect });
///
/// // Query nearby shapes
/// var nearby = try grid.queryNearby(query_point, query_radius, allocator);
/// ```
pub const SpatialGrid = struct {
    grid_size: f32,
    bounds: Rectangle,
    cells: []std.ArrayList(usize), // Each cell contains indices of shapes
    allocator: std.mem.Allocator,
    width: usize,
    height: usize,

    pub fn init(allocator: std.mem.Allocator, bounds: Rectangle, grid_size: f32) !SpatialGrid {
        // Input validation - grid size must be positive, bounds must be non-negative
        if (grid_size <= 0.0 or bounds.size.x < 0.0 or bounds.size.y < 0.0) {
            return error.InvalidGridParameters;
        }

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

    inline fn getCellIndex(self: *const SpatialGrid, x: usize, y: usize) usize {
        return y * self.width + x;
    }

    inline fn worldToGrid(self: *const SpatialGrid, world_pos: Vec2) struct { x: usize, y: usize } {
        // Cache bounds to avoid repeated member access
        const bounds_x = self.bounds.position.x;
        const bounds_y = self.bounds.position.y;
        const inv_grid_size = 1.0 / self.grid_size; // Multiply instead of divide

        const relative_x = world_pos.x - bounds_x;
        const relative_y = world_pos.y - bounds_y;

        // Use multiplication instead of division for performance
        const grid_x = @as(usize, @intFromFloat(@max(0, @min(@as(f32, @floatFromInt(self.width - 1)), relative_x * inv_grid_size))));
        const grid_y = @as(usize, @intFromFloat(@max(0, @min(@as(f32, @floatFromInt(self.height - 1)), relative_y * inv_grid_size))));
        return .{ .x = grid_x, .y = grid_y };
    }

    pub fn clear(self: *SpatialGrid) void {
        for (self.cells) |*cell| {
            cell.clearRetainingCapacity();
        }
    }

    pub fn addShape(self: *SpatialGrid, shape_index: usize, shape: Shape) !void {
        // Pre-calculate shape bounds to avoid repeated switch evaluations
        const bounds: types.Bounds = switch (shape) {
            .circle => |c| types.Bounds.init(
                c.center.x - c.radius,
                c.center.y - c.radius,
                c.center.x + c.radius,
                c.center.y + c.radius,
            ),
            .rectangle => |r| types.Bounds.init(
                r.position.x,
                r.position.y,
                r.position.x + r.size.x,
                r.position.y + r.size.y,
            ),
            .point => |p| types.Bounds.init(p.x, p.y, p.x, p.y),
            .line => |l| types.Bounds.fromPoints(l.start, l.end),
        };

        const min_grid = self.worldToGrid(bounds.getMin());
        const max_grid = self.worldToGrid(bounds.getMax());

        // Cache width to avoid member access in inner loop
        const width = self.width;

        var y = min_grid.y;
        while (y <= max_grid.y) : (y += 1) {
            // Calculate base cell index for this row once
            const row_base = y * width;
            var x = min_grid.x;
            while (x <= max_grid.x) : (x += 1) {
                const cell_index = row_base + x;
                try self.cells[cell_index].append(shape_index);
            }
        }
    }

    pub fn getNeighbors(self: *const SpatialGrid, shape: Shape, neighbors: *std.ArrayList(usize)) !void {
        neighbors.clearRetainingCapacity();

        const center = switch (shape) {
            .circle => |c| c.center,
            .rectangle => |r| r.center(),
            .point => |p| p,
            .line => |l| l.midpoint(),
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

// Tests for spatial grid functionality
test "spatial grid creation and basic operations" {
    const allocator = std.testing.allocator;
    const bounds = Rectangle.fromXYWH(0.0, 0.0, 100.0, 100.0);

    var grid = try SpatialGrid.init(allocator, bounds, 10.0);
    defer grid.deinit();

    // Grid should be created successfully
    try std.testing.expect(grid.width == 10);
    try std.testing.expect(grid.height == 10);
    try std.testing.expect(grid.grid_size == 10.0);
}

test "spatial grid shape addition and neighbor queries" {
    const allocator = std.testing.allocator;
    const bounds = Rectangle.fromXYWH(0.0, 0.0, 100.0, 100.0);

    var grid = try SpatialGrid.init(allocator, bounds, 20.0);
    defer grid.deinit();

    // Add some shapes
    const circle1 = Shape{ .circle = types.Circle{ .center = Vec2.init(10.0, 10.0), .radius = 5.0 } };
    const circle2 = Shape{ .circle = types.Circle{ .center = Vec2.init(30.0, 30.0), .radius = 5.0 } };
    const rect1 = Shape{ .rectangle = Rectangle.fromXYWH(50.0, 50.0, 10.0, 10.0) };

    try grid.addShape(0, circle1);
    try grid.addShape(1, circle2);
    try grid.addShape(2, rect1);

    // Query neighbors
    var neighbors = std.ArrayList(usize).init(allocator);
    defer neighbors.deinit();

    try grid.getNeighbors(circle1, &neighbors);
    try std.testing.expect(neighbors.items.len > 0);
}

test "spatial grid world to grid coordinate conversion" {
    const allocator = std.testing.allocator;
    const bounds = Rectangle.fromXYWH(0.0, 0.0, 100.0, 100.0);

    var grid = try SpatialGrid.init(allocator, bounds, 10.0);
    defer grid.deinit();

    // Test coordinate conversion
    const grid_pos1 = grid.worldToGrid(Vec2.init(5.0, 5.0));
    const grid_pos2 = grid.worldToGrid(Vec2.init(15.0, 25.0));

    try std.testing.expect(grid_pos1.x == 0 and grid_pos1.y == 0);
    try std.testing.expect(grid_pos2.x == 1 and grid_pos2.y == 2);
}

test "spatial grid invalid parameters" {
    const allocator = std.testing.allocator;

    // Invalid grid size should return error
    const bounds = Rectangle.fromXYWH(0.0, 0.0, 100.0, 100.0);
    const result = SpatialGrid.init(allocator, bounds, 0.0);
    try std.testing.expectError(error.InvalidGridParameters, result);
}

test "spatial grid performance with many shapes" {
    const allocator = std.testing.allocator;
    const bounds = Rectangle.fromXYWH(0.0, 0.0, 1000.0, 1000.0);

    var grid = try SpatialGrid.init(allocator, bounds, 50.0);
    defer grid.deinit();

    // Add many shapes in a grid pattern
    const shape_count = 100;
    var shapes: [shape_count]Shape = undefined;

    for (0..shape_count) |i| {
        const x = @as(f32, @floatFromInt(i % 10)) * 100.0 + 25.0;
        const y = @as(f32, @floatFromInt(i / 10)) * 100.0 + 25.0;
        shapes[i] = Shape{ .circle = types.Circle{ .center = Vec2.init(x, y), .radius = 10.0 } };
        try grid.addShape(i, shapes[i]);
    }

    // Test neighbor queries (should be much faster than O(N) brute force)
    var neighbors = std.ArrayList(usize).init(allocator);
    defer neighbors.deinit();

    // Query neighbors for several shapes
    for (0..10) |i| {
        neighbors.clearRetainingCapacity();
        try grid.getNeighbors(shapes[i], &neighbors);

        // Each shape should have a reasonable number of neighbors (not all shapes)
        try std.testing.expect(neighbors.items.len > 0);
        try std.testing.expect(neighbors.items.len < shape_count); // Should be much less than total
    }
}

test "spatial grid memory efficiency" {
    const allocator = std.testing.allocator;
    const bounds = Rectangle.fromXYWH(0.0, 0.0, 100.0, 100.0);

    // Test with different grid sizes to verify memory usage scales appropriately
    const grid_sizes = [_]f32{ 10.0, 20.0, 50.0 };

    for (grid_sizes) |grid_size| {
        var grid = try SpatialGrid.init(allocator, bounds, grid_size);
        defer grid.deinit();

        // Grid cell count should be inversely related to grid size
        const expected_cells = @ceil(bounds.size.x / grid_size) * @ceil(bounds.size.y / grid_size);
        const actual_cells = @as(f32, @floatFromInt(grid.width * grid.height));

        try std.testing.expect(@abs(actual_cells - expected_cells) < 1.0);
    }
}

test "spatial grid scalability comparison" {
    const allocator = std.testing.allocator;
    const bounds = Rectangle.fromXYWH(0.0, 0.0, 200.0, 200.0);

    var grid = try SpatialGrid.init(allocator, bounds, 40.0);
    defer grid.deinit();

    // Test with increasing numbers of shapes
    const test_sizes = [_]usize{ 10, 50, 100 };

    for (test_sizes) |size| {
        grid.clear();

        // Add shapes in a clustered pattern to test worst-case scenarios
        for (0..size) |i| {
            const angle = @as(f32, @floatFromInt(i)) * 2.0 * std.math.pi / @as(f32, @floatFromInt(size));
            const radius = 30.0;
            const x = 100.0 + radius * @cos(angle);
            const y = 100.0 + radius * @sin(angle);

            const shape = Shape{ .circle = types.Circle{ .center = Vec2.init(x, y), .radius = 5.0 } };
            try grid.addShape(i, shape);
        }

        // Query a central shape that should find many neighbors
        const central_shape = Shape{ .circle = types.Circle{ .center = Vec2.init(100.0, 100.0), .radius = 5.0 } };

        var neighbors = std.ArrayList(usize).init(allocator);
        defer neighbors.deinit();

        try grid.getNeighbors(central_shape, &neighbors);

        // Should find a reasonable number of neighbors for clustered shapes
        try std.testing.expect(neighbors.items.len > 0);
        // But not necessarily all shapes (depends on grid cell size and clustering)
    }
}

test "spatial grid coordinate precision" {
    const allocator = std.testing.allocator;
    const bounds = Rectangle.fromXYWH(0.0, 0.0, 10.0, 10.0);

    var grid = try SpatialGrid.init(allocator, bounds, 1.0);
    defer grid.deinit();

    // Test edge cases near grid boundaries
    const edge_positions = [_]Vec2{
        Vec2.init(0.0, 0.0), // Min corner
        Vec2.init(10.0, 10.0), // Max corner
        Vec2.init(5.0, 5.0), // Center
        Vec2.init(0.999, 0.999), // Just inside grid cell
        Vec2.init(1.001, 1.001), // Just in next grid cell
    };

    for (edge_positions, 0..) |pos, i| {
        const shape = Shape{ .point = pos };
        try grid.addShape(i, shape);

        // Verify the shape was added successfully
        var neighbors = std.ArrayList(usize).init(allocator);
        defer neighbors.deinit();

        try grid.getNeighbors(shape, &neighbors);

        // Should find at least itself or nearby shapes
        try std.testing.expect(neighbors.items.len > 0);
    }
}
