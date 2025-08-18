const std = @import("std");
const c = @import("../lib/platform/sdl.zig");
const controls = @import("../hex/controls.zig");
const history = @import("../lib/core/collections.zig");
const router_mod = @import("router.zig");
const game_renderer = @import("../hex/game_renderer.zig");
const browser_renderer = @import("renderer.zig");
const page = @import("page.zig");

pub const Hud = struct {
    is_open: bool,
    history: history.SimpleHistory,
    router: router_mod.Router,
    renderer: browser_renderer.BrowserRenderer,
    links: std.ArrayList(page.Link),
    hovered_link: ?usize,
    allocator: std.mem.Allocator,
    link_arena: std.heap.ArenaAllocator,

    pub fn init(allocator: std.mem.Allocator, base_renderer: *game_renderer.GameRenderer) !Hud {
        var hud_sys = Hud{
            .is_open = false,
            .history = history.SimpleHistory.init(),
            .router = router_mod.Router.init(allocator),
            .renderer = browser_renderer.BrowserRenderer.init(base_renderer),
            .links = std.ArrayList(page.Link).init(allocator),
            .hovered_link = null,
            .allocator = allocator,
            .link_arena = std.heap.ArenaAllocator.init(allocator),
        };

        // Initialize font system
        const log = std.log.scoped(.hud);
        log.info("Initializing HUD font system...", .{});
        try hud_sys.renderer.initFonts(allocator);
        log.info("HUD font system initialized", .{});

        // Initialize with home page
        try hud_sys.router.navigate("/");

        return hud_sys;
    }

    pub fn deinit(self: *Hud) void {
        self.renderer.deinitFonts(self.allocator);
        self.router.deinit();
        self.links.deinit();
        self.link_arena.deinit();
    }

    pub fn toggle(self: *Hud) void {
        self.is_open = !self.is_open;
        if (self.is_open) {
            // Reset to home when opening
            self.history = history.SimpleHistory.init();
            self.router.navigate("/") catch |err| {
                std.log.err("Failed to navigate to home page: {}", .{err});
                // If navigation fails, keep HUD closed to prevent broken state
                self.is_open = false;
            };
        }
    }

    pub fn handleEvent(self: *Hud, event: c.sdl.SDL_Event) !bool {
        if (!self.is_open) return false;

        // Debug: Log all mouse clicks when HUD is open
        if (event.type == c.sdl.SDL_EVENT_MOUSE_BUTTON_DOWN) {
            const log = std.log.scoped(.hud_click);
            log.info("HUD click detected at ({},{})", .{ event.button.x, event.button.y });
        }

        switch (event.type) {
            c.sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                const button_event = event.button;

                switch (button_event.button) {
                    c.sdl.SDL_BUTTON_X1 => { // Back button
                        if (self.history.back()) {
                            try self.router.navigate(self.history.getCurrentPath());
                        }
                        return true;
                    },
                    c.sdl.SDL_BUTTON_X2 => { // Forward button
                        if (self.history.forward()) {
                            try self.router.navigate(self.history.getCurrentPath());
                        }
                        return true;
                    },
                    c.sdl.SDL_BUTTON_LEFT => {
                        const mouse_x = button_event.x;
                        const mouse_y = button_event.y;

                        // Check IDE page-specific interactions first
                        if (self.router.getCurrentPage()) |current_page| {
                            const log = std.log.scoped(.hud_routing);
                            log.info("Current page: '{s}'", .{current_page.path});

                            if (std.mem.eql(u8, current_page.path, "/ide")) {
                                log.info("On IDE page, handling file tree click", .{});
                                const ide_page_impl: *@import("../menu/ide/+page.zig").IDEPage = @fieldParentPtr("base", current_page);

                                // Try file tree interaction first
                                const point = @import("../lib/math/mod.zig").Vec2{ .x = @floatFromInt(mouse_x), .y = @floatFromInt(mouse_y) };
                                if (ide_page_impl.handleFileTreeClick(point) catch false) {
                                    return true; // File tree handled the click
                                }

                                // Search controls removed for simplicity
                            }
                        }

                        // Check if clicking a link
                        if (self.hovered_link) |link_index| {
                            if (link_index >= self.links.items.len) {
                                std.log.err("Invalid hovered link index: {} >= {}", .{ link_index, self.links.items.len });
                                self.hovered_link = null;
                                return true;
                            }
                            const link = self.links.items[link_index];
                            // Copy path to stack buffer to avoid use-after-free from arena reset
                            var path_buffer: [512]u8 = undefined;
                            const path_copy = std.fmt.bufPrint(&path_buffer, "{s}", .{link.path}) catch {
                                std.log.err("Link path too long: '{s}'", .{link.path});
                                return true;
                            };
                            try self.navigateTo(path_copy);
                        }

                        // Check navigation bar buttons
                        const screen_size = self.renderer.getScreenSize();
                        const bar_y = screen_size.y * 0.1;
                        const button_margin = 50.0;

                        // Back button bounds (circle at button_margin, bar_y with radius 15)
                        if (mouse_x >= button_margin - 15 and mouse_x <= button_margin + 15 and
                            mouse_y >= bar_y - 15 and mouse_y <= bar_y + 15)
                        {
                            if (self.history.back()) {
                                try self.router.navigate(self.history.getCurrentPath());
                            }
                            return true;
                        }

                        // Forward button bounds (circle at button_margin + 40, bar_y with radius 15)
                        if (mouse_x >= button_margin + 25 and mouse_x <= button_margin + 55 and
                            mouse_y >= bar_y - 15 and mouse_y <= bar_y + 15)
                        {
                            if (self.history.forward()) {
                                try self.router.navigate(self.history.getCurrentPath());
                            }
                            return true;
                        }

                        return true;
                    },
                    else => {},
                }
            },
            c.sdl.SDL_EVENT_MOUSE_MOTION => {
                const motion_event = event.motion;
                const mouse_x = motion_event.x;
                const mouse_y = motion_event.y;

                // Check IDE page-specific hover first
                if (self.router.getCurrentPage()) |current_page| {
                    if (std.mem.eql(u8, current_page.path, "/ide")) {
                        const ide_page_impl: *@import("../menu/ide/+page.zig").IDEPage = @fieldParentPtr("base", current_page);

                        const point = @import("../lib/math/mod.zig").Vec2{ .x = @floatFromInt(mouse_x), .y = @floatFromInt(mouse_y) };

                        // Adjust point to be relative to file explorer panel (same as in handleFileTreeClick)
                        const explorer_rect = @import("../lib/math/mod.zig").Vec2{ .x = 8 + 8, .y = 60 + 8 + 30 };
                        const relative_point = @import("../lib/math/mod.zig").Vec2{ .x = point.x - explorer_rect.x, .y = point.y - explorer_rect.y };

                        ide_page_impl.file_tree_component.handleHover(relative_point);
                    }
                }

                // Check which link is hovered
                self.hovered_link = null;
                for (self.links.items, 0..) |link, i| {
                    if (mouse_x >= link.bounds.position.x and
                        mouse_x <= link.bounds.position.x + link.bounds.size.x and
                        mouse_y >= link.bounds.position.y and
                        mouse_y <= link.bounds.position.y + link.bounds.size.y)
                    {
                        self.hovered_link = i;
                        break;
                    }
                }
                return true;
            },
            c.sdl.SDL_EVENT_KEY_DOWN => {
                const key_event = event.key;
                if (key_event.scancode == c.sdl.SDL_SCANCODE_GRAVE) { // Backtick
                    self.toggle();
                    return true;
                } else if (key_event.scancode == c.sdl.SDL_SCANCODE_ESCAPE) {
                    self.is_open = false;
                    return true;
                }
            },
            else => {},
        }

        return false;
    }

    pub fn navigateTo(self: *Hud, path: []const u8) !void {
        try self.history.navigate(path);
        try self.router.navigate(path);
    }

    pub fn update(self: *Hud, dt: f32) void {
        if (!self.is_open) return;

        if (self.router.getCurrentPage()) |current_page| {
            current_page.update(dt);
        }
    }

    pub fn render(self: *Hud, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass) !void {
        if (!self.is_open) return;

        // Render overlay background
        try self.renderer.renderOverlay(cmd_buffer, render_pass);

        // Render navigation bar
        const can_go_back = self.history.current_index > 0;
        const can_go_forward = self.history.current_index < self.history.stack_size - 1;
        try self.renderer.renderNavigationBar(cmd_buffer, render_pass, self.history.getCurrentPath(), can_go_back, can_go_forward);

        // Reset arena for new frame (retaining capacity for performance)
        _ = self.link_arena.reset(.retain_capacity);

        // Clear links for this frame
        self.links.clearRetainingCapacity();

        // Render current page with layouts (passing arena for dynamic strings)
        try self.router.renderWithLayouts(&self.links, self.link_arena.allocator());

        // Render special page content (like IDE dashboard)
        if (self.router.getCurrentPage()) |current_page| {
            try self.renderer.renderPageContent(cmd_buffer, render_pass, current_page);
        }

        // Render links with hover states
        try self.renderer.renderLinks(cmd_buffer, render_pass, self.links.items, self.hovered_link);
    }
};
