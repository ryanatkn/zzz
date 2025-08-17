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

pub const TextInput = struct {
    base: Component,

    text: reactive.Signal([]const u8),
    cursor_pos: reactive.Signal(usize),
    selection_start: reactive.Signal(?usize),
    selection_end: reactive.Signal(?usize),

    placeholder: reactive.Signal([]const u8),
    max_length: reactive.Signal(usize),

    text_color: reactive.Signal(Color),
    placeholder_color: reactive.Signal(Color),
    cursor_color: reactive.Signal(Color),
    selection_color: reactive.Signal(Color),

    is_focused: reactive.Signal(bool),
    cursor_blink_timer: f32 = 0,
    cursor_visible: bool = true,

    text_buffer: std.ArrayList(u8),

    on_change: ?*const fn ([]const u8) void = null,
    on_submit: ?*const fn ([]const u8) void = null,

    const Self = @This();

    pub fn init(self: *Component, allocator: std.mem.Allocator, props: ComponentProps) !void {
        _ = props;
        const input: *TextInput = @fieldParentPtr("base", self);

        input.text = try reactive.signal(allocator, []const u8, "");
        input.cursor_pos = try reactive.signal(allocator, usize, 0);
        input.selection_start = try reactive.signal(allocator, ?usize, null);
        input.selection_end = try reactive.signal(allocator, ?usize, null);

        input.placeholder = try reactive.signal(allocator, []const u8, "Enter text...");
        input.max_length = try reactive.signal(allocator, usize, 255);

        input.text_color = try reactive.signal(allocator, Color, Color{ .r = 255, .g = 255, .b = 255, .a = 255 });
        input.placeholder_color = try reactive.signal(allocator, Color, Color{ .r = 128, .g = 128, .b = 128, .a = 255 });
        input.cursor_color = try reactive.signal(allocator, Color, Color{ .r = 255, .g = 255, .b = 255, .a = 255 });
        input.selection_color = try reactive.signal(allocator, Color, Color{ .r = 60, .g = 100, .b = 160, .a = 128 });

        input.is_focused = try reactive.signal(allocator, bool, false);
        input.text_buffer = std.ArrayList(u8).init(allocator);
    }

    pub fn deinit(self: *Component, allocator: std.mem.Allocator) void {
        _ = allocator;
        const input: *TextInput = @fieldParentPtr("base", self);

        input.text.deinit();
        input.cursor_pos.deinit();
        input.selection_start.deinit();
        input.selection_end.deinit();
        input.placeholder.deinit();
        input.max_length.deinit();
        input.text_color.deinit();
        input.placeholder_color.deinit();
        input.cursor_color.deinit();
        input.selection_color.deinit();
        input.is_focused.deinit();
        input.text_buffer.deinit();
    }

    pub fn update(self: *Component, dt: f32) void {
        const input: *TextInput = @fieldParentPtr("base", self);

        if (input.is_focused.get()) {
            input.cursor_blink_timer += dt;
            if (input.cursor_blink_timer >= 0.5) {
                input.cursor_blink_timer = 0;
                input.cursor_visible = !input.cursor_visible;
            }
        }
    }

    pub fn render(self: *const Component, renderer: anytype) !void {
        const input: *const TextInput = @fieldParentPtr("base", self);

        if (!self.props.visible.get()) return;

        const bounds = self.props.getBounds();

        if (@hasDecl(@TypeOf(renderer), "drawRect")) {
            const bg_color = if (input.is_focused.get())
                Color{ .r = 50, .g = 50, .b = 50, .a = 255 }
            else
                Color{ .r = 40, .g = 40, .b = 40, .a = 255 };

            try renderer.drawRect(bounds, bg_color);

            const border_color = if (input.is_focused.get())
                Color{ .r = 100, .g = 150, .b = 200, .a = 255 }
            else
                Color{ .r = 80, .g = 80, .b = 80, .a = 255 };

            if (@hasDecl(@TypeOf(renderer), "drawRectBorder")) {
                try renderer.drawRectBorder(bounds, border_color, 1.0);
            }
        }

        const text_to_display = if (input.text.get().len > 0)
            input.text.get()
        else if (!input.is_focused.get())
            input.placeholder.get()
        else
            "";

        const text_color = if (input.text.get().len > 0 or input.is_focused.get())
            input.text_color.get()
        else
            input.placeholder_color.get();

        const text_pos = Vec2{
            .x = bounds.position.x + 5,
            .y = bounds.position.y + bounds.size.y / 2 - 6,
        };

        if (@hasDecl(@TypeOf(renderer), "drawText") and text_to_display.len > 0) {
            try renderer.drawText(text_to_display, text_pos, text_color, 12.0);
        }

        if (input.is_focused.get() and input.cursor_visible) {
            const cursor_x = text_pos.x + @as(f32, @floatFromInt(input.cursor_pos.get())) * 7.0;
            const cursor_rect = Rectangle{
                .position = Vec2{ .x = cursor_x, .y = bounds.position.y + 4 },
                .size = Vec2{ .x = 1, .y = bounds.size.y - 8 },
            };

            if (@hasDecl(@TypeOf(renderer), "drawRect")) {
                try renderer.drawRect(cursor_rect, input.cursor_color.get());
            }
        }

        if (input.selection_start.get()) |start| {
            if (input.selection_end.get()) |end| {
                const sel_start = @min(start, end);
                const sel_end = @max(start, end);

                const sel_x = text_pos.x + @as(f32, @floatFromInt(sel_start)) * 7.0;
                const sel_width = @as(f32, @floatFromInt(sel_end - sel_start)) * 7.0;

                const selection_rect = Rectangle{
                    .position = Vec2{ .x = sel_x, .y = bounds.position.y + 2 },
                    .size = Vec2{ .x = sel_width, .y = bounds.size.y - 4 },
                };

                if (@hasDecl(@TypeOf(renderer), "drawRect")) {
                    try renderer.drawRect(selection_rect, input.selection_color.get());
                }
            }
        }
    }

    pub fn handleEvent(self: *Component, event: anytype) bool {
        const input: *TextInput = @fieldParentPtr("base", self);

        if (!self.props.enabled.get() or !self.props.visible.get()) return false;

        if (@hasField(@TypeOf(event), "mouse_x") and @hasField(@TypeOf(event), "mouse_y")) {
            const mouse_pos = Vec2{ .x = event.mouse_x, .y = event.mouse_y };
            const bounds = self.props.getBounds();

            if (@hasField(@TypeOf(event), "mouse_pressed") and event.mouse_pressed) {
                if (bounds.contains(mouse_pos)) {
                    input.is_focused.set(true);
                    input.cursor_visible = true;
                    input.cursor_blink_timer = 0;

                    const text_x = bounds.position.x + 5;
                    const char_index = @as(usize, @intFromFloat(@max(0, (mouse_pos.x - text_x) / 7.0)));
                    const new_pos = @min(char_index, input.text.get().len);
                    input.cursor_pos.set(new_pos);

                    return true;
                } else {
                    input.is_focused.set(false);
                }
            }
        }

        if (input.is_focused.get()) {
            if (@hasField(@TypeOf(event), "key_pressed")) {
                return input.handleKeyPress(event.key_pressed);
            }
        }

        return false;
    }

    fn handleKeyPress(self: *TextInput, key: anytype) bool {
        _ = self;
        _ = key;
        return false;
    }

    pub fn destroy(self: *Component, allocator: std.mem.Allocator) void {
        const input: *TextInput = @fieldParentPtr("base", self);
        allocator.destroy(input);
    }

    pub fn setText(self: *TextInput, new_text: []const u8) void {
        self.text_buffer.clearRetainingCapacity();
        self.text_buffer.appendSlice(new_text) catch return;
        self.text.set(self.text_buffer.items);
        self.cursor_pos.set(@min(self.cursor_pos.get(), new_text.len));

        if (self.on_change) |callback| {
            callback(new_text);
        }
    }

    pub fn insertText(self: *TextInput, text_to_insert: []const u8) void {
        if (self.text_buffer.items.len + text_to_insert.len > self.max_length.get()) return;

        const cursor = self.cursor_pos.get();
        self.text_buffer.insertSlice(cursor, text_to_insert) catch return;
        self.text.set(self.text_buffer.items);
        self.cursor_pos.set(cursor + text_to_insert.len);

        if (self.on_change) |callback| {
            callback(self.text_buffer.items);
        }
    }

    pub fn deleteCharacterAt(self: *TextInput, index: usize) void {
        if (index >= self.text_buffer.items.len) return;

        _ = self.text_buffer.orderedRemove(index);
        self.text.set(self.text_buffer.items);

        if (self.cursor_pos.get() > index) {
            self.cursor_pos.set(self.cursor_pos.get() - 1);
        }

        if (self.on_change) |callback| {
            callback(self.text_buffer.items);
        }
    }

    pub fn clear(self: *TextInput) void {
        self.text_buffer.clearRetainingCapacity();
        self.text.set("");
        self.cursor_pos.set(0);
        self.selection_start.set(null);
        self.selection_end.set(null);

        if (self.on_change) |callback| {
            callback("");
        }
    }

    pub fn setOnChange(self: *TextInput, callback: *const fn ([]const u8) void) void {
        self.on_change = callback;
    }

    pub fn setOnSubmit(self: *TextInput, callback: *const fn ([]const u8) void) void {
        self.on_submit = callback;
    }

    pub fn focus(self: *TextInput) void {
        self.is_focused.set(true);
        self.cursor_visible = true;
        self.cursor_blink_timer = 0;
    }

    pub fn blur(self: *TextInput) void {
        self.is_focused.set(false);
    }
};

pub fn createTextInput(allocator: std.mem.Allocator, position: Vec2, size: Vec2) !*Component {
    const input = try allocator.create(TextInput);

    const props = try ComponentProps.init(allocator, position, size);

    input.* = TextInput{
        .base = Component{
            .vtable = Component.VTable{
                .init = TextInput.init,
                .deinit = TextInput.deinit,
                .update = TextInput.update,
                .render = TextInput.render,
                .handle_event = TextInput.handleEvent,
                .destroy = TextInput.destroy,
            },
            .props = props,
            .children = std.ArrayList(*Component).init(allocator),
            .parent = null,
        },
        .text = undefined,
        .cursor_pos = undefined,
        .selection_start = undefined,
        .selection_end = undefined,
        .placeholder = undefined,
        .max_length = undefined,
        .text_color = undefined,
        .placeholder_color = undefined,
        .cursor_color = undefined,
        .selection_color = undefined,
        .is_focused = undefined,
        .text_buffer = undefined,
    };

    try input.base.init(allocator, props);

    return &input.base;
}
