const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const reactive = @import("../reactive/mod.zig");
const component = @import("component.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;
const Color = colors.Color;
const Component = component.Component;
const ComponentProps = component.ComponentProps;

pub const ScrollDirection = enum {
    vertical,
    horizontal,
    both,
};

pub const ScrollBar = struct {
    visible: bool = true,
    width: f32 = 12.0,
    thumb_color: Color = Color{ .r = 100, .g = 100, .b = 100, .a = 255 },
    track_color: Color = Color{ .r = 40, .g = 40, .b = 40, .a = 255 },
    thumb_hover_color: Color = Color{ .r = 120, .g = 120, .b = 120, .a = 255 },
};

pub const ScrollableView = struct {
    base: Component,
    
    content_size: reactive.Signal(Vec2),
    scroll_offset: reactive.Signal(Vec2),
    scroll_direction: reactive.Signal(ScrollDirection),
    scrollbar_config: reactive.Signal(ScrollBar),
    
    is_dragging_vertical: bool = false,
    is_dragging_horizontal: bool = false,
    drag_start_offset: Vec2 = Vec2{ .x = 0, .y = 0 },
    drag_start_mouse: Vec2 = Vec2{ .x = 0, .y = 0 },
    
    const Self = @This();
    
    pub fn init(self: *Component, allocator: std.mem.Allocator, props: ComponentProps) !void {
        _ = props;
        const scrollable: *ScrollableView = @fieldParentPtr("base", self);
        
        scrollable.content_size = try reactive.signal(allocator, Vec2, Vec2{ .x = 1000, .y = 1000 });
        scrollable.scroll_offset = try reactive.signal(allocator, Vec2, Vec2{ .x = 0, .y = 0 });
        scrollable.scroll_direction = try reactive.signal(allocator, ScrollDirection, .both);
        scrollable.scrollbar_config = try reactive.signal(allocator, ScrollBar, ScrollBar{});
    }
    
    pub fn deinit(self: *Component, allocator: std.mem.Allocator) void {
        _ = allocator;
        const scrollable: *ScrollableView = @fieldParentPtr("base", self);
        
        scrollable.content_size.deinit();
        scrollable.scroll_offset.deinit();
        scrollable.scroll_direction.deinit();
        scrollable.scrollbar_config.deinit();
    }
    
    pub fn update(self: *Component, dt: f32) void {
        _ = dt;
        const scrollable: *ScrollableView = @fieldParentPtr("base", self);
        
        scrollable.clampScrollOffset();
        scrollable.updateChildPositions();
    }
    
    pub fn render(self: *const Component, renderer: anytype) !void {
        const scrollable: *const ScrollableView = @fieldParentPtr("base", self);
        
        if (!self.props.visible.get()) return;
        const config = scrollable.scrollbar_config.get();
        const direction = scrollable.scroll_direction.get();
        
        if (config.visible) {
            if (direction == .vertical or direction == .both) {
                const v_scrollbar = scrollable.getVerticalScrollbarBounds();
                const v_thumb = scrollable.getVerticalThumbBounds();
                
                if (@hasDecl(@TypeOf(renderer), "drawRect")) {
                    try renderer.drawRect(v_scrollbar, config.track_color);
                    try renderer.drawRect(v_thumb, config.thumb_color);
                }
            }
            
            if (direction == .horizontal or direction == .both) {
                const h_scrollbar = scrollable.getHorizontalScrollbarBounds();
                const h_thumb = scrollable.getHorizontalThumbBounds();
                
                if (@hasDecl(@TypeOf(renderer), "drawRect")) {
                    try renderer.drawRect(h_scrollbar, config.track_color);
                    try renderer.drawRect(h_thumb, config.thumb_color);
                }
            }
        }
    }
    
    pub fn handleEvent(self: *Component, event: anytype) bool {
        const scrollable: *ScrollableView = @fieldParentPtr("base", self);
        
        if (!self.props.enabled.get() or !self.props.visible.get()) return false;
        
        if (@hasField(@TypeOf(event), "mouse_wheel_y")) {
            if (event.mouse_wheel_y != 0) {
                const offset = scrollable.scroll_offset.get();
                const new_y = offset.y - event.mouse_wheel_y * 20;
                scrollable.scroll_offset.set(Vec2{ .x = offset.x, .y = new_y });
                return true;
            }
        }
        
        if (@hasField(@TypeOf(event), "mouse_x") and @hasField(@TypeOf(event), "mouse_y")) {
            const mouse_pos = Vec2{ .x = event.mouse_x, .y = event.mouse_y };
            
            const v_thumb = scrollable.getVerticalThumbBounds();
            const h_thumb = scrollable.getHorizontalThumbBounds();
            const over_v_thumb = v_thumb.contains(mouse_pos);
            const over_h_thumb = h_thumb.contains(mouse_pos);
            
            if (@hasField(@TypeOf(event), "mouse_pressed") and event.mouse_pressed) {
                if (over_v_thumb) {
                    scrollable.is_dragging_vertical = true;
                    scrollable.drag_start_offset = scrollable.scroll_offset.get();
                    scrollable.drag_start_mouse = mouse_pos;
                    return true;
                } else if (over_h_thumb) {
                    scrollable.is_dragging_horizontal = true;
                    scrollable.drag_start_offset = scrollable.scroll_offset.get();
                    scrollable.drag_start_mouse = mouse_pos;
                    return true;
                }
            } else if (@hasField(@TypeOf(event), "mouse_released") and event.mouse_released) {
                scrollable.is_dragging_vertical = false;
                scrollable.is_dragging_horizontal = false;
            } else if (scrollable.is_dragging_vertical or scrollable.is_dragging_horizontal) {
                const delta = Vec2{
                    .x = mouse_pos.x - scrollable.drag_start_mouse.x,
                    .y = mouse_pos.y - scrollable.drag_start_mouse.y,
                };
                
                const bounds = self.props.getBounds();
                const content_size = scrollable.content_size.get();
                const viewport_size = scrollable.getViewportSize();
                
                var new_offset = scrollable.drag_start_offset;
                
                if (scrollable.is_dragging_vertical) {
                    const scrollable_height = content_size.y - viewport_size.y;
                    const scrollbar_travel = bounds.size.y - scrollable.getVerticalThumbBounds().size.y;
                    if (scrollbar_travel > 0) {
                        new_offset.y = scrollable.drag_start_offset.y + (delta.y / scrollbar_travel) * scrollable_height;
                    }
                }
                
                if (scrollable.is_dragging_horizontal) {
                    const scrollable_width = content_size.x - viewport_size.x;
                    const scrollbar_travel = bounds.size.x - scrollable.getHorizontalThumbBounds().size.x;
                    if (scrollbar_travel > 0) {
                        new_offset.x = scrollable.drag_start_offset.x + (delta.x / scrollbar_travel) * scrollable_width;
                    }
                }
                
                scrollable.scroll_offset.set(new_offset);
                return true;
            }
        }
        
        return false;
    }
    
    pub fn destroy(self: *Component, allocator: std.mem.Allocator) void {
        const scrollable: *ScrollableView = @fieldParentPtr("base", self);
        allocator.destroy(scrollable);
    }
    
    fn getViewportSize(self: *const ScrollableView) Vec2 {
        const bounds = self.base.props.getBounds();
        const config = self.scrollbar_config.get();
        const direction = self.scroll_direction.get();
        
        var viewport_size = bounds.size;
        
        if (config.visible) {
            if (direction == .vertical or direction == .both) {
                viewport_size.x -= config.width;
            }
            if (direction == .horizontal or direction == .both) {
                viewport_size.y -= config.width;
            }
        }
        
        return viewport_size;
    }
    
    fn getVerticalScrollbarBounds(self: *const ScrollableView) Rectangle {
        const bounds = self.base.props.getBounds();
        const config = self.scrollbar_config.get();
        
        return Rectangle{
            .position = Vec2{
                .x = bounds.position.x + bounds.size.x - config.width,
                .y = bounds.position.y,
            },
            .size = Vec2{
                .x = config.width,
                .y = bounds.size.y - if (self.scroll_direction.get() == .both) config.width else 0,
            },
        };
    }
    
    fn getHorizontalScrollbarBounds(self: *const ScrollableView) Rectangle {
        const bounds = self.base.props.getBounds();
        const config = self.scrollbar_config.get();
        
        return Rectangle{
            .position = Vec2{
                .x = bounds.position.x,
                .y = bounds.position.y + bounds.size.y - config.width,
            },
            .size = Vec2{
                .x = bounds.size.x - if (self.scroll_direction.get() == .both) config.width else 0,
                .y = config.width,
            },
        };
    }
    
    fn getVerticalThumbBounds(self: *const ScrollableView) Rectangle {
        const scrollbar = self.getVerticalScrollbarBounds();
        const content_size = self.content_size.get();
        const viewport_size = self.getViewportSize();
        const offset = self.scroll_offset.get();
        
        const thumb_height = (viewport_size.y / content_size.y) * scrollbar.size.y;
        const thumb_y = (offset.y / (content_size.y - viewport_size.y)) * (scrollbar.size.y - thumb_height);
        
        return Rectangle{
            .position = Vec2{
                .x = scrollbar.position.x,
                .y = scrollbar.position.y + thumb_y,
            },
            .size = Vec2{
                .x = scrollbar.size.x,
                .y = @max(thumb_height, 20),
            },
        };
    }
    
    fn getHorizontalThumbBounds(self: *const ScrollableView) Rectangle {
        const scrollbar = self.getHorizontalScrollbarBounds();
        const content_size = self.content_size.get();
        const viewport_size = self.getViewportSize();
        const offset = self.scroll_offset.get();
        
        const thumb_width = (viewport_size.x / content_size.x) * scrollbar.size.x;
        const thumb_x = (offset.x / (content_size.x - viewport_size.x)) * (scrollbar.size.x - thumb_width);
        
        return Rectangle{
            .position = Vec2{
                .x = scrollbar.position.x + thumb_x,
                .y = scrollbar.position.y,
            },
            .size = Vec2{
                .x = @max(thumb_width, 20),
                .y = scrollbar.size.y,
            },
        };
    }
    
    fn clampScrollOffset(self: *ScrollableView) void {
        const offset = self.scroll_offset.get();
        const content_size = self.content_size.get();
        const viewport_size = self.getViewportSize();
        
        const max_x = @max(0, content_size.x - viewport_size.x);
        const max_y = @max(0, content_size.y - viewport_size.y);
        
        const clamped = Vec2{
            .x = std.math.clamp(offset.x, 0, max_x),
            .y = std.math.clamp(offset.y, 0, max_y),
        };
        
        if (!offset.equals(clamped)) {
            self.scroll_offset.set(clamped);
        }
    }
    
    fn updateChildPositions(self: *ScrollableView) void {
        const offset = self.scroll_offset.get();
        const viewport_bounds = self.base.props.getBounds();
        
        for (self.base.children.items) |child| {
            const child_pos = child.props.position.get();
            const adjusted_pos = Vec2{
                .x = viewport_bounds.position.x + child_pos.x - offset.x,
                .y = viewport_bounds.position.y + child_pos.y - offset.y,
            };
            
            child.props.position.set(adjusted_pos);
        }
    }
    
    pub fn scrollTo(self: *ScrollableView, position: Vec2) void {
        self.scroll_offset.set(position);
    }
    
    pub fn scrollToBottom(self: *ScrollableView) void {
        const content_size = self.content_size.get();
        const viewport_size = self.getViewportSize();
        
        self.scroll_offset.set(Vec2{
            .x = self.scroll_offset.get().x,
            .y = @max(0, content_size.y - viewport_size.y),
        });
    }
    
    pub fn setContentSize(self: *ScrollableView, size: Vec2) void {
        self.content_size.set(size);
    }
};

pub fn createScrollableView(
    allocator: std.mem.Allocator,
    position: Vec2,
    size: Vec2,
    content_size: Vec2,
) !*Component {
    const scrollable = try allocator.create(ScrollableView);
    
    var props = try ComponentProps.init(allocator, position, size);
    props.background_color.set(Color{ .r = 30, .g = 30, .b = 30, .a = 255 });
    
    scrollable.* = ScrollableView{
        .base = Component{
            .vtable = Component.VTable{
                .init = ScrollableView.init,
                .deinit = ScrollableView.deinit,
                .update = ScrollableView.update,
                .render = ScrollableView.render,
                .handle_event = ScrollableView.handleEvent,
                .destroy = ScrollableView.destroy,
            },
            .props = props,
            .children = std.ArrayList(*Component).init(allocator),
            .parent = null,
        },
        .content_size = undefined,
        .scroll_offset = undefined,
        .scroll_direction = undefined,
        .scrollbar_config = undefined,
    };
    
    try scrollable.base.init(allocator, props);
    scrollable.content_size.set(content_size);
    
    return &scrollable.base;
}