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
const ide_constants = @import("constants.zig");
const syntax_highlighter = @import("syntax_highlighter.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const Component = @import("../../lib/ui/component.zig").Component;
const ComponentProps = @import("../../lib/ui/component.zig").ComponentProps;
const DirectoryScanner = directory_scanner.DirectoryScanner;
const DirectoryEntry = directory_scanner.DirectoryEntry;
const FileTreeComponent = file_tree.FileTreeComponent;
const ZigHighlighter = syntax_highlighter.ZigHighlighter;

/// File type filter options for search
pub const FileTypeFilter = enum {
    all,        // Show all files
    zig,        // Only .zig files
    markdown,   // Only .md files
    config,     // Config files (.json, .toml, etc.)
    
    pub fn getDisplayName(self: FileTypeFilter) []const u8 {
        return switch (self) {
            .all => "All",
            .zig => "Zig",
            .markdown => "Markdown", 
            .config => "Config",
        };
    }
    
    pub fn matches(self: FileTypeFilter, filename: []const u8) bool {
        return switch (self) {
            .all => true,
            .zig => std.mem.endsWith(u8, filename, ".zig"),
            .markdown => std.mem.endsWith(u8, filename, ".md"),
            .config => std.mem.endsWith(u8, filename, ".json") or 
                      std.mem.endsWith(u8, filename, ".toml") or
                      std.mem.endsWith(u8, filename, ".yml") or
                      std.mem.endsWith(u8, filename, ".yaml"),
        };
    }
};

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
    
    // Search and filtering state
    search_query: []const u8 = "",
    file_type_filter: FileTypeFilter = .all,
    search_buffer: [256]u8 = undefined, // Buffer for search input
    search_text_length: usize = 0,
    
    // Display settings
    screen_width: f32 = 2560.0,  // Assume high-res display
    screen_height: f32 = 1440.0,

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

    /// Update search query and rebuild filtered tree
    pub fn setSearchQuery(self: *IDEPage, query: []const u8) !void {
        // Copy query to buffer (truncate if too long)
        const copy_len = @min(query.len, self.search_buffer.len - 1);
        @memcpy(self.search_buffer[0..copy_len], query[0..copy_len]);
        self.search_buffer[copy_len] = 0; // Null terminate
        self.search_text_length = copy_len;
        self.search_query = self.search_buffer[0..copy_len];
        
        // Rebuild tree with new filter
        try self.rebuildFilteredTree();
    }

    /// Set file type filter and rebuild tree
    pub fn setFileTypeFilter(self: *IDEPage, filter: FileTypeFilter) !void {
        self.file_type_filter = filter;
        try self.rebuildFilteredTree();
    }

    /// Get current search query
    pub fn getSearchQuery(self: *const IDEPage) []const u8 {
        return self.search_query;
    }

    /// Get current file type filter
    pub fn getFileTypeFilter(self: *const IDEPage) FileTypeFilter {
        return self.file_type_filter;
    }

    /// Check if an entry matches current search/filter criteria
    fn matchesFilter(self: *const IDEPage, entry: *const DirectoryEntry) bool {
        // Always show directories (they might contain matching files)
        if (entry.metadata.is_directory) return true;
        
        // Check file type filter
        if (!self.file_type_filter.matches(entry.metadata.name)) return false;
        
        // Check search query (case-insensitive)
        if (self.search_query.len > 0) {
            // Simple case-insensitive substring search
            var name_lower: [256]u8 = undefined;
            if (entry.metadata.name.len < name_lower.len) {
                for (entry.metadata.name, 0..) |c, i| {
                    name_lower[i] = std.ascii.toLower(c);
                }
                const name_slice = name_lower[0..entry.metadata.name.len];
                
                var query_lower: [256]u8 = undefined;
                for (self.search_query, 0..) |c, i| {
                    query_lower[i] = std.ascii.toLower(c);
                }
                const query_slice = query_lower[0..self.search_query.len];
                
                return std.mem.indexOf(u8, name_slice, query_slice) != null;
            }
        }
        
        return true;
    }

    /// Rebuild file tree with current search/filter applied
    fn rebuildFilteredTree(self: *IDEPage) !void {
        if (self.root_directory) |root| {
            // For now, just rebuild the tree normally
            // In a more advanced implementation, we'd filter the tree structure
            try self.file_tree_component.setRootEntry(root);
        }
    }

    /// Render the dashboard UI components using the provided renderer  
    pub fn renderDashboard(self: *IDEPage, renderer: anytype) !void {
        _ = renderer;
        if (!self.initialized) return;
        
        // TODO: Implement actual dashboard rendering with properly typed components
        // For now this is a placeholder that will be expanded in later phases
    }

    /// Load file content safely with size and error handling
    fn loadFileContent(self: *IDEPage, entry: *DirectoryEntry) !void {
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

