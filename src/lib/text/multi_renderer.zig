const std = @import("std");
const c = @import("../c.zig");
const types = @import("../types.zig");
const text_primitives = @import("primitives.zig");
const text_renderer = @import("renderer.zig");
const font_manager = @import("../font/manager.zig");

const Vec2 = types.Vec2;
const Color = types.Color;
const RenderMethod = text_primitives.RenderMethod;
const TextTexture = text_primitives.TextTexture;
const TextStats = text_primitives.TextStats;

/// Grid cell containing text rendered with specific method and size
pub const GridCell = struct {
    text: []const u8,
    texture: ?TextTexture,
    position: Vec2,
    size: Vec2,
    font_size: f32,
    method: RenderMethod,
    stats: ?TextStats,
    visible: bool,
};

/// Multi-method text renderer for comparison grid
pub const MultiTextRenderer = struct {
    allocator: std.mem.Allocator,
    device: *c.sdl.SDL_GPUDevice,
    text_renderer: *text_renderer.TextRenderer,
    font_manager: *font_manager.FontManager,
    primitives: text_primitives.TextPrimitives,

    // Grid storage
    grid_cells: std.ArrayList(GridCell),

    // Performance tracking
    total_render_time_us: u64,
    cells_rendered: u32,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        device: *c.sdl.SDL_GPUDevice,
        tr: *text_renderer.TextRenderer,
        fm: *font_manager.FontManager,
    ) Self {
        return Self{
            .allocator = allocator,
            .device = device,
            .text_renderer = tr,
            .font_manager = fm,
            .primitives = text_primitives.TextPrimitives.init(allocator, device, fm),
            .grid_cells = std.ArrayList(GridCell).init(allocator),
            .total_render_time_us = 0,
            .cells_rendered = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.grid_cells.items) |*cell| {
            if (cell.texture) |texture| {
                texture.deinit(self.device);
            }
        }
        self.grid_cells.deinit();
    }

    /// Create a comparison grid with all methods and sizes
    pub fn createComparisonGrid(
        self: *Self,
        test_text: []const u8,
        font_sizes: []const f32,
        start_pos: Vec2,
        cell_spacing: Vec2,
    ) !void {
        // Clear existing grid
        for (self.grid_cells.items) |*cell| {
            if (cell.texture) |texture| {
                texture.deinit(self.device);
            }
        }
        self.grid_cells.clearRetainingCapacity();

        // All rendering methods to test
        const methods = [_]RenderMethod{
            .bitmap,
            .oversampled_2x,
            .oversampled_4x,
            .sdf,
            .cached,
        };

        // Calculate cell size based on largest expected text
        const max_font_size = font_sizes[font_sizes.len - 1];
        const cell_width = max_font_size * @as(f32, @floatFromInt(test_text.len)) * 0.6 + 20;
        const cell_height = max_font_size * 1.5 + 10;

        // Create grid
        for (methods, 0..) |method, method_idx| {
            for (font_sizes, 0..) |size, size_idx| {
                const x = start_pos.x + @as(f32, @floatFromInt(size_idx)) * (cell_width + cell_spacing.x);
                const y = start_pos.y + @as(f32, @floatFromInt(method_idx)) * (cell_height + cell_spacing.y);

                const cell = GridCell{
                    .text = test_text,
                    .texture = null,
                    .position = Vec2{ .x = x, .y = y },
                    .size = Vec2{ .x = cell_width, .y = cell_height },
                    .font_size = size,
                    .method = method,
                    .stats = null,
                    .visible = true,
                };

                try self.grid_cells.append(cell);
            }
        }
    }

    /// Render all visible cells in the grid
    pub fn renderGrid(self: *Self, render_pass: *c.sdl.SDL_GPURenderPass) !void {
        const start_time = std.time.microTimestamp();
        self.cells_rendered = 0;

        // First pass: Create textures for cells that need them
        for (self.grid_cells.items) |*cell| {
            if (cell.visible and cell.texture == null) {
                cell.texture = try self.primitives.createTextTexture(
                    cell.text,
                    cell.font_size,
                    cell.method,
                    Color.white(),
                );

                cell.stats = try self.primitives.calculateTextStats(
                    cell.texture.?,
                    cell.text,
                );

                self.cells_rendered += 1;
            }
        }

        // Second pass: Batch render all textures
        for (self.grid_cells.items) |cell| {
            if (cell.visible and cell.texture != null) {
                const texture = cell.texture.?;

                // Queue the text for rendering
                self.text_renderer.queueTextTexture(
                    texture.texture,
                    null, // Use default sampler
                    @intCast(texture.width),
                    @intCast(texture.height),
                    cell.position,
                    Color.white(),
                );
            }
        }

        // Draw all queued text
        try self.text_renderer.drawQueuedText(render_pass);

        self.total_render_time_us = @intCast(std.time.microTimestamp() - start_time);
    }

    /// Render quality indicators below each cell
    pub fn renderQualityIndicators(
        self: *Self,
        render_pass: *c.sdl.SDL_GPURenderPass,
    ) !void {
        _ = render_pass;

        for (self.grid_cells.items) |cell| {
            if (cell.visible and cell.stats != null) {
                const stats = cell.stats.?;

                // Create quality indicator text
                var buffer: [64]u8 = undefined;
                const quality_text = try std.fmt.bufPrint(&buffer, "{d:.0}%", .{stats.coverage_percent});

                // Determine color based on quality
                const quality_color = text_primitives.TextPrimitives.getQualityColor(stats.coverage_percent);

                // Render quality indicator below cell
                const indicator_pos = Vec2{
                    .x = cell.position.x,
                    .y = cell.position.y + cell.size.y - 15,
                };

                // Create small indicator texture
                const indicator = try self.primitives.createTextTexture(
                    quality_text,
                    10.0, // Small font for indicators
                    .bitmap,
                    quality_color,
                );
                defer indicator.deinit(self.device);

                self.text_renderer.queueTextTexture(
                    indicator.texture,
                    null,
                    @intCast(indicator.width),
                    @intCast(indicator.height),
                    indicator_pos,
                    quality_color,
                );
            }
        }
    }

    /// Get statistics for the entire grid
    pub fn getGridStats(self: *Self) GridStats {
        var total_coverage: f32 = 0;
        var total_sharpness: f32 = 0;
        var count: u32 = 0;

        for (self.grid_cells.items) |cell| {
            if (cell.stats) |stats| {
                total_coverage += stats.coverage_percent;
                total_sharpness += stats.edge_sharpness;
                count += 1;
            }
        }

        return GridStats{
            .avg_coverage = if (count > 0) total_coverage / @as(f32, @floatFromInt(count)) else 0,
            .avg_sharpness = if (count > 0) total_sharpness / @as(f32, @floatFromInt(count)) else 0,
            .total_render_time_us = self.total_render_time_us,
            .cells_rendered = self.cells_rendered,
        };
    }

    /// Clear all cached textures
    pub fn clearCache(self: *Self) void {
        for (self.grid_cells.items) |*cell| {
            if (cell.texture) |texture| {
                texture.deinit(self.device);
                cell.texture = null;
                cell.stats = null;
            }
        }
    }
};

/// Overall grid statistics
pub const GridStats = struct {
    avg_coverage: f32,
    avg_sharpness: f32,
    total_render_time_us: u64,
    cells_rendered: u32,
};
