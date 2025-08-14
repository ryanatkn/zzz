const std = @import("std");
const edge_builder = @import("edge_builder.zig");

const log = std.log.scoped(.scanline_renderer);
const Edge = edge_builder.Edge;

/// Active edge for scanline algorithm
pub const ActiveEdge = struct {
    x: f32,           // Current X intersection with scanline
    dx: f32,          // Change in X per scanline
    y_max: f32,       // Maximum Y value of edge
    winding: i32,     // Winding direction (+1 or -1)
    
    /// Update X coordinate for next scanline
    pub fn advance(self: *ActiveEdge) void {
        self.x += self.dx;
    }
};

/// Configuration for scanline rendering
pub const ScanlineConfig = struct {
    /// Anti-aliasing mode
    antialiasing: bool = true,
    
    /// Gamma correction for anti-aliasing
    gamma: f32 = 2.2,
    
    /// Coverage threshold (minimum coverage to set pixel)
    coverage_threshold: f32 = 0.01,
    
    /// Whether to use even-odd fill rule (vs non-zero winding)
    even_odd_rule: bool = false,
};

/// Scanline renderer for converting edges to bitmap
pub const ScanlineRenderer = struct {
    allocator: std.mem.Allocator,
    config: ScanlineConfig,
    
    pub fn init(allocator: std.mem.Allocator, config: ScanlineConfig) ScanlineRenderer {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }
    
    /// Render edges to bitmap using scanline algorithm
    pub fn render(
        self: *ScanlineRenderer,
        edges: []const Edge,
        bitmap: []u8,
        width: u32,
        height: u32,
    ) !void {
        if (edges.len == 0) return;
        
        // Clear bitmap
        @memset(bitmap, 0);
        
        // Create active edge list
        var active_edges = std.ArrayList(ActiveEdge).init(self.allocator);
        defer active_edges.deinit();
        
        // Process each scanline
        for (0..height) |y| {
            const y_float = @as(f32, @floatFromInt(y)) + 0.5;
            
            // Clear active edges for this scanline
            active_edges.clearRetainingCapacity();
            
            // Find all edges that cross this scanline
            for (edges) |edge| {
                if (edge.crossesScanline(y_float)) {
                    const active = ActiveEdge{
                        .x = edge.xAtY(y_float),
                        .dx = if (@abs(edge.y1 - edge.y0) > 0.001)
                            (edge.x1 - edge.x0) / (edge.y1 - edge.y0)
                        else
                            0,
                        .y_max = @max(edge.y0, edge.y1),
                        .winding = edge.winding,
                    };
                    try active_edges.append(active);
                }
            }
            
            // Sort active edges by X coordinate
            std.sort.insertion(ActiveEdge, active_edges.items, {}, lessThanByX);
            
            // Fill pixels using winding rule
            if (self.config.even_odd_rule) {
                try self.fillScanlineEvenOdd(bitmap, width, y, active_edges.items);
            } else {
                try self.fillScanlineNonZero(bitmap, width, y, active_edges.items);
            }
        }
        
        // Apply gamma correction if needed
        if (self.config.antialiasing and self.config.gamma != 1.0) {
            self.applyGammaCorrection(bitmap);
        }
    }
    
    /// Fill scanline using non-zero winding rule (default, more robust)
    fn fillScanlineNonZero(
        self: *ScanlineRenderer,
        bitmap: []u8,
        width: u32,
        y: usize,
        active_edges: []ActiveEdge,
    ) !void {
        if (active_edges.len == 0) return;
        
        var winding_number: i32 = 0;
        var last_x: f32 = 0;
        
        for (active_edges) |edge| {
            // Fill pixels between last_x and edge.x if we're inside (winding != 0)
            if (winding_number != 0) {
                const x_start = @max(0, last_x);
                const x_end = @min(@as(f32, @floatFromInt(width)), edge.x);
                
                if (x_end > x_start) {
                    const start_pixel = @as(u32, @intFromFloat(@floor(x_start)));
                    const end_pixel = @min(width, @as(u32, @intFromFloat(@ceil(x_end))));
                    
                    for (start_pixel..end_pixel) |x| {
                        const idx = y * width + x;
                        if (idx < bitmap.len) {
                            if (self.config.antialiasing) {
                                // Calculate coverage
                                const pixel_start = @as(f32, @floatFromInt(x));
                                const pixel_end = pixel_start + 1.0;
                                const covered_start = @max(x_start, pixel_start);
                                const covered_end = @min(x_end, pixel_end);
                                const coverage = @max(0, covered_end - covered_start);
                                
                                if (coverage > self.config.coverage_threshold) {
                                    const value = @as(u8, @intFromFloat(@min(255, coverage * 255)));
                                    bitmap[idx] = @max(bitmap[idx], value);
                                }
                            } else {
                                bitmap[idx] = 255;
                            }
                        }
                    }
                }
            }
            
            // Update winding number AFTER filling
            winding_number += edge.winding;
            last_x = edge.x;
        }
    }
    
    /// Fill scanline using even-odd rule (simpler but less robust)
    fn fillScanlineEvenOdd(
        self: *ScanlineRenderer,
        bitmap: []u8,
        width: u32,
        y: usize,
        active_edges: []ActiveEdge,
    ) !void {
        _ = self;
        if (active_edges.len == 0) return;
        
        var inside = false;
        var last_x: f32 = 0;
        
        for (active_edges) |edge| {
            if (inside) {
                // Fill pixels between last_x and edge.x
                const start_pixel = @max(0, @as(u32, @intFromFloat(@floor(last_x))));
                const end_pixel = @min(width, @as(u32, @intFromFloat(@ceil(edge.x))));
                
                for (start_pixel..end_pixel) |x| {
                    const idx = y * width + x;
                    if (idx < bitmap.len) {
                        bitmap[idx] = 255;
                    }
                }
            }
            
            inside = !inside;
            last_x = edge.x;
        }
    }
    
    /// Apply gamma correction to bitmap
    fn applyGammaCorrection(self: *ScanlineRenderer, bitmap: []u8) void {
        const inv_gamma = 1.0 / self.config.gamma;
        
        for (bitmap) |*pixel| {
            if (pixel.* > 0 and pixel.* < 255) {
                const normalized = @as(f32, @floatFromInt(pixel.*)) / 255.0;
                const corrected = std.math.pow(f32, normalized, inv_gamma);
                pixel.* = @intFromFloat(corrected * 255.0);
            }
        }
    }
    
    fn lessThanByX(_: void, a: ActiveEdge, b: ActiveEdge) bool {
        return a.x < b.x;
    }
};

/// Simplified scanline renderer for testing
pub fn renderSimple(edges: []const Edge, bitmap: []u8, width: u32, height: u32) void {
    @memset(bitmap, 0);
    
    for (0..height) |y| {
        const y_float = @as(f32, @floatFromInt(y)) + 0.5;
        var intersections = std.BoundedArray(f32, 256).init(0) catch return;
        
        // Find intersections
        for (edges) |edge| {
            if (edge.crossesScanline(y_float)) {
                intersections.append(edge.xAtY(y_float)) catch continue;
            }
        }
        
        // Sort intersections
        std.sort.insertion(f32, intersections.slice(), {}, std.sort.asc(f32));
        
        // Fill between pairs (even-odd rule)
        var i: usize = 0;
        while (i + 1 < intersections.len) : (i += 2) {
            const x_start = @max(0, @as(u32, @intFromFloat(@floor(intersections.get(i)))));
            const x_end = @min(width, @as(u32, @intFromFloat(@ceil(intersections.get(i + 1)))));
            
            for (x_start..x_end) |x| {
                bitmap[y * width + x] = 255;
            }
        }
    }
}