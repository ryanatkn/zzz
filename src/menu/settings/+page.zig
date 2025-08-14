const std = @import("std");
const page = @import("../../hud/page.zig");

const SettingsPage = struct {
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

    fn render(self: *const page.Page, links: *std.ArrayList(page.Link)) !void {
        _ = self;

        const screen_width = 1920.0;
        const screen_height = 1080.0;

        const center_x = screen_width / 2.0;
        const start_y = screen_height * 0.3;
        const link_height = 50.0;
        const link_width = 300.0;
        const link_spacing = 20.0;

        // Add navigation links
        try links.append(page.createLink("Video Settings", "/settings/video", center_x - link_width / 2.0, start_y, link_width, link_height));

        try links.append(page.createLink("Audio Settings", "/settings/audio", center_x - link_width / 2.0, start_y + link_height + link_spacing, link_width, link_height));

        try links.append(page.createLink("Font Settings", "/settings/fonts", center_x - link_width / 2.0, start_y + (link_height + link_spacing) * 2, link_width, link_height));

        try links.append(page.createLink("Back to Menu", "/", center_x - link_width / 2.0, start_y + (link_height + link_spacing) * 4, link_width, link_height));
    }

    fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
        const settings_page: *SettingsPage = @fieldParentPtr("base", self);
        allocator.destroy(settings_page);
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const settings_page = try allocator.create(SettingsPage);
    settings_page.* = .{
        .base = .{
            .vtable = .{
                .init = SettingsPage.init,
                .deinit = SettingsPage.deinit,
                .update = SettingsPage.update,
                .render = SettingsPage.render,
                .destroy = SettingsPage.destroy,
            },
            .path = "/settings",
            .title = "Settings",
        },
    };
    return &settings_page.base;
}
