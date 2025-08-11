const std = @import("std");
const page = @import("page.zig");

const index_page = @import("../routes/index.zig");
const settings_page = @import("../routes/settings.zig");
const settings_video_page = @import("../routes/settings/video.zig");
const settings_audio_page = @import("../routes/settings/audio.zig");
const stats_page = @import("../routes/stats.zig");

pub const Router = struct {
    allocator: std.mem.Allocator,
    current_page: ?*page.Page,

    pub fn init(allocator: std.mem.Allocator) Router {
        return .{
            .allocator = allocator,
            .current_page = null,
        };
    }

    pub fn deinit(self: *Router) void {
        if (self.current_page) |p| {
            p.deinit(self.allocator);
            self.allocator.destroy(p);
            self.current_page = null;
        }
    }

    pub fn navigate(self: *Router, path: []const u8) !void {
        // Clean up current page
        if (self.current_page) |p| {
            p.deinit(self.allocator);
            self.allocator.destroy(p);
            self.current_page = null;
        }

        // Route to new page
        if (std.mem.eql(u8, path, "/")) {
            self.current_page = try index_page.create(self.allocator);
        } else if (std.mem.eql(u8, path, "/settings")) {
            self.current_page = try settings_page.create(self.allocator);
        } else if (std.mem.eql(u8, path, "/settings/video")) {
            self.current_page = try settings_video_page.create(self.allocator);
        } else if (std.mem.eql(u8, path, "/settings/audio")) {
            self.current_page = try settings_audio_page.create(self.allocator);
        } else if (std.mem.eql(u8, path, "/stats")) {
            self.current_page = try stats_page.create(self.allocator);
        } else {
            // Default to index for unknown paths
            self.current_page = try index_page.create(self.allocator);
        }

        // Initialize the new page
        if (self.current_page) |p| {
            try p.init(self.allocator);
        }
    }

    pub fn getCurrentPage(self: *const Router) ?*page.Page {
        return self.current_page;
    }
};