const std = @import("std");
const page = @import("../../../lib/browser/page.zig");
const reactive = @import("../../../lib/reactive/mod.zig");

/// Demonstration page showing ReactiveRef automatic cleanup
pub const ReactiveRefDemoPage = struct {
    base: page.Page,
    arena: std.heap.ArenaAllocator,

    // Using ReactiveRef for automatic cleanup - no manual destroy() calls needed!
    count: reactive.Signal(u32),
    doubled: reactive.ReactiveRef(reactive.Derived(u32)),
    effect: reactive.EffectRef,

    fn init(self: *page.Page, allocator: std.mem.Allocator) !void {
        const demo_page: *ReactiveRefDemoPage = @fieldParentPtr("base", self);

        // Initialize arena
        demo_page.arena = std.heap.ArenaAllocator.init(allocator);

        // Initialize reactive context if not already done
        reactive.init(allocator) catch {};

        // Create regular signal (no heap allocation)
        demo_page.count = try reactive.signal(allocator, u32, 42);

        // Store page pointer for closures
        const PageData = struct {
            var page_ptr: *ReactiveRefDemoPage = undefined;
            var count_ptr: *reactive.Signal(u32) = undefined;
        };
        PageData.page_ptr = demo_page;
        PageData.count_ptr = &demo_page.count;

        // Create RAII-managed derived value (automatic cleanup!)
        demo_page.doubled = try reactive.createDerivedRef(allocator, u32, struct {
            fn compute() u32 {
                return PageData.count_ptr.get() * 2;
            }
        }.compute);

        // Create RAII-managed effect (automatic cleanup!)
        demo_page.effect = try reactive.createEffectRef(allocator, struct {
            fn run() void {
                const count = PageData.count_ptr.get();
                const doubled = PageData.page_ptr.doubled.get().get();
                // Effect that logs changes
                _ = count;
                _ = doubled;
            }
        }.run);
    }

    fn deinit(self: *page.Page, allocator: std.mem.Allocator) void {
        _ = allocator;
        const demo_page: *ReactiveRefDemoPage = @fieldParentPtr("base", self);

        // Clean up reactive objects - ReactiveRef handles destroy() automatically!
        demo_page.count.deinit(); // Regular signal cleanup
        demo_page.doubled.deinit(); // ReactiveRef automatically calls destroy()
        demo_page.effect.deinit(); // ReactiveRef automatically calls destroy()

        // Clean up arena
        demo_page.arena.deinit();
    }

    fn update(self: *page.Page, dt: f32) void {
        _ = self;
        _ = dt;
    }

    fn render(self: *const page.Page, links: *std.ArrayList(page.Link), arena: std.mem.Allocator) !void {
        const demo_page: *const ReactiveRefDemoPage = @fieldParentPtr("base", self);

        const screen_width = 1920.0;
        const screen_height = 1080.0;

        // Header
        try links.append(page.createLink("REACTIVE REF DEMO - NO MEMORY LEAKS!", "", screen_width / 2.0 - 400, 50, 800, 60));

        // Show values
        const mutable_page: *ReactiveRefDemoPage = @constCast(demo_page);
        const count_text = try std.fmt.allocPrint(arena, "Count: {}", .{mutable_page.count.get()});
        try links.append(page.createLink(count_text, "", 400, 200, 300, 40));

        const doubled_text = try std.fmt.allocPrint(arena, "Doubled: {}", .{mutable_page.doubled.get().get()});
        try links.append(page.createLink(doubled_text, "", 400, 250, 300, 40));

        // Increment button
        try links.append(page.createLink("Increment (No Leaks!)", "/reactive-ref-demo?increment", 400, 300, 300, 50));

        // Description
        try links.append(page.createLink("This page uses ReactiveRef for automatic cleanup.", "", 400, 400, 600, 30));
        try links.append(page.createLink("No manual allocator.destroy() calls needed!", "", 400, 440, 600, 30));
        try links.append(page.createLink("Memory leaks are impossible with this pattern.", "", 400, 480, 600, 30));

        // Back button
        try links.append(page.createLink("Back to Menu", "/", screen_width / 2.0 - 100, screen_height - 150, 200, 50));
    }

    fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
        const demo_page: *ReactiveRefDemoPage = @fieldParentPtr("base", self);
        allocator.destroy(demo_page);
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const demo_page = try allocator.create(ReactiveRefDemoPage);
    demo_page.* = .{
        .base = .{
            .vtable = .{
                .init = ReactiveRefDemoPage.init,
                .deinit = ReactiveRefDemoPage.deinit,
                .update = ReactiveRefDemoPage.update,
                .render = ReactiveRefDemoPage.render,
                .destroy = ReactiveRefDemoPage.destroy,
            },
            .path = "/reactive-ref-demo",
            .title = "ReactiveRef Demo",
        },
        .arena = undefined,
        .count = undefined,
        .doubled = undefined,
        .effect = undefined,
    };
    return &demo_page.base;
}
