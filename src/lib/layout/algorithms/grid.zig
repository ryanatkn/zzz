/// CSS Grid layout algorithm implementation
///
/// This module implements a simplified CSS Grid layout algorithm with support
/// for explicit grid definitions, auto-placement, and basic grid properties.
const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../types.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;

/// Grid track sizing
pub const TrackSize = union(enum) {
    /// Fixed size in pixels
    fixed: f32,
    /// Fractional unit (share of remaining space)
    fr: f32,
    /// Minimum content size
    min_content,
    /// Maximum content size
    max_content,
    /// Auto-sizing
    auto,
    /// Fit content with max size
    fit_content: f32,
    /// Min-max range
    minmax: struct { min: TrackSize, max: TrackSize },

    /// Resolve track size to pixels
    pub fn resolve(
        self: TrackSize,
        available_space: f32,
        min_content: f32,
        max_content: f32,
    ) f32 {
        return switch (self) {
            .fixed => |size| size,
            .fr => available_space, // Will be resolved later in fr distribution
            .min_content => min_content,
            .max_content => max_content,
            .auto => @max(min_content, @min(max_content, available_space)),
            .fit_content => |max_size| @min(max_size, @max(min_content, available_space)),
            .minmax => |range| {
                const min_resolved = range.min.resolve(available_space, min_content, max_content);
                const max_resolved = range.max.resolve(available_space, min_content, max_content);
                return @max(min_resolved, @min(max_resolved, available_space));
            },
        };
    }

    /// Check if track size is flexible (fr unit)
    pub fn isFlexible(self: TrackSize) bool {
        return switch (self) {
            .fr => true,
            .minmax => |range| range.max.isFlexible(),
            else => false,
        };
    }

    /// Get fr value for flexible tracks
    pub fn getFrValue(self: TrackSize) f32 {
        return switch (self) {
            .fr => |value| value,
            .minmax => |range| range.max.getFrValue(),
            else => 0.0,
        };
    }
};

/// Grid area specification
pub const GridArea = struct {
    /// Row start (1-based, inclusive)
    row_start: u32,
    /// Row end (1-based, exclusive)
    row_end: u32,
    /// Column start (1-based, inclusive)
    column_start: u32,
    /// Column end (1-based, exclusive)
    column_end: u32,

    /// Create grid area from span notation
    pub fn span(row: u32, column: u32, row_span: u32, column_span: u32) GridArea {
        return GridArea{
            .row_start = row,
            .row_end = row + row_span,
            .column_start = column,
            .column_end = column + column_span,
        };
    }

    /// Get number of rows spanned
    pub fn getRowSpan(self: GridArea) u32 {
        return self.row_end - self.row_start;
    }

    /// Get number of columns spanned
    pub fn getColumnSpan(self: GridArea) u32 {
        return self.column_end - self.column_start;
    }
};

/// Grid layout algorithm
pub const GridLayout = struct {
    /// Grid container configuration
    pub const Config = struct {
        /// Row track definitions
        grid_template_rows: std.ArrayList(TrackSize),
        /// Column track definitions
        grid_template_columns: std.ArrayList(TrackSize),
        /// Gap between rows
        row_gap: f32 = 0.0,
        /// Gap between columns
        column_gap: f32 = 0.0,
        /// How to justify items within their grid areas
        justify_items: types.JustifyContent = .stretch,
        /// How to align items within their grid areas
        align_items: types.AlignItems = .stretch,
        /// How to justify the entire grid within the container
        justify_content: types.JustifyContent = .flex_start,
        /// How to align the entire grid within the container
        align_content: types.AlignItems = .flex_start,
        /// Auto placement algorithm
        grid_auto_flow: GridAutoFlow = .row,
        /// Auto row track sizes
        grid_auto_rows: TrackSize = .auto,
        /// Auto column track sizes
        grid_auto_columns: TrackSize = .auto,

        pub const GridAutoFlow = enum {
            row,
            column,
            row_dense,
            column_dense,
        };
    };

    /// Grid item properties
    pub const GridItem = struct {
        /// Preferred size of the item
        size: Vec2,
        /// Item margins
        margin: types.Spacing,
        /// Size constraints
        constraints: types.Constraints,
        /// Grid area placement (optional)
        grid_area: ?GridArea = null,
        /// Item alignment overrides
        justify_self: ?types.JustifyContent = null,
        align_self: ?types.AlignItems = null,
        /// Element index for results
        index: usize,
    };

    /// Calculated grid track
    const GridTrack = struct {
        size: f32,
        position: f32,
    };

    /// Perform grid layout calculation
    pub fn calculateLayout(
        container_bounds: Rectangle,
        items: []const GridItem,
        config: Config,
        allocator: std.mem.Allocator,
    ) ![]types.LayoutResult {
        if (items.len == 0) {
            return try allocator.alloc(types.LayoutResult, 0);
        }

        // Create grid structure
        var grid = try createGrid(items, config, allocator);
        defer grid.deinit();

        // Calculate track sizes
        const row_tracks = try calculateTrackSizes(
            grid.row_count,
            config.grid_template_rows,
            container_bounds.size.y,
            config.row_gap,
            config.grid_auto_rows,
            allocator,
        );
        defer allocator.free(row_tracks);

        const column_tracks = try calculateTrackSizes(
            grid.column_count,
            config.grid_template_columns,
            container_bounds.size.x,
            config.column_gap,
            config.grid_auto_columns,
            allocator,
        );
        defer allocator.free(column_tracks);

        // Place items in grid
        return try placeGridItems(
            container_bounds,
            items,
            grid,
            row_tracks,
            column_tracks,
            config,
            allocator,
        );
    }

    /// Grid structure
    const Grid = struct {
        row_count: u32,
        column_count: u32,
        item_placements: std.ArrayList(GridItemPlacement),

        fn deinit(self: *Grid) void {
            self.item_placements.deinit();
        }
    };

    /// Grid item placement
    const GridItemPlacement = struct {
        item_index: usize,
        area: GridArea,
    };

    /// Create grid structure and place items
    fn createGrid(
        items: []const GridItem,
        config: Config,
        allocator: std.mem.Allocator,
    ) !Grid {
        var grid = Grid{
            .row_count = @max(1, @as(u32, @intCast(config.grid_template_rows.items.len))),
            .column_count = @max(1, @as(u32, @intCast(config.grid_template_columns.items.len))),
            .item_placements = std.ArrayList(GridItemPlacement).init(allocator),
        };

        // Create occupancy map for auto-placement
        var occupancy_map = std.HashMap(struct { row: u32, col: u32 }, bool, struct {
            pub fn hash(self: @This(), key: struct { row: u32, col: u32 }) u64 {
                _ = self;
                return @as(u64, key.row) << 32 | @as(u64, key.col);
            }
            pub fn eql(self: @This(), a: struct { row: u32, col: u32 }, b: struct { row: u32, col: u32 }) bool {
                _ = self;
                return a.row == b.row and a.col == b.col;
            }
        }, 80).init(allocator);
        defer occupancy_map.deinit();

        // First pass: place explicitly positioned items
        for (items, 0..) |item, i| {
            if (item.grid_area) |area| {
                try grid.item_placements.append(GridItemPlacement{
                    .item_index = i,
                    .area = area,
                });

                // Update grid size if needed
                grid.row_count = @max(grid.row_count, area.row_end);
                grid.column_count = @max(grid.column_count, area.column_end);

                // Mark cells as occupied
                var row = area.row_start;
                while (row < area.row_end) : (row += 1) {
                    var col = area.column_start;
                    while (col < area.column_end) : (col += 1) {
                        try occupancy_map.put(.{ .row = row, .col = col }, true);
                    }
                }
            }
        }

        // Second pass: auto-place remaining items
        var auto_row: u32 = 1;
        var auto_col: u32 = 1;

        for (items, 0..) |item, i| {
            if (item.grid_area == null) {
                // Find next available position
                const area = try findNextAvailableArea(
                    &auto_row,
                    &auto_col,
                    1, // Default span
                    1, // Default span
                    grid.row_count,
                    grid.column_count,
                    &occupancy_map,
                    config.grid_auto_flow,
                );

                try grid.item_placements.append(GridItemPlacement{
                    .item_index = i,
                    .area = area,
                });

                // Update grid size if needed
                grid.row_count = @max(grid.row_count, area.row_end);
                grid.column_count = @max(grid.column_count, area.column_end);

                // Mark cells as occupied
                var row = area.row_start;
                while (row < area.row_end) : (row += 1) {
                    var col = area.column_start;
                    while (col < area.column_end) : (col += 1) {
                        try occupancy_map.put(.{ .row = row, .col = col }, true);
                    }
                }
            }
        }

        return grid;
    }

    /// Find next available grid area for auto-placement
    fn findNextAvailableArea(
        auto_row: *u32,
        auto_col: *u32,
        row_span: u32,
        col_span: u32,
        max_row: u32,
        max_col: u32,
        occupancy_map: *std.HashMap(struct { row: u32, col: u32 }, bool, struct {
            pub fn hash(self: @This(), key: struct { row: u32, col: u32 }) u64 {
                _ = self;
                return @as(u64, key.row) << 32 | @as(u64, key.col);
            }
            pub fn eql(self: @This(), a: struct { row: u32, col: u32 }, b: struct { row: u32, col: u32 }) bool {
                _ = self;
                return a.row == b.row and a.col == b.col;
            }
        }, 80),
        auto_flow: Config.GridAutoFlow,
    ) !GridArea {
        const is_row_flow = auto_flow == .row or auto_flow == .row_dense;

        while (true) {
            // Check if current position can fit the item
            if (canFitAt(auto_row.*, auto_col.*, row_span, col_span, occupancy_map)) {
                const area = GridArea{
                    .row_start = auto_row.*,
                    .row_end = auto_row.* + row_span,
                    .column_start = auto_col.*,
                    .column_end = auto_col.* + col_span,
                };
                return area;
            }

            // Advance to next position
            if (is_row_flow) {
                auto_col.* += 1;
                if (auto_col.* + col_span > max_col + 1) {
                    auto_col.* = 1;
                    auto_row.* += 1;
                }
            } else {
                auto_row.* += 1;
                if (auto_row.* + row_span > max_row + 1) {
                    auto_row.* = 1;
                    auto_col.* += 1;
                }
            }
        }
    }

    /// Check if item can fit at given position
    fn canFitAt(
        row: u32,
        col: u32,
        row_span: u32,
        col_span: u32,
        occupancy_map: *std.HashMap(struct { row: u32, col: u32 }, bool, struct {
            pub fn hash(self: @This(), key: struct { row: u32, col: u32 }) u64 {
                _ = self;
                return @as(u64, key.row) << 32 | @as(u64, key.col);
            }
            pub fn eql(self: @This(), a: struct { row: u32, col: u32 }, b: struct { row: u32, col: u32 }) bool {
                _ = self;
                return a.row == b.row and a.col == b.col;
            }
        }, 80),
    ) bool {
        var r = row;
        while (r < row + row_span) : (r += 1) {
            var c = col;
            while (c < col + col_span) : (c += 1) {
                if (occupancy_map.get(.{ .row = r, .col = c }) != null) {
                    return false;
                }
            }
        }
        return true;
    }

    /// Calculate track sizes for rows or columns
    fn calculateTrackSizes(
        track_count: u32,
        template_tracks: std.ArrayList(TrackSize),
        available_space: f32,
        gap: f32,
        auto_track_size: TrackSize,
        allocator: std.mem.Allocator,
    ) ![]GridTrack {
        var tracks = try allocator.alloc(GridTrack, track_count);

        // Calculate total gap space
        const total_gap = if (track_count > 1) @as(f32, @floatFromInt(track_count - 1)) * gap else 0;
        const space_for_tracks = available_space - total_gap;

        // Determine track sizes
        var total_fr: f32 = 0;
        var used_space: f32 = 0;

        for (0..track_count) |i| {
            const track_size = if (i < template_tracks.items.len)
                template_tracks.items[i]
            else
                auto_track_size;

            if (track_size.isFlexible()) {
                total_fr += track_size.getFrValue();
            } else {
                // TODO: Calculate min/max content sizes properly
                const resolved_size = track_size.resolve(space_for_tracks, 0, 100);
                tracks[i].size = resolved_size;
                used_space += resolved_size;
            }
        }

        // Distribute remaining space to fr tracks
        const remaining_space = @max(0, space_for_tracks - used_space);
        const space_per_fr = if (total_fr > 0) remaining_space / total_fr else 0;

        for (0..track_count) |i| {
            const track_size = if (i < template_tracks.items.len)
                template_tracks.items[i]
            else
                auto_track_size;

            if (track_size.isFlexible()) {
                tracks[i].size = space_per_fr * track_size.getFrValue();
            }
        }

        // Calculate positions
        var current_position: f32 = 0;
        for (tracks) |*track| {
            track.position = current_position;
            current_position += track.size + gap;
        }

        return tracks;
    }

    /// Place grid items and create layout results
    fn placeGridItems(
        container_bounds: Rectangle,
        items: []const GridItem,
        grid: Grid,
        row_tracks: []const GridTrack,
        column_tracks: []const GridTrack,
        config: Config,
        allocator: std.mem.Allocator,
    ) ![]types.LayoutResult {
        var results = try allocator.alloc(types.LayoutResult, items.len);

        for (grid.item_placements.items) |placement| {
            const item = items[placement.item_index];
            const area = placement.area;

            // Calculate grid area bounds
            const start_row = @min(area.row_start - 1, row_tracks.len - 1);
            const end_row = @min(area.row_end - 1, row_tracks.len);
            const start_col = @min(area.column_start - 1, column_tracks.len - 1);
            const end_col = @min(area.column_end - 1, column_tracks.len);

            const area_x = column_tracks[start_col].position;
            const area_y = row_tracks[start_row].position;

            var area_width: f32 = 0;
            for (start_col..end_col) |col_idx| {
                area_width += column_tracks[col_idx].size;
                if (col_idx < end_col - 1) {
                    area_width += config.column_gap;
                }
            }

            var area_height: f32 = 0;
            for (start_row..end_row) |row_idx| {
                area_height += row_tracks[row_idx].size;
                if (row_idx < end_row - 1) {
                    area_height += config.row_gap;
                }
            }

            // Calculate item size within grid area
            const item_size = calculateItemSizeInArea(
                item,
                Vec2{ .x = area_width, .y = area_height },
                config,
            );

            // Calculate item position within grid area
            const item_position = calculateItemPositionInArea(
                item,
                item_size,
                Vec2{ .x = area_width, .y = area_height },
                config,
            );

            results[placement.item_index] = types.LayoutResult{
                .position = Vec2{
                    .x = container_bounds.position.x + area_x + item_position.x,
                    .y = container_bounds.position.y + area_y + item_position.y,
                },
                .size = item_size,
                .element_index = item.index,
            };
        }

        return results;
    }

    /// Calculate item size within its grid area
    fn calculateItemSizeInArea(
        item: GridItem,
        area_size: Vec2,
        config: Config,
    ) Vec2 {
        var size = item.size;

        // Apply constraints
        size.x = item.constraints.constrainWidth(size.x);
        size.y = item.constraints.constrainHeight(size.y);

        // Apply justification and alignment
        const justify = item.justify_self orelse config.justify_items;
        const alignment = item.align_self orelse config.align_items;

        if (justify == .stretch) {
            size.x = area_size.x;
        }

        if (alignment == .stretch) {
            size.y = area_size.y;
        }

        return size;
    }

    /// Calculate item position within its grid area
    fn calculateItemPositionInArea(
        item: GridItem,
        item_size: Vec2,
        area_size: Vec2,
        config: Config,
    ) Vec2 {
        const justify = item.justify_self orelse config.justify_items;
        const alignment = item.align_self orelse config.align_items;

        var position = Vec2.ZERO;

        // Horizontal positioning
        switch (justify) {
            .flex_start, .stretch => position.x = 0,
            .flex_end => position.x = area_size.x - item_size.x,
            .center => position.x = (area_size.x - item_size.x) / 2.0,
            else => position.x = 0,
        }

        // Vertical positioning
        switch (alignment) {
            .flex_start, .stretch => position.y = 0,
            .flex_end => position.y = area_size.y - item_size.y,
            .center => position.y = (area_size.y - item_size.y) / 2.0,
            else => position.y = 0,
        }

        return position;
    }
};

// Tests
test "grid layout basic 2x2 grid" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var template_rows = std.ArrayList(TrackSize).init(allocator);
    defer template_rows.deinit();
    try template_rows.append(.{ .fixed = 100 });
    try template_rows.append(.{ .fixed = 100 });

    var template_columns = std.ArrayList(TrackSize).init(allocator);
    defer template_columns.deinit();
    try template_columns.append(.{ .fixed = 150 });
    try template_columns.append(.{ .fixed = 150 });

    const container = Rectangle{
        .position = Vec2.ZERO,
        .size = Vec2{ .x = 300, .y = 200 },
    };

    const items = [_]GridLayout.GridItem{
        .{
            .size = Vec2{ .x = 100, .y = 80 },
            .margin = types.Spacing{},
            .constraints = types.Constraints{},
            .grid_area = GridArea{
                .row_start = 1,
                .row_end = 2,
                .column_start = 1,
                .column_end = 2,
            },
            .index = 0,
        },
        .{
            .size = Vec2{ .x = 100, .y = 80 },
            .margin = types.Spacing{},
            .constraints = types.Constraints{},
            .grid_area = GridArea{
                .row_start = 2,
                .row_end = 3,
                .column_start = 2,
                .column_end = 3,
            },
            .index = 1,
        },
    };

    const config = GridLayout.Config{
        .grid_template_rows = template_rows,
        .grid_template_columns = template_columns,
    };

    const results = try GridLayout.calculateLayout(container, &items, config, allocator);
    defer allocator.free(results);

    try testing.expect(results.len == 2);

    // First item should be in top-left grid cell
    try testing.expect(results[0].position.x == 0);
    try testing.expect(results[0].position.y == 0);

    // Second item should be in bottom-right grid cell
    try testing.expect(results[1].position.x == 150); // Second column
    try testing.expect(results[1].position.y == 100); // Second row
}
