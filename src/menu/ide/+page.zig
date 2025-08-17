const std = @import("std");
const page = @import("../../hud/page.zig");

const IDEPage = struct {
    base: page.Page,
    allocator: std.mem.Allocator,
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const ide_page = try allocator.create(IDEPage);
    ide_page.* = IDEPage{
        .base = page.Page{
            .vtable = page.Page.VTable{
                .init = init,
                .deinit = deinit,
                .update = update,
                .render = render,
                .destroy = destroy,
            },
            .path = "/ide",
            .title = "IDE",
        },
        .allocator = allocator,
    };
    return &ide_page.base;
}

fn init(self: *page.Page, allocator: std.mem.Allocator) !void {
    _ = self;
    _ = allocator;
}

fn deinit(self: *page.Page, allocator: std.mem.Allocator) void {
    _ = self;
    _ = allocator;
}

fn update(self: *page.Page, dt: f32) void {
    _ = self;
    _ = dt;
}

fn render(self: *const page.Page, links: *std.ArrayList(page.Link)) !void {
    _ = self;
    
    // Simple layout with three panels described via text
    try links.append(page.createLink("< Back to Menu", "/", 20, 20, 150, 30));
    
    // File Explorer Panel
    try links.append(page.createLink("FILE EXPLORER", "", 100, 100, 200, 30));
    try links.append(page.createLink("src/", "", 120, 150, 180, 25));
    try links.append(page.createLink("  lib/", "", 140, 180, 180, 25));
    try links.append(page.createLink("    ui/", "", 160, 210, 180, 25));
    try links.append(page.createLink("      panel.zig", "", 180, 240, 180, 25));
    try links.append(page.createLink("      tree_view.zig", "", 180, 270, 180, 25));
    try links.append(page.createLink("      text_area.zig", "", 180, 300, 180, 25));
    try links.append(page.createLink("  hex/", "", 140, 330, 180, 25));
    try links.append(page.createLink("  menu/", "", 140, 360, 180, 25));
    try links.append(page.createLink("README.md", "", 120, 390, 180, 25));
    try links.append(page.createLink("CLAUDE.md", "", 120, 420, 180, 25));
    
    // Text Editor Panel
    try links.append(page.createLink("TEXT EDITOR", "", 600, 100, 200, 30));
    try links.append(page.createLink("// Welcome to the Zzz IDE", "", 620, 150, 500, 25));
    try links.append(page.createLink("// Select a file from the explorer to begin", "", 620, 180, 500, 25));
    try links.append(page.createLink("//", "", 620, 210, 500, 25));
    try links.append(page.createLink("// Features:", "", 620, 240, 500, 25));
    try links.append(page.createLink("// - File Explorer (left panel)", "", 620, 270, 500, 25));
    try links.append(page.createLink("// - Text Editor (center panel)", "", 620, 300, 500, 25));
    try links.append(page.createLink("// - Terminal (right panel)", "", 620, 330, 500, 25));
    try links.append(page.createLink("//", "", 620, 360, 500, 25));
    try links.append(page.createLink("// TODOs:", "", 620, 390, 500, 25));
    try links.append(page.createLink("// - Implement file I/O operations", "", 620, 420, 500, 25));
    try links.append(page.createLink("// - Add syntax highlighting", "", 620, 450, 500, 25));
    try links.append(page.createLink("// - Terminal command execution", "", 620, 480, 500, 25));
    try links.append(page.createLink("// - Copy/paste support", "", 620, 510, 500, 25));
    try links.append(page.createLink("// - Search and replace", "", 620, 540, 500, 25));
    
    // Terminal Panel
    try links.append(page.createLink("TERMINAL", "", 1300, 100, 200, 30));
    try links.append(page.createLink("$ Zzz Terminal v0.1.0", "", 1320, 150, 400, 25));
    try links.append(page.createLink("$ Type 'help' for commands", "", 1320, 180, 400, 25));
    try links.append(page.createLink("$ > help", "", 1320, 210, 400, 25));
    try links.append(page.createLink("$ Available commands:", "", 1320, 240, 400, 25));
    try links.append(page.createLink("$   help - Show this help", "", 1320, 270, 400, 25));
    try links.append(page.createLink("$   clear - Clear terminal", "", 1320, 300, 400, 25));
    try links.append(page.createLink("$   ls - List files (TODO)", "", 1320, 330, 400, 25));
    try links.append(page.createLink("$   pwd - Show directory (TODO)", "", 1320, 360, 400, 25));
    try links.append(page.createLink("$   cat - View file (TODO)", "", 1320, 390, 400, 25));
    try links.append(page.createLink("$ > _", "", 1320, 420, 400, 25));
    
    // Info panel at bottom
    try links.append(page.createLink("IDE components created in src/lib/ui/", "", 100, 650, 500, 25));
    try links.append(page.createLink("Panel, ScrollableView, TreeView, TextInput, TextArea, ListView", "", 100, 680, 700, 25));
    try links.append(page.createLink("Ready for integration with actual file I/O and editing", "", 100, 710, 600, 25));
}

fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
    const ide: *IDEPage = @fieldParentPtr("base", self);
    allocator.destroy(ide);
}