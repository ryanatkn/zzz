const std = @import("std");
const c = @import("../../lib/platform/sdl.zig");
const page = @import("../../hud/page.zig");
const bitmap_simple = @import("../../lib/font/renderers/bitmap_simple.zig");
const font_types = @import("../../lib/font/font_types.zig");
const types = @import("../../lib/core/types.zig");
const bitmap_utils = @import("../../lib/image/bitmap.zig");
const log_throttle = @import("../../lib/debug/log_throttle.zig");

const Vec2 = types.Vec2;
const Color = types.Color;
const SimpleBitmapRenderer = bitmap_simple.SimpleBitmapRenderer;

pub const FontGridTestPage = struct {
    base: page.Page,
    renderer: SimpleBitmapRenderer,
    initialized: bool,
    test_status: []const u8,

    fn init(self: *page.Page, allocator: std.mem.Allocator) !void {
        const grid_page: *FontGridTestPage = @fieldParentPtr("base", self);
        grid_page.renderer = SimpleBitmapRenderer.init();
        grid_page.initialized = true;
        grid_page.test_status = "Simplified font test ready";
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

        try links.append(page.createLink(
            "Font Test (Simplified)",
            "/font_test_simple",
            center_x - link_width / 2.0,
            start_y,
            link_width,
            link_height
        ));

        try links.append(page.createLink(
            "Back to Menu",
            "/",
            center_x - link_width / 2.0,
            start_y + (link_height + link_spacing) * 2,
            link_width,
            link_height
        ));
    }

    fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
        const font_page: *FontGridTestPage = @fieldParentPtr("base", self);
        allocator.destroy(font_page);
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const font_page = try allocator.create(FontGridTestPage);
    font_page.* = .{
        .base = .{
            .vtable = .{
                .init = FontGridTestPage.init,
                .deinit = FontGridTestPage.deinit,
                .update = FontGridTestPage.update,
                .render = FontGridTestPage.render,
                .destroy = FontGridTestPage.destroy,
            },
            .path = "/font_grid_test",
            .title = "Font Grid Test (Simplified)",
        },
        .renderer = undefined, // Will be set in init
        .initialized = false,
        .test_status = "Not initialized",
    };
    return &font_page.base;
}
