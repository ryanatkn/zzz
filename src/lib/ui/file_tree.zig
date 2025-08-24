const std = @import("std");
const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");
const color_math = @import("../math/color.zig");
const directory_scanner = @import("../platform/directory_scanner.zig");
const BaseStyle = @import("styles/base_style.zig");

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
            .folder_closed, .folder_open => BaseStyle.Colors.file_folder,
            .file_zig => BaseStyle.Colors.file_zig,
            .file_markdown => BaseStyle.Colors.file_markdown,
            .file_shader => BaseStyle.Colors.file_shader,
            .file_config => BaseStyle.Colors.file_config,
            .file_text => BaseStyle.Colors.file_text,
            .file_unknown => BaseStyle.Colors.file_unknown,
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
            .bounds = math.Rectangle.init(position, Vec2.size(item_width, item_height)),
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

    /// Build filtered list of tree items for rendering
    pub fn buildFilteredRenderList(self: *Self, root: *DirectoryEntry, start_position: Vec2, search_query: []const u8, file_type_filter: anytype) !void {
        self.items.clearRetainingCapacity();
        var current_y = start_position.y;
        try self.buildFilteredRenderListRecursive(root, 0, start_position.x, &current_y, search_query, file_type_filter);
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

    /// Recursively build filtered render list
    fn buildFilteredRenderListRecursive(self: *Self, entry: *DirectoryEntry, depth: u32, x: f32, current_y: *f32, search_query: []const u8, file_type_filter: anytype) !void {
        // Check if this entry matches the filter
        var should_show = entry.metadata.is_directory or self.entryMatches(entry, search_query, file_type_filter);

        // For directories, check if any children match
        if (entry.metadata.is_directory and !should_show) {
            should_show = self.hasMatchingChildrenFiltered(entry, search_query, file_type_filter);
        }

        if (should_show) {
            const position = Vec2{ .x = x + @as(f32, @floatFromInt(depth)) * 20.0, .y = current_y.* };
            const item = TreeItem.create(entry, depth, position);
            try self.items.append(item);
            current_y.* += 26.0; // Item height + spacing
        }

        // Add children if directory is expanded and shown
        if (entry.metadata.is_directory and entry.expanded and should_show) {
            for (entry.children.items) |child| {
                try self.buildFilteredRenderListRecursive(child, depth + 1, x, current_y, search_query, file_type_filter);
            }
        }
    }

    /// Check if an entry matches the filter criteria
    fn entryMatches(self: *Self, entry: *const DirectoryEntry, search_query: []const u8, file_type_filter: anytype) bool {
        _ = self;

        // Always show directories (they might contain matching files)
        if (entry.metadata.is_directory) return true;

        // Check file type filter
        if (!file_type_filter.matches(entry.metadata.name)) return false;

        // Check search query (case-insensitive)
        if (search_query.len > 0) {
            // Simple case-insensitive substring search
            var name_lower: [256]u8 = undefined;
            if (entry.metadata.name.len < name_lower.len) {
                for (entry.metadata.name, 0..) |c, i| {
                    name_lower[i] = std.ascii.toLower(c);
                }
                const name_slice = name_lower[0..entry.metadata.name.len];

                var query_lower: [256]u8 = undefined;
                for (search_query, 0..) |c, i| {
                    query_lower[i] = std.ascii.toLower(c);
                }
                const query_slice = query_lower[0..search_query.len];

                return std.mem.indexOf(u8, name_slice, query_slice) != null;
            }
        }

        return true;
    }

    /// Check if directory has any matching children (recursively)
    fn hasMatchingChildrenFiltered(self: *Self, entry: *const DirectoryEntry, search_query: []const u8, file_type_filter: anytype) bool {
        for (entry.children.items) |child| {
            if (self.entryMatches(child, search_query, file_type_filter)) return true;
            if (child.metadata.is_directory and self.hasMatchingChildrenFiltered(child, search_query, file_type_filter)) {
                return true;
            }
        }
        return false;
    }

    /// Get item at point (for mouse interaction)
    pub fn getItemAtPoint(self: *const Self, point: Vec2) ?*TreeItem {
        const log = std.log.scoped(.file_tree_click);
        log.info("getItemAtPoint called with point ({d:.1},{d:.1})", .{ point.x, point.y });
        log.info("Checking {} items", .{self.items.items.len});

        for (self.items.items, 0..) |*item, i| {
            if (i < 3) { // Debug first 3 items
                log.info("Item {}: '{s}' bounds ({d:.1},{d:.1}) size ({d:.1},{d:.1})", .{ i, item.entry.metadata.name, item.bounds.position.x, item.bounds.position.y, item.bounds.size.x, item.bounds.size.y });
            }
            if (item.containsPoint(point)) {
                log.info("Found matching item: '{s}'", .{item.entry.metadata.name});
                return item;
            }
        }
        log.info("No item found at point", .{});
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
            // Build initial render list with panel-relative coordinates
            try self.renderer.buildRenderList(r, Vec2.ZERO);
        }
    }

    /// Set root directory entry with filtering
    pub fn setRootEntryWithFilter(self: *Self, root: ?*DirectoryEntry, search_query: []const u8, file_type_filter: anytype) !void {
        self.root_entry = root;
        if (root) |r| {
            // Auto-expand root
            r.expanded = true;
            // Build filtered render list with panel-relative coordinates
            try self.renderer.buildFilteredRenderList(r, Vec2.ZERO, search_query, file_type_filter);
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
                    try self.renderer.buildRenderList(root, Vec2.ZERO);
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

    /// Move selection to next visible item (Down arrow)
    pub fn selectNext(self: *Self) void {
        const items = self.getVisibleItems();
        if (items.len == 0) return;

        if (self.state.selected_entry) |current| {
            // Find current selection and move to next
            for (items, 0..) |item, i| {
                if (item.entry == current) {
                    if (i + 1 < items.len) {
                        self.state.selectEntry(items[i + 1].entry);
                    }
                    return;
                }
            }
        }

        // No selection or not found - select first item
        if (items.len > 0) {
            self.state.selectEntry(items[0].entry);
        }
    }

    /// Move selection to previous visible item (Up arrow)
    pub fn selectPrevious(self: *Self) void {
        const items = self.getVisibleItems();
        if (items.len == 0) return;

        if (self.state.selected_entry) |current| {
            // Find current selection and move to previous
            for (items, 0..) |item, i| {
                if (item.entry == current) {
                    if (i > 0) {
                        self.state.selectEntry(items[i - 1].entry);
                    }
                    return;
                }
            }
        }

        // No selection or not found - select last item
        if (items.len > 0) {
            self.state.selectEntry(items[items.len - 1].entry);
        }
    }

    /// Expand/collapse selected directory (Right/Left arrow)
    pub fn toggleSelectedExpansion(self: *Self) void {
        if (self.state.selected_entry) |selected| {
            if (selected.metadata.is_directory) {
                self.renderer.toggleExpanded(selected);
                // Rebuild render list to reflect changes
                if (self.root_entry) |root| {
                    self.renderer.buildRenderList(root, Vec2.ZERO) catch {};
                }
            }
        }
    }

    /// Get selected file path for opening
    pub fn getSelectedFilePath(self: *const Self) ?[]const u8 {
        if (self.state.selected_entry) |selected| {
            if (!selected.metadata.is_directory) {
                return selected.getFullPath();
            }
        }
        return null;
    }
};
