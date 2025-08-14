const std = @import("std");
const page = @import("../../../../hud/page.zig");
const font_config = @import("../../../../lib/font_config.zig");
const save_mod = @import("../save.zig");

const SavePage = struct {
    base: page.Page,
    saved: bool = false,
    error_msg: ?[]const u8 = null,
    
    fn init(self: *page.Page, allocator: std.mem.Allocator) !void {
        const save_page: *SavePage = @fieldParentPtr("base", self);
        
        // Attempt to save settings
        const settings = font_config.FontSettings{};
        save_mod.saveSettings(allocator, settings) catch |err| {
            save_page.error_msg = switch (err) {
                error.AccessDenied => "Access denied to save file",
                error.OutOfMemory => "Out of memory",
                else => "Failed to save settings",
            };
            return;
        };
        
        save_page.saved = true;
    }
    
    fn deinit(self: *page.Page, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }
    
    fn update(self: *page.Page, dt: f32) void {
        _ = self;
        _ = dt;
    }
    
    fn render(self: *const page.Page, links: *std.ArrayList(page.Link)) !void {
        const save_page: *const SavePage = @fieldParentPtr("base", self);
        
        const screen_width = 1920.0;
        const screen_height = 1080.0;
        const center_x = screen_width / 2.0;
        const start_y = screen_height * 0.4;
        const link_height = 40.0;
        const link_width = 400.0;
        const link_spacing = 20.0;
        
        var y_pos: f32 = start_y;
        
        if (save_page.saved) {
            try links.append(page.createLink(
                "✓ Settings saved successfully!",
                "",
                center_x - link_width / 2.0,
                y_pos,
                link_width,
                link_height
            ));
            y_pos += link_height + link_spacing;
            
            try links.append(page.createLink(
                "Saved to: font_settings.json",
                "",
                center_x - link_width / 2.0,
                y_pos,
                link_width,
                link_height
            ));
        } else if (save_page.error_msg) |msg| {
            try links.append(page.createLink(
                "✗ Failed to save settings",
                "",
                center_x - link_width / 2.0,
                y_pos,
                link_width,
                link_height
            ));
            y_pos += link_height + link_spacing;
            
            try links.append(page.createLink(
                msg,
                "",
                center_x - link_width / 2.0,
                y_pos,
                link_width,
                link_height
            ));
        }
        
        y_pos += link_height + link_spacing * 2;
        
        try links.append(page.createLink(
            "Back to Font Settings",
            "/settings/fonts",
            center_x - link_width / 2.0,
            y_pos,
            link_width,
            link_height
        ));
        
        y_pos += link_height + link_spacing;
        
        try links.append(page.createLink(
            "Back to Menu",
            "/",
            center_x - link_width / 2.0,
            y_pos,
            link_width,
            link_height
        ));
    }
    
    fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
        const save_page: *SavePage = @fieldParentPtr("base", self);
        allocator.destroy(save_page);
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const save_page = try allocator.create(SavePage);
    save_page.* = .{
        .base = .{
            .vtable = .{
                .init = SavePage.init,
                .deinit = SavePage.deinit,
                .update = SavePage.update,
                .render = SavePage.render,
                .destroy = SavePage.destroy,
            },
            .path = "/settings/fonts/save",
            .title = "Save Font Settings",
        },
        .saved = false,
        .error_msg = null,
    };
    return &save_page.base;
}