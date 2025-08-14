const std = @import("std");
const page = @import("../../hud/page.zig");
const multi_text_renderer = @import("../../lib/text/multi_renderer.zig");
const text_primitives = @import("../../lib/text/primitives.zig");
const types = @import("../../lib/types.zig");

const Vec2 = types.Vec2;
const Color = types.Color;

const FontGridTestPage = struct {
    base: page.Page,
    multi_renderer: ?multi_text_renderer.MultiTextRenderer,
    initialized: bool,
    
    // Test configuration
    test_text: []const u8,
    font_sizes: [11]f32,
    
    fn init(self: *page.Page, allocator: std.mem.Allocator) !void {
        const grid_page: *FontGridTestPage = @fieldParentPtr("base", self);
        
        // Initialize test configuration
        grid_page.test_text = "Ag123@";
        grid_page.font_sizes = [_]f32{ 8, 10, 12, 14, 16, 20, 24, 32, 48, 64, 72 };
        grid_page.initialized = false;
        grid_page.multi_renderer = null;
        
        _ = allocator;
    }
    
    fn deinit(self: *page.Page, allocator: std.mem.Allocator) void {
        const grid_page: *FontGridTestPage = @fieldParentPtr("base", self);
        
        if (grid_page.multi_renderer) |*renderer| {
            renderer.deinit();
        }
        
        _ = allocator;
    }
    
    fn update(self: *page.Page, dt: f32) void {
        _ = self;
        _ = dt;
    }
    
    fn render(self: *const page.Page, links: *std.ArrayList(page.Link)) !void {
        const grid_page: *const FontGridTestPage = @fieldParentPtr("base", self);
        
        const screen_width = 1920.0;
        const screen_height = 1080.0;
        
        // Page header
        try links.append(page.createLink(
            "FONT RENDERING COMPARISON GRID",
            "",
            50, 20, 600, 40
        ));
        
        // Instructions
        try links.append(page.createLink(
            "All methods displayed simultaneously for direct comparison",
            "",
            50, 65, 800, 25
        ));
        
        // Column headers (font sizes)
        const start_x = 150.0;
        const start_y = 120.0;
        const cell_width = 140.0;
        const cell_height = 60.0;
        const spacing = 10.0;
        
        // Size labels across top
        for (grid_page.font_sizes, 0..) |size, i| {
            const x = start_x + @as(f32, @floatFromInt(i)) * (cell_width + spacing);
            var buffer: [32]u8 = undefined;
            const label = try std.fmt.bufPrint(&buffer, "{d}pt", .{size});
            
            try links.append(page.createLink(
                label,
                "",
                x, start_y - 30, cell_width, 25
            ));
        }
        
        // Row headers (rendering methods)
        const methods = [_]struct { name: []const u8, desc: []const u8 }{
            .{ .name = "Bitmap", .desc = "Direct rasterization" },
            .{ .name = "2x AA", .desc = "2x oversampling" },
            .{ .name = "4x AA", .desc = "4x oversampling" },
            .{ .name = "SDF", .desc = "Distance field" },
            .{ .name = "Cached", .desc = "Persistent cache" },
        };
        
        for (methods, 0..) |method, row| {
            const y = start_y + @as(f32, @floatFromInt(row)) * (cell_height + spacing);
            
            // Method name
            try links.append(page.createLink(
                method.name,
                "",
                20, y + 15, 100, 30
            ));
        }
        
        // Grid cells - each shows the test text rendered with specific method/size
        for (methods, 0..) |_, row| {
            for (grid_page.font_sizes, 0..) |size, col| {
                const x = start_x + @as(f32, @floatFromInt(col)) * (cell_width + spacing);
                const y = start_y + @as(f32, @floatFromInt(row)) * (cell_height + spacing);
                
                // Cell background (for visual separation)
                // Text will be rendered by multi_renderer in actual implementation
                try links.append(page.createLink(
                    grid_page.test_text,
                    "",
                    x, y, cell_width, cell_height
                ));
                
                // Quality indicator placeholder
                var quality_buffer: [32]u8 = undefined;
                const quality = calculateQualityEstimate(size, row);
                const quality_text = try std.fmt.bufPrint(&quality_buffer, "{d}%", .{quality});
                
                // Color based on quality
                const color_indicator = if (quality >= 80) "✓" else if (quality >= 60) "~" else "✗";
                
                try links.append(page.createLink(
                    quality_text,
                    "",
                    x, y + cell_height - 20, 40, 15
                ));
                
                try links.append(page.createLink(
                    color_indicator,
                    "",
                    x + 45, y + cell_height - 20, 20, 15
                ));
            }
        }
        
        // Statistics panel
        const stats_y = start_y + 5.0 * (cell_height + spacing) + 40;
        
        try links.append(page.createLink(
            "STATISTICS",
            "",
            50, stats_y, 200, 30
        ));
        
        // Performance metrics
        try links.append(page.createLink(
            "Total cells: 55 (5 methods × 11 sizes)",
            "",
            50, stats_y + 40, 400, 25
        ));
        
        try links.append(page.createLink(
            "Render time: <measuring>",
            "",
            50, stats_y + 70, 400, 25
        ));
        
        try links.append(page.createLink(
            "Avg quality: <calculating>",
            "",
            50, stats_y + 100, 400, 25
        ));
        
        // Legend
        const legend_x = 1400.0;
        try links.append(page.createLink(
            "QUALITY LEGEND",
            "",
            legend_x, start_y, 200, 30
        ));
        
        try links.append(page.createLink(
            "✓ 80-100% Good",
            "",
            legend_x, start_y + 40, 200, 25
        ));
        
        try links.append(page.createLink(
            "~ 60-79% Fair",
            "",
            legend_x, start_y + 70, 200, 25
        ));
        
        try links.append(page.createLink(
            "✗ 0-59% Poor",
            "",
            legend_x, start_y + 100, 200, 25
        ));
        
        // Test text samples
        try links.append(page.createLink(
            "TEST SAMPLES",
            "",
            legend_x, start_y + 150, 200, 30
        ));
        
        const samples = [_][]const u8{
            "ABCDEFGHIJ",
            "abcdefghij",
            "0123456789",
            "!@#$%^&*()",
        };
        
        for (samples, 0..) |sample, i| {
            try links.append(page.createLink(
                sample,
                "",
                legend_x, start_y + 190 + @as(f32, @floatFromInt(i)) * 30, 200, 25
            ));
        }
        
        // Navigation
        try links.append(page.createLink(
            "Back to Menu",
            "/",
            screen_width / 2.0 - 100.0,
            screen_height - 80.0,
            200,
            50
        ));
        
        // Actions
        try links.append(page.createLink(
            "Export Stats",
            "",
            50,
            screen_height - 80.0,
            150,
            40
        ));
        
        try links.append(page.createLink(
            "Clear Cache",
            "",
            220,
            screen_height - 80.0,
            150,
            40
        ));
    }
    
    fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
        const grid_page: *FontGridTestPage = @fieldParentPtr("base", self);
        allocator.destroy(grid_page);
    }
    
    // Helper function to estimate quality based on size and method
    fn calculateQualityEstimate(font_size: f32, method_index: usize) u32 {
        // Rough estimates for demonstration
        const base_quality: f32 = switch (method_index) {
            0 => 70.0, // Bitmap
            1 => 80.0, // 2x AA
            2 => 90.0, // 4x AA
            3 => 85.0, // SDF
            4 => 75.0, // Cached
            else => 50.0,
        };
        
        // Adjust based on font size
        const size_factor: f32 = if (font_size < 12) 
            0.5
        else if (font_size < 24)
            0.8
        else if (font_size < 48)
            1.0
        else
            1.1;
        
        const quality = base_quality * size_factor;
        return @min(100, @as(u32, @intFromFloat(quality)));
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const grid_page = try allocator.create(FontGridTestPage);
    grid_page.* = .{
        .base = .{
            .vtable = .{
                .init = FontGridTestPage.init,
                .deinit = FontGridTestPage.deinit,
                .update = FontGridTestPage.update,
                .render = FontGridTestPage.render,
                .destroy = FontGridTestPage.destroy,
            },
            .path = "/font-grid-test",
            .title = "Font Grid Test",
        },
        .multi_renderer = null,
        .initialized = false,
        .test_text = undefined,
        .font_sizes = undefined,
    };
    return &grid_page.base;
}