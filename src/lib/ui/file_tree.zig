const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const directory_scanner = @import("../platform/directory_scanner.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const DirectoryEntry = directory_scanner.DirectoryEntry;
const FileType = directory_scanner.FileType;

/// Visual state for file tree rendering
pub const FileTreeState = struct {
    selected_entry: ?*DirectoryEntry = null,
    hovered_entry: ?*DirectoryEntry = null,
    scroll_offset: f32 = 0.0,
    
    /// Select an entry
    pub fn selectEntry(self: *FileTreeState, entry: ?*DirectoryEntry) void {
        self.selected_entry = entry;
    }
    
    /// Set hovered entry
    pub fn setHovered(self: *FileTreeState, entry: ?*DirectoryEntry) void {
        self.hovered_entry = entry;
    }
    
    /// Check if entry is selected
    pub fn isSelected(self: *const FileTreeState, entry: *const DirectoryEntry) bool {
        return self.selected_entry == entry;
    }
    
    /// Check if entry is hovered
    pub fn isHovered(self: *const FileTreeState, entry: *const DirectoryEntry) bool {
        return self.hovered_entry == entry;
    }
};

/// File tree icon types
pub const FileIcon = enum {
    folder_closed,
    folder_open,
    file_zig,
    file_markdown,
    file_shader,
    file_config,
    file_text,
    file_unknown,
    
    /// Get icon for file type and expanded state
    pub fn fromFileType(file_type: FileType, expanded: bool) FileIcon {
        return switch (file_type) {
            .directory => if (expanded) .folder_open else .folder_closed,
            .zig_source => .file_zig,
            .markdown => .file_markdown,
            .shader_hlsl => .file_shader,
            .config_zon => .file_config,
            .text_file => .file_text,
            .unknown => .file_unknown,
        };
    }
    
    /// Get color for icon
    pub fn getColor(self: FileIcon) Color {
        return switch (self) {
            .folder_closed, .folder_open => Color{ .r = 100, .g = 149, .b = 237, .a = 255 }, // Blue
            .file_zig => Color{ .r = 255, .g = 140, .b = 0, .a = 255 },     // Orange
            .file_markdown => Color{ .r = 50, .g = 205, .b = 50, .a = 255 }, // Green
            .file_shader => Color{ .r = 255, .g = 20, .b = 147, .a = 255 },  // Pink
            .file_config => Color{ .r = 255, .g = 215, .b = 0, .a = 255 },   // Gold
            .file_text => Color{ .r = 169, .g = 169, .b = 169, .a = 255 },   // Gray
            .file_unknown => Color{ .r = 128, .g = 128, .b = 128, .a = 255 }, // Dark Gray
        };
    }
};

/// Tree item for rendering
pub const TreeItem = struct {
    entry: *DirectoryEntry,
    depth: u32,
    position: Vec2,
    bounds: math.Rectangle,
    icon: FileIcon,
    visible: bool,
    
    /// Create tree item for rendering
    pub fn create(entry: *DirectoryEntry, depth: u32, position: Vec2) TreeItem {
        const icon = FileIcon.fromFileType(entry.metadata.file_type, entry.expanded);
        const item_height: f32 = 24.0;
        const item_width: f32 = 280.0; // Slightly less than panel width for margins
        
        return TreeItem{
            .entry = entry,
            .depth = depth,
            .position = position,
            .bounds = math.Rectangle{
                .position = position,
                .size = Vec2{ .x = item_width, .y = item_height },
            },
            .icon = icon,
            .visible = true,
        };
    }
    
    /// Check if point is within item bounds
    pub fn containsPoint(self: *const TreeItem, point: Vec2) bool {
        return point.x >= self.bounds.position.x and 
               point.x <= self.bounds.position.x + self.bounds.size.x and
               point.y >= self.bounds.position.y and 
               point.y <= self.bounds.position.y + self.bounds.size.y;
    }
};

/// File tree renderer for converting directory structure to renderable items
pub const FileTreeRenderer = struct {
    allocator: std.mem.Allocator,
    items: std.ArrayList(TreeItem),
    
    const Self = @This();
    
    /// Initialize renderer
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .items = std.ArrayList(TreeItem).init(allocator),
        };
    }
    
    /// Clean up renderer
    pub fn deinit(self: *Self) void {
        self.items.deinit();
    }
    
    /// Build flat list of tree items for rendering from directory tree
    pub fn buildRenderList(self: *Self, root: *DirectoryEntry, start_position: Vec2) !void {
        self.items.clearRetainingCapacity();
        var current_y = start_position.y;
        try self.buildRenderListRecursive(root, 0, start_position.x, &current_y);
    }
    
    /// Recursively build render list
    fn buildRenderListRecursive(self: *Self, entry: *DirectoryEntry, depth: u32, x: f32, current_y: *f32) !void {
        const position = Vec2{ .x = x + @as(f32, @floatFromInt(depth)) * 20.0, .y = current_y.* };
        const item = TreeItem.create(entry, depth, position);
        try self.items.append(item);
        
        current_y.* += 26.0; // Item height + spacing
        
        // Add children if expanded
        if (entry.metadata.is_directory and entry.expanded) {
            for (entry.children.items) |child| {
                try self.buildRenderListRecursive(child, depth + 1, x, current_y);
            }
        }
    }
    
    /// Get item at point (for mouse interaction)
    pub fn getItemAtPoint(self: *const Self, point: Vec2) ?*TreeItem {
        for (self.items.items) |*item| {
            if (item.containsPoint(point)) {
                return item;
            }
        }
        return null;
    }
    
    /// Get all visible items
    pub fn getVisibleItems(self: *const Self) []TreeItem {
        return self.items.items;
    }
    
    /// Toggle expanded state of directory entry
    pub fn toggleExpanded(self: *Self, entry: *DirectoryEntry) void {
        _ = self;
        if (entry.metadata.is_directory) {
            entry.expanded = !entry.expanded;
        }
    }
};

/// File tree component for integration with UI system
pub const FileTreeComponent = struct {
    renderer: FileTreeRenderer,
    state: FileTreeState,
    root_entry: ?*DirectoryEntry,
    
    const Self = @This();
    
    /// Initialize file tree component
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .renderer = FileTreeRenderer.init(allocator),
            .state = FileTreeState{},
            .root_entry = null,
        };
    }
    
    /// Clean up component
    pub fn deinit(self: *Self) void {
        self.renderer.deinit();
    }
    
    /// Set root directory entry
    pub fn setRootEntry(self: *Self, root: ?*DirectoryEntry) !void {
        self.root_entry = root;
        if (root) |r| {
            // Auto-expand root
            r.expanded = true;
            // Build initial render list
            try self.renderer.buildRenderList(r, Vec2{ .x = 10.0, .y = 10.0 });
        }
    }
    
    /// Handle mouse click
    pub fn handleClick(self: *Self, point: Vec2) !bool {
        if (self.renderer.getItemAtPoint(point)) |item| {
            // Select the item
            self.state.selectEntry(item.entry);
            
            // Toggle expansion if it's a directory
            if (item.entry.metadata.is_directory) {
                self.renderer.toggleExpanded(item.entry);
                // Rebuild render list after expansion change
                if (self.root_entry) |root| {
                    try self.renderer.buildRenderList(root, Vec2{ .x = 10.0, .y = 10.0 });
                }
            }
            
            return true; // Event consumed
        }
        return false; // Event not handled
    }
    
    /// Handle mouse hover
    pub fn handleHover(self: *Self, point: Vec2) void {
        if (self.renderer.getItemAtPoint(point)) |item| {
            self.state.setHovered(item.entry);
        } else {
            self.state.setHovered(null);
        }
    }
    
    /// Get currently selected entry
    pub fn getSelectedEntry(self: *const Self) ?*DirectoryEntry {
        return self.state.selected_entry;
    }
    
    /// Get visible items for rendering
    pub fn getVisibleItems(self: *const Self) []TreeItem {
        return self.renderer.getVisibleItems();
    }
    
    /// Get visual state for rendering
    pub fn getState(self: *const Self) *const FileTreeState {
        return &self.state;
    }
};