const std = @import("std");
const c = @import("../lib/c.zig");
const types = @import("../lib/types.zig");
const controls = @import("../hex/controls.zig");
const history = @import("../lib/history.zig");
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

    pub fn init(allocator: std.mem.Allocator, base_renderer: *game_renderer.GameRenderer) !Hud {
        var hud_sys = Hud{
            .is_open = false,
            .history = history.SimpleHistory.init(),
            .router = router_mod.Router.init(allocator),
            .renderer = browser_renderer.BrowserRenderer.init(base_renderer),
            .links = std.ArrayList(page.Link).init(allocator),
            .hovered_link = null,
            .allocator = allocator,
        };
        
        // Initialize font system
        try hud_sys.renderer.initFonts(allocator);

        // Initialize with home page
        try hud_sys.router.navigate("/");
        
        return hud_sys;
    }

    pub fn deinit(self: *Hud) void {
        self.renderer.deinitFonts(self.allocator);
        self.router.deinit();
        self.links.deinit();
    }

    pub fn toggle(self: *Hud) void {
        self.is_open = !self.is_open;
        if (self.is_open) {
            // Reset to home when opening
            self.history = history.SimpleHistory.init();
            self.router.navigate("/") catch unreachable;
        }
    }

    pub fn handleEvent(self: *Hud, event: c.sdl.SDL_Event) !bool {
        if (!self.is_open) return false;

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
                        // Check if clicking a link
                        if (self.hovered_link) |link_index| {
                            const link = self.links.items[link_index];
                            try self.navigateTo(link.path);
                        }
                        
                        // Check navigation bar buttons
                        const screen_height = 1080.0; // TODO: Get from renderer
                        const bar_y = screen_height * 0.1;
                        const button_margin = 50.0;
                        
                        const mouse_x = button_event.x;
                        const mouse_y = button_event.y;
                        
                        // Back button bounds (circle at button_margin, bar_y with radius 15)
                        if (mouse_x >= button_margin - 15 and mouse_x <= button_margin + 15 and
                            mouse_y >= bar_y - 15 and mouse_y <= bar_y + 15) {
                            if (self.history.back()) {
                                try self.router.navigate(self.history.getCurrentPath());
                            }
                            return true;
                        }
                        
                        // Forward button bounds (circle at button_margin + 40, bar_y with radius 15)
                        if (mouse_x >= button_margin + 25 and mouse_x <= button_margin + 55 and
                            mouse_y >= bar_y - 15 and mouse_y <= bar_y + 15) {
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
                
                // Check which link is hovered
                self.hovered_link = null;
                for (self.links.items, 0..) |link, i| {
                    if (mouse_x >= link.bounds.position.x and 
                        mouse_x <= link.bounds.position.x + link.bounds.size.x and
                        mouse_y >= link.bounds.position.y and 
                        mouse_y <= link.bounds.position.y + link.bounds.size.y) {
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
        try self.renderer.renderNavigationBar(
            cmd_buffer,
            render_pass,
            self.history.getCurrentPath(),
            can_go_back,
            can_go_forward
        );

        // Clear links for this frame
        self.links.clearRetainingCapacity();

        // Render current page with layouts
        try self.router.renderWithLayouts(&self.links);

        // Render links with hover states
        try self.renderer.renderLinks(cmd_buffer, render_pass, self.links.items, self.hovered_link);
    }
};