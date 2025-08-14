const std = @import("std");
const page = @import("../hud/page.zig");

const RootLayout = struct {
    base: page.Layout,
    allocator: std.mem.Allocator,

    fn init(self: *page.Layout, allocator: std.mem.Allocator) !void {
        _ = self;
        _ = allocator;
    }

    fn deinit(self: *page.Layout, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }

    fn render(self: *const page.Layout, links: *std.ArrayList(page.Link), slot: *const page.RenderSlot) !void {
        _ = self;

        // Render any global header/navigation here if needed
        // For now, just render the slot content
        try slot.render(links);

        // Could add global footer here
    }

    fn destroy(self: *page.Layout, allocator: std.mem.Allocator) void {
        const root_layout: *RootLayout = @fieldParentPtr("base", self);
        allocator.destroy(root_layout);
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Layout {
    const layout = try allocator.create(RootLayout);
    layout.* = .{
        .base = .{
            .vtable = .{
                .init = RootLayout.init,
                .deinit = RootLayout.deinit,
                .render = RootLayout.render,
                .destroy = RootLayout.destroy,
            },
            .path = "/",
        },
        .allocator = allocator,
    };
    return &layout.base;
}
