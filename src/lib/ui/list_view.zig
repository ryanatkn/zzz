const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const reactive = @import("../reactive.zig");
const component = @import("component.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;
const Color = colors.Color;
const Component = component.Component;
const ComponentProps = component.ComponentProps;

pub const ListItem = struct {
    text: []const u8,
    color: Color = Color{ .r = 200, .g = 200, .b = 200, .a = 255 },
    icon: ?[]const u8 = null,
    user_data: ?*anyopaque = null,
};

pub const ListView = struct {
    base: Component,
    
    items: std.ArrayList(ListItem),
    selected_index: reactive.Signal(?usize),
    
    item_height: reactive.Signal(f32),
    max_visible_items: reactive.Signal(usize),
    scroll_offset: reactive.Signal(usize),
    
    text_color: reactive.Signal(Color),
    selected_bg_color: reactive.Signal(Color),
    hover_bg_color: reactive.Signal(Color),
    
    auto_scroll_to_bottom: reactive.Signal(bool),
    virtual_scrolling: reactive.Signal(bool),
    
    hovered_index: ?usize = null,
    
    on_item_selected: ?*const fn (usize, ListItem) void = null,
    on_item_double_clicked: ?*const fn (usize, ListItem) void = null,
    
    const Self = @This();
    
    pub fn init(self: *Component, allocator: std.mem.Allocator, props: ComponentProps) !void {
        _ = props;
        const list: *ListView = @fieldParentPtr("base", self);
        
        list.items = std.ArrayList(ListItem).init(allocator);
        list.selected_index = try reactive.signal(allocator, ?usize, null);
        
        list.item_height = try reactive.signal(allocator, f32, 20.0);
        list.max_visible_items = try reactive.signal(allocator, usize, 20);
        list.scroll_offset = try reactive.signal(allocator, usize, 0);
        
        list.text_color = try reactive.signal(allocator, Color, Color{ .r = 200, .g = 200, .b = 200, .a = 255 });
        list.selected_bg_color = try reactive.signal(allocator, Color, Color{ .r = 60, .g = 100, .b = 160, .a = 255 });
        list.hover_bg_color = try reactive.signal(allocator, Color, Color{ .r = 50, .g = 50, .b = 50, .a = 255 });
        
        list.auto_scroll_to_bottom = try reactive.signal(allocator, bool, false);
        list.virtual_scrolling = try reactive.signal(allocator, bool, true);
    }
    
    pub fn deinit(self: *Component, allocator: std.mem.Allocator) void {
        _ = allocator;
        const list: *ListView = @fieldParentPtr("base", self);
        
        list.items.deinit();
        list.selected_index.deinit();
        list.item_height.deinit();
        list.max_visible_items.deinit();
        list.scroll_offset.deinit();
        list.text_color.deinit();
        list.selected_bg_color.deinit();
        list.hover_bg_color.deinit();
        list.auto_scroll_to_bottom.deinit();
        list.virtual_scrolling.deinit();
    }
    
    pub fn update(self: *Component, dt: f32) void {
        _ = dt;
        const list: *ListView = @fieldParentPtr("base", self);
        
        if (list.auto_scroll_to_bottom.get()) {
            const total_items = list.items.items.len;
            const max_visible = list.max_visible_items.get();
            
            if (total_items > max_visible) {
                list.scroll_offset.set(total_items - max_visible);
            }
        }
    }
    
    pub fn render(self: *const Component, renderer: anytype) !void {
        const list: *const ListView = @fieldParentPtr("base", self);
        
        if (!self.props.visible.get()) return;
        
        const bounds = self.props.getBounds();
        const item_height = list.item_height.get();
        const scroll_offset = list.scroll_offset.get();
        
        if (@hasDecl(@TypeOf(renderer), "drawRect")) {
            const bg_color = Color{ .r = 30, .g = 30, .b = 30, .a = 255 };
            try renderer.drawRect(bounds, bg_color);
        }
        
        const start_index = if (list.virtual_scrolling.get()) scroll_offset else 0;
        const visible_count = @as(usize, @intFromFloat(bounds.size.y / item_height)) + 1;
        const end_index = @min(start_index + visible_count, list.items.items.len);
        
        var y = bounds.position.y;
        
        for (start_index..end_index) |i| {
            const item = list.items.items[i];
            const item_rect = Rectangle{
                .position = Vec2{ .x = bounds.position.x, .y = y },
                .size = Vec2{ .x = bounds.size.x, .y = item_height },
            };
            
            if (list.selected_index.get()) |selected| {
                if (selected == i) {
                    if (@hasDecl(@TypeOf(renderer), "drawRect")) {
                        try renderer.drawRect(item_rect, list.selected_bg_color.get());
                    }
                }
            } else if (list.hovered_index) |hovered| {
                if (hovered == i) {
                    if (@hasDecl(@TypeOf(renderer), "drawRect")) {
                        try renderer.drawRect(item_rect, list.hover_bg_color.get());
                    }
                }
            }
            
            const text_x = bounds.position.x + 5;
            const text_y = y + item_height / 2 - 6;
            
            if (@hasDecl(@TypeOf(renderer), "drawText")) {
                if (item.icon) |icon| {
                    var text_buf: [512]u8 = undefined;
                    const text = std.fmt.bufPrint(&text_buf, "{s} {s}", .{ icon, item.text }) catch item.text;
                    try renderer.drawText(text, Vec2{ .x = text_x, .y = text_y }, item.color, 12.0);
                } else {
                    try renderer.drawText(item.text, Vec2{ .x = text_x, .y = text_y }, item.color, 12.0);
                }
            }
            
            y += item_height;
            if (y >= bounds.position.y + bounds.size.y) break;
        }
        
        if (list.items.items.len > visible_count) {
            const scrollbar_width = 8.0;
            const scrollbar_x = bounds.position.x + bounds.size.x - scrollbar_width;
            const scrollbar_height = bounds.size.y;
            
            const thumb_height = (visible_count * scrollbar_height) / @as(f32, @floatFromInt(list.items.items.len));
            const thumb_y = bounds.position.y + (@as(f32, @floatFromInt(scroll_offset)) * scrollbar_height) / @as(f32, @floatFromInt(list.items.items.len));
            
            if (@hasDecl(@TypeOf(renderer), "drawRect")) {
                const track_rect = Rectangle{
                    .position = Vec2{ .x = scrollbar_x, .y = bounds.position.y },
                    .size = Vec2{ .x = scrollbar_width, .y = scrollbar_height },
                };
                try renderer.drawRect(track_rect, Color{ .r = 40, .g = 40, .b = 40, .a = 255 });
                
                const thumb_rect = Rectangle{
                    .position = Vec2{ .x = scrollbar_x, .y = thumb_y },
                    .size = Vec2{ .x = scrollbar_width, .y = @max(thumb_height, 20) },
                };
                try renderer.drawRect(thumb_rect, Color{ .r = 100, .g = 100, .b = 100, .a = 255 });
            }
        }
    }
    
    pub fn handleEvent(self: *Component, event: anytype) bool {
        const list: *ListView = @fieldParentPtr("base", self);
        
        if (!self.props.enabled.get() or !self.props.visible.get()) return false;
        
        if (@hasField(@TypeOf(event), "mouse_x") and @hasField(@TypeOf(event), "mouse_y")) {
            const mouse_pos = Vec2{ .x = event.mouse_x, .y = event.mouse_y };
            const bounds = self.props.getBounds();
            
            if (!bounds.contains(mouse_pos)) {
                list.hovered_index = null;
                return false;
            }
            
            const item_height = list.item_height.get();
            const relative_y = mouse_pos.y - bounds.position.y;
            const item_index = @as(usize, @intFromFloat(relative_y / item_height)) + list.scroll_offset.get();
            
            if (item_index < list.items.items.len) {
                list.hovered_index = item_index;
                
                if (@hasField(@TypeOf(event), "mouse_pressed") and event.mouse_pressed) {
                    list.selected_index.set(item_index);
                    
                    if (list.on_item_selected) |callback| {
                        callback(item_index, list.items.items[item_index]);
                    }
                    
                    return true;
                } else if (@hasField(@TypeOf(event), "mouse_double_clicked") and event.mouse_double_clicked) {
                    if (list.on_item_double_clicked) |callback| {
                        callback(item_index, list.items.items[item_index]);
                    }
                    return true;
                }
            } else {
                list.hovered_index = null;
            }
        }
        
        if (@hasField(@TypeOf(event), "mouse_wheel_y")) {
            if (event.mouse_wheel_y != 0) {
                const current_offset = list.scroll_offset.get();
                const new_offset = if (event.mouse_wheel_y > 0)
                    @max(0, @as(i32, @intCast(current_offset)) - 3)
                else
                    @min(list.items.items.len -| 1, current_offset + 3);
                
                list.scroll_offset.set(@intCast(new_offset));
                return true;
            }
        }
        
        return false;
    }
    
    pub fn destroy(self: *Component, allocator: std.mem.Allocator) void {
        const list: *ListView = @fieldParentPtr("base", self);
        allocator.destroy(list);
    }
    
    pub fn addItem(self: *ListView, item: ListItem) !void {
        try self.items.append(item);
        
        if (self.auto_scroll_to_bottom.get()) {
            self.scrollToBottom();
        }
    }
    
    pub fn clearItems(self: *ListView) void {
        self.items.clearRetainingCapacity();
        self.selected_index.set(null);
        self.hovered_index = null;
        self.scroll_offset.set(0);
    }
    
    pub fn removeItem(self: *ListView, index: usize) void {
        if (index >= self.items.items.len) return;
        
        _ = self.items.orderedRemove(index);
        
        if (self.selected_index.get()) |selected| {
            if (selected == index) {
                self.selected_index.set(null);
            } else if (selected > index) {
                self.selected_index.set(selected - 1);
            }
        }
    }
    
    pub fn scrollToItem(self: *ListView, index: usize) void {
        if (index >= self.items.items.len) return;
        
        const max_visible = self.max_visible_items.get();
        
        if (index < self.scroll_offset.get()) {
            self.scroll_offset.set(index);
        } else if (index >= self.scroll_offset.get() + max_visible) {
            self.scroll_offset.set(index - max_visible + 1);
        }
    }
    
    pub fn scrollToBottom(self: *ListView) void {
        const total_items = self.items.items.len;
        const max_visible = self.max_visible_items.get();
        
        if (total_items > max_visible) {
            self.scroll_offset.set(total_items - max_visible);
        } else {
            self.scroll_offset.set(0);
        }
    }
    
    pub fn setOnItemSelected(self: *ListView, callback: *const fn (usize, ListItem) void) void {
        self.on_item_selected = callback;
    }
    
    pub fn setOnItemDoubleClicked(self: *ListView, callback: *const fn (usize, ListItem) void) void {
        self.on_item_double_clicked = callback;
    }
    
    pub fn setAutoScrollToBottom(self: *ListView, enabled: bool) void {
        self.auto_scroll_to_bottom.set(enabled);
    }
};

pub fn createListView(allocator: std.mem.Allocator, position: Vec2, size: Vec2) !*Component {
    const list = try allocator.create(ListView);
    
    const props = try ComponentProps.init(allocator, position, size);
    
    list.* = ListView{
        .base = Component{
            .vtable = Component.VTable{
                .init = ListView.init,
                .deinit = ListView.deinit,
                .update = ListView.update,
                .render = ListView.render,
                .handle_event = ListView.handleEvent,
                .destroy = ListView.destroy,
            },
            .props = props,
            .children = std.ArrayList(*Component).init(allocator),
            .parent = null,
        },
        .items = undefined,
        .selected_index = undefined,
        .item_height = undefined,
        .max_visible_items = undefined,
        .scroll_offset = undefined,
        .text_color = undefined,
        .selected_bg_color = undefined,
        .hover_bg_color = undefined,
        .auto_scroll_to_bottom = undefined,
        .virtual_scrolling = undefined,
    };
    
    try list.base.init(allocator, props);
    
    const visible_items = @as(usize, @intFromFloat(size.y / 20.0));
    list.max_visible_items.set(visible_items);
    
    return &list.base;
}