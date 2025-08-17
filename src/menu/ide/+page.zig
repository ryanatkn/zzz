const std = @import("std");
const page = @import("../../hud/page.zig");
const math = @import("../../lib/math/mod.zig");
const directory_scanner = @import("../../lib/platform/directory_scanner.zig");
const file_tree = @import("../../lib/ui/file_tree.zig");
const ide_constants = @import("constants.zig");
const syntax_highlighter = @import("syntax_highlighter.zig");

const Vec2 = math.Vec2;
const DirectoryScanner = directory_scanner.DirectoryScanner;
const DirectoryEntry = directory_scanner.DirectoryEntry;
const FileTreeComponent = file_tree.FileTreeComponent;
const ZigHighlighter = syntax_highlighter.ZigHighlighter;


pub const IDEPage = struct {
    base: page.Page,
    allocator: std.mem.Allocator,

    // File system state
    directory_scanner: DirectoryScanner,
    file_tree_component: FileTreeComponent,
    root_directory: ?*DirectoryEntry = null,

    // Syntax highlighting
    syntax_highlighter: ZigHighlighter,

    // UI state
    initialized: bool = false,
    loading: bool = false,
    error_message: ?[]const u8 = null,

    // File content state
    current_file_content: ?[]const u8 = null,
    current_file_error: ?[]const u8 = null,


    /// Get currently selected file entry
    pub fn getSelectedEntry(self: *const IDEPage) ?*DirectoryEntry {
        return self.file_tree_component.getSelectedEntry();
    }

    /// Handle mouse interaction with file tree
    pub fn handleFileTreeClick(self: *IDEPage, point: Vec2) !bool {
        // Adjust point to be relative to file tree content area (inside panel)
        const tree_content_offset = Vec2{ .x = 8 + 8 + 10, .y = 60 + 8 + 30 }; // panel + margins + tree offset
        const relative_point = Vec2{ .x = point.x - tree_content_offset.x, .y = point.y - tree_content_offset.y };

        const clicked = try self.file_tree_component.handleClick(relative_point);

        // If a file was selected, try to load its content
        if (clicked) {
            if (self.getSelectedEntry()) |selected| {
                if (!selected.metadata.is_directory) {
                    try self.loadFileContent(selected);
                }
            }
        }

        return clicked;
    }

    /// Get current file content for display
    pub fn getCurrentFileContent(self: *const IDEPage) ?[]const u8 {
        return self.current_file_content;
    }

    /// Get current file error for display
    pub fn getCurrentFileError(self: *const IDEPage) ?[]const u8 {
        return self.current_file_error;
    }

    /// Check if current file should be syntax highlighted
    pub fn shouldHighlightCurrentFile(self: *const IDEPage) bool {
        if (self.getSelectedEntry()) |selected| {
            if (!selected.metadata.is_directory) {
                return syntax_highlighter.shouldHighlight(selected.metadata.name);
            }
        }
        return false;
    }

    /// Get syntax highlighter reference
    pub fn getSyntaxHighlighter(self: *IDEPage) *ZigHighlighter {
        return &self.syntax_highlighter;
    }


    /// Load file content safely with size and error handling
    pub fn loadFileContent(self: *IDEPage, entry: *DirectoryEntry) !void {
        // Clear previous content and errors
        if (self.current_file_content) |old_content| {
            self.allocator.free(old_content);
            self.current_file_content = null;
        }
        self.current_file_error = null;

        // Check file size first
        if (entry.metadata.size > ide_constants.FILE_LIMITS.MAX_FILE_SIZE) {
            self.current_file_error = "File too large (max 1MB)";
            return;
        }

        // Try to open and read the file
        const file = std.fs.cwd().openFile(entry.metadata.full_path, .{}) catch |err| {
            self.current_file_error = switch (err) {
                error.FileNotFound => "File not found",
                error.AccessDenied => "Access denied",
                error.IsDir => "Cannot read directory",
                else => "Failed to open file",
            };
            return;
        };
        defer file.close();

        // Read file content
        const content = file.readToEndAlloc(self.allocator, ide_constants.FILE_LIMITS.MAX_FILE_SIZE) catch |err| {
            self.current_file_error = switch (err) {
                error.OutOfMemory => "Out of memory",
                error.FileTooBig => "File too large",
                else => "Failed to read file",
            };
            return;
        };

        self.current_file_content = content;
    }
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
        .syntax_highlighter = ZigHighlighter.init(allocator),
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
    const ide: *IDEPage = @fieldParentPtr("base", self);

    // Clean up file content
    if (ide.current_file_content) |content| {
        allocator.free(content);
        ide.current_file_content = null;
    }

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

fn render(self: *const page.Page, links: *std.ArrayList(page.Link), arena: std.mem.Allocator) !void {
    const ide: *const IDEPage = @fieldParentPtr("base", self);

    // Navigation
    try links.append(page.createLink("< Back to Menu", "/", 20, 20, 150, 30));
    
    // Add expand/collapse all buttons if initialized
    if (ide.initialized and !ide.loading and ide.error_message == null) {
        // File explorer panel positioning
        const panel_x: f32 = 8 + 8; // panel gap + panel border
        const panel_y: f32 = 60 + 8; // header height + panel gap
        const button_y: f32 = panel_y + 5; // Just below panel header
        
        // Expand All button
        try links.append(page.createLink("Expand All", "/ide?expand_all=true", panel_x + 10, button_y, 80, 20));
        
        // Collapse All button  
        try links.append(page.createLink("Collapse All", "/ide?collapse_all=true", panel_x + 100, button_y, 80, 20));
        
        try renderFileTreeLinks(ide, links, arena);
    }
}

/// Create Links for file tree items (using the proven working link system)
fn renderFileTreeLinks(ide: *const IDEPage, links: *std.ArrayList(page.Link), arena: std.mem.Allocator) !void {
    const tree_items = ide.file_tree_component.getVisibleItems();
    
    // File explorer panel positioning (matching renderFileTree)
    const panel_x: f32 = 8 + 8; // panel gap + panel border
    const panel_y: f32 = 60 + 8; // header height + panel gap
    const tree_start_y: f32 = panel_y + 35; // panel header space + button space
    
    for (tree_items, 0..) |item, i| {
        const item_y = tree_start_y + @as(f32, @floatFromInt(i)) * 26.0; // Item spacing
        const item_x = panel_x + 10 + @as(f32, @floatFromInt(item.depth)) * 20.0; // Indentation
        
        // Create display text with indicators for directories (using arena allocation)
        const display_name = if (item.entry.metadata.is_directory)
            std.fmt.allocPrint(arena, "[{s}] {s}", .{ 
                if (item.entry.expanded) "-" else "+", 
                item.entry.metadata.name 
            }) catch item.entry.metadata.name
        else
            item.entry.metadata.name;
            
        // Create action path for this item (using arena allocation)
        const action_path = if (item.entry.metadata.is_directory)
            std.fmt.allocPrint(arena, "/ide?toggle={s}", .{ item.entry.metadata.name }) catch "/ide"
        else
            std.fmt.allocPrint(arena, "/ide?file={s}", .{ item.entry.metadata.name }) catch "/ide";
        
        // Create the link
        try links.append(page.createLink(
            display_name,
            action_path,
            item_x,
            item_y,
            250.0, // Width
            20.0   // Height
        ));
    }
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
