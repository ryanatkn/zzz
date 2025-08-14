const std = @import("std");
const types = @import("../lib/types.zig");

pub const Link = struct {
    text: []const u8,
    path: []const u8,
    bounds: types.Rectangle,
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
        render: *const fn (self: *const Page, links: *std.ArrayList(Link)) anyerror!void,
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

    pub fn render(self: *const Page, links: *std.ArrayList(Link)) !void {
        try self.vtable.render(self, links);
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
