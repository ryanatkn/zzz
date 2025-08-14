const std = @import("std");
const page = @import("../../hud/page.zig");

const VectorTestPage = struct {
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

        // Page header
        try links.append(page.createLink("VECTOR GRAPHICS TEST PAGE", "", 50, 50, 600, 60));

        // Demo section headers
        try links.append(page.createLink("Vector Circles Demo", "", 50, 150, 300, 40));
        try links.append(page.createLink("High quality scalable circles", "", 60, 190, 280, 30));

        try links.append(page.createLink("Bezier Curves Demo", "", 400, 150, 300, 40));
        try links.append(page.createLink("Animated quadratic curves", "", 410, 190, 280, 30));

        try links.append(page.createLink("Polygon Rendering", "", 750, 150, 300, 40));
        try links.append(page.createLink("Complex filled shapes", "", 760, 190, 280, 30));

        try links.append(page.createLink("Vector Path System", "", 1100, 150, 300, 40));
        try links.append(page.createLink("Procedural shape generation", "", 1110, 190, 280, 30));

        // Performance info
        try links.append(page.createLink("Performance Features:", "", 50, 400, 400, 40));
        try links.append(page.createLink("• GPU-accelerated tessellation", "", 60, 440, 380, 30));
        try links.append(page.createLink("• Adaptive quality control", "", 60, 470, 380, 30));
        try links.append(page.createLink("• Batched primitive rendering", "", 60, 500, 380, 30));
        try links.append(page.createLink("• Memory-efficient caching", "", 60, 530, 380, 30));

        // Quality comparison
        try links.append(page.createLink("Quality Modes:", "", 500, 400, 400, 40));
        try links.append(page.createLink("Fast: 8 segments per curve", "", 510, 440, 380, 30));
        try links.append(page.createLink("Medium: 16 segments per curve", "", 510, 470, 380, 30));
        try links.append(page.createLink("High: 32 segments per curve", "", 510, 500, 380, 30));
        try links.append(page.createLink("Ultra: 64 segments per curve", "", 510, 530, 380, 30));

        // API examples
        try links.append(page.createLink("Usage Examples:", "", 950, 400, 400, 40));
        try links.append(page.createLink("renderer.drawVectorCircle(...)", "", 960, 440, 380, 30));
        try links.append(page.createLink("renderer.drawQuadraticCurve(...)", "", 960, 470, 380, 30));
        try links.append(page.createLink("renderer.setVectorQuality(.high)", "", 960, 500, 380, 30));

        // Note about implementation
        try links.append(page.createLink("NOTE: Vector graphics rendering integrated", "", 50, 600, 500, 40));
        try links.append(page.createLink("with font system for unified GPU pipeline", "", 50, 630, 500, 30));

        // Navigation
        const center_x = screen_width / 2.0;
        const start_y = screen_height * 0.25;
        const link_height = 50.0;
        const link_width = 600.0;
        const link_spacing = 20.0;

        try links.append(page.createLink("Back to Menu", "/", center_x - link_width / 2.0, start_y + (link_height + link_spacing) * 12, link_width, link_height));

        try links.append(page.createLink("View Font Test", "/font-test", center_x - link_width / 2.0, start_y + (link_height + link_spacing) * 13, link_width, link_height));
    }

    fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
        const test_page: *VectorTestPage = @fieldParentPtr("base", self);
        allocator.destroy(test_page);
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const vector_test_page = try allocator.create(VectorTestPage);
    vector_test_page.* = .{
        .base = .{
            .vtable = .{
                .init = VectorTestPage.init,
                .deinit = VectorTestPage.deinit,
                .update = VectorTestPage.update,
                .render = VectorTestPage.render,
                .destroy = VectorTestPage.destroy,
            },
            .path = "/vector-test",
            .title = "Vector Graphics Test",
        },
    };
    return &vector_test_page.base;
}
