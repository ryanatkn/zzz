/// Scrollable terminal component extending ScrollableView for terminal-specific needs
const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const reactive = @import("../reactive/mod.zig");
const component = @import("component.zig");
const scrollable = @import("scrollable.zig");
const terminal_renderer = @import("terminal_renderer.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;
const Color = colors.Color;
const Component = component.Component;
const ComponentProps = component.ComponentProps;
const ScrollableView = scrollable.ScrollableView;
const TerminalRenderer = terminal_renderer.TerminalRenderer;
const TerminalContent = terminal_renderer.TerminalContent;

pub const ScrollableTerminal = struct {
    base: ScrollableView,
    terminal_renderer: TerminalRenderer,
    
    // Terminal-specific state
    content: reactive.Signal(TerminalContent),
    header_text: reactive.Signal(?[]const u8),
    auto_scroll: reactive.Signal(bool), // Scroll to bottom when new content arrives
    
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(self: *Component, allocator: std.mem.Allocator, props: ComponentProps) !void {
        const scrollable_terminal: *ScrollableTerminal = @fieldParentPtr("base", self);
        
        // Initialize base scrollable view
        try ScrollableView.init(&scrollable_terminal.base.base, allocator, props);
        
        // Initialize terminal-specific components
        scrollable_terminal.terminal_renderer = try TerminalRenderer.createDefault(allocator);
        scrollable_terminal.content = try reactive.signal(allocator, TerminalContent, TerminalContent.empty());
        scrollable_terminal.header_text = try reactive.signal(allocator, ?[]const u8, null);
        scrollable_terminal.auto_scroll = try reactive.signal(allocator, bool, true);
        scrollable_terminal.allocator = allocator;
        
        // Configure scrollable for terminal use
        scrollable_terminal.base.scroll_direction.set(.vertical);
        
        // Set up scroll bar appearance for terminal theme
        var scrollbar_config = scrollable_terminal.base.scrollbar_config.get();
        scrollbar_config.thumb_color = Color{ .r = 100, .g = 100, .b = 100, .a = 200 };
        scrollbar_config.track_color = Color{ .r = 40, .g = 40, .b = 40, .a = 150 };
        scrollbar_config.width = 8.0;
        scrollable_terminal.base.scrollbar_config.set(scrollbar_config);
    }

    pub fn deinit(self: *Component, allocator: std.mem.Allocator) void {
        const scrollable_terminal: *ScrollableTerminal = @fieldParentPtr("base", self);
        
        scrollable_terminal.terminal_renderer.deinit();
        scrollable_terminal.content.deinit();
        scrollable_terminal.header_text.deinit();
        scrollable_terminal.auto_scroll.deinit();
        
        // Deinitialize base
        ScrollableView.deinit(&scrollable_terminal.base.base, allocator);
    }

    pub fn update(self: *Component, dt: f32) void {
        const scrollable_terminal: *ScrollableTerminal = @fieldParentPtr("base", self);
        
        // Update base scrollable
        ScrollableView.update(&scrollable_terminal.base.base, dt);
        
        // Update terminal renderer (cursor blinking, etc.)
        scrollable_terminal.terminal_renderer.update(dt);
        
        // Auto-scroll to bottom if enabled and new content arrived
        if (scrollable_terminal.auto_scroll.get()) {
            scrollable_terminal.scrollToBottom();
        }
        
        // Update viewport based on current bounds
        const bounds = self.props.getBounds();
        scrollable_terminal.terminal_renderer.updateViewport(bounds);
        
        // Sync scroll position with terminal renderer
        scrollable_terminal.syncScrollPosition();
    }

    pub fn render(self: *const Component, renderer: anytype) !void {
        const scrollable_terminal: *const ScrollableTerminal = @fieldParentPtr("base", self);
        
        if (!self.props.visible.get()) return;
        
        const bounds = self.props.getBounds();
        const content = scrollable_terminal.content.get();
        const header = scrollable_terminal.header_text.get();
        
        // Render terminal content
        try scrollable_terminal.terminal_renderer.render(renderer, bounds, content, header);
        
        // Render scrollbar overlay
        try ScrollableView.render(&scrollable_terminal.base.base, renderer);
    }

    pub fn handleEvent(self: *Component, event: anytype) bool {
        const scrollable_terminal: *ScrollableTerminal = @fieldParentPtr("base", self);
        
        // Handle scroll events
        if (scrollable_terminal.handleScrollEvent(event)) {
            return true;
        }
        
        // Let base handle other events (scrollbar interaction)
        return ScrollableView.handleEvent(&scrollable_terminal.base.base, event);
    }

    pub fn destroy(self: *Component, allocator: std.mem.Allocator) void {
        const scrollable_terminal: *ScrollableTerminal = @fieldParentPtr("base", self);
        allocator.destroy(scrollable_terminal);
    }

    /// Handle terminal-specific scroll events
    fn handleScrollEvent(self: *ScrollableTerminal, event: anytype) bool {
        if (@hasField(@TypeOf(event), "type")) {
            switch (event.type) {
                // Handle mouse wheel scrolling
                0x20000000 => { // SDL_EVENT_MOUSE_WHEEL (placeholder value)
                    if (@hasField(@TypeOf(event), "wheel")) {
                        const wheel_y = event.wheel.y;
                        const scroll_lines = 3; // Lines to scroll per wheel click
                        
                        if (wheel_y > 0) {
                            self.scrollUp(scroll_lines);
                        } else if (wheel_y < 0) {
                            self.scrollDown(scroll_lines);
                        }
                        return true;
                    }
                },
                // Handle keyboard scrolling
                0x10000000 => { // SDL_EVENT_KEY_DOWN (placeholder value)
                    if (@hasField(@TypeOf(event), "key")) {
                        // Page Up/Down for faster scrolling
                        if (event.key.scancode == 0x4B) { // Page Up
                            self.scrollUp(10);
                            return true;
                        } else if (event.key.scancode == 0x4E) { // Page Down
                            self.scrollDown(10);
                            return true;
                        }
                    }
                },
                else => {},
            }
        }
        return false;
    }

    /// Scroll up by specified number of lines
    pub fn scrollUp(self: *ScrollableTerminal, lines: usize) void {
        self.terminal_renderer.scroll(@intCast(lines));
        self.auto_scroll.set(false); // Disable auto-scroll when manually scrolling
    }

    /// Scroll down by specified number of lines
    pub fn scrollDown(self: *ScrollableTerminal, lines: usize) void {
        self.terminal_renderer.scroll(-@as(i32, @intCast(lines)));
        
        // Re-enable auto-scroll if we've scrolled to the bottom
        const viewport = self.terminal_renderer.viewport.get();
        if (viewport.scroll_offset == 0) {
            self.auto_scroll.set(true);
        }
    }

    /// Scroll to the bottom (most recent content)
    pub fn scrollToBottom(self: *ScrollableTerminal) void {
        // Reset scroll offset to 0 (bottom)
        var viewport = self.terminal_renderer.viewport.get();
        viewport.scroll_offset = 0;
        self.terminal_renderer.viewport.set(viewport);
        self.auto_scroll.set(true);
    }

    /// Sync scroll position between terminal renderer and scrollable view
    fn syncScrollPosition(self: *ScrollableTerminal) void {
        const viewport = self.terminal_renderer.viewport.get();
        const content = self.content.get();
        
        // Calculate total content height
        const total_lines = content.lines.len + 1; // +1 for input line
        const content_height = @as(f32, @floatFromInt(total_lines)) * self.terminal_renderer.text_renderer.config.get().line_height;
        
        // Update scrollable view content size
        self.base.content_size.set(Vec2{ .x = 0, .y = content_height });
        
        // Calculate scroll offset as percentage
        const scroll_percentage = if (total_lines > viewport.visible_lines)
            @as(f32, @floatFromInt(viewport.scroll_offset)) / @as(f32, @floatFromInt(total_lines - viewport.visible_lines))
        else 
            0.0;
            
        // Update scrollable view scroll offset
        const bounds = self.base.base.props.getBounds();
        const max_scroll = @max(0, content_height - bounds.size.y);
        self.base.scroll_offset.set(Vec2{ .x = 0, .y = max_scroll * scroll_percentage });
    }

    /// Update terminal content
    pub fn setContent(self: *ScrollableTerminal, content: TerminalContent) void {
        self.content.set(content);
    }

    /// Set header text
    pub fn setHeaderText(self: *ScrollableTerminal, text: ?[]const u8) void {
        self.header_text.set(text);
    }

    /// Set focus state
    pub fn setFocus(self: *ScrollableTerminal, focused: bool) void {
        self.terminal_renderer.setFocus(focused);
    }

    /// Enable/disable auto-scroll
    pub fn setAutoScroll(self: *ScrollableTerminal, enabled: bool) void {
        self.auto_scroll.set(enabled);
    }

    /// Initialize border for focus indication
    pub fn initBorder(self: *ScrollableTerminal, bounds: Rectangle) !void {
        try self.terminal_renderer.initBorder(bounds);
    }
};

/// Create a scrollable terminal component
pub fn createScrollableTerminal(allocator: std.mem.Allocator, bounds: Rectangle) !*ScrollableTerminal {
    const scrollable_terminal = try allocator.create(ScrollableTerminal);
    
    const props = ComponentProps{
        .bounds = try reactive.signal(allocator, Rectangle, bounds),
        .visible = try reactive.signal(allocator, bool, true),
        .background_color = try reactive.signal(allocator, Color, Color{ .r = 20, .g = 25, .b = 30, .a = 255 }),
    };
    
    scrollable_terminal.* = ScrollableTerminal{
        .base = ScrollableView{
            .base = Component{
                .props = props,
                .vtable = Component.VTable{
                    .init = ScrollableTerminal.init,
                    .deinit = ScrollableTerminal.deinit,
                    .update = ScrollableTerminal.update,
                    .render = ScrollableTerminal.render,
                    .handleEvent = ScrollableTerminal.handleEvent,
                    .destroy = ScrollableTerminal.destroy,
                },
            },
            .content_size = undefined, // Will be initialized in init()
            .scroll_offset = undefined,
            .scroll_direction = undefined,
            .scrollbar_config = undefined,
        },
        .terminal_renderer = undefined, // Will be initialized in init()
        .content = undefined,
        .header_text = undefined,
        .auto_scroll = undefined,
        .allocator = allocator,
    };
    
    try scrollable_terminal.base.base.vtable.init(&scrollable_terminal.base.base, allocator, props);
    return scrollable_terminal;
}