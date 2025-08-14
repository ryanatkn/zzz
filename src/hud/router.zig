const std = @import("std");
const page = @import("page.zig");

const root_page = @import("../menu/+page.zig");
const root_layout = @import("../menu/+layout.zig");
const settings_page = @import("../menu/settings/+page.zig");
const settings_video_page = @import("../menu/settings/video/+page.zig");
const settings_audio_page = @import("../menu/settings/audio/+page.zig");
const settings_fonts_page = @import("../menu/settings/fonts/+page.zig");
const settings_fonts_save_page = @import("../menu/settings/fonts/save/+page.zig");
const stats_page = @import("../menu/stats/+page.zig");
const font_test_page = @import("../menu/font_test/+page.zig");

pub const Router = struct {
    allocator: std.mem.Allocator,
    current_page: ?*page.Page,
    current_layouts: std.ArrayList(*page.Layout),

    pub fn init(allocator: std.mem.Allocator) Router {
        return .{
            .allocator = allocator,
            .current_page = null,
            .current_layouts = std.ArrayList(*page.Layout).init(allocator),
        };
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
        // Clean up current page and layouts
        self.cleanupCurrent();

        // Route to new page based on path
        if (std.mem.eql(u8, path, "/")) {
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
        } else if (std.mem.eql(u8, path, "/font-test")) {
            // Load root layout
            const layout = try root_layout.create(self.allocator);
            try layout.init(self.allocator);
            try self.current_layouts.append(layout);
            
            // Load font test page
            self.current_page = try font_test_page.create(self.allocator);
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

    pub fn renderWithLayouts(self: *const Router, links: *std.ArrayList(page.Link)) !void {
        if (self.current_page == null) return;
        
        // For now, just render the page directly without layout composition
        // A full implementation would compose layouts
        try self.current_page.?.render(links);
    }
};