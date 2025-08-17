const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const reactive = @import("../reactive.zig");
const component = @import("component.zig");
const text = @import("text.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;
const Color = colors.Color;
const Component = component.Component;
const ComponentProps = component.ComponentProps;

pub const TreeNodeData = struct {
    label: []const u8,
    icon: ?[]const u8 = null,
    is_directory: bool = false,
    path: []const u8 = "",
    user_data: ?*anyopaque = null,
};

pub const TreeNode = struct {
    data: TreeNodeData,
    expanded: bool = false,
    selected: bool = false,
    children: std.ArrayList(*TreeNode),
    parent: ?*TreeNode = null,
    depth: u32 = 0,
    
    pub fn init(allocator: std.mem.Allocator, data: TreeNodeData) !*TreeNode {
        const node = try allocator.create(TreeNode);
        node.* = TreeNode{
            .data = data,
            .children = std.ArrayList(*TreeNode).init(allocator),
        };
        return node;
    }
    
    pub fn deinit(self: *TreeNode, allocator: std.mem.Allocator) void {
        for (self.children.items) |child| {
            child.deinit(allocator);
        }
        self.children.deinit();
        allocator.destroy(self);
    }
    
    pub fn addChild(self: *TreeNode, child: *TreeNode) !void {
        child.parent = self;
        child.depth = self.depth + 1;
        try self.children.append(child);
    }
    
    pub fn toggleExpanded(self: *TreeNode) void {
        self.expanded = !self.expanded;
    }
};

pub const TreeView = struct {
    base: Component,
    
    root_nodes: std.ArrayList(*TreeNode),
    selected_node: reactive.Signal(?*TreeNode),
    row_height: reactive.Signal(f32),
    indent_width: reactive.Signal(f32),
    
    text_color: reactive.Signal(Color),
    selected_bg_color: reactive.Signal(Color),
    hover_bg_color: reactive.Signal(Color),
    
    hovered_node: ?*TreeNode = null,
    
    on_node_selected: ?*const fn (*TreeNode) void = null,
    on_node_double_clicked: ?*const fn (*TreeNode) void = null,
    
    const Self = @This();
    
    pub fn init(self: *Component, allocator: std.mem.Allocator, props: ComponentProps) !void {
        _ = props;
        const tree: *TreeView = @fieldParentPtr("base", self);
        
        tree.root_nodes = std.ArrayList(*TreeNode).init(allocator);
        tree.selected_node = try reactive.signal(allocator, ?*TreeNode, null);
        tree.row_height = try reactive.signal(allocator, f32, 24.0);
        tree.indent_width = try reactive.signal(allocator, f32, 20.0);
        
        tree.text_color = try reactive.signal(allocator, Color, Color{ .r = 200, .g = 200, .b = 200, .a = 255 });
        tree.selected_bg_color = try reactive.signal(allocator, Color, Color{ .r = 60, .g = 100, .b = 160, .a = 255 });
        tree.hover_bg_color = try reactive.signal(allocator, Color, Color{ .r = 50, .g = 50, .b = 50, .a = 255 });
    }
    
    pub fn deinit(self: *Component, allocator: std.mem.Allocator) void {
        const tree: *TreeView = @fieldParentPtr("base", self);
        
        for (tree.root_nodes.items) |node| {
            node.deinit(allocator);
        }
        tree.root_nodes.deinit();
        
        tree.selected_node.deinit();
        tree.row_height.deinit();
        tree.indent_width.deinit();
        tree.text_color.deinit();
        tree.selected_bg_color.deinit();
        tree.hover_bg_color.deinit();
    }
    
    pub fn update(self: *Component, dt: f32) void {
        _ = self;
        _ = dt;
    }
    
    pub fn render(self: *const Component, renderer: anytype) !void {
        const tree: *const TreeView = @fieldParentPtr("base", self);
        
        if (!self.props.visible.get()) return;
        
        const bounds = self.props.getBounds();
        var y_offset: f32 = 0;
        
        for (tree.root_nodes.items) |node| {
            y_offset = try tree.renderNode(renderer, node, bounds.position.x, bounds.position.y + y_offset, bounds.size.x);
        }
    }
    
    fn renderNode(self: *const TreeView, renderer: anytype, node: *TreeNode, x: f32, y: f32, width: f32) !f32 {
        const row_height = self.row_height.get();
        const indent_width = self.indent_width.get();
        const indent = @as(f32, @floatFromInt(node.depth)) * indent_width;
        
        const row_rect = Rectangle{
            .position = Vec2{ .x = x, .y = y },
            .size = Vec2{ .x = width, .y = row_height },
        };
        
        if (node.selected) {
            if (@hasDecl(@TypeOf(renderer), "drawRect")) {
                try renderer.drawRect(row_rect, self.selected_bg_color.get());
            }
        } else if (self.hovered_node == node) {
            if (@hasDecl(@TypeOf(renderer), "drawRect")) {
                try renderer.drawRect(row_rect, self.hover_bg_color.get());
            }
        }
        
        const expand_icon = if (node.data.is_directory)
            (if (node.expanded) "▼ " else "▶ ")
        else
            "  ";
        
        const icon = node.data.icon orelse (if (node.data.is_directory) "📁 " else "📄 ");
        
        const label_x = x + indent + 20;
        const label_y = y + row_height / 2 - 6;
        
        if (@hasDecl(@TypeOf(renderer), "drawText")) {
            var label_buf: [256]u8 = undefined;
            const label = std.fmt.bufPrint(&label_buf, "{s}{s}{s}", .{ expand_icon, icon, node.data.label }) catch node.data.label;
            
            try renderer.drawText(label, Vec2{ .x = label_x, .y = label_y }, self.text_color.get(), 12.0);
        }
        
        var total_height = row_height;
        
        if (node.expanded) {
            for (node.children.items) |child| {
                const child_height = try self.renderNode(renderer, child, x, y + total_height, width);
                total_height += child_height;
            }
        }
        
        return total_height;
    }
    
    pub fn handleEvent(self: *Component, event: anytype) bool {
        const tree: *TreeView = @fieldParentPtr("base", self);
        
        if (!self.props.enabled.get() or !self.props.visible.get()) return false;
        
        if (@hasField(@TypeOf(event), "mouse_x") and @hasField(@TypeOf(event), "mouse_y")) {
            const mouse_pos = Vec2{ .x = event.mouse_x, .y = event.mouse_y };
            const bounds = self.props.getBounds();
            
            if (!bounds.contains(mouse_pos)) {
                tree.hovered_node = null;
                return false;
            }
            
            const clicked_node = tree.getNodeAtPosition(mouse_pos, bounds.position);
            
            if (@hasField(@TypeOf(event), "mouse_pressed") and event.mouse_pressed) {
                if (clicked_node) |node| {
                    if (tree.selected_node.get()) |old_selected| {
                        old_selected.selected = false;
                    }
                    
                    node.selected = true;
                    tree.selected_node.set(node);
                    
                    if (node.data.is_directory) {
                        node.toggleExpanded();
                    }
                    
                    if (tree.on_node_selected) |callback| {
                        callback(node);
                    }
                    
                    return true;
                }
            } else if (@hasField(@TypeOf(event), "mouse_double_clicked") and event.mouse_double_clicked) {
                if (clicked_node) |node| {
                    if (tree.on_node_double_clicked) |callback| {
                        callback(node);
                    }
                    return true;
                }
            } else {
                tree.hovered_node = clicked_node;
            }
        }
        
        return false;
    }
    
    fn getNodeAtPosition(self: *const TreeView, pos: Vec2, base_pos: Vec2) ?*TreeNode {
        var y_offset: f32 = 0;
        
        for (self.root_nodes.items) |node| {
            if (self.getNodeAtPositionRecursive(node, pos, base_pos.x, base_pos.y + y_offset, &y_offset)) |found| {
                return found;
            }
        }
        
        return null;
    }
    
    fn getNodeAtPositionRecursive(self: *const TreeView, node: *TreeNode, pos: Vec2, x: f32, y: f32, y_offset: *f32) ?*TreeNode {
        const row_height = self.row_height.get();
        
        const row_rect = Rectangle{
            .position = Vec2{ .x = x, .y = y },
            .size = Vec2{ .x = self.base.props.size.get().x, .y = row_height },
        };
        
        if (row_rect.contains(pos)) {
            return node;
        }
        
        y_offset.* += row_height;
        
        if (node.expanded) {
            for (node.children.items) |child| {
                if (self.getNodeAtPositionRecursive(child, pos, x, y + y_offset.*, y_offset)) |found| {
                    return found;
                }
            }
        }
        
        return null;
    }
    
    pub fn destroy(self: *Component, allocator: std.mem.Allocator) void {
        const tree: *TreeView = @fieldParentPtr("base", self);
        allocator.destroy(tree);
    }
    
    pub fn addRootNode(self: *TreeView, node: *TreeNode) !void {
        node.depth = 0;
        try self.root_nodes.append(node);
    }
    
    pub fn clearNodes(self: *TreeView, allocator: std.mem.Allocator) void {
        for (self.root_nodes.items) |node| {
            node.deinit(allocator);
        }
        self.root_nodes.clearRetainingCapacity();
        self.selected_node.set(null);
        self.hovered_node = null;
    }
    
    pub fn getSelectedNode(self: *const TreeView) ?*TreeNode {
        return self.selected_node.get();
    }
    
    pub fn setOnNodeSelected(self: *TreeView, callback: *const fn (*TreeNode) void) void {
        self.on_node_selected = callback;
    }
    
    pub fn setOnNodeDoubleClicked(self: *TreeView, callback: *const fn (*TreeNode) void) void {
        self.on_node_double_clicked = callback;
    }
};

pub fn createTreeView(allocator: std.mem.Allocator, position: Vec2, size: Vec2) !*Component {
    const tree = try allocator.create(TreeView);
    
    var props = try ComponentProps.init(allocator, position, size);
    props.background_color.set(Color{ .r = 30, .g = 30, .b = 30, .a = 255 });
    
    tree.* = TreeView{
        .base = Component{
            .vtable = Component.VTable{
                .init = TreeView.init,
                .deinit = TreeView.deinit,
                .update = TreeView.update,
                .render = TreeView.render,
                .handle_event = TreeView.handleEvent,
                .destroy = TreeView.destroy,
            },
            .props = props,
            .children = std.ArrayList(*Component).init(allocator),
            .parent = null,
        },
        .root_nodes = undefined,
        .selected_node = undefined,
        .row_height = undefined,
        .indent_width = undefined,
        .text_color = undefined,
        .selected_bg_color = undefined,
        .hover_bg_color = undefined,
    };
    
    try tree.base.init(allocator, props);
    
    return &tree.base;
}

pub fn createFileTreeFromDirectory(allocator: std.mem.Allocator, path: []const u8) !*TreeNode {
    _ = allocator;
    _ = path;
    return error.NotImplemented;
}