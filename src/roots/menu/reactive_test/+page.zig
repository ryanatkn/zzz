const std = @import("std");
const page = @import("../../../lib/browser/page.zig");
const reactive = @import("../../../lib/reactive/mod.zig");
const gannaway = @import("../../../lib/gannaway/mod.zig");

pub const ReactiveTestPage = struct {
    base: page.Page,
    arena: std.heap.ArenaAllocator,

    // Current reactive system state
    current_count: reactive.Signal(u32),
    current_doubled: *reactive.Derived(u32),
    current_effect: *reactive.Effect,
    current_log: std.ArrayList([]const u8),

    // Gannaway system state
    gannaway_count: *gannaway.State(u32),
    gannaway_doubled: *gannaway.Compute(u32),
    gannaway_watcher: *gannaway.Watcher,
    gannaway_log: std.ArrayList([]const u8),

    fn init(self: *page.Page, allocator: std.mem.Allocator) !void {
        const test_page: *ReactiveTestPage = @fieldParentPtr("base", self);

        // Initialize arena for string allocations
        test_page.arena = std.heap.ArenaAllocator.init(allocator);
        const arena_allocator = test_page.arena.allocator();

        // Initialize reactive context if not already done
        reactive.init(allocator) catch {};

        // Initialize current reactive system
        test_page.current_count = try reactive.signal(allocator, u32, 0);
        test_page.current_log = std.ArrayList([]const u8).init(arena_allocator);

        // Store page pointer for closures
        const PageData = struct {
            var page_ptr: *ReactiveTestPage = undefined;
            var count_ptr: *reactive.Signal(u32) = undefined;
        };
        PageData.page_ptr = test_page;
        PageData.count_ptr = &test_page.current_count;

        // Create derived value
        test_page.current_doubled = try reactive.derived(allocator, u32, struct {
            fn compute() u32 {
                return PageData.count_ptr.get() * 2;
            }
        }.compute);

        // Create effect that logs changes
        test_page.current_effect = try reactive.createEffect(allocator, struct {
            fn run() void {
                const count = PageData.count_ptr.get();
                const doubled = PageData.page_ptr.current_doubled.get();
                const msg = std.fmt.allocPrint(PageData.page_ptr.arena.allocator(), "Count: {}, Doubled: {}", .{ count, doubled }) catch return;
                PageData.page_ptr.current_log.append(msg) catch {};
            }
        }.run);

        // Initialize Gannaway system
        test_page.gannaway_count = try gannaway.state(u32).init(allocator, 0);
        test_page.gannaway_log = std.ArrayList([]const u8).init(arena_allocator);

        // Store Gannaway state for closures
        const GannawayData = struct {
            var page_ptr: *ReactiveTestPage = undefined;
            var count_ptr: *gannaway.State(u32) = undefined;
        };
        GannawayData.page_ptr = test_page;
        GannawayData.count_ptr = test_page.gannaway_count;

        // Create Gannaway computed value
        test_page.gannaway_doubled = try gannaway.compute(allocator, u32, .{
            .dependencies = &[_]*gannaway.Watchable{test_page.gannaway_count.asWatchable()},
            .compute_fn = struct {
                fn calc() u32 {
                    return GannawayData.count_ptr.get() * 2;
                }
            }.calc,
        });

        // Create Gannaway watcher
        test_page.gannaway_watcher = try gannaway.watch(allocator, .{
            .targets = &[_]*gannaway.Watchable{
                test_page.gannaway_count.asWatchable(),
                test_page.gannaway_doubled.asWatchable(),
            },
            .callback = struct {
                fn onChange(changed: *const gannaway.Watchable) void {
                    _ = changed;
                    const count = GannawayData.count_ptr.get();
                    const doubled = GannawayData.page_ptr.gannaway_doubled.get();
                    const msg = std.fmt.allocPrint(GannawayData.page_ptr.arena.allocator(), "Count: {}, Doubled: {}", .{ count, doubled }) catch return;
                    GannawayData.page_ptr.gannaway_log.append(msg) catch {};
                }
            }.onChange,
        });

        // Subscribe watcher to state changes
        try test_page.gannaway_count.subscribe(test_page.gannaway_watcher.asObserver());
    }

    fn deinit(self: *page.Page, allocator: std.mem.Allocator) void {
        const test_page: *ReactiveTestPage = @fieldParentPtr("base", self);

        // Clean up current reactive system
        test_page.current_count.deinit();
        
        // Clean up heap-allocated reactive objects (fix memory leak)
        test_page.current_doubled.deinit();
        allocator.destroy(test_page.current_doubled);
        
        test_page.current_effect.deinit();
        allocator.destroy(test_page.current_effect);
        
        test_page.current_log.deinit();

        // Clean up Gannaway system
        test_page.gannaway_count.deinit();
        test_page.gannaway_doubled.deinit();
        test_page.gannaway_watcher.deinit();
        test_page.gannaway_log.deinit();

        // Clean up arena
        test_page.arena.deinit();
    }

    fn update(self: *page.Page, dt: f32) void {
        _ = self;
        _ = dt;
    }

    fn render(self: *const page.Page, links: *std.ArrayList(page.Link), arena: std.mem.Allocator) !void {
        const test_page: *const ReactiveTestPage = @fieldParentPtr("base", self);

        const screen_width = 1920.0;
        const screen_height = 1080.0;

        // Header
        try links.append(page.createLink("REACTIVE SYSTEM COMPARISON TEST", "", screen_width / 2.0 - 300, 50, 600, 60));

        // Column headers
        const left_x = 200.0;
        const right_x = 1000.0;
        const header_y = 150.0;

        try links.append(page.createLink("Current System (Svelte 5 style)", "", left_x, header_y, 500, 40));

        try links.append(page.createLink("Gannaway System (Explicit)", "", right_x, header_y, 500, 40));

        // Divider line (using a thin box)
        try links.append(page.createLink("", "", screen_width / 2.0 - 2, header_y + 60, 4, 600));

        // Current system panel
        const current_y = 250.0;
        const mutable_page: *ReactiveTestPage = @constCast(test_page);
        const current_count_text = try std.fmt.allocPrint(arena, "Count: {}", .{mutable_page.current_count.get()});
        try links.append(page.createLink(current_count_text, "", left_x, current_y, 300, 35));

        try links.append(page.createLink("Increment", "/reactive-test?current_increment", left_x, current_y + 50, 150, 40));

        const current_doubled_text = try std.fmt.allocPrint(arena, "Doubled: {}", .{mutable_page.current_doubled.get()});
        try links.append(page.createLink(current_doubled_text, "", left_x, current_y + 110, 300, 35));

        try links.append(page.createLink("Effect Log:", "", left_x, current_y + 170, 200, 30));

        // Show last 5 log entries for current system
        const current_log_start = if (mutable_page.current_log.items.len > 5)
            mutable_page.current_log.items.len - 5
        else
            0;

        for (mutable_page.current_log.items[current_log_start..], 0..) |log_entry, i| {
            const log_text = try std.fmt.allocPrint(arena, "> {s}", .{log_entry});
            try links.append(page.createLink(log_text, "", left_x + 20, current_y + 210 + @as(f32, @floatFromInt(i)) * 30, 450, 25));
        }

        // Gannaway system panel
        const gannaway_y = 250.0;
        const gannaway_count_text = try std.fmt.allocPrint(arena, "Count: {}", .{mutable_page.gannaway_count.get()});
        try links.append(page.createLink(gannaway_count_text, "", right_x, gannaway_y, 300, 35));

        try links.append(page.createLink("Increment", "/reactive-test?gannaway_increment", right_x, gannaway_y + 50, 150, 40));

        const gannaway_doubled_text = try std.fmt.allocPrint(arena, "Doubled: {}", .{mutable_page.gannaway_doubled.get()});
        try links.append(page.createLink(gannaway_doubled_text, "", right_x, gannaway_y + 110, 300, 35));

        try links.append(page.createLink("Watch Log:", "", right_x, gannaway_y + 170, 200, 30));

        // Show last 5 log entries for Gannaway system
        const gannaway_log_start = if (mutable_page.gannaway_log.items.len > 5)
            mutable_page.gannaway_log.items.len - 5
        else
            0;

        for (mutable_page.gannaway_log.items[gannaway_log_start..], 0..) |log_entry, i| {
            const log_text = try std.fmt.allocPrint(arena, "> {s}", .{log_entry});
            try links.append(page.createLink(log_text, "", right_x + 20, gannaway_y + 210 + @as(f32, @floatFromInt(i)) * 30, 450, 25));
        }

        // Back button
        try links.append(page.createLink("Back to Menu", "/", screen_width / 2.0 - 100, screen_height - 150, 200, 50));

        // Note: Increment actions are now handled by the router
    }

    fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
        const test_page: *ReactiveTestPage = @fieldParentPtr("base", self);
        allocator.destroy(test_page);
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const test_page = try allocator.create(ReactiveTestPage);
    test_page.* = .{
        .base = .{
            .vtable = .{
                .init = ReactiveTestPage.init,
                .deinit = ReactiveTestPage.deinit,
                .update = ReactiveTestPage.update,
                .render = ReactiveTestPage.render,
                .destroy = ReactiveTestPage.destroy,
            },
            .path = "/reactive-test",
            .title = "Reactive System Test",
        },
        .arena = undefined,
        .current_count = undefined,
        .current_doubled = undefined,
        .current_effect = undefined,
        .current_log = undefined,
        .gannaway_count = undefined,
        .gannaway_doubled = undefined,
        .gannaway_watcher = undefined,
        .gannaway_log = undefined,
    };
    return &test_page.base;
}
