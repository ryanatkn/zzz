const std = @import("std");
const c = @import("../../lib/platform/sdl.zig");
const page = @import("../../hud/page.zig");
const multi_strategy_renderer = @import("../../lib/font/multi_strategy_renderer.zig");
const renderer_display = @import("../../lib/font/renderer_display.zig");
const font_types = @import("../../lib/font/font_types.zig");
const types = @import("../../lib/core/types.zig");
const renderer_interface = @import("../../lib/font/renderers/renderer_interface.zig");
const log_throttle = @import("../../lib/debug/log_throttle.zig");

const Vec2 = types.Vec2;
const Color = types.Color;
const MultiStrategyRenderer = multi_strategy_renderer.MultiStrategyRenderer;
const MultiRenderResult = multi_strategy_renderer.MultiRenderResult;
const RendererDisplay = renderer_display.RendererDisplay;
const RenderStrategy = renderer_interface.RenderStrategy;
const GlyphOutline = font_types.GlyphOutline;
const Point = font_types.Point;
const Contour = font_types.Contour;

pub const FontGridTestPage = struct {
    base: page.Page,
    multi_renderer: ?MultiStrategyRenderer,
    display: ?RendererDisplay,
    initialized: bool,
    auto_initialized: bool, // Track if we've done the auto-init
    
    // Test configuration
    test_text: []const u8,
    font_sizes: [3]f32,
    
    // Test results from last run
    last_test_results: ?[]MultiRenderResult,
    test_status: []const u8, // Status message for display

    fn init(self: *page.Page, allocator: std.mem.Allocator) !void {
        const grid_page: *FontGridTestPage = @fieldParentPtr("base", self);

        // Initialize test configuration
        grid_page.test_text = "Test";
        grid_page.font_sizes = [_]f32{ 16, 24, 48 };
        grid_page.initialized = false;
        grid_page.auto_initialized = false;
        grid_page.multi_renderer = null;
        grid_page.display = null;
        grid_page.last_test_results = null;
        grid_page.test_status = "Not initialized";

        _ = allocator;
    }

    // Auto-initialize the multi-strategy renderer system immediately
    pub fn autoInitialize(self: *FontGridTestPage, allocator: std.mem.Allocator, device: *c.sdl.SDL_GPUDevice) void {
        std.log.info("DEBUG: autoInitialize function called!", .{});
        
        if (self.auto_initialized) {
            std.log.info("DEBUG: Already auto-initialized, returning early", .{});
            return;
        }
        
        std.log.info("DEBUG: Starting auto-initialization process...", .{});
        
        self.auto_initialized = true;
        self.test_status = "Initializing renderers...";
        
        log_throttle.logInfo("font_grid_start", "Starting font grid test auto-initialization", .{});
        
        // Initialize multi-strategy renderer
        self.multi_renderer = MultiStrategyRenderer.init(allocator) catch |err| {
            log_throttle.logError("font_grid_init", "Failed to initialize multi-strategy renderer: {}", .{err});
            self.test_status = "Renderer init failed";
            return;
        };
        
        log_throttle.logInfo("font_grid_renderer_ok", "Multi-strategy renderer initialized successfully", .{});
        
        // Initialize display system
        self.display = RendererDisplay.init(allocator, device);
        
        log_throttle.logInfo("font_grid_display_ok", "Renderer display system initialized successfully", .{});
        
        // Mark as initialized now that core systems are ready
        self.initialized = true;
        self.test_status = "Running test suite...";
        
        // Immediately run test suite with medium font size
        const test_font_size = self.font_sizes[1]; // 24pt
        log_throttle.logInfo("font_grid_test_start", "Running test suite with font size {}pt", .{test_font_size});
        
        const results = self.runTestSuite(allocator, test_font_size) catch |err| {
            log_throttle.logError("font_grid_test", "Failed to run test suite: {}", .{err});
            self.test_status = "Test suite failed";
            return;
        };
        
        log_throttle.logInfo("font_grid_results", "Test suite completed with {} results", .{results.len});
        
        // Create display textures for all results
        self.createDisplayTextures(results) catch |err| {
            log_throttle.logError("font_grid_display", "Failed to create display textures: {}", .{err});
            self.test_status = "Display creation failed";
            return;
        };
        
        log_throttle.logInfo("font_grid_textures", "Display textures created successfully", .{});
        
        self.test_status = "Ready - All renderers active";
        
        // Log success
        log_throttle.logInfo("font_grid_success", "Font grid test auto-initialized with {} renderers", .{results.len});
    }
    
    // Create GPU textures for display from render results
    fn createDisplayTextures(self: *FontGridTestPage, results: []MultiRenderResult) !void {
        if (self.display == null) return error.DisplayNotInitialized;
        
        log_throttle.logInfo("display_texture_start", "Creating display textures for {} results", .{results.len});
        
        var success_count: usize = 0;
        for (results) |result| {
            if (result.result) |render_result| {
                log_throttle.logInfo("create_texture", "Creating texture for strategy {s}: {}x{} bitmap", .{result.strategy.getName(), render_result.width, render_result.height});
                
                _ = self.display.?.createDisplayTexture(render_result, result.strategy) catch |err| {
                    log_throttle.logError("display_texture_fail", "Failed to create display texture for {s}: {}", .{result.strategy.getName(), err});
                    continue;
                };
                
                success_count += 1;
                log_throttle.logInfo("texture_success", "Successfully created texture for {s}", .{result.strategy.getName()});
            } else {
                log_throttle.logInfo("texture_skip", "Skipping {s}: no render result", .{result.strategy.getName()});
            }
        }
        
        log_throttle.logInfo("display_texture_complete", "Created {} display textures from {} results", .{success_count, results.len});
    }

    pub fn isGridPage(self: *const FontGridTestPage) bool {
        _ = self;
        return true;
    }
    
    // Test all rendering strategies with a simple test shape
    pub fn runTestSuite(self: *FontGridTestPage, allocator: std.mem.Allocator, font_size: f32) ![]MultiRenderResult {
        if (!self.initialized or self.multi_renderer == null) {
            return error.NotInitialized;
        }
        
        // Create a simple test glyph outline (rectangle)
        var test_outline = try self.createTestGlyphOutline(allocator);
        defer test_outline.deinit(allocator);
        
        // Test with all strategies
        const results = try self.multi_renderer.?.renderWithAllStrategies(test_outline, font_size);
        
        // Store results for display (just reference, don't take ownership)
        self.last_test_results = results;
        
        return results;
    }
    
    // Create a simple rectangular test glyph for testing
    fn createTestGlyphOutline(self: *FontGridTestPage, allocator: std.mem.Allocator) !GlyphOutline {
        _ = self;
        
        // Create a simple rectangular contour using proper TTF units
        // Use full 0-1000 range for clear visibility at all font sizes
        const points = try allocator.alloc(Point, 4);
        // Counter-clockwise winding for positive fill (standard TTF convention)
        points[0] = Point{ .x = 100, .y = 100 };   // Bottom-left
        points[1] = Point{ .x = 100, .y = 900 };   // Top-left  
        points[2] = Point{ .x = 700, .y = 900 };   // Top-right
        points[3] = Point{ .x = 700, .y = 100 };   // Bottom-right
        
        const on_curve = try allocator.alloc(bool, 4);
        on_curve[0] = true;
        on_curve[1] = true;
        on_curve[2] = true;
        on_curve[3] = true;
        
        const contours = try allocator.alloc(Contour, 1);
        contours[0] = Contour{
            .points = points,
            .on_curve = on_curve,
        };
        
        // Add debug logging to verify glyph creation
        log_throttle.logInfo("test_glyph_created", "Created test glyph: {}x{} rectangle ({}x{} units)", .{600, 800, 700-100, 900-100});
        
        return GlyphOutline{
            .contours = contours,
            .bounds = font_types.GlyphBounds{
                .x_min = 100,
                .y_min = 100,
                .x_max = 700,
                .y_max = 900,
            },
            .metrics = font_types.GlyphMetrics{
                .advance_width = 800,
                .left_side_bearing = 100,
            },
        };
    }

    fn deinit(self: *page.Page, allocator: std.mem.Allocator) void {
        _ = allocator;
        const grid_page: *FontGridTestPage = @fieldParentPtr("base", self);

        if (grid_page.multi_renderer) |*renderer| {
            renderer.deinit();
        }
        
        if (grid_page.display) |*display| {
            display.deinit();
        }
        
        // Note: last_test_results is just a reference to MultiStrategyRenderer's internal memory
        // The MultiStrategyRenderer will clean up its own results, so we don't free here
    }

    fn update(self: *page.Page, dt: f32) void {
        _ = self;
        _ = dt;
    }

    fn render(self: *const page.Page, links: *std.ArrayList(page.Link)) !void {
        const grid_page: *const FontGridTestPage = @fieldParentPtr("base", self);

        // Safety check: Don't render if not properly initialized
        if (!grid_page.initialized and !grid_page.auto_initialized) {
            try links.append(page.createLink("Font Grid Test - Initializing...", "", 50, 20, 400, 40));
            return;
        }

        // Validate font_sizes before using them
        for (grid_page.font_sizes) |size| {
            if (std.math.isNan(size) or std.math.isInf(size) or size <= 0 or size > 200) {
                try links.append(page.createLink("Font Grid Test - Invalid Configuration", "", 50, 20, 400, 40));
                return;
            }
        }

        const screen_width = 1920.0;
        const screen_height = 1080.0;

        // Page header
        try links.append(page.createLink("FONT RENDERING COMPARISON GRID", "", 50, 20, 600, 40));

        // Instructions
        try links.append(page.createLink("All methods displayed simultaneously for direct comparison", "", 50, 65, 800, 25));

        // Column headers (font sizes)
        const start_x = 150.0;
        const start_y = 120.0;
        const cell_width = 140.0;
        const cell_height = 60.0;
        const spacing = 10.0;

        // Size labels across top
        for (grid_page.font_sizes, 0..) |size, i| {
            const x = start_x + @as(f32, @floatFromInt(i)) * (cell_width + spacing);
            var buffer: [32]u8 = [_]u8{0} ** 32;  // Initialize to zeros
            const label = try std.fmt.bufPrint(&buffer, "{d}pt", .{size});

            try links.append(page.createLink(label, "", x, start_y - 30, cell_width, 25));
        }

        // Row headers (rendering strategies)
        const strategies = [_]RenderStrategy{
            .simple_bitmap,
            .debug_ascii,
            .oversampling_2x,
            .oversampling_4x,
            .scanline_antialiased,
        };

        for (strategies, 0..) |strategy, row| {
            const y = start_y + @as(f32, @floatFromInt(row)) * (cell_height + spacing);

            // Strategy name
            try links.append(page.createLink(strategy.getName(), "", 20, y + 15, 100, 30));
        }

        // Grid cells - show rendering strategy results
        for (strategies, 0..) |strategy, row| {
            for (grid_page.font_sizes, 0..) |size, col| {
                const x = start_x + @as(f32, @floatFromInt(col)) * (cell_width + spacing);
                const y = start_y + @as(f32, @floatFromInt(row)) * (cell_height + spacing);

                // Cell background
                try links.append(page.createLink("[Render Test]", "", x, y, cell_width, cell_height));
                
                // Strategy and size info  
                var info_buffer: [64]u8 = [_]u8{0} ** 64;  // Initialize to zeros
                const info_text = try std.fmt.bufPrint(&info_buffer, "{s} {d}pt", .{strategy.getName(), size});
                // Validate UTF-8 before using
                if (std.unicode.utf8ValidateSlice(info_text)) {
                    try links.append(page.createLink(info_text, "", x + 5, y + 5, cell_width - 10, 20));
                }

                // Quality tier indication (static for now)
                const quality_tier = strategy.getQualityTier();
                const perf_tier = strategy.getPerformanceTier();
                
                var tier_buffer: [32]u8 = [_]u8{0} ** 32;  // Initialize to zeros
                const tier_text = try std.fmt.bufPrint(&tier_buffer, "Q{d} P{d}", .{quality_tier, perf_tier});
                try links.append(page.createLink(tier_text, "", x + 5, y + cell_height - 20, 60, 15));
                
                // Status indicator
                const status = if (strategy == .scanline_antialiased) "?" else "+";
                try links.append(page.createLink(status, "", x + cell_width - 25, y + cell_height - 20, 20, 15));
            }
        }

        // Statistics panel
        const stats_y = start_y + 5.0 * (cell_height + spacing) + 40;

        try links.append(page.createLink("STATISTICS", "", 50, stats_y, 200, 30));

        // Performance metrics
        var stats_buffer: [128]u8 = [_]u8{0} ** 128;  // Initialize to zeros
        const total_cells = strategies.len * grid_page.font_sizes.len;
        const stats_text = try std.fmt.bufPrint(&stats_buffer, "Total combinations: {d} ({d} strategies x {d} sizes)", .{total_cells, strategies.len, grid_page.font_sizes.len});
        try links.append(page.createLink(stats_text, "", 50, stats_y + 40, 500, 25));

        try links.append(page.createLink("Status: Ready for testing", "", 50, stats_y + 70, 400, 25));

        // Status display
        var status_buffer: [128]u8 = [_]u8{0} ** 128;  // Initialize to zeros
        const status_text = try std.fmt.bufPrint(&status_buffer, "Status: {s}", .{grid_page.test_status});
        try links.append(page.createLink(status_text, "", 50, stats_y + 100, 400, 25));
        
        // Test controls
        try links.append(page.createLink("Re-run Tests", "", 50, stats_y + 130, 150, 40));
        try links.append(page.createLink("Export Results", "", 220, stats_y + 130, 150, 40));

        // Legend
        const legend_x = 1400.0;
        try links.append(page.createLink("LEGEND", "", legend_x, start_y, 200, 30));

        try links.append(page.createLink("+ Working", "", legend_x, start_y + 40, 200, 25));

        try links.append(page.createLink("? Unknown/Testing", "", legend_x, start_y + 70, 200, 25));

        try links.append(page.createLink("X Failed/Error", "", legend_x, start_y + 100, 200, 25));
        
        // Quality tiers
        try links.append(page.createLink("Q1=Low Q2=Med Q3=High", "", legend_x, start_y + 140, 200, 25));
        try links.append(page.createLink("P1=Fast P2=Med P3=Slow", "", legend_x, start_y + 170, 200, 25));

        // Test text samples
        try links.append(page.createLink("TEST SAMPLES", "", legend_x, start_y + 150, 200, 30));

        const samples = [_][]const u8{
            "ABCDEFGHIJ",
            "abcdefghij",
            "0123456789",
            "!@#$%^&*()",
        };

        for (samples, 0..) |sample, i| {
            try links.append(page.createLink(sample, "", legend_x, start_y + 190 + @as(f32, @floatFromInt(i)) * 30, 200, 25));
        }

        // Navigation
        try links.append(page.createLink("Back to Menu", "/", screen_width / 2.0 - 100.0, screen_height - 80.0, 200, 50));

        // Actions
        try links.append(page.createLink("Export Stats", "", 50, screen_height - 80.0, 150, 40));

        try links.append(page.createLink("Clear Cache", "", 220, screen_height - 80.0, 150, 40));
    }

    fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
        const grid_page: *FontGridTestPage = @fieldParentPtr("base", self);
        allocator.destroy(grid_page);
    }

    // Get initialization status for display
    pub fn getInitStatus(self: *const FontGridTestPage) []const u8 {
        return self.test_status;
    }
    
    // Get count of available strategies
    pub fn getStrategyCount(self: *const FontGridTestPage) usize {
        _ = self;
        return 5;
    }
    
    // Get display texture for a specific strategy (for rendering)
    pub fn getDisplayTexture(self: *const FontGridTestPage, strategy: RenderStrategy) ?*c.sdl.SDL_GPUTexture {
        if (self.display) |display| {
            return display.getDisplayTexture(strategy);
        }
        return null;
    }
    
    // Check if auto-initialization has been attempted
    pub fn isAutoInitialized(self: *const FontGridTestPage) bool {
        return self.auto_initialized;
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
        .display = null,
        .initialized = false,
        .auto_initialized = false,
        .test_text = "Test",
        .font_sizes = [_]f32{ 16, 24, 48 },
        .last_test_results = null,
        .test_status = "Not initialized",
    };
    return &grid_page.base;
}
