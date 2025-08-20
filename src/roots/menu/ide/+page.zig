const std = @import("std");
const page = @import("../../../lib/browser/page.zig");
const math = @import("../../../lib/math/mod.zig");
const directory_scanner = @import("../../../lib/platform/directory_scanner.zig");
const file_tree = @import("../../../lib/ui/file_tree.zig");
const ide_constants = @import("constants.zig");
const syntax_highlighter = @import("syntax_highlighter.zig");
const terminal_ui = @import("../../../lib/ui/terminal.zig");
const sdl = @import("../../../lib/platform/sdl.zig");

const Vec2 = math.Vec2;
const DirectoryScanner = directory_scanner.DirectoryScanner;
const DirectoryEntry = directory_scanner.DirectoryEntry;
const FileTreeComponent = file_tree.FileTreeComponent;
const ZigHighlighter = syntax_highlighter.ZigHighlighter;
const TerminalComponent = terminal_ui.TerminalComponent;
const KeyboardEvent = sdl.sdl.SDL_KeyboardEvent;

/// Which panel currently has focus for input handling
pub const FocusedPanel = enum {
    FileTree,
    Content,
    Terminal,
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

    // Terminal component (replaces info panel)
    terminal_component: ?TerminalComponent = null,

    // Focus management
    focused_panel: FocusedPanel = .Terminal,

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
            // Set focus to file tree
            self.focused_panel = .FileTree;

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

    /// Get terminal component (initialize if needed)
    pub fn getTerminal(self: *IDEPage) !*TerminalComponent {
        if (self.terminal_component == null) {
            // Initialize terminal with simple bounds
            const bounds = math.Rectangle{
                .position = Vec2{ .x = 0, .y = 0 },
                .size = Vec2{ .x = 400, .y = 300 },
            };

            // Simple initialization without complex operations
            self.terminal_component = TerminalComponent.init(self.allocator, bounds) catch |err| {
                self.error_message = "Failed to initialize terminal";
                return err;
            };
        }

        return &self.terminal_component.?;
    }

    /// Clear terminal
    pub fn clearTerminal(self: *IDEPage) void {
        if (self.terminal_component) |*terminal| {
            terminal.clear();
        }
    }

    /// Handle click in terminal panel area
    pub fn handleTerminalClick(self: *IDEPage, point: Vec2) bool {
        // Calculate terminal panel bounds (right panel)
        const screen_width: f32 = 1920; // From constants
        const screen_height: f32 = 1080;
        const panel_gap: f32 = 8;
        const header_height: f32 = 60;

        // Terminal panel is the rightmost panel (preview panel replacement)
        const content_width = (screen_width - 4 * panel_gap) / 3; // Three equal panels
        const terminal_x = 2 * panel_gap + 2 * content_width + panel_gap;
        const terminal_y = header_height + panel_gap;
        const terminal_width = content_width;
        const terminal_height = screen_height - header_height - 2 * panel_gap;

        const terminal_bounds = math.Rectangle{
            .position = Vec2{ .x = terminal_x, .y = terminal_y },
            .size = Vec2{ .x = terminal_width, .y = terminal_height },
        };

        // Check if click is within terminal bounds
        if (point.x >= terminal_bounds.position.x and
            point.x <= terminal_bounds.position.x + terminal_bounds.size.x and
            point.y >= terminal_bounds.position.y and
            point.y <= terminal_bounds.position.y + terminal_bounds.size.y)
        {
            self.focused_panel = .Terminal;

            // Ensure terminal is initialized and focused
            if (self.getTerminal()) |terminal| {
                terminal.setFocus(true);
                return true;
            } else |_| {
                return false;
            }
        }

        return false;
    }

    /// Handle keyboard input for focused panel
    pub fn handleKeyboardInput(self: *IDEPage, key_event: KeyboardEvent) bool {
        const log = std.log.scoped(.ide_input);
        log.info("IDE handleKeyboardInput - focused_panel: {}, scancode: {d}", .{ self.focused_panel, key_event.scancode });

        if (self.focused_panel != .Terminal) {
            log.info("Not terminal focused, panel: {}", .{self.focused_panel});
            return false;
        }

        if (self.terminal_component) |*terminal| {
            // Ensure terminal component is focused
            terminal.setFocus(true);
            log.info("Forwarding key to terminal component", .{});
            return terminal.handleKeyPress(key_event);
        } else {
            log.warn("Terminal component not initialized", .{});
        }

        return false;
    }

    /// Get focused panel
    pub fn getFocusedPanel(self: *const IDEPage) FocusedPanel {
        return self.focused_panel;
    }

    /// Set focused panel
    pub fn setFocusedPanel(self: *IDEPage, panel: FocusedPanel) void {
        self.focused_panel = panel;
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

    // Clean up terminal component
    if (ide.terminal_component) |*terminal| {
        terminal.deinit();
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
    const ide: *IDEPage = @fieldParentPtr("base", self);

    // Update terminal component
    if (ide.terminal_component) |*terminal| {
        terminal.update(dt);
    }
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
            std.fmt.allocPrint(arena, "[{s}] {s}", .{ if (item.entry.expanded) "-" else "+", item.entry.metadata.name }) catch item.entry.metadata.name
        else
            item.entry.metadata.name;

        // Create action path for this item (using arena allocation)
        const action_path = if (item.entry.metadata.is_directory)
            std.fmt.allocPrint(arena, "/ide?toggle={s}", .{item.entry.metadata.name}) catch "/ide"
        else
            std.fmt.allocPrint(arena, "/ide?file={s}", .{item.entry.metadata.name}) catch "/ide";

        // Create the link
        try links.append(page.createLink(display_name, action_path, item_x, item_y, 250.0, // Width
            20.0 // Height
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
