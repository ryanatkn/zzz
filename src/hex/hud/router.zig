const std = @import("std");
const page = @import("../../lib/browser/page.zig");
const directory_scanner = @import("../../lib/platform/directory_scanner.zig");
const math = @import("../../lib/math/mod.zig");
const game_mod = @import("../game.zig");
const loggers = @import("../../lib/debug/loggers.zig");

const root_page = @import("../../roots/menu/+page.zig");
const root_layout = @import("../../roots/menu/+layout.zig");
const settings_page = @import("../../roots/menu/settings/+page.zig");
const settings_video_page = @import("../../roots/menu/settings/video/+page.zig");
const settings_audio_page = @import("../../roots/menu/settings/audio/+page.zig");
const settings_fonts_page = @import("../../roots/menu/settings/fonts/+page.zig");
const settings_fonts_save_page = @import("../../roots/menu/settings/fonts/save/+page.zig");
const stats_page = @import("../../roots/menu/stats/+page.zig");
const font_grid_test_page = @import("../../roots/menu/font_grid_test/+page.zig");
const vector_test_page = @import("../../roots/menu/vector_test/+page.zig");
const ide_page = @import("../../roots/menu/ide/+page.zig");
const reactive_test_page = @import("../../roots/menu/reactive_test/+page.zig");
const layout_benchmark_page = @import("../../roots/menu/layout_benchmark/+page.zig");

const DirectoryEntry = directory_scanner.DirectoryEntry;
const Vec2 = math.Vec2;
const GameState = game_mod.GameState;

// Global reference to game state for world reloading (set from main)
var global_game_state: ?*GameState = null;

/// Set global game state reference for world reloading
pub fn setGameStateReference(game_state: *GameState) void {
    global_game_state = game_state;
}

pub const Router = struct {
    allocator: std.mem.Allocator,
    current_page: ?*page.Page,
    current_layouts: std.ArrayList(*page.Layout),
    game_renderer: ?*@import("../game_renderer.zig").GameRenderer = null,

    pub fn init(allocator: std.mem.Allocator) Router {
        return .{
            .allocator = allocator,
            .current_page = null,
            .current_layouts = std.ArrayList(*page.Layout).init(allocator),
            .game_renderer = null,
        };
    }

    pub fn setGameRenderer(self: *Router, renderer: *@import("../game_renderer.zig").GameRenderer) void {
        self.game_renderer = renderer;
    }

    pub fn deinit(self: *Router) void {
        self.cleanupCurrent();
        self.current_layouts.deinit();
    }

    fn cleanupCurrent(self: *Router) void {
        if (self.current_page) |p| {
            p.deinit(self.allocator);
            p.destroy(self.allocator);
            self.current_page = null;
        }

        for (self.current_layouts.items) |layout| {
            layout.deinit(self.allocator);
            layout.destroy(self.allocator);
        }
        self.current_layouts.clearRetainingCapacity();
    }

    pub fn navigate(self: *Router, path: []const u8) !void {
        const ui_log = loggers.getUILog();
        ui_log.info("router_navigate", "Router navigate called with path: '{s}'", .{path});

        // Handle empty paths gracefully - ignore them instead of navigating to root
        if (path.len == 0) {
            ui_log.info("router_navigate", "Ignoring empty path navigation", .{});
            return;
        }

        // Check if we're navigating within the same page (only query parameters changed)
        if (self.current_page) |current_page| {
            const current_base_path = self.extractBasePath(current_page.path);
            const new_base_path = self.extractBasePath(path);

            ui_log.info("router_navigate", "Current page: '{s}', base: '{s}', new base: '{s}'", .{ current_page.path, current_base_path, new_base_path });

            // Handle query-only paths (starting with ?) as same-page navigation
            const is_query_only = path.len > 0 and path[0] == '?';
            const is_same_page = std.mem.eql(u8, current_base_path, new_base_path) or is_query_only;

            if (is_same_page) {
                ui_log.info("router_navigate", "Same page navigation - handling action without page recreation", .{});
                // Same page, just handle the action without destroying/recreating
                if (std.mem.indexOf(u8, path, "?")) |query_start| {
                    const query = path[query_start + 1 ..];

                    // Check if it's a world loading query, reactive test action, or layout benchmark action
                    if (std.mem.startsWith(u8, query, "load_world=")) {
                        ui_log.info("router_navigate", "Calling handleWorldLoading with query: '{s}'", .{query});
                        try self.handleWorldLoading(query);
                    } else if (std.mem.eql(u8, current_base_path, "/reactive-test")) {
                        ui_log.info("router_navigate", "Calling handleReactiveTestAction with query: '{s}'", .{query});
                        try self.handleReactiveTestAction(query);
                    } else if (std.mem.eql(u8, current_base_path, "/layout-benchmark")) {
                        ui_log.info("router_navigate", "Calling handleLayoutBenchmarkAction with query: '{s}'", .{query});
                        try self.handleLayoutBenchmarkAction(query);
                    } else {
                        ui_log.info("router_navigate", "Calling handleIDEAction with query: '{s}'", .{query});
                        try self.handleIDEAction(query);
                    }
                }
                return;
            }
        }

        // Different page, clean up current page and layouts
        self.cleanupCurrent();

        // Route to new page based on path
        if (std.mem.eql(u8, path, "/") or std.mem.startsWith(u8, path, "/?")) {
            // Handle world loading if query parameter present
            if (std.mem.indexOf(u8, path, "?")) |query_start| {
                const query = path[query_start + 1 ..];
                try self.handleWorldLoading(query);
            }

            // Load root layout
            const layout = try root_layout.create(self.allocator);
            try layout.init(self.allocator);
            try self.current_layouts.append(layout);

            // Load root page
            self.current_page = try root_page.create(self.allocator);
        } else if (std.mem.eql(u8, path, "/settings")) {
            // Load root layout
            const layout = try root_layout.create(self.allocator);
            try layout.init(self.allocator);
            try self.current_layouts.append(layout);

            // Load settings page
            self.current_page = try settings_page.create(self.allocator);
        } else if (std.mem.eql(u8, path, "/settings/video")) {
            // Load root layout
            const layout = try root_layout.create(self.allocator);
            try layout.init(self.allocator);
            try self.current_layouts.append(layout);

            // Could add settings layout here if we had one

            // Load video settings page
            self.current_page = try settings_video_page.create(self.allocator);
        } else if (std.mem.eql(u8, path, "/settings/audio")) {
            // Load root layout
            const layout = try root_layout.create(self.allocator);
            try layout.init(self.allocator);
            try self.current_layouts.append(layout);

            // Could add settings layout here if we had one

            // Load audio settings page
            self.current_page = try settings_audio_page.create(self.allocator);
        } else if (std.mem.eql(u8, path, "/settings/fonts")) {
            // Load root layout
            const layout = try root_layout.create(self.allocator);
            try layout.init(self.allocator);
            try self.current_layouts.append(layout);

            // Load fonts settings page
            self.current_page = try settings_fonts_page.create(self.allocator);
        } else if (std.mem.eql(u8, path, "/settings/fonts/save")) {
            // Load root layout
            const layout = try root_layout.create(self.allocator);
            try layout.init(self.allocator);
            try self.current_layouts.append(layout);

            // Load fonts save page
            self.current_page = try settings_fonts_save_page.create(self.allocator);
        } else if (std.mem.eql(u8, path, "/stats")) {
            // Load root layout
            const layout = try root_layout.create(self.allocator);
            try layout.init(self.allocator);
            try self.current_layouts.append(layout);

            // Load stats page
            self.current_page = try stats_page.create(self.allocator);
        } else if (std.mem.eql(u8, path, "/font-grid-test")) {
            // Load root layout
            const layout = try root_layout.create(self.allocator);
            try layout.init(self.allocator);
            try self.current_layouts.append(layout);

            // Load font grid test page
            self.current_page = try font_grid_test_page.create(self.allocator);
        } else if (std.mem.eql(u8, path, "/vector-test")) {
            // Load root layout
            const layout = try root_layout.create(self.allocator);
            try layout.init(self.allocator);
            try self.current_layouts.append(layout);

            // Load vector test page
            self.current_page = try vector_test_page.create(self.allocator);
        } else if (std.mem.startsWith(u8, path, "/ide")) {
            // Handle IDE page and IDE actions

            // Load root layout
            const layout = try root_layout.create(self.allocator);
            try layout.init(self.allocator);
            try self.current_layouts.append(layout);

            // Load IDE page
            self.current_page = try ide_page.create(self.allocator);

            // Handle IDE actions (query parameters)
            if (std.mem.indexOf(u8, path, "?")) |query_start| {
                const query = path[query_start + 1 ..];
                try self.handleIDEAction(query);
            }
        } else if (std.mem.eql(u8, path, "/reactive-test") or std.mem.startsWith(u8, path, "/reactive-test?")) {
            // Handle reactive test page
            // Load root layout
            const layout = try root_layout.create(self.allocator);
            try layout.init(self.allocator);
            try self.current_layouts.append(layout);

            // Load reactive test page
            self.current_page = try reactive_test_page.create(self.allocator);
        } else if (std.mem.eql(u8, path, "/layout-benchmark") or std.mem.startsWith(u8, path, "/layout-benchmark?")) {
            // Handle layout benchmark page
            // Load root layout
            const layout = try root_layout.create(self.allocator);
            try layout.init(self.allocator);
            try self.current_layouts.append(layout);

            // Load layout benchmark page
            self.current_page = try layout_benchmark_page.create(self.allocator);

            // Handle benchmark actions (query parameters)
            if (std.mem.indexOf(u8, path, "?")) |query_start| {
                const query = path[query_start + 1 ..];
                try self.handleLayoutBenchmarkAction(query);
            }
        } else {
            // Default to index for unknown paths
            // Load root layout
            const layout = try root_layout.create(self.allocator);
            try layout.init(self.allocator);
            try self.current_layouts.append(layout);

            // Load root page
            self.current_page = try root_page.create(self.allocator);
        }

        // Initialize the new page
        if (self.current_page) |p| {
            try p.init(self.allocator);
        }
    }

    pub fn getCurrentPage(self: *const Router) ?*page.Page {
        return self.current_page;
    }

    /// Extract base path before query parameters (e.g., "/ide?file=foo" -> "/ide")
    fn extractBasePath(self: *Router, path: []const u8) []const u8 {
        _ = self;
        if (std.mem.indexOf(u8, path, "?")) |query_start| {
            return path[0..query_start];
        }
        return path;
    }

    /// Handle IDE-specific actions from query parameters
    fn handleIDEAction(self: *Router, query: []const u8) !void {
        if (self.current_page) |current_page| {
            if (std.mem.eql(u8, current_page.path, "/ide")) {
                const ide_page_impl: *ide_page.IDEPage = @fieldParentPtr("base", current_page);

                // Parse query parameters
                if (std.mem.startsWith(u8, query, "toggle=")) {
                    const folder_name = query[7..]; // Skip "toggle="
                    try self.handleFolderToggle(ide_page_impl, folder_name);
                } else if (std.mem.startsWith(u8, query, "file=")) {
                    const file_name = query[5..]; // Skip "file="
                    try self.handleFileLoad(ide_page_impl, file_name);
                } else if (std.mem.eql(u8, query, "expand_all=true")) {
                    try self.handleExpandAll(ide_page_impl);
                } else if (std.mem.eql(u8, query, "collapse_all=true")) {
                    try self.handleCollapseAll(ide_page_impl);
                }
            }
        }
    }

    /// Handle reactive test actions from query parameters
    fn handleReactiveTestAction(self: *Router, query: []const u8) !void {
        const ui_log = loggers.getUILog();
        ui_log.info("reactive_test_action", "Handling reactive test action: '{s}'", .{query});

        if (self.current_page) |current_page| {
            if (std.mem.eql(u8, current_page.path, "/reactive-test")) {
                const reactive_page_impl: *reactive_test_page.ReactiveTestPage = @fieldParentPtr("base", current_page);

                if (std.mem.eql(u8, query, "current_increment")) {
                    ui_log.info("reactive_test_action", "Incrementing current system counter", .{});
                    // Increment current system counter
                    reactive_page_impl.current_count.set(reactive_page_impl.current_count.get() + 1);
                } else if (std.mem.eql(u8, query, "gannaway_increment")) {
                    ui_log.info("reactive_test_action", "Incrementing Gannaway system counter", .{});
                    // Increment Gannaway counter with explicit notification
                    reactive_page_impl.gannaway_count.update(reactive_page_impl.gannaway_count.get() + 1);
                } else {
                    ui_log.info("reactive_test_action", "Unknown reactive test action: '{s}'", .{query});
                }
            }
        }
    }

    /// Handle layout benchmark actions from query parameters
    fn handleLayoutBenchmarkAction(self: *Router, query: []const u8) !void {
        const ui_log = loggers.getUILog();
        ui_log.info("layout_benchmark_action", "Handling layout benchmark action: '{s}'", .{query});
        if (self.current_page) |current_page| {
            if (std.mem.eql(u8, current_page.path, "/layout-benchmark")) {
                const benchmark_page_impl: *layout_benchmark_page.LayoutBenchmarkPage = @fieldParentPtr("base", current_page);

                // Pass GPU device if available
                if (self.game_renderer) |renderer| {
                    benchmark_page_impl.setGPUDevice(renderer.gpu.device);
                }

                if (std.mem.startsWith(u8, query, "action=")) {
                    const action = query[7..]; // Skip "action="
                    try benchmark_page_impl.handleAction(action);
                    ui_log.info("layout_benchmark_action", "Executed benchmark action: '{s}'", .{action});
                } else {
                    ui_log.info("layout_benchmark_action", "Unknown layout benchmark query: '{s}'", .{query});
                }
            }
        }
    }

    /// Handle folder expand/collapse
    fn handleFolderToggle(self: *Router, ide_impl: *ide_page.IDEPage, folder_name: []const u8) !void {
        _ = self;
        const ui_log = loggers.getUILog();
        ui_log.info("ide_action", "Toggle folder: '{s}'", .{folder_name});

        // Find and toggle the folder in the file tree
        const tree_items = ide_impl.file_tree_component.getVisibleItems();
        for (tree_items) |item| {
            if (std.mem.eql(u8, item.entry.metadata.name, folder_name)) {
                if (item.entry.metadata.is_directory) {
                    // Toggle expansion
                    item.entry.expanded = !item.entry.expanded;

                    // Rebuild the tree
                    if (ide_impl.root_directory) |root| {
                        try ide_impl.file_tree_component.renderer.buildRenderList(root, Vec2{ .x = 0.0, .y = 0.0 });
                    }

                    ui_log.info("ide_action", "Toggled folder '{s}' to {}", .{ folder_name, item.entry.expanded });
                    break;
                }
            }
        }
    }

    /// Handle file loading
    fn handleFileLoad(self: *Router, ide_impl: *ide_page.IDEPage, file_name: []const u8) !void {
        _ = self;
        const ui_log = loggers.getUILog();
        ui_log.info("ide_action", "Load file: '{s}'", .{file_name});

        ui_log.info("ide_action", "File tree has {} visible items", .{ide_impl.file_tree_component.getVisibleItems().len});

        // Find and select the file in the file tree
        const tree_items = ide_impl.file_tree_component.getVisibleItems();
        var found = false;
        for (tree_items) |item| {
            ui_log.info("ide_action", "Checking tree item: '{s}' (is_dir: {}) vs looking for: '{s}'", .{ item.entry.metadata.name, item.entry.metadata.is_directory, file_name });
            if (std.mem.eql(u8, item.entry.metadata.name, file_name)) {
                ui_log.info("ide_action", "Found matching item: '{s}', full_path: '{s}'", .{ item.entry.metadata.name, item.entry.metadata.full_path });
                if (!item.entry.metadata.is_directory) {
                    // Select the file
                    ide_impl.file_tree_component.state.selectEntry(item.entry);

                    ui_log.info("ide_action", "About to load file content for: '{s}'", .{item.entry.metadata.full_path});
                    // Load the file content
                    try ide_impl.loadFileContent(item.entry);

                    ui_log.info("ide_action", "Successfully loaded file '{s}'", .{file_name});
                    found = true;
                    break;
                }
            }
        }
        if (!found) {
            ui_log.warn("ide_action", "File '{s}' not found in tree with {} items", .{ file_name, tree_items.len });
        }
    }

    /// Handle expand all action
    fn handleExpandAll(self: *Router, ide_impl: *ide_page.IDEPage) !void {
        const ui_log = loggers.getUILog();
        ui_log.info("ide_action", "Expand all folders", .{});

        if (ide_impl.root_directory) |root| {
            self.expandAllRecursive(root);
            // Rebuild the tree
            try ide_impl.file_tree_component.renderer.buildRenderList(root, Vec2{ .x = 0.0, .y = 0.0 });
        }
    }

    /// Handle collapse all action
    fn handleCollapseAll(self: *Router, ide_impl: *ide_page.IDEPage) !void {
        const ui_log = loggers.getUILog();
        ui_log.info("ide_action", "Collapse all folders", .{});

        if (ide_impl.root_directory) |root| {
            self.collapseAllRecursive(root);
            // Rebuild the tree
            try ide_impl.file_tree_component.renderer.buildRenderList(root, Vec2{ .x = 0.0, .y = 0.0 });
        }
    }

    /// Recursively expand all directories
    fn expandAllRecursive(self: *Router, entry: *DirectoryEntry) void {
        if (entry.metadata.is_directory) {
            entry.expanded = true;
            for (entry.children.items) |child| {
                self.expandAllRecursive(child);
            }
        }
    }

    /// Recursively collapse all directories
    fn collapseAllRecursive(self: *Router, entry: *DirectoryEntry) void {
        if (entry.metadata.is_directory) {
            entry.expanded = false;
            for (entry.children.items) |child| {
                self.collapseAllRecursive(child);
            }
        }
    }

    /// Handle world loading from query parameters
    fn handleWorldLoading(self: *Router, query: []const u8) !void {
        const ui_log = loggers.getUILog();
        ui_log.info("world_loading", "Processing world loading query: '{s}'", .{query});

        // Parse load_world parameter
        if (std.mem.startsWith(u8, query, "load_world=")) {
            const world_path = query[11..]; // Skip "load_world="
            ui_log.info("world_loading", "Loading world: '{s}'", .{world_path});

            if (global_game_state) |game_state| {
                // Reload the game with the new world
                game_state.reloadWithWorld(world_path) catch |err| {
                    ui_log.err("world_loading", "World reload failed: {}", .{err});
                    return;
                };
                ui_log.info("world_loading", "World successfully reloaded: '{s}'", .{world_path});
            } else {
                ui_log.warn("world_loading", "No game state reference available for world reloading", .{});
            }
        }
        _ = self; // unused for now
    }

    pub fn renderWithLayouts(self: *const Router, links: *std.ArrayList(page.Link), arena: std.mem.Allocator) !void {
        if (self.current_page == null) return;

        // For now, just render the page directly without layout composition
        // A full implementation would compose layouts
        try self.current_page.?.render(links, arena);
    }
};
