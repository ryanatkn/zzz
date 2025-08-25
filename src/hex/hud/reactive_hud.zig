const std = @import("std");
const c = @import("../../lib/platform/sdl.zig");
const history = @import("../../lib/core/collections.zig");
const router_mod = @import("router.zig");
const game_renderer = @import("../game_renderer.zig");
const browser_renderer = @import("renderer.zig");
const page = @import("../../lib/browser/page.zig");
const math = @import("../../lib/math/mod.zig");
const loggers = @import("../../lib/debug/loggers.zig");

// Reactive system imports
const reactive = @import("../../lib/reactive/mod.zig");
const component = @import("../../lib/reactive/component.zig");
const ide_page = @import("../../roots/menu/ide/+page.zig");

/// Reactive HUD component data
pub const ReactiveHudData = struct {
    // Traditional state (still needed for complex objects)
    history: history.SimpleHistory,
    router: router_mod.Router,
    renderer: browser_renderer.BrowserRenderer,
    links: std.ArrayList(page.Link),
    allocator: std.mem.Allocator,
    link_arena: std.heap.ArenaAllocator,

    // Reactive state
    is_open: *reactive.Signal(bool),
    current_path: *reactive.Signal([]const u8),
    hovered_link: *reactive.Signal(?usize),
    needs_rerender: *reactive.Signal(bool),

    // Derived values
    can_go_back: *reactive.Derived(bool),
    can_go_forward: *reactive.Derived(bool),

    // Cache for last rendered frame to avoid unnecessary work
    last_link_count: u32,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, base_renderer: *game_renderer.GameRenderer) !Self {
        return Self.initWithOptions(allocator, base_renderer);
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, base_renderer: *game_renderer.GameRenderer) !Self {
        // Create reactive signals
        const is_open_signal = try allocator.create(reactive.Signal(bool));
        is_open_signal.* = try reactive.Signal(bool).init(allocator, false);

        const current_path_signal = try allocator.create(reactive.Signal([]const u8));
        current_path_signal.* = try reactive.Signal([]const u8).init(allocator, "/");

        const hovered_link_signal = try allocator.create(reactive.Signal(?usize));
        hovered_link_signal.* = try reactive.Signal(?usize).init(allocator, null);

        const needs_rerender_signal = try allocator.create(reactive.Signal(bool));
        needs_rerender_signal.* = try reactive.Signal(bool).init(allocator, true);

        var router = router_mod.Router.init(allocator);
        router.setGameRenderer(base_renderer);

        var self = Self{
            .history = history.SimpleHistory.init(),
            .router = router,
            .renderer = browser_renderer.BrowserRenderer.init(base_renderer),
            .links = std.ArrayList(page.Link).init(allocator),
            .allocator = allocator,
            .link_arena = std.heap.ArenaAllocator.init(allocator),
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
        const ui_log = loggers.getUILog();
        ui_log.info("reactive_hud", "Initializing reactive HUD font system...", .{});
        try self.renderer.initFonts(allocator);
        ui_log.info("reactive_hud", "Reactive HUD font system initialized", .{});

        // Initialize with home page
        try self.router.navigate("/");

        return self;
    }

    fn createCanGoBackDerived(self: *Self) !*reactive.Derived(bool) {
        const SelfRef = struct {
            var hud_ref: *ReactiveHudData = undefined;
        };
        SelfRef.hud_ref = self;

        return try reactive.derived(self.allocator, bool, struct {
            fn compute() bool {
                const hud = SelfRef.hud_ref;
                // Track dependency on current_path to recompute when navigation changes
                _ = hud.current_path.get();
                return hud.history.current_index > 0;
            }
        }.compute);
    }

    fn createCanGoForwardDerived(self: *Self) !*reactive.Derived(bool) {
        const SelfRef = struct {
            var hud_ref: *ReactiveHudData = undefined;
        };
        SelfRef.hud_ref = self;

        return try reactive.derived(self.allocator, bool, struct {
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

        if (new_state) {
            // Reset to home when opening
            self.history = history.SimpleHistory.init();
            self.router.navigate("/") catch |err| {
                const ui_log = loggers.getUILog();
                ui_log.err("reactive_hud", "Failed to navigate to home page in reactive HUD: {}", .{err});
                // Don't open HUD if navigation fails
                return;
            };
            // Use a constant string literal for the home path - no duplication needed
            self.current_path.set("/");
        }

        self.is_open.set(new_state);
    }

    pub fn navigateTo(self: *Self, path: []const u8) !void {
        try self.history.navigate(path);
        try self.router.navigate(path);

        // CRITICAL: Signal<[]const u8> stores the slice directly, not the string data.
        // If we pass a temporary slice (from link.path or function parameters),
        // it becomes a dangling pointer when the function returns, causing crashes.
        // We must duplicate the string so the signal owns stable memory.
        const owned_path = try self.link_arena.allocator().dupe(u8, path);
        self.current_path.set(owned_path);
    }

    pub fn setHoveredLink(self: *Self, link_index: ?usize) void {
        self.hovered_link.set(link_index);
    }

    pub fn goBack(self: *Self) !bool {
        if (self.history.back()) {
            const path = self.history.getCurrentPath();
            try self.router.navigate(path);

            // Even though SimpleHistory returns stable slices from fixed buffers,
            // we still duplicate for consistency with navigateTo() memory model
            const owned_path = try self.link_arena.allocator().dupe(u8, path);
            self.current_path.set(owned_path);
            return true;
        }
        return false;
    }

    pub fn goForward(self: *Self) !bool {
        if (self.history.forward()) {
            const path = self.history.getCurrentPath();
            try self.router.navigate(path);

            // Even though SimpleHistory returns stable slices from fixed buffers,
            // we still duplicate for consistency with navigateTo() memory model
            const owned_path = try self.link_arena.allocator().dupe(u8, path);
            self.current_path.set(owned_path);
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
        self.link_arena.deinit();
    }

    // Component vtable implementation
    fn onMount(state: *anyopaque) !void {
        _ = state;
        const ui_log = loggers.getUILog();
        ui_log.info("reactive_hud", "Reactive HUD component mounted", .{});
    }

    fn onUnmount(state: *anyopaque) void {
        _ = state;
        const ui_log = loggers.getUILog();
        ui_log.info("reactive_hud", "Reactive HUD component unmounted", .{});
    }

    fn onRender(state: *anyopaque) !void {
        const self = component.castComponentState(ReactiveHudData, state);

        // This is called automatically when reactive dependencies change
        // Mark that we need to re-render
        self.needs_rerender.set(true);

        const ui_log = loggers.getUILog();
        ui_log.debug("reactive_hud", "Reactive HUD render triggered - path: {s}, open: {}", .{ self.current_path.peek(), self.is_open.peek() });
    }

    fn shouldRender(state: *anyopaque) bool {
        const self = component.castComponentState(ReactiveHudData, state);

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
        const self = component.castComponentState(ReactiveHudData, state);
        self.deinit();
        allocator.destroy(self);
    }

    pub const vtable = component.ReactiveComponent.ComponentVTable{
        .onMount = ReactiveHudData.onMount,
        .onUnmount = ReactiveHudData.onUnmount,
        .onRender = ReactiveHudData.onRender,
        .shouldRender = ReactiveHudData.shouldRender,
        .destroy = ReactiveHudData.destroy,
    };
};

/// Main reactive HUD system
pub const ReactiveHud = struct {
    component: *component.ReactiveComponent,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, base_renderer: *game_renderer.GameRenderer) !Self {
        return Self.initWithOptions(allocator, base_renderer);
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, base_renderer: *game_renderer.GameRenderer) !Self {
        const hud_data = try ReactiveHudData.initWithOptions(allocator, base_renderer);

        const reactive_component = try component.createComponent(ReactiveHudData, allocator, hud_data, ReactiveHudData.vtable);

        // Mount the component to start reactive lifecycle
        try reactive_component.mount();

        return Self{
            .component = reactive_component,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.component.deinit();
    }

    pub fn getHudData(self: *Self) *ReactiveHudData {
        return component.getComponentData(ReactiveHudData, self.component);
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
                        const mouse_x = button_event.x;
                        const mouse_y = button_event.y;

                        // Check IDE page-specific interactions first
                        if (hud_data.router.getCurrentPage()) |current_page| {
                            if (std.mem.eql(u8, current_page.path, "/ide")) {
                                const ide_page_impl: *ide_page.IDEPage = @fieldParentPtr("base", current_page);
                                const point = math.Vec2{ .x = mouse_x, .y = mouse_y };

                                // Try terminal click first
                                if (ide_page_impl.handleTerminalClick(point)) {
                                    return true;
                                }

                                // Try file tree interaction
                                if (ide_page_impl.handleFileTreeClick(point) catch false) {
                                    return true; // File tree handled the click
                                }
                            }
                        }

                        // Check if clicking a link
                        if (hud_data.hovered_link.peek()) |link_index| {
                            const link = hud_data.links.items[link_index];
                            try hud_data.navigateTo(link.path);
                        }

                        // Check navigation bar buttons
                        const screen_size = hud_data.renderer.getScreenSize();
                        const bar_y = screen_size.y * 0.1;
                        const button_margin = 50.0;

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

                // Handle system keys first
                if (key_event.scancode == c.sdl.SDL_SCANCODE_GRAVE) { // Backtick
                    self.toggle();
                    return true;
                } else if (key_event.scancode == c.sdl.SDL_SCANCODE_ESCAPE) {
                    hud_data.is_open.set(false);
                    return true;
                }

                // Route to current page for input handling
                if (hud_data.router.getCurrentPage()) |current_page| {
                    if (std.mem.eql(u8, current_page.path, "/ide")) {
                        const ide_page_impl: *ide_page.IDEPage = @fieldParentPtr("base", current_page);
                        if (ide_page_impl.handleKeyboardInput(key_event)) {
                            return true; // IDE page handled the key
                        }
                    }
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
        const batcher = reactive.batch.getGlobalBatcher() orelse return;
        batcher.startBatch();
        defer batcher.endBatch();

        // Render overlay background
        try hud_data.renderer.renderOverlay(cmd_buffer, render_pass);

        // Render navigation bar with reactive state
        try hud_data.renderer.renderNavigationBar(cmd_buffer, render_pass, hud_data.current_path.peek(), hud_data.can_go_back.get(), hud_data.can_go_forward.get());

        // Reset arena for new frame (retaining capacity for performance)
        _ = hud_data.link_arena.reset(.retain_capacity);

        // Clear links for this frame
        hud_data.links.clearRetainingCapacity();

        // Render current page with layouts (passing arena for dynamic strings)
        try hud_data.router.renderWithLayouts(&hud_data.links, hud_data.link_arena.allocator());

        // Render custom GPU content for pages that need it
        if (hud_data.router.getCurrentPage()) |current_page| {
            try hud_data.renderer.renderPageContent(cmd_buffer, render_pass, current_page);
        }

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
