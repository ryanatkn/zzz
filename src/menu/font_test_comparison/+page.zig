const std = @import("std");
const c = @import("../../lib/platform/sdl.zig");
const page = @import("../../hud/page.zig");
const bitmap_simple = @import("../../lib/font/renderers/bitmap_simple.zig");
const oversampling = @import("../../lib/font/renderers/oversampling.zig");
const debug_ascii = @import("../../lib/font/renderers/debug_ascii.zig");
const font_types = @import("../../lib/font/font_types.zig");
const types = @import("../../lib/core/types.zig");
const bitmap_utils = @import("../../lib/image/bitmap.zig");
const log_throttle = @import("../../lib/debug/log_throttle.zig");

const Vec2 = types.Vec2;
const Color = types.Color;

pub const FontComparisonPage = struct {
    base: page.Page,
    simple_renderer: bitmap_simple.SimpleBitmapRenderer,
    oversampling_2x_renderer: oversampling.OversamplingRenderer,
    oversampling_4x_renderer: oversampling.OversamplingRenderer,
    ascii_renderer: debug_ascii.DebugAsciiRenderer,
    initialized: bool,
    test_status: []const u8,

    fn init(self: *page.Page, allocator: std.mem.Allocator) !void {
        const comp_page: *FontComparisonPage = @fieldParentPtr("base", self);
        comp_page.simple_renderer = bitmap_simple.SimpleBitmapRenderer.init();
        comp_page.oversampling_2x_renderer = oversampling.OversamplingRenderer.init(2);
        comp_page.oversampling_4x_renderer = oversampling.OversamplingRenderer.init(4);
        comp_page.ascii_renderer = debug_ascii.DebugAsciiRenderer.init();
        comp_page.initialized = true;
        comp_page.test_status = "All working font renderers ready for comparison";
        _ = allocator;
    }

    fn deinit(self: *page.Page, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }

    fn update(self: *page.Page, dt: f32) void {
        _ = self;
        _ = dt;
    }

    fn render(self: *const page.Page, links: *std.ArrayList(page.Link)) !void {
        _ = self;
        
        // Define layout constants
        const screen_width = 1920.0;
        const screen_height = 1080.0;
        const center_x = screen_width / 2.0;
        const start_y = screen_height * 0.2;
        const link_height = 40.0;
        const link_width = 400.0;
        const link_spacing = 15.0;

        var current_y: f32 = start_y;

        // Header section
        try links.append(page.createLink(
            "📊 Performance Comparison",
            "/font_test_perf_comparison",
            center_x - link_width / 2.0,
            current_y,
            link_width,
            link_height
        ));
        current_y += link_height + link_spacing;

        try links.append(page.createLink(
            "📷 Visual Quality Comparison",
            "/font_test_visual_comparison",
            center_x - link_width / 2.0,
            current_y,
            link_width,
            link_height
        ));
        current_y += link_height + link_spacing;

        try links.append(page.createLink(
            "🔧 Technical Metrics",
            "/font_test_tech_metrics",
            center_x - link_width / 2.0,
            current_y,
            link_width,
            link_height
        ));
        current_y += link_height + link_spacing;

        // Size comparison tests
        current_y += link_spacing;
        try links.append(page.createLink(
            "Small Text (12pt-16pt)",
            "/font_test_small_sizes",
            center_x - link_width / 2.0,
            current_y,
            link_width,
            link_height
        ));
        current_y += link_height + link_spacing;

        try links.append(page.createLink(
            "Medium Text (18pt-36pt)",
            "/font_test_medium_sizes",
            center_x - link_width / 2.0,
            current_y,
            link_width,
            link_height
        ));
        current_y += link_height + link_spacing;

        try links.append(page.createLink(
            "Large Text (48pt-72pt)",
            "/font_test_large_sizes",
            center_x - link_width / 2.0,
            current_y,
            link_width,
            link_height
        ));
        current_y += link_height + link_spacing;

        // Navigation
        current_y += link_spacing * 2;
        try links.append(page.createLink(
            "Back to Font Tests",
            "/font_grid_test",
            center_x - link_width / 2.0,
            current_y,
            link_width,
            link_height
        ));
    }

    fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
        const comp_page: *FontComparisonPage = @fieldParentPtr("base", self);
        allocator.destroy(comp_page);
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const comp_page = try allocator.create(FontComparisonPage);
    comp_page.* = .{
        .base = .{
            .vtable = .{
                .init = FontComparisonPage.init,
                .deinit = FontComparisonPage.deinit,
                .update = FontComparisonPage.update,
                .render = FontComparisonPage.render,
                .destroy = FontComparisonPage.destroy,
            },
            .path = "/font_test_comparison",
            .title = "Font Renderer Comparison Suite",
        },
        .simple_renderer = undefined,
        .oversampling_2x_renderer = undefined, 
        .oversampling_4x_renderer = undefined,
        .ascii_renderer = undefined,
        .initialized = false,
        .test_status = "Not initialized",
    };
    return &comp_page.base;
}