const std = @import("std");
const c = @import("../lib/c.zig");
const types = @import("../lib/types.zig");
const history = @import("../lib/history.zig");
const router_mod = @import("router.zig");
const game_renderer = @import("../hex/game_renderer.zig");
const browser_renderer = @import("renderer.zig");
const page = @import("page.zig");

// Reactive system imports
const ReactiveComponent = @import("../lib/reactive/component.zig").ReactiveComponent;
const createComponent = @import("../lib/reactive/component.zig").createComponent;
const getComponentData = @import("../lib/reactive/component.zig").getComponentData;
const signal = @import("../lib/reactive/signal.zig");
const derived = @import("../lib/reactive/derived.zig");
const effect = @import("../lib/reactive/effect.zig");
const batch = @import("../lib/reactive/batch.zig");

/// Reactive HUD component data
pub const ReactiveHudData = struct {
    // Traditional state (still needed for complex objects)
    history: history.SimpleHistory,
    router: router_mod.Router,
    renderer: browser_renderer.BrowserRenderer,
    links: std.ArrayList(page.Link),
    allocator: std.mem.Allocator,

    // Reactive state
    is_open: *signal.Signal(bool),
    current_path: *signal.Signal([]const u8),
    hovered_link: *signal.Signal(?usize),
    needs_rerender: *signal.Signal(bool),

    // Derived values
    can_go_back: *derived.Derived(bool),
    can_go_forward: *derived.Derived(bool),

    // Cache for last rendered frame to avoid unnecessary work
    last_link_count: u32,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, base_renderer: *game_renderer.GameRenderer) !Self {
        return Self.initWithOptions(allocator, base_renderer, false);
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, base_renderer: *game_renderer.GameRenderer, font_test_mode: bool) !Self {
        // Create reactive signals
        const is_open_signal = try allocator.create(signal.Signal(bool));
        is_open_signal.* = try signal.Signal(bool).init(allocator, false);

        const current_path_signal = try allocator.create(signal.Signal([]const u8));
        current_path_signal.* = try signal.Signal([]const u8).init(allocator, "/");

        const hovered_link_signal = try allocator.create(signal.Signal(?usize));
        hovered_link_signal.* = try signal.Signal(?usize).init(allocator, null);

        const needs_rerender_signal = try allocator.create(signal.Signal(bool));
        needs_rerender_signal.* = try signal.Signal(bool).init(allocator, true);

        var self = Self{
            .history = history.SimpleHistory.init(),
            .router = router_mod.Router.init(allocator),
            .renderer = browser_renderer.BrowserRenderer.init(base_renderer),
            .links = std.ArrayList(page.Link).init(allocator),
            .allocator = allocator,
            .is_open = is_open_signal,
            .current_path = current_path_signal,
            .hovered_link = hovered_link_signal,
            .needs_rerender = needs_rerender_signal,
            .can_go_back = undefined, // Set below
            .can_go_forward = undefined, // Set below
            .last_link_count = 0,
        };

        // Create derived values
        self.can_go_back = try self.createCanGoBackDerived();
        self.can_go_forward = try self.createCanGoForwardDerived();

        // Initialize font system
        const log = std.log.scoped(.reactive_hud);
        log.info("Initializing reactive HUD font system...", .{});
        try self.renderer.initFonts(allocator);
        log.info("Reactive HUD font system initialized", .{});

        // Initialize with appropriate page based on mode
        if (font_test_mode) {
            try self.router.navigate("/font-grid-test");
            // Set path signal and history without triggering reset
            current_path_signal.set("/font-grid-test");
            _ = self.history.navigate("/font-grid-test") catch {};
            // Open HUD in font test mode
            is_open_signal.set(true);
        } else {
            try self.router.navigate("/");
        }

        return self;
    }

    fn createCanGoBackDerived(self: *Self) !*derived.Derived(bool) {
        const SelfRef = struct {
            var hud_ref: *ReactiveHudData = undefined;
        };
        SelfRef.hud_ref = self;

        return try derived.derived(self.allocator, bool, struct {
            fn compute() bool {
                const hud = SelfRef.hud_ref;
                // Track dependency on current_path to recompute when navigation changes
                _ = hud.current_path.get();
                return hud.history.current_index > 0;
            }
        }.compute);
    }

    fn createCanGoForwardDerived(self: *Self) !*derived.Derived(bool) {
        const SelfRef = struct {
            var hud_ref: *ReactiveHudData = undefined;
        };
        SelfRef.hud_ref = self;

        return try derived.derived(self.allocator, bool, struct {
            fn compute() bool {
                const hud = SelfRef.hud_ref;
                // Track dependency on current_path to recompute when navigation changes
                _ = hud.current_path.get();
                return hud.history.current_index < hud.history.stack_size - 1;
            }
        }.compute);
    }

    pub fn toggle(self: *Self) void {
        const new_state = !self.is_open.peek();
        self.is_open.set(new_state);

        if (new_state) {
            // Reset to home when opening
            self.history = history.SimpleHistory.init();
            self.router.navigate("/") catch unreachable;
            self.current_path.set("/");
        }
    }

    pub fn navigateTo(self: *Self, path: []const u8) !void {
        try self.history.navigate(path);
        try self.router.navigate(path);
        self.current_path.set(path);
    }

    pub fn setHoveredLink(self: *Self, link_index: ?usize) void {
        self.hovered_link.set(link_index);
    }

    pub fn goBack(self: *Self) !bool {
        if (self.history.back()) {
            const path = self.history.getCurrentPath();
            try self.router.navigate(path);
            self.current_path.set(path);
            return true;
        }
        return false;
    }

    pub fn goForward(self: *Self) !bool {
        if (self.history.forward()) {
            const path = self.history.getCurrentPath();
            try self.router.navigate(path);
            self.current_path.set(path);
            return true;
        }
        return false;
    }

    pub fn updatePage(self: *Self, dt: f32) void {
        if (!self.is_open.peek()) return;

        if (self.router.getCurrentPage()) |current_page| {
            current_page.update(dt);
        }
    }

    pub fn deinit(self: *Self) void {
        // Clean up derived values
        self.can_go_back.deinit();
        self.allocator.destroy(self.can_go_back);
        self.can_go_forward.deinit();
        self.allocator.destroy(self.can_go_forward);

        // Clean up reactive signals
        self.is_open.deinit();
        self.allocator.destroy(self.is_open);
        self.current_path.deinit();
        self.allocator.destroy(self.current_path);
        self.hovered_link.deinit();
        self.allocator.destroy(self.hovered_link);
        self.needs_rerender.deinit();
        self.allocator.destroy(self.needs_rerender);

        // Clean up traditional components
        self.renderer.deinitFonts(self.allocator);
        self.router.deinit();
        self.links.deinit();
    }

    // Component vtable implementation
    fn onMount(state: *anyopaque) !void {
        _ = state;
        const log = std.log.scoped(.reactive_hud);
        log.info("Reactive HUD component mounted", .{});
    }

    fn onUnmount(state: *anyopaque) void {
        _ = state;
        const log = std.log.scoped(.reactive_hud);
        log.info("Reactive HUD component unmounted", .{});
    }

    fn onRender(state: *anyopaque) !void {
        const self = @as(*ReactiveHudData, @ptrCast(@alignCast(state)));

        // This is called automatically when reactive dependencies change
        // Mark that we need to re-render
        self.needs_rerender.set(true);

        const log = std.log.scoped(.reactive_hud);
        log.debug("Reactive HUD render triggered - path: {s}, open: {}", .{ self.current_path.peek(), self.is_open.peek() });
    }

    fn shouldRender(state: *anyopaque) bool {
        const self = @as(*ReactiveHudData, @ptrCast(@alignCast(state)));

        // Only render if HUD is open and something has changed
        const should_render = self.is_open.peek() and self.needs_rerender.peek();

        // Check if link count changed (cache optimization)
        const current_link_count = @as(u32, @intCast(self.links.items.len));
        if (current_link_count != self.last_link_count) {
            self.last_link_count = current_link_count;
            return true;
        }

        return should_render;
    }

    fn destroy(state: *anyopaque, allocator: std.mem.Allocator) void {
        const self = @as(*ReactiveHudData, @ptrCast(@alignCast(state)));
        self.deinit();
        allocator.destroy(self);
    }

    pub const vtable = ReactiveComponent.ComponentVTable{
        .onMount = ReactiveHudData.onMount,
        .onUnmount = ReactiveHudData.onUnmount,
        .onRender = ReactiveHudData.onRender,
        .shouldRender = ReactiveHudData.shouldRender,
        .destroy = ReactiveHudData.destroy,
    };
};

/// Main reactive HUD system
pub const ReactiveHud = struct {
    component: *ReactiveComponent,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, base_renderer: *game_renderer.GameRenderer) !Self {
        return Self.initWithOptions(allocator, base_renderer, false);
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, base_renderer: *game_renderer.GameRenderer, font_test_mode: bool) !Self {
        const hud_data = try ReactiveHudData.initWithOptions(allocator, base_renderer, font_test_mode);

        const component = try createComponent(ReactiveHudData, allocator, hud_data, ReactiveHudData.vtable);

        // Mount the component to start reactive lifecycle
        try component.mount();

        return Self{
            .component = component,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.component.deinit();
    }

    pub fn getHudData(self: *Self) *ReactiveHudData {
        return getComponentData(ReactiveHudData, self.component);
    }

    // Convenience methods that delegate to HUD data
    pub fn toggle(self: *Self) void {
        self.getHudData().toggle();
    }

    pub fn handleEvent(self: *Self, event: c.sdl.SDL_Event) !bool {
        const hud_data = self.getHudData();

        if (!hud_data.is_open.peek()) return false;

        switch (event.type) {
            c.sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                const button_event = event.button;

                switch (button_event.button) {
                    c.sdl.SDL_BUTTON_X1 => { // Back button
                        _ = try hud_data.goBack();
                        return true;
                    },
                    c.sdl.SDL_BUTTON_X2 => { // Forward button
                        _ = try hud_data.goForward();
                        return true;
                    },
                    c.sdl.SDL_BUTTON_LEFT => {
                        // Check if clicking a link
                        if (hud_data.hovered_link.peek()) |link_index| {
                            const link = hud_data.links.items[link_index];
                            try hud_data.navigateTo(link.path);
                        }

                        // Check navigation bar buttons
                        const screen_height = 1080.0; // TODO: Get from renderer
                        const bar_y = screen_height * 0.1;
                        const button_margin = 50.0;

                        const mouse_x = button_event.x;
                        const mouse_y = button_event.y;

                        // Back button bounds
                        if (mouse_x >= button_margin - 15 and mouse_x <= button_margin + 15 and
                            mouse_y >= bar_y - 15 and mouse_y <= bar_y + 15)
                        {
                            _ = try hud_data.goBack();
                            return true;
                        }

                        // Forward button bounds
                        if (mouse_x >= button_margin + 25 and mouse_x <= button_margin + 55 and
                            mouse_y >= bar_y - 15 and mouse_y <= bar_y + 15)
                        {
                            _ = try hud_data.goForward();
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
                var hovered_link: ?usize = null;
                for (hud_data.links.items, 0..) |link, i| {
                    if (mouse_x >= link.bounds.position.x and
                        mouse_x <= link.bounds.position.x + link.bounds.size.x and
                        mouse_y >= link.bounds.position.y and
                        mouse_y <= link.bounds.position.y + link.bounds.size.y)
                    {
                        hovered_link = i;
                        break;
                    }
                }
                hud_data.setHoveredLink(hovered_link);
                return true;
            },
            c.sdl.SDL_EVENT_KEY_DOWN => {
                const key_event = event.key;
                if (key_event.scancode == c.sdl.SDL_SCANCODE_GRAVE) { // Backtick
                    self.toggle();
                    return true;
                } else if (key_event.scancode == c.sdl.SDL_SCANCODE_ESCAPE) {
                    hud_data.is_open.set(false);
                    return true;
                }
            },
            else => {},
        }

        return false;
    }

    pub fn update(self: *Self, dt: f32) void {
        const hud_data = self.getHudData();
        hud_data.updatePage(dt);
    }

    pub fn render(self: *Self, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass) !void {
        const hud_data = self.getHudData();

        if (!hud_data.is_open.peek()) return;

        // Use batching for rendering operations
        const batcher = batch.getGlobalBatcher() orelse return;
        batcher.startBatch();
        defer batcher.endBatch();

        // Render overlay background
        try hud_data.renderer.renderOverlay(cmd_buffer, render_pass);

        // Render navigation bar with reactive state
        try hud_data.renderer.renderNavigationBar(cmd_buffer, render_pass, hud_data.current_path.peek(), hud_data.can_go_back.get(), hud_data.can_go_forward.get());

        // Clear links for this frame
        hud_data.links.clearRetainingCapacity();

        // Render current page with layouts
        try hud_data.router.renderWithLayouts(&hud_data.links);

        // Render links with hover states
        try hud_data.renderer.renderLinks(cmd_buffer, render_pass, hud_data.links.items, hud_data.hovered_link.peek());

        // Mark render as complete
        hud_data.needs_rerender.set(false);
    }

    pub fn isOpen(self: *Self) bool {
        return self.getHudData().is_open.peek();
    }

    // Compatibility method for existing code
    pub fn is_open(self: *Self) bool {
        return self.isOpen();
    }
};
