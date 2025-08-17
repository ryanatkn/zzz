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

pub const TextArea = struct {
    base: Component,
    
    lines: std.ArrayList([]const u8),
    cursor_line: reactive.Signal(usize),
    cursor_column: reactive.Signal(usize),
    
    show_line_numbers: reactive.Signal(bool),
    line_number_width: reactive.Signal(f32),
    syntax_highlighting: reactive.Signal(bool),
    
    text_color: reactive.Signal(Color),
    line_number_color: reactive.Signal(Color),
    cursor_color: reactive.Signal(Color),
    selection_color: reactive.Signal(Color),
    
    is_focused: reactive.Signal(bool),
    is_readonly: reactive.Signal(bool),
    
    scroll_offset: reactive.Signal(Vec2),
    line_height: f32 = 16.0,
    char_width: f32 = 7.0,
    
    on_change: ?*const fn ([]const []const u8) void = null,
    
    const Self = @This();
    
    pub fn init(self: *Component, allocator: std.mem.Allocator, props: ComponentProps) !void {
        _ = props;
        const area: *TextArea = @fieldParentPtr("base", self);
        
        area.lines = std.ArrayList([]const u8).init(allocator);
        try area.lines.append("");
        
        area.cursor_line = try reactive.signal(allocator, usize, 0);
        area.cursor_column = try reactive.signal(allocator, usize, 0);
        
        area.show_line_numbers = try reactive.signal(allocator, bool, true);
        area.line_number_width = try reactive.signal(allocator, f32, 40.0);
        area.syntax_highlighting = try reactive.signal(allocator, bool, false);
        
        area.text_color = try reactive.signal(allocator, Color, Color{ .r = 200, .g = 200, .b = 200, .a = 255 });
        area.line_number_color = try reactive.signal(allocator, Color, Color{ .r = 100, .g = 100, .b = 100, .a = 255 });
        area.cursor_color = try reactive.signal(allocator, Color, Color{ .r = 255, .g = 255, .b = 255, .a = 255 });
        area.selection_color = try reactive.signal(allocator, Color, Color{ .r = 60, .g = 100, .b = 160, .a = 128 });
        
        area.is_focused = try reactive.signal(allocator, bool, false);
        area.is_readonly = try reactive.signal(allocator, bool, false);
        area.scroll_offset = try reactive.signal(allocator, Vec2, Vec2{ .x = 0, .y = 0 });
    }
    
    pub fn deinit(self: *Component, allocator: std.mem.Allocator) void {
        _ = allocator;
        const area: *TextArea = @fieldParentPtr("base", self);
        
        area.lines.deinit();
        area.cursor_line.deinit();
        area.cursor_column.deinit();
        area.show_line_numbers.deinit();
        area.line_number_width.deinit();
        area.syntax_highlighting.deinit();
        area.text_color.deinit();
        area.line_number_color.deinit();
        area.cursor_color.deinit();
        area.selection_color.deinit();
        area.is_focused.deinit();
        area.is_readonly.deinit();
        area.scroll_offset.deinit();
    }
    
    pub fn update(self: *Component, dt: f32) void {
        _ = self;
        _ = dt;
    }
    
    pub fn render(self: *const Component, renderer: anytype) !void {
        const area: *const TextArea = @fieldParentPtr("base", self);
        
        if (!self.props.visible.get()) return;
        
        const bounds = self.props.getBounds();
        
        if (@hasDecl(@TypeOf(renderer), "drawRect")) {
            const bg_color = Color{ .r = 30, .g = 30, .b = 30, .a = 255 };
            try renderer.drawRect(bounds, bg_color);
        }
        
        const show_line_nums = area.show_line_numbers.get();
        const line_num_width = if (show_line_nums) area.line_number_width.get() else 0;
        const scroll = area.scroll_offset.get();
        
        if (show_line_nums) {
            const line_num_bg = Rectangle{
                .position = bounds.position,
                .size = Vec2{ .x = line_num_width, .y = bounds.size.y },
            };
            
            if (@hasDecl(@TypeOf(renderer), "drawRect")) {
                const bg_color = Color{ .r = 25, .g = 25, .b = 25, .a = 255 };
                try renderer.drawRect(line_num_bg, bg_color);
            }
        }
        
        const text_start_x = bounds.position.x + line_num_width + 5;
        var y = bounds.position.y + 5 - scroll.y;
        
        for (area.lines.items, 0..) |line, i| {
            if (y > bounds.position.y + bounds.size.y) break;
            if (y + area.line_height < bounds.position.y) {
                y += area.line_height;
                continue;
            }
            
            if (show_line_nums and @hasDecl(@TypeOf(renderer), "drawText")) {
                var num_buf: [16]u8 = undefined;
                const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{i + 1}) catch "?";
                const num_x = bounds.position.x + line_num_width - @as(f32, @floatFromInt(num_str.len)) * area.char_width - 5;
                try renderer.drawText(num_str, Vec2{ .x = num_x, .y = y }, area.line_number_color.get(), 12.0);
            }
            
            if (@hasDecl(@TypeOf(renderer), "drawText") and line.len > 0) {
                try renderer.drawText(line, Vec2{ .x = text_start_x - scroll.x, .y = y }, area.text_color.get(), 12.0);
            }
            
            if (area.is_focused.get() and area.cursor_line.get() == i) {
                const cursor_x = text_start_x + @as(f32, @floatFromInt(area.cursor_column.get())) * area.char_width - scroll.x;
                const cursor_rect = Rectangle{
                    .position = Vec2{ .x = cursor_x, .y = y },
                    .size = Vec2{ .x = 2, .y = area.line_height },
                };
                
                if (@hasDecl(@TypeOf(renderer), "drawRect")) {
                    try renderer.drawRect(cursor_rect, area.cursor_color.get());
                }
            }
            
            y += area.line_height;
        }
    }
    
    pub fn handleEvent(self: *Component, event: anytype) bool {
        const area: *TextArea = @fieldParentPtr("base", self);
        
        if (!self.props.enabled.get() or !self.props.visible.get()) return false;
        
        if (@hasField(@TypeOf(event), "mouse_x") and @hasField(@TypeOf(event), "mouse_y")) {
            const mouse_pos = Vec2{ .x = event.mouse_x, .y = event.mouse_y };
            const bounds = self.props.getBounds();
            
            if (@hasField(@TypeOf(event), "mouse_pressed") and event.mouse_pressed) {
                if (bounds.contains(mouse_pos)) {
                    area.is_focused.set(true);
                    
                    const line_num_width = if (area.show_line_numbers.get()) area.line_number_width.get() else 0;
                    const text_start_x = bounds.position.x + line_num_width + 5;
                    const scroll = area.scroll_offset.get();
                    
                    const clicked_line = @as(usize, @intFromFloat(@max(0, (mouse_pos.y - bounds.position.y - 5 + scroll.y) / area.line_height)));
                    const clicked_col = @as(usize, @intFromFloat(@max(0, (mouse_pos.x - text_start_x + scroll.x) / area.char_width)));
                    
                    if (clicked_line < area.lines.items.len) {
                        area.cursor_line.set(clicked_line);
                        const line_len = area.lines.items[clicked_line].len;
                        area.cursor_column.set(@min(clicked_col, line_len));
                    }
                    
                    return true;
                } else {
                    area.is_focused.set(false);
                }
            }
        }
        
        if (@hasField(@TypeOf(event), "mouse_wheel_y")) {
            if (event.mouse_wheel_y != 0) {
                const scroll = area.scroll_offset.get();
                const new_y = @max(0, scroll.y - event.mouse_wheel_y * area.line_height * 3);
                area.scroll_offset.set(Vec2{ .x = scroll.x, .y = new_y });
                return true;
            }
        }
        
        return false;
    }
    
    pub fn destroy(self: *Component, allocator: std.mem.Allocator) void {
        const area: *TextArea = @fieldParentPtr("base", self);
        allocator.destroy(area);
    }
    
    pub fn setText(self: *TextArea, text: []const u8) !void {
        self.lines.clearRetainingCapacity();
        
        var it = std.mem.tokenize(u8, text, "\n");
        while (it.next()) |line| {
            try self.lines.append(line);
        }
        
        if (self.lines.items.len == 0) {
            try self.lines.append("");
        }
        
        self.cursor_line.set(0);
        self.cursor_column.set(0);
        
        if (self.on_change) |callback| {
            callback(self.lines.items);
        }
    }
    
    pub fn getSelectedText(self: *const TextArea) []const u8 {
        if (self.cursor_line.get() >= self.lines.items.len) return "";
        return self.lines.items[self.cursor_line.get()];
    }
    
    pub fn insertTextAtCursor(self: *TextArea, text: []const u8) !void {
        if (self.is_readonly.get()) return;
        _ = text;
        if (self.on_change) |callback| {
            callback(self.lines.items);
        }
    }
    
    pub fn deleteCharacterAtCursor(self: *TextArea) void {
        if (self.is_readonly.get()) return;
        if (self.on_change) |callback| {
            callback(self.lines.items);
        }
    }
    
    pub fn setReadOnly(self: *TextArea, readonly: bool) void {
        self.is_readonly.set(readonly);
    }
    
    pub fn setOnChange(self: *TextArea, callback: *const fn ([]const []const u8) void) void {
        self.on_change = callback;
    }
    
    pub fn focus(self: *TextArea) void {
        self.is_focused.set(true);
    }
    
    pub fn blur(self: *TextArea) void {
        self.is_focused.set(false);
    }
};

pub fn createTextArea(allocator: std.mem.Allocator, position: Vec2, size: Vec2) !*Component {
    const area = try allocator.create(TextArea);
    
    const props = try ComponentProps.init(allocator, position, size);
    
    area.* = TextArea{
        .base = Component{
            .vtable = Component.VTable{
                .init = TextArea.init,
                .deinit = TextArea.deinit,
                .update = TextArea.update,
                .render = TextArea.render,
                .handle_event = TextArea.handleEvent,
                .destroy = TextArea.destroy,
            },
            .props = props,
            .children = std.ArrayList(*Component).init(allocator),
            .parent = null,
        },
        .lines = undefined,
        .cursor_line = undefined,
        .cursor_column = undefined,
        .show_line_numbers = undefined,
        .line_number_width = undefined,
        .syntax_highlighting = undefined,
        .text_color = undefined,
        .line_number_color = undefined,
        .cursor_color = undefined,
        .selection_color = undefined,
        .is_focused = undefined,
        .is_readonly = undefined,
        .scroll_offset = undefined,
    };
    
    try area.base.init(allocator, props);
    
    return &area.base;
}