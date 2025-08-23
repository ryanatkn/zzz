/// Spatial grid system for efficient spatial partitioning and queries
const std = @import("std");
const math = @import("../../math/mod.zig");

const Vec2 = math.Vec2;

// ========================
// GRID COORDINATES
// ========================

/// Grid-based coordinate system for spatial partitioning
pub const GridCoordinates = struct {
    cell_size: f32,

    pub fn init(cell_size: f32) GridCoordinates {
        return .{ .cell_size = cell_size };
    }

    /// Convert world position to grid cell coordinates
    pub fn worldToGrid(self: GridCoordinates, world_pos: Vec2) Vec2 {
        return Vec2{
            .x = @floor(world_pos.x / self.cell_size),
            .y = @floor(world_pos.y / self.cell_size),
        };
    }

    /// Convert grid cell coordinates to world position (cell center)
    pub fn gridToWorld(self: GridCoordinates, grid_pos: Vec2) Vec2 {
        return Vec2{
            .x = grid_pos.x * self.cell_size + self.cell_size / 2.0,
            .y = grid_pos.y * self.cell_size + self.cell_size / 2.0,
        };
    }

    /// Get world position of grid cell corner (top-left)
    pub fn gridCornerToWorld(self: GridCoordinates, grid_pos: Vec2) Vec2 {
        return Vec2{
            .x = grid_pos.x * self.cell_size,
            .y = grid_pos.y * self.cell_size,
        };
    }

    /// Get all grid cells that intersect with a circle
    pub fn getCellsInRadius(self: GridCoordinates, center: Vec2, radius: f32, allocator: std.mem.Allocator) !std.ArrayList(Vec2) {
        var cells = std.ArrayList(Vec2).init(allocator);

        const center_cell = self.worldToGrid(center);
        const cell_radius = @ceil(radius / self.cell_size);

        var y: f32 = center_cell.y - cell_radius;
        while (y <= center_cell.y + cell_radius) : (y += 1) {
            var x: f32 = center_cell.x - cell_radius;
            while (x <= center_cell.x + cell_radius) : (x += 1) {
                const cell_world_pos = self.gridToWorld(Vec2{ .x = x, .y = y });
                const diff = cell_world_pos.sub(center);
                const distance = diff.length();

                // Include cells if they're within radius + diagonal distance to cell corner
                if (distance <= radius + self.cell_size * std.math.sqrt2) {
                    try cells.append(Vec2{ .x = x, .y = y });
                }
            }
        }

        return cells;
    }

    /// Get all grid cells that intersect with a rectangle
    pub fn getCellsInRect(self: GridCoordinates, pos: Vec2, size: Vec2, allocator: std.mem.Allocator) !std.ArrayList(Vec2) {
        var cells = std.ArrayList(Vec2).init(allocator);

        const min_cell = self.worldToGrid(pos);
        const max_cell = self.worldToGrid(pos.add(size));

        var y: f32 = min_cell.y;
        while (y <= max_cell.y) : (y += 1) {
            var x: f32 = min_cell.x;
            while (x <= max_cell.x) : (x += 1) {
                try cells.append(Vec2{ .x = x, .y = y });
            }
        }

        return cells;
    }

    /// Check if two grid positions are adjacent (including diagonally)
    pub fn areAdjacent(grid_pos1: Vec2, grid_pos2: Vec2) bool {
        const dx = @abs(grid_pos1.x - grid_pos2.x);
        const dy = @abs(grid_pos1.y - grid_pos2.y);

        return dx <= 1 and dy <= 1 and (dx != 0 or dy != 0);
    }

    /// Get Manhattan distance between two grid positions
    pub fn manhattanDistance(grid_pos1: Vec2, grid_pos2: Vec2) f32 {
        return @abs(grid_pos1.x - grid_pos2.x) + @abs(grid_pos1.y - grid_pos2.y);
    }

    /// Get Chebyshev distance (max of x, y differences) between grid positions
    pub fn chebyshevDistance(grid_pos1: Vec2, grid_pos2: Vec2) f32 {
        const dx = @abs(grid_pos1.x - grid_pos2.x);
        const dy = @abs(grid_pos1.y - grid_pos2.y);
        return @max(dx, dy);
    }
};

// ========================
// SPATIAL HASH GRID
// ========================

/// Simple spatial hash for object tracking
pub const SpatialHash = struct {
    cell_size: f32,
    grid_width: u32,
    grid_height: u32,
    cells: []std.ArrayList(u32), // Object IDs per cell
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, world_width: f32, world_height: f32, cell_size: f32) !SpatialHash {
        const grid_width = @as(u32, @intFromFloat(@ceil(world_width / cell_size)));
        const grid_height = @as(u32, @intFromFloat(@ceil(world_height / cell_size)));

        const cells = try allocator.alloc(std.ArrayList(u32), grid_width * grid_height);
        for (cells) |*cell| {
            cell.* = std.ArrayList(u32).init(allocator);
        }

        return SpatialHash{
            .cell_size = cell_size,
            .grid_width = grid_width,
            .grid_height = grid_height,
            .cells = cells,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SpatialHash) void {
        for (self.cells) |*cell| {
            cell.deinit();
        }
        self.allocator.free(self.cells);
    }

    /// Convert world position to cell index
    fn worldToCell(self: SpatialHash, world_pos: Vec2) ?usize {
        const grid_x = @as(u32, @intFromFloat(@floor(world_pos.x / self.cell_size)));
        const grid_y = @as(u32, @intFromFloat(@floor(world_pos.y / self.cell_size)));

        if (grid_x >= self.grid_width or grid_y >= self.grid_height) {
            return null;
        }

        return grid_y * self.grid_width + grid_x;
    }

    /// Add object to spatial hash
    pub fn addObject(self: *SpatialHash, object_id: u32, world_pos: Vec2) !void {
        if (self.worldToCell(world_pos)) |cell_index| {
            try self.cells[cell_index].append(object_id);
        }
    }

    /// Remove object from spatial hash (expensive - searches all cells)
    pub fn removeObject(self: *SpatialHash, object_id: u32) void {
        for (self.cells) |*cell| {
            if (std.mem.indexOfScalar(u32, cell.items, object_id)) |index| {
                _ = cell.swapRemove(index);
                return; // Object found and removed
            }
        }
    }

    /// Get all objects in radius around a position
    pub fn queryRadius(self: SpatialHash, center: Vec2, radius: f32, allocator: std.mem.Allocator) !std.ArrayList(u32) {
        var results = std.ArrayList(u32).init(allocator);

        const cell_radius = @as(i32, @intFromFloat(@ceil(radius / self.cell_size)));
        const center_x = @as(i32, @intFromFloat(@floor(center.x / self.cell_size)));
        const center_y = @as(i32, @intFromFloat(@floor(center.y / self.cell_size)));

        var y: i32 = center_y - cell_radius;
        while (y <= center_y + cell_radius) : (y += 1) {
            var x: i32 = center_x - cell_radius;
            while (x <= center_x + cell_radius) : (x += 1) {
                if (x >= 0 and y >= 0 and
                    x < @as(i32, @intCast(self.grid_width)) and
                    y < @as(i32, @intCast(self.grid_height)))
                {
                    const cell_index = @as(usize, @intCast(y)) * self.grid_width + @as(usize, @intCast(x));

                    // Add all objects from this cell
                    try results.appendSlice(self.cells[cell_index].items);
                }
            }
        }

        return results;
    }

    /// Clear all objects from the spatial hash
    pub fn clear(self: *SpatialHash) void {
        for (self.cells) |*cell| {
            cell.clearAndFree();
        }
    }
};

test "grid coordinate conversions" {
    const grid = GridCoordinates.init(10.0);

    // Test world to grid conversion
    const world_pos = Vec2{ .x = 25.0, .y = 37.0 };
    const grid_pos = grid.worldToGrid(world_pos);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), grid_pos.x, 0.01); // floor(25/10) = 2
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), grid_pos.y, 0.01); // floor(37/10) = 3

    // Test grid to world conversion (center)
    const recovered_world = grid.gridToWorld(grid_pos);
    try std.testing.expectApproxEqAbs(@as(f32, 25.0), recovered_world.x, 0.01); // 2*10 + 5 = 25
    try std.testing.expectApproxEqAbs(@as(f32, 35.0), recovered_world.y, 0.01); // 3*10 + 5 = 35

    // Test grid corner conversion
    const corner_world = grid.gridCornerToWorld(grid_pos);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), corner_world.x, 0.01); // 2*10 = 20
    try std.testing.expectApproxEqAbs(@as(f32, 30.0), corner_world.y, 0.01); // 3*10 = 30
}

test "grid distance calculations" {
    const pos1 = Vec2{ .x = 0.0, .y = 0.0 };
    const pos2 = Vec2{ .x = 3.0, .y = 4.0 };

    // Test Manhattan distance
    const manhattan = GridCoordinates.manhattanDistance(pos1, pos2);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), manhattan, 0.01); // |3-0| + |4-0| = 7

    // Test Chebyshev distance
    const chebyshev = GridCoordinates.chebyshevDistance(pos1, pos2);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), chebyshev, 0.01); // max(3, 4) = 4

    // Test adjacency
    const adjacent_pos = Vec2{ .x = 1.0, .y = 1.0 };
    const non_adjacent_pos = Vec2{ .x = 2.0, .y = 2.0 };

    try std.testing.expect(GridCoordinates.areAdjacent(pos1, adjacent_pos));
    try std.testing.expect(!GridCoordinates.areAdjacent(pos1, non_adjacent_pos));
}

test "spatial hash operations" {
    const allocator = std.testing.allocator;

    var spatial_hash = try SpatialHash.init(allocator, 100.0, 100.0, 10.0);
    defer spatial_hash.deinit();

    // Add some objects
    try spatial_hash.addObject(1, Vec2{ .x = 5.0, .y = 5.0 });
    try spatial_hash.addObject(2, Vec2{ .x = 15.0, .y = 15.0 });
    try spatial_hash.addObject(3, Vec2{ .x = 85.0, .y = 85.0 });

    // Query radius around first object
    const results = try spatial_hash.queryRadius(Vec2{ .x = 5.0, .y = 5.0 }, 20.0, allocator);
    defer results.deinit();

    // Should find objects 1 and 2 (both within ~20 unit radius considering grid cells)
    try std.testing.expect(results.items.len >= 1); // At least object 1 should be found

    // Clear and verify
    spatial_hash.clear();
    const empty_results = try spatial_hash.queryRadius(Vec2{ .x = 5.0, .y = 5.0 }, 20.0, allocator);
    defer empty_results.deinit();

    try std.testing.expect(empty_results.items.len == 0);
}
