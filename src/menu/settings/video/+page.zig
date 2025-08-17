const std = @import("std");
const page = @import("../../../hud/page.zig");

const VideoSettingsPage = struct {
    base: page.Page,

    fn init(self: *page.Page, allocator: std.mem.Allocator) !void {
        _ = self;
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

    fn render(self: *const page.Page, links: *std.ArrayList(page.Link), arena: std.mem.Allocator) !void {
        const constants = @import("../../../hud/constants.zig");
        const screen_width = constants.SCREEN.BASE_WIDTH;
        const screen_height = constants.SCREEN.BASE_HEIGHT;
        _ = self;
        _ = arena;

        const center_x = screen_width / 2.0;
        const start_y = screen_height * 0.3;
        const link_height = 50.0;
        const link_width = 300.0;
        const link_spacing = 20.0;

        // Placeholder for video settings options
        // In a real implementation, these would be interactive controls

        try links.append(page.createLink("Back to Settings", "/settings", center_x - link_width / 2.0, start_y + (link_height + link_spacing) * 3, link_width, link_height));

        try links.append(page.createLink("Back to Menu", "/", center_x - link_width / 2.0, start_y + (link_height + link_spacing) * 4, link_width, link_height));
    }

    fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
        const video_settings_page: *VideoSettingsPage = @fieldParentPtr("base", self);
        allocator.destroy(video_settings_page);
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const video_page = try allocator.create(VideoSettingsPage);
    video_page.* = .{
        .base = .{
            .vtable = .{
                .init = VideoSettingsPage.init,
                .deinit = VideoSettingsPage.deinit,
                .update = VideoSettingsPage.update,
                .render = VideoSettingsPage.render,
                .destroy = VideoSettingsPage.destroy,
            },
            .path = "/settings/video",
            .title = "Video Settings",
        },
    };
    return &video_page.base;
}
