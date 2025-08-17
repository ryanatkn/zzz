const std = @import("std");
const page = @import("../../hud/page.zig");
const math = @import("../../lib/math/mod.zig");
const colors = @import("../../lib/core/colors.zig");
const panel = @import("../../lib/ui/panel.zig");
const tree_view = @import("../../lib/ui/tree_view.zig");
const text_area = @import("../../lib/ui/text_area.zig");
const layout = @import("../../lib/ui/layout.zig");
const reactive = @import("../../lib/reactive/mod.zig");
const directory_scanner = @import("../../lib/platform/directory_scanner.zig");
const file_tree = @import("../../lib/ui/file_tree.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const Component = @import("../../lib/ui/component.zig").Component;
const ComponentProps = @import("../../lib/ui/component.zig").ComponentProps;
const DirectoryScanner = directory_scanner.DirectoryScanner;
const DirectoryEntry = directory_scanner.DirectoryEntry;
const FileTreeComponent = file_tree.FileTreeComponent;

pub const IDEPage = struct {
    base: page.Page,
    allocator: std.mem.Allocator,
    
    // File system state
    directory_scanner: DirectoryScanner,
    file_tree_component: FileTreeComponent,
    root_directory: ?*DirectoryEntry = null,
    
    // UI state
    initialized: bool = false,
    loading: bool = false,
    error_message: ?[]const u8 = null,
    
    // File content state
    current_file_content: ?[]const u8 = null,
    current_file_error: ?[]const u8 = null,
    
    // Display settings
    screen_width: f32 = 2560.0,  // Assume high-res display
    screen_height: f32 = 1440.0,
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
            .title = "Modern IDE Dashboard",
        },
        .allocator = allocator,
        .directory_scanner = DirectoryScanner.init(allocator),
        .file_tree_component = FileTreeComponent.init(allocator),
    };
    return &ide_page.base;
}

fn init(self: *page.Page, allocator: std.mem.Allocator) !void {
    _ = allocator;
    const ide: *IDEPage = @fieldParentPtr("base", self);
    
    // Load directory structure
    try loadDirectory(ide);
    
    ide.initialized = true;
}

fn deinit(self: *page.Page, allocator: std.mem.Allocator) void {
    _ = allocator;
    const ide: *IDEPage = @fieldParentPtr("base", self);
    
    // Clean up file tree
    ide.file_tree_component.deinit();
    
    // Clean up directory tree
    if (ide.root_directory) |root| {
        ide.directory_scanner.freeTree(root);
        ide.root_directory = null;
    }
    
    ide.initialized = false;
}

fn update(self: *page.Page, dt: f32) void {
    _ = dt;
    _ = self;
}

fn render(self: *const page.Page, links: *std.ArrayList(page.Link)) !void {
    _ = self;

    // Simple navigation - actual UI is rendered via GPU in renderPageContent
    try links.append(page.createLink("< Back to Menu", "/", 20, 20, 150, 30));
}

fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
    const ide: *IDEPage = @fieldParentPtr("base", self);
    allocator.destroy(ide);
}

/// Load directory structure (hardcoded to src/ for now)
fn loadDirectory(self: *IDEPage) !void {
    self.loading = true;
    self.error_message = null;
    
    // Scan src directory
    self.root_directory = self.directory_scanner.scanDirectory("src") catch |err| {
        const error_msg = switch (err) {
            error.FileNotFound => "Directory 'src' not found",
            error.AccessDenied => "Access denied to 'src' directory", 
            else => "Failed to scan directory",
        };
        self.error_message = error_msg;
        self.loading = false;
        return err;
    };
    
    // Set up file tree component
    try self.file_tree_component.setRootEntry(self.root_directory);
    
    self.loading = false;
}

/// Get currently selected file entry
pub fn getSelectedEntry(self: *const IDEPage) ?*DirectoryEntry {
    return self.file_tree_component.getSelectedEntry();
}

/// Handle mouse interaction with file tree
pub fn handleFileTreeClick(self: *IDEPage, point: Vec2) !bool {
    // Adjust point to be relative to file explorer panel
    const explorer_rect = Vec2{ .x = 8 + 8, .y = 60 + 8 + 30 }; // panel position + header + margin
    const relative_point = Vec2{ 
        .x = point.x - explorer_rect.x, 
        .y = point.y - explorer_rect.y 
    };
    
    return try self.file_tree_component.handleClick(relative_point);
}

/// Render the dashboard UI components using the provided renderer  
pub fn renderDashboard(self: *IDEPage, renderer: anytype) !void {
    _ = renderer;
    if (!self.initialized) return;
    
    // TODO: Implement actual dashboard rendering with properly typed components
    // For now this is a placeholder that will be expanded in later phases
}
