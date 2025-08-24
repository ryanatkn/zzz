// Simple Buffer-based Font Test Page - replaces texture-based font grid
// Shows basic information about the new buffer-based text rendering system

const std = @import("std");
const page = @import("../../../lib/browser/page.zig");
const constants = @import("../../../lib/browser/constants.zig");
const math = @import("../../../lib/math/mod.zig");
const colors = @import("../../../lib/core/colors.zig");

const Vec2 = math.Vec2;

pub const FontGridTestPage = struct {
    base: page.Page,
    initialized: bool, // For compatibility with hud/renderer.zig

    fn init(self: *page.Page, allocator: std.mem.Allocator) !void {
        _ = self;
        _ = allocator;
    }

    fn deinit(self: *page.Page, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }

    fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
        const font_grid_test_page: *FontGridTestPage = @fieldParentPtr("base", self);
        allocator.destroy(font_grid_test_page);
    }

    fn update(self: *page.Page, dt: f32) void {
        _ = self;
        _ = dt;
    }

    fn render(self: *const page.Page, links: *std.ArrayList(page.Link), arena: std.mem.Allocator) !void {
        _ = self;
        _ = arena;

        // Define layout constants for centered content
        const screen_width = constants.SCREEN_WIDTH;
        const screen_height = constants.SCREEN_HEIGHT;
        const center_x = screen_width / 2.0;
        const start_y = screen_height * 0.3;
        const link_height = 50.0; // Standard link height
        const link_width = 300.0; // Standard link width
        const link_spacing = 20.0; // Standard link spacing

        // Show information about the buffer-based rendering system
        // (This would be rendered as text if we had working text rendering)

        // Navigation back to menu
        try links.append(page.createLink("Back to Menu", "/", center_x - link_width / 2.0, start_y + (link_height + link_spacing) * 2, link_width, link_height));
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const font_grid_test_page = try allocator.create(FontGridTestPage);
    font_grid_test_page.* = .{
        .base = .{
            .vtable = .{
                .init = FontGridTestPage.init,
                .deinit = FontGridTestPage.deinit,
                .update = FontGridTestPage.update,
                .render = FontGridTestPage.render,
                .destroy = FontGridTestPage.destroy,
            },
            .path = "/font_grid_test",
            .title = "Buffer Font Test",
        },
        .initialized = false, // Start uninitialized for compatibility
    };
    return &font_grid_test_page.base;
}
