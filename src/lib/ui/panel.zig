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

pub const PanelSplitDirection = enum {
    horizontal,
    vertical,
};

pub const PanelBorder = struct {
    width: f32 = 1.0,
    color: Color = Color{ .r = 80, .g = 80, .b = 80, .a = 255 },
};

pub const Panel = struct {
    base: Component,
    
    border: reactive.Signal(PanelBorder),
    content_padding: reactive.Signal(Vec2),
    
    const Self = @This();
    
    pub fn init(self: *Component, allocator: std.mem.Allocator, props: ComponentProps) !void {
        _ = props;
        const panel: *Panel = @fieldParentPtr("base", self);
        
        panel.border = try reactive.signal(allocator, PanelBorder, PanelBorder{});
        panel.content_padding = try reactive.signal(allocator, Vec2, Vec2{ .x = 4, .y = 4 });
    }
    
    pub fn deinit(self: *Component, allocator: std.mem.Allocator) void {
        _ = allocator;
        const panel: *Panel = @fieldParentPtr("base", self);
        
        panel.border.deinit();
        panel.content_padding.deinit();
    }
    
    pub fn update(self: *Component, dt: f32) void {
        _ = self;
        _ = dt;
    }
    
    pub fn render(self: *const Component, renderer: anytype) !void {
        const panel: *const Panel = @fieldParentPtr("base", self);
        
        if (!self.props.visible.get()) return;
        
        const bounds = self.props.getBounds();
        const border = panel.border.get();
        
        if (self.props.background_color.get().a > 0) {
            if (@hasDecl(@TypeOf(renderer), "drawRect")) {
                try renderer.drawRect(bounds, self.props.background_color.get());
            }
        }
        
        if (border.width > 0 and border.color.a > 0) {
            if (@hasDecl(@TypeOf(renderer), "drawRectBorder")) {
                try renderer.drawRectBorder(bounds, border.color, border.width);
            }
        }
    }
    
    pub fn handleEvent(self: *Component, event: anytype) bool {
        _ = self;
        _ = event;
        return false;
    }
    
    pub fn destroy(self: *Component, allocator: std.mem.Allocator) void {
        const panel: *Panel = @fieldParentPtr("base", self);
        allocator.destroy(panel);
    }
    
    pub fn getContentBounds(self: *const Panel) Rectangle {
        const bounds = self.base.props.getBounds();
        const padding = self.content_padding.get();
        const border = self.border.get();
        
        return Rectangle{
            .position = Vec2{
                .x = bounds.position.x + padding.x + border.width,
                .y = bounds.position.y + padding.y + border.width,
            },
            .size = Vec2{
                .x = bounds.size.x - (padding.x * 2) - (border.width * 2),
                .y = bounds.size.y - (padding.y * 2) - (border.width * 2),
            },
        };
    }
};

pub const PanelLayout = struct {
    base: Component,
    
    split_direction: reactive.Signal(PanelSplitDirection),
    split_ratio: reactive.Signal(f32),
    divider_width: reactive.Signal(f32),
    divider_color: reactive.Signal(Color),
    min_panel_size: reactive.Signal(f32),
    
    left_or_top_panel: ?*Component = null,
    right_or_bottom_panel: ?*Component = null,
    
    is_dragging: bool = false,
    drag_start_pos: Vec2 = Vec2{ .x = 0, .y = 0 },
    drag_start_ratio: f32 = 0.5,
    
    const Self = @This();
    
    pub fn init(self: *Component, allocator: std.mem.Allocator, props: ComponentProps) !void {
        _ = props;
        const layout: *PanelLayout = @fieldParentPtr("base", self);
        
        layout.split_direction = try reactive.signal(allocator, PanelSplitDirection, .horizontal);
        layout.split_ratio = try reactive.signal(allocator, f32, 0.5);
        layout.divider_width = try reactive.signal(allocator, f32, 4.0);
        layout.divider_color = try reactive.signal(allocator, Color, Color{ .r = 60, .g = 60, .b = 60, .a = 255 });
        layout.min_panel_size = try reactive.signal(allocator, f32, 50.0);
    }
    
    pub fn deinit(self: *Component, allocator: std.mem.Allocator) void {
        _ = allocator;
        const layout: *PanelLayout = @fieldParentPtr("base", self);
        
        layout.split_direction.deinit();
        layout.split_ratio.deinit();
        layout.divider_width.deinit();
        layout.divider_color.deinit();
        layout.min_panel_size.deinit();
    }
    
    pub fn update(self: *Component, dt: f32) void {
        _ = dt;
        const layout: *PanelLayout = @fieldParentPtr("base", self);
        
        layout.updatePanelPositions();
    }
    
    pub fn render(self: *const Component, renderer: anytype) !void {
        const layout: *const PanelLayout = @fieldParentPtr("base", self);
        
        if (!self.props.visible.get()) return;
        
        const bounds = self.props.getBounds();
        const divider_rect = layout.getDividerBounds();
        
        if (@hasDecl(@TypeOf(renderer), "drawRect")) {
            try renderer.drawRect(divider_rect, layout.divider_color.get());
        }
    }
    
    pub fn handleEvent(self: *Component, event: anytype) bool {
        const layout: *PanelLayout = @fieldParentPtr("base", self);
        
        if (!self.props.enabled.get() or !self.props.visible.get()) return false;
        
        if (@hasField(@TypeOf(event), "mouse_x") and @hasField(@TypeOf(event), "mouse_y")) {
            const mouse_pos = Vec2{ .x = event.mouse_x, .y = event.mouse_y };
            const divider_bounds = layout.getDividerBounds();
            const is_over_divider = divider_bounds.contains(mouse_pos);
            
            if (@hasField(@TypeOf(event), "mouse_pressed") and event.mouse_pressed and is_over_divider) {
                layout.is_dragging = true;
                layout.drag_start_pos = mouse_pos;
                layout.drag_start_ratio = layout.split_ratio.get();
                return true;
            } else if (@hasField(@TypeOf(event), "mouse_released") and event.mouse_released) {
                layout.is_dragging = false;
            } else if (layout.is_dragging) {
                const bounds = self.props.getBounds();
                const delta = if (layout.split_direction.get() == .horizontal)
                    (mouse_pos.x - layout.drag_start_pos.x) / bounds.size.x
                else
                    (mouse_pos.y - layout.drag_start_pos.y) / bounds.size.y;
                
                const new_ratio = std.math.clamp(layout.drag_start_ratio + delta, 0.1, 0.9);
                layout.split_ratio.set(new_ratio);
                return true;
            }
        }
        
        return false;
    }
    
    pub fn destroy(self: *Component, allocator: std.mem.Allocator) void {
        const layout: *PanelLayout = @fieldParentPtr("base", self);
        allocator.destroy(layout);
    }
    
    fn getDividerBounds(self: *const PanelLayout) Rectangle {
        const bounds = self.base.props.getBounds();
        const ratio = self.split_ratio.get();
        const divider_width = self.divider_width.get();
        
        if (self.split_direction.get() == .horizontal) {
            const divider_x = bounds.position.x + bounds.size.x * ratio - divider_width / 2;
            return Rectangle{
                .position = Vec2{ .x = divider_x, .y = bounds.position.y },
                .size = Vec2{ .x = divider_width, .y = bounds.size.y },
            };
        } else {
            const divider_y = bounds.position.y + bounds.size.y * ratio - divider_width / 2;
            return Rectangle{
                .position = Vec2{ .x = bounds.position.x, .y = divider_y },
                .size = Vec2{ .x = bounds.size.x, .y = divider_width },
            };
        }
    }
    
    fn updatePanelPositions(self: *PanelLayout) void {
        const bounds = self.base.props.getBounds();
        const ratio = self.split_ratio.get();
        const divider_width = self.divider_width.get();
        
        if (self.split_direction.get() == .horizontal) {
            const left_width = bounds.size.x * ratio - divider_width / 2;
            const right_width = bounds.size.x * (1 - ratio) - divider_width / 2;
            
            if (self.left_or_top_panel) |panel| {
                panel.props.position.set(bounds.position);
                panel.props.size.set(Vec2{ .x = left_width, .y = bounds.size.y });
            }
            
            if (self.right_or_bottom_panel) |panel| {
                const right_x = bounds.position.x + left_width + divider_width;
                panel.props.position.set(Vec2{ .x = right_x, .y = bounds.position.y });
                panel.props.size.set(Vec2{ .x = right_width, .y = bounds.size.y });
            }
        } else {
            const top_height = bounds.size.y * ratio - divider_width / 2;
            const bottom_height = bounds.size.y * (1 - ratio) - divider_width / 2;
            
            if (self.left_or_top_panel) |panel| {
                panel.props.position.set(bounds.position);
                panel.props.size.set(Vec2{ .x = bounds.size.x, .y = top_height });
            }
            
            if (self.right_or_bottom_panel) |panel| {
                const bottom_y = bounds.position.y + top_height + divider_width;
                panel.props.position.set(Vec2{ .x = bounds.position.x, .y = bottom_y });
                panel.props.size.set(Vec2{ .x = bounds.size.x, .y = bottom_height });
            }
        }
    }
    
    pub fn setLeftOrTopPanel(self: *PanelLayout, panel: *Component) !void {
        if (self.left_or_top_panel) |old_panel| {
            try self.base.removeChild(old_panel);
        }
        self.left_or_top_panel = panel;
        try self.base.addChild(panel);
        self.updatePanelPositions();
    }
    
    pub fn setRightOrBottomPanel(self: *PanelLayout, panel: *Component) !void {
        if (self.right_or_bottom_panel) |old_panel| {
            try self.base.removeChild(old_panel);
        }
        self.right_or_bottom_panel = panel;
        try self.base.addChild(panel);
        self.updatePanelPositions();
    }
};

pub fn createPanel(allocator: std.mem.Allocator, position: Vec2, size: Vec2) !*Component {
    const panel = try allocator.create(Panel);
    
    var props = try ComponentProps.init(allocator, position, size);
    props.background_color.set(Color{ .r = 40, .g = 40, .b = 40, .a = 255 });
    
    panel.* = Panel{
        .base = Component{
            .vtable = Component.VTable{
                .init = Panel.init,
                .deinit = Panel.deinit,
                .update = Panel.update,
                .render = Panel.render,
                .handle_event = Panel.handleEvent,
                .destroy = Panel.destroy,
            },
            .props = props,
            .children = std.ArrayList(*Component).init(allocator),
            .parent = null,
        },
        .border = undefined,
        .content_padding = undefined,
    };
    
    try panel.base.init(allocator, props);
    
    return &panel.base;
}

pub fn createPanelLayout(
    allocator: std.mem.Allocator,
    position: Vec2,
    size: Vec2,
    direction: PanelSplitDirection,
) !*Component {
    const layout = try allocator.create(PanelLayout);
    
    var props = try ComponentProps.init(allocator, position, size);
    
    layout.* = PanelLayout{
        .base = Component{
            .vtable = Component.VTable{
                .init = PanelLayout.init,
                .deinit = PanelLayout.deinit,
                .update = PanelLayout.update,
                .render = PanelLayout.render,
                .handle_event = PanelLayout.handleEvent,
                .destroy = PanelLayout.destroy,
            },
            .props = props,
            .children = std.ArrayList(*Component).init(allocator),
            .parent = null,
        },
        .split_direction = undefined,
        .split_ratio = undefined,
        .divider_width = undefined,
        .divider_color = undefined,
        .min_panel_size = undefined,
    };
    
    try layout.base.init(allocator, props);
    layout.split_direction.set(direction);
    
    return &layout.base;
}