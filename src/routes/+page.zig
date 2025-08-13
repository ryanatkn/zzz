const std = @import("std");
const page = @import("../browser/page.zig");

const IndexPage = struct {
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
        
        const screen_width = 1920.0; // TODO: Get from renderer
        const screen_height = 1080.0;
        
        const center_x = screen_width / 2.0;
        const start_y = screen_height * 0.3;
        const link_height = 50.0;
        const link_width = 300.0;
        const link_spacing = 20.0;
        
        // Add navigation links
        try links.append(page.createLink(
            "Settings",
            "/settings",
            center_x - link_width / 2.0,
            start_y,
            link_width,
            link_height
        ));
        
        try links.append(page.createLink(
            "Statistics",
            "/stats",
            center_x - link_width / 2.0,
            start_y + link_height + link_spacing,
            link_width,
            link_height
        ));
    }
    
    fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
        const index_page: *IndexPage = @fieldParentPtr("base", self);
        allocator.destroy(index_page);
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const index_page = try allocator.create(IndexPage);
    index_page.* = .{
        .base = .{
            .vtable = .{
                .init = IndexPage.init,
                .deinit = IndexPage.deinit,
                .update = IndexPage.update,
                .render = IndexPage.render,
                .destroy = IndexPage.destroy,
            },
            .path = "/",
            .title = "System Menu",
        },
    };
    return &index_page.base;
}