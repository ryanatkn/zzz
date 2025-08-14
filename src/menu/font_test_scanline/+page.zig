const std = @import("std");
const c = @import("../../lib/platform/sdl.zig");
const page = @import("../../hud/page.zig");
const scanline = @import("../../lib/font/renderers/scanline.zig");
const font_types = @import("../../lib/font/font_types.zig");
const types = @import("../../lib/core/types.zig");
const bitmap_utils = @import("../../lib/image/bitmap.zig");
const log_throttle = @import("../../lib/debug/log_throttle.zig");

const Vec2 = types.Vec2;
const Color = types.Color;
const ScanlineRenderer = scanline.ScanlineRenderer;

pub const FontScanlineTestPage = struct {
    base: page.Page,
    renderer: ScanlineRenderer,
    initialized: bool,
    test_status: []const u8,

    fn init(self: *page.Page, allocator: std.mem.Allocator) !void {
        const test_page: *FontScanlineTestPage = @fieldParentPtr("base", self);
        test_page.renderer = ScanlineRenderer.init();
        test_page.initialized = true;
        test_page.test_status = "Scanline renderer test ready";
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
        const start_y = screen_height * 0.3;
        const link_height = 50.0;
        const link_width = 300.0;
        const link_spacing = 20.0;

        var current_y = start_y;

        try links.append(page.createLink(
            "Test Scanline (Fast)",
            "/font_test_scanline_fast",
            center_x - link_width / 2.0,
            current_y,
            link_width,
            link_height
        ));
        current_y += link_height + link_spacing;

        try links.append(page.createLink(
            "Test Scanline (Quality)",
            "/font_test_scanline_quality",
            center_x - link_width / 2.0,
            current_y,
            link_width,
            link_height
        ));
        current_y += link_height + link_spacing;

        current_y += link_spacing;
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
        const test_page: *FontScanlineTestPage = @fieldParentPtr("base", self);
        allocator.destroy(test_page);
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const test_page = try allocator.create(FontScanlineTestPage);
    test_page.* = .{
        .base = .{
            .vtable = .{
                .init = FontScanlineTestPage.init,
                .deinit = FontScanlineTestPage.deinit,
                .update = FontScanlineTestPage.update,
                .render = FontScanlineTestPage.render,
                .destroy = FontScanlineTestPage.destroy,
            },
            .path = "/font_test_scanline",
            .title = "Scanline Renderer Test",
        },
        .renderer = undefined, // Will be set in init
        .initialized = false,
        .test_status = "Not initialized",
    };
    return &test_page.base;
}