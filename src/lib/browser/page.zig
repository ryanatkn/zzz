const std = @import("std");
const math = @import("../math/mod.zig");

pub const Link = struct {
    text: []const u8,
    path: []const u8,
    bounds: math.Rectangle,
};

pub const RenderSlot = struct {
    render_fn: *const fn (links: *std.ArrayList(Link)) anyerror!void,

    pub fn render(self: *const RenderSlot, links: *std.ArrayList(Link)) !void {
        try self.render_fn(links);
    }
};

pub const Layout = struct {
    pub const VTable = struct {
        init: *const fn (self: *Layout, allocator: std.mem.Allocator) anyerror!void,
        deinit: *const fn (self: *Layout, allocator: std.mem.Allocator) void,
        render: *const fn (self: *const Layout, links: *std.ArrayList(Link), slot: *const RenderSlot) anyerror!void,
        destroy: *const fn (self: *Layout, allocator: std.mem.Allocator) void,
    };

    vtable: VTable,
    path: []const u8,

    pub fn init(self: *Layout, allocator: std.mem.Allocator) !void {
        try self.vtable.init(self, allocator);
    }

    pub fn deinit(self: *Layout, allocator: std.mem.Allocator) void {
        self.vtable.deinit(self, allocator);
    }

    pub fn render(self: *const Layout, links: *std.ArrayList(Link), slot: *const RenderSlot) !void {
        try self.vtable.render(self, links, slot);
    }

    pub fn destroy(self: *Layout, allocator: std.mem.Allocator) void {
        self.vtable.destroy(self, allocator);
    }
};

pub const Page = struct {
    pub const VTable = struct {
        init: *const fn (self: *Page, allocator: std.mem.Allocator) anyerror!void,
        deinit: *const fn (self: *Page, allocator: std.mem.Allocator) void,
        update: *const fn (self: *Page, dt: f32) void,
        render: *const fn (self: *const Page, links: *std.ArrayList(Link), arena: std.mem.Allocator) anyerror!void,
        destroy: *const fn (self: *Page, allocator: std.mem.Allocator) void,
    };

    vtable: VTable,
    path: []const u8,
    title: []const u8,

    pub fn init(self: *Page, allocator: std.mem.Allocator) !void {
        try self.vtable.init(self, allocator);
    }

    pub fn deinit(self: *Page, allocator: std.mem.Allocator) void {
        self.vtable.deinit(self, allocator);
    }

    pub fn update(self: *Page, dt: f32) void {
        self.vtable.update(self, dt);
    }

    pub fn render(self: *const Page, links: *std.ArrayList(Link), arena: std.mem.Allocator) !void {
        try self.vtable.render(self, links, arena);
    }

    pub fn destroy(self: *Page, allocator: std.mem.Allocator) void {
        self.vtable.destroy(self, allocator);
    }
};

pub fn createLink(text: []const u8, path: []const u8, x: f32, y: f32, width: f32, height: f32) Link {
    return .{
        .text = text,
        .path = path,
        .bounds = .{
            .position = .{ .x = x, .y = y },
            .size = .{ .x = width, .y = height },
        },
    };
}

/// Create a link using normalized coordinates (0-1) that scale with screen size
/// This is better than hardcoded coordinates for responsive design
pub fn createResponsiveLink(text: []const u8, path: []const u8, norm_x: f32, norm_y: f32, norm_width: f32, norm_height: f32, screen_width: f32, screen_height: f32) Link {
    return createLink(
        text,
        path,
        norm_x * screen_width,
        norm_y * screen_height,
        norm_width * screen_width,
        norm_height * screen_height,
    );
}

/// Create a link using base 1920x1080 coordinates converted to current screen size
/// This allows using existing coordinate values while being responsive
pub fn createLinkFrom1080p(text: []const u8, path: []const u8, x_1080p: f32, y_1080p: f32, width_1080p: f32, height_1080p: f32, screen_width: f32, screen_height: f32) Link {
    const constants = @import("../core/constants.zig");
    const scale_x = screen_width / constants.SCREEN.BASE_WIDTH;
    const scale_y = screen_height / constants.SCREEN.BASE_HEIGHT;
    return createLink(
        text,
        path,
        x_1080p * scale_x,
        y_1080p * scale_y,
        width_1080p * scale_x,
        height_1080p * scale_y,
    );
}
