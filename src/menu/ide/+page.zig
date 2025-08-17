const std = @import("std");
const page = @import("../../hud/page.zig");
const panel = @import("../../lib/ui/panel.zig");
const tree_view = @import("../../lib/ui/tree_view.zig");
const text_area = @import("../../lib/ui/text_area.zig");
const list_view = @import("../../lib/ui/list_view.zig");
const text_input = @import("../../lib/ui/text_input.zig");
const math = @import("../../lib/math/mod.zig");
const colors = @import("../../lib/core/colors.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;

const IDEPage = struct {
    base: page.Page,
    allocator: std.mem.Allocator,
    
    main_layout: ?*panel.PanelLayout = null,
    left_panel: ?*panel.Panel = null,
    center_panel: ?*panel.Panel = null,
    right_panel: ?*panel.Panel = null,
    
    file_tree: ?*tree_view.TreeView = null,
    editor: ?*text_area.TextArea = null,
    terminal_output: ?*list_view.ListView = null,
    terminal_input: ?*text_input.TextInput = null,
    
    current_file: ?[]const u8 = null,
    current_directory: []const u8 = ".",
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const ide_page = try allocator.create(IDEPage);
    ide_page.* = IDEPage{
        .base = page.Page{
            .init = init,
            .deinit = deinit,
            .update = update,
            .render = render,
            .destroy = destroy,
        },
        .allocator = allocator,
    };
    return &ide_page.base;
}

fn init(self: *page.Page) !void {
    const ide: *IDEPage = @fieldParentPtr("base", self);
    
    const screen_size = Vec2{ .x = 1920, .y = 1080 };
    
    ide.main_layout = @ptrCast(@alignCast(try panel.createPanelLayout(
        ide.allocator,
        Vec2{ .x = 0, .y = 0 },
        screen_size,
        .horizontal,
    )));
    
    const layout: *panel.PanelLayout = @fieldParentPtr("base", ide.main_layout.?);
    layout.split_ratio.set(0.2);
    
    const secondary_layout = @ptrCast(@alignCast(try panel.createPanelLayout(
        ide.allocator,
        Vec2{ .x = 0, .y = 0 },
        Vec2{ .x = 1536, .y = 1080 },
        .horizontal,
    )));
    
    const sec_layout: *panel.PanelLayout = @fieldParentPtr("base", secondary_layout);
    sec_layout.split_ratio.set(0.7);
    
    ide.left_panel = @ptrCast(@alignCast(try panel.createPanel(
        ide.allocator,
        Vec2{ .x = 0, .y = 0 },
        Vec2{ .x = 384, .y = 1080 },
    )));
    
    ide.center_panel = @ptrCast(@alignCast(try panel.createPanel(
        ide.allocator,
        Vec2{ .x = 0, .y = 0 },
        Vec2{ .x = 1075, .y = 1080 },
    )));
    
    ide.right_panel = @ptrCast(@alignCast(try panel.createPanel(
        ide.allocator,
        Vec2{ .x = 0, .y = 0 },
        Vec2{ .x = 461, .y = 1080 },
    )));
    
    ide.file_tree = @ptrCast(@alignCast(try tree_view.createTreeView(
        ide.allocator,
        Vec2{ .x = 5, .y = 5 },
        Vec2{ .x = 374, .y = 1070 },
    )));
    
    try populateFileTree(ide);
    
    ide.editor = @ptrCast(@alignCast(try text_area.createTextArea(
        ide.allocator,
        Vec2{ .x = 5, .y = 5 },
        Vec2{ .x = 1065, .y = 1070 },
    )));
    
    ide.editor.?.show_line_numbers.set(true);
    ide.editor.?.setReadOnly(false);
    
    const welcome_text =
        \\// Welcome to the Zzz IDE
        \\// Select a file from the explorer on the left to begin editing
        \\//
        \\// Features:
        \\// - File Explorer (left panel)
        \\// - Text Editor (center panel)
        \\// - Terminal (right panel)
        \\//
        \\// TODOs:
        \\// - File I/O operations
        \\// - Syntax highlighting
        \\// - Terminal command execution
        \\// - Copy/paste support
        \\// - Search and replace
        ;
    
    try ide.editor.?.setText(welcome_text);
    
    ide.terminal_output = @ptrCast(@alignCast(try list_view.createListView(
        ide.allocator,
        Vec2{ .x = 5, .y = 5 },
        Vec2{ .x = 451, .y = 1030 },
    )));
    
    ide.terminal_output.?.setAutoScrollToBottom(true);
    
    try ide.terminal_output.?.addItem(.{
        .text = "Zzz Terminal v0.1.0",
        .color = Color{ .r = 100, .g = 200, .b = 100, .a = 255 },
    });
    try ide.terminal_output.?.addItem(.{
        .text = "Type 'help' for available commands",
        .color = Color{ .r = 150, .g = 150, .b = 150, .a = 255 },
    });
    
    ide.terminal_input = @ptrCast(@alignCast(try text_input.createTextInput(
        ide.allocator,
        Vec2{ .x = 5, .y = 1040 },
        Vec2{ .x = 451, .y = 30 },
    )));
    
    ide.terminal_input.?.placeholder.set("Enter command...");
    
    const FileSelectedContext = struct {
        ide_ptr: *IDEPage,
        
        fn onFileSelected(node: *tree_view.TreeNode) void {
            const ctx = @fieldParentPtr(@This(), "ide_ptr", @as(**IDEPage, @ptrCast(@alignCast(node.data.user_data))));
            ctx.ide_ptr.loadFile(node.data.path) catch |err| {
                std.debug.print("Error loading file: {}\n", .{err});
            };
        }
    };
    
    const TerminalSubmitContext = struct {
        ide_ptr: *IDEPage,
        
        fn onSubmit(text: []const u8) void {
            const ctx = @fieldParentPtr(@This(), "ide_ptr", @as(**IDEPage, @ptrCast(@alignCast(@constCast(text.ptr)))));
            ctx.ide_ptr.executeCommand(text) catch |err| {
                std.debug.print("Error executing command: {}\n", .{err});
            };
        }
    };
    
    try layout.setLeftOrTopPanel(@ptrCast(ide.left_panel));
    try layout.setRightOrBottomPanel(secondary_layout);
    try sec_layout.setLeftOrTopPanel(@ptrCast(ide.center_panel));
    try sec_layout.setRightOrBottomPanel(@ptrCast(ide.right_panel));
    
    try ide.left_panel.?.base.addChild(@ptrCast(ide.file_tree));
    try ide.center_panel.?.base.addChild(@ptrCast(ide.editor));
    try ide.right_panel.?.base.addChild(@ptrCast(ide.terminal_output));
    try ide.right_panel.?.base.addChild(@ptrCast(ide.terminal_input));
}

fn populateFileTree(ide: *IDEPage) !void {
    const root = try tree_view.TreeNode.init(ide.allocator, .{
        .label = "zzz",
        .is_directory = true,
        .path = ".",
    });
    
    const src = try tree_view.TreeNode.init(ide.allocator, .{
        .label = "src",
        .is_directory = true,
        .path = "src",
    });
    
    const lib = try tree_view.TreeNode.init(ide.allocator, .{
        .label = "lib",
        .is_directory = true,
        .path = "src/lib",
    });
    
    const ui = try tree_view.TreeNode.init(ide.allocator, .{
        .label = "ui",
        .is_directory = true,
        .path = "src/lib/ui",
    });
    
    const panel_file = try tree_view.TreeNode.init(ide.allocator, .{
        .label = "panel.zig",
        .is_directory = false,
        .path = "src/lib/ui/panel.zig",
    });
    
    const tree_file = try tree_view.TreeNode.init(ide.allocator, .{
        .label = "tree_view.zig",
        .is_directory = false,
        .path = "src/lib/ui/tree_view.zig",
    });
    
    const text_area_file = try tree_view.TreeNode.init(ide.allocator, .{
        .label = "text_area.zig",
        .is_directory = false,
        .path = "src/lib/ui/text_area.zig",
    });
    
    const readme = try tree_view.TreeNode.init(ide.allocator, .{
        .label = "README.md",
        .is_directory = false,
        .path = "README.md",
    });
    
    const claude_md = try tree_view.TreeNode.init(ide.allocator, .{
        .label = "CLAUDE.md",
        .is_directory = false,
        .path = "CLAUDE.md",
    });
    
    try ui.addChild(panel_file);
    try ui.addChild(tree_file);
    try ui.addChild(text_area_file);
    
    try lib.addChild(ui);
    try src.addChild(lib);
    
    try root.addChild(src);
    try root.addChild(readme);
    try root.addChild(claude_md);
    
    root.expanded = true;
    src.expanded = true;
    lib.expanded = true;
    ui.expanded = true;
    
    try ide.file_tree.?.addRootNode(root);
}

fn loadFile(ide: *IDEPage, path: []const u8) !void {
    _ = path;
    
    try ide.terminal_output.?.addItem(.{
        .text = "TODO: File loading not yet implemented",
        .color = Color{ .r = 255, .g = 200, .b = 100, .a = 255 },
    });
}

fn executeCommand(ide: *IDEPage, command: []const u8) !void {
    try ide.terminal_output.?.addItem(.{
        .text = command,
        .color = Color{ .r = 200, .g = 200, .b = 200, .a = 255 },
        .icon = "> ",
    });
    
    if (std.mem.eql(u8, command, "help")) {
        try ide.terminal_output.?.addItem(.{
            .text = "Available commands:",
            .color = Color{ .r = 150, .g = 150, .b = 150, .a = 255 },
        });
        try ide.terminal_output.?.addItem(.{
            .text = "  help - Show this help message",
            .color = Color{ .r = 150, .g = 150, .b = 150, .a = 255 },
        });
        try ide.terminal_output.?.addItem(.{
            .text = "  clear - Clear terminal output",
            .color = Color{ .r = 150, .g = 150, .b = 150, .a = 255 },
        });
        try ide.terminal_output.?.addItem(.{
            .text = "  ls - List files (TODO)",
            .color = Color{ .r = 150, .g = 150, .b = 150, .a = 255 },
        });
        try ide.terminal_output.?.addItem(.{
            .text = "  pwd - Print working directory (TODO)",
            .color = Color{ .r = 150, .g = 150, .b = 150, .a = 255 },
        });
    } else if (std.mem.eql(u8, command, "clear")) {
        ide.terminal_output.?.clearItems();
        try ide.terminal_output.?.addItem(.{
            .text = "Terminal cleared",
            .color = Color{ .r = 100, .g = 200, .b = 100, .a = 255 },
        });
    } else {
        try ide.terminal_output.?.addItem(.{
            .text = "Command not implemented yet",
            .color = Color{ .r = 255, .g = 100, .b = 100, .a = 255 },
        });
    }
    
    ide.terminal_input.?.clear();
}

fn deinit(self: *page.Page) void {
    const ide: *IDEPage = @fieldParentPtr("base", self);
    _ = ide;
}

fn update(self: *page.Page, dt: f32) void {
    const ide: *IDEPage = @fieldParentPtr("base", self);
    _ = ide;
    _ = dt;
}

fn render(self: *page.Page, links: *std.ArrayList(page.Link)) !void {
    const ide: *IDEPage = @fieldParentPtr("base", self);
    _ = ide;
    
    try links.append(page.Link{
        .text = "< Back to Menu",
        .target = "/",
        .position = .{ .x = 20, .y = 20 },
        .color = .{ .r = 200, .g = 200, .b = 200, .a = 255 },
    });
}

fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
    const ide: *IDEPage = @fieldParentPtr("base", self);
    allocator.destroy(ide);
}