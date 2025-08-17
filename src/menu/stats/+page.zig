const std = @import("std");
const page = @import("../../hud/page.zig");

const StatsPage = struct {
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
        const constants = @import("../../hud/constants.zig");
        const screen_width = constants.SCREEN.BASE_WIDTH;
        const screen_height = constants.SCREEN.BASE_HEIGHT;
        _ = self;

        const center_x = screen_width / 2.0;
        const start_y = screen_height * 0.3;
        const link_height = 50.0;
        const link_width = 300.0;
        const link_spacing = 20.0;

        // Placeholder for game statistics display
        // In a real implementation, this would show actual game stats

        try links.append(page.createLink("Back to Menu", "/", center_x - link_width / 2.0, start_y + (link_height + link_spacing) * 5, link_width, link_height));
    }

    fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
        const stats_page: *StatsPage = @fieldParentPtr("base", self);
        allocator.destroy(stats_page);
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const stats_page = try allocator.create(StatsPage);
    stats_page.* = .{
        .base = .{
            .vtable = .{
                .init = StatsPage.init,
                .deinit = StatsPage.deinit,
                .update = StatsPage.update,
                .render = StatsPage.render,
                .destroy = StatsPage.destroy,
            },
            .path = "/stats",
            .title = "Statistics",
        },
    };
    return &stats_page.base;
}
