const std = @import("std");
const c = @import("../../lib/platform/sdl.zig");
const page = @import("../../hud/page.zig");
const debug_ascii = @import("../../lib/font/renderers/debug_ascii.zig");
const font_types = @import("../../lib/font/font_types.zig");
const types = @import("../../lib/core/types.zig");
const bitmap_utils = @import("../../lib/image/bitmap.zig");
const log_throttle = @import("../../lib/debug/log_throttle.zig");

const Vec2 = types.Vec2;
const Color = types.Color;
const DebugAsciiRenderer = debug_ascii.DebugAsciiRenderer;

pub const FontAsciiTestPage = struct {
    base: page.Page,
    renderer: DebugAsciiRenderer,
    initialized: bool,
    test_status: []const u8,

    fn init(self: *page.Page, allocator: std.mem.Allocator) !void {
        const test_page: *FontAsciiTestPage = @fieldParentPtr("base", self);
        test_page.renderer = DebugAsciiRenderer.init();
        test_page.initialized = true;
        test_page.test_status = "Debug ASCII renderer test ready";
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

        var current_y: f32 = start_y;

        try links.append(page.createLink(
            "ASCII Art Visualization",
            "/font_test_ascii_art",
            center_x - link_width / 2.0,
            current_y,
            link_width,
            link_height
        ));
        current_y += link_height + link_spacing;

        try links.append(page.createLink(
            "Console Debug Output",
            "/font_test_ascii_console",
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
        const test_page: *FontAsciiTestPage = @fieldParentPtr("base", self);
        allocator.destroy(test_page);
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const test_page = try allocator.create(FontAsciiTestPage);
    test_page.* = .{
        .base = .{
            .vtable = .{
                .init = FontAsciiTestPage.init,
                .deinit = FontAsciiTestPage.deinit,
                .update = FontAsciiTestPage.update,
                .render = FontAsciiTestPage.render,
                .destroy = FontAsciiTestPage.destroy,
            },
            .path = "/font_test_ascii",
            .title = "Debug ASCII Renderer Test",
        },
        .renderer = undefined, // Will be set in init
        .initialized = false,
        .test_status = "Not initialized",
    };
    return &test_page.base;
}