const std = @import("std");
const page = @import("../../../hud/page.zig");
const fonts = @import("../../../lib/fonts.zig");

const FontsSettingsPage = struct {
    base: page.Page,
    font_manager: ?*fonts.FontManager = null,
    current_settings: fonts.FontSettings = .{},
    selected_category: fonts.FontCategory = .mono,
    
    fn init(self: *page.Page, allocator: std.mem.Allocator) !void {
        _ = allocator;
        const fonts_page: *FontsSettingsPage = @fieldParentPtr("base", self);
        
        // TODO: Get font manager from game state
        fonts_page.current_settings = fonts.FontSettings{};
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
        const fonts_page: *const FontsSettingsPage = @fieldParentPtr("base", self);
        
        const screen_width = 1920.0;
        const screen_height = 1080.0;
        
        const center_x = screen_width / 2.0;
        const start_y = screen_height * 0.2;
        const link_height = 40.0;
        const link_width = 400.0;
        const link_spacing = 15.0;
        const column_spacing = 450.0;
        
        // Title area
        var y_pos: f32 = start_y;
        
        // Font Categories (left column)
        const left_x = center_x - column_spacing;
        
        try links.append(page.createLink(
            "Monospace Fonts",
            "/settings/fonts/mono",
            left_x,
            y_pos,
            link_width,
            link_height
        ));
        y_pos += link_height + link_spacing;
        
        try links.append(page.createLink(
            "Sans-serif Fonts",
            "/settings/fonts/sans",
            left_x,
            y_pos,
            link_width,
            link_height
        ));
        y_pos += link_height + link_spacing;
        
        try links.append(page.createLink(
            "Display Serif Fonts",
            "/settings/fonts/serif-display",
            left_x,
            y_pos,
            link_width,
            link_height
        ));
        y_pos += link_height + link_spacing;
        
        try links.append(page.createLink(
            "Text Serif Fonts",
            "/settings/fonts/serif-text",
            left_x,
            y_pos,
            link_width,
            link_height
        ));
        y_pos += link_height + link_spacing;
        
        // Current Settings (right column)
        const right_x = center_x + 50.0;
        var right_y: f32 = start_y;
        
        // Display current font selections
        var settings_buf: [256]u8 = undefined;
        
        const mono_text = try std.fmt.bufPrint(&settings_buf, "Mono: {s}", .{fonts_page.current_settings.mono_family});
        try links.append(page.createLink(
            mono_text,
            "",  // No navigation, just display
            right_x,
            right_y,
            link_width,
            link_height
        ));
        right_y += link_height + link_spacing;
        
        const sans_text = try std.fmt.bufPrint(&settings_buf, "Sans: {s}", .{fonts_page.current_settings.sans_family});
        try links.append(page.createLink(
            sans_text,
            "",
            right_x,
            right_y,
            link_width,
            link_height
        ));
        right_y += link_height + link_spacing;
        
        const serif_display_text = try std.fmt.bufPrint(&settings_buf, "Display: {s}", .{fonts_page.current_settings.serif_display_family});
        try links.append(page.createLink(
            serif_display_text,
            "",
            right_x,
            right_y,
            link_width,
            link_height
        ));
        right_y += link_height + link_spacing;
        
        const serif_text_text = try std.fmt.bufPrint(&settings_buf, "Text: {s}", .{fonts_page.current_settings.serif_text_family});
        try links.append(page.createLink(
            serif_text_text,
            "",
            right_x,
            right_y,
            link_width,
            link_height
        ));
        
        // Size settings (bottom section)
        y_pos += link_height + link_spacing * 2;
        
        try links.append(page.createLink(
            "Font Sizes",
            "/settings/fonts/sizes",
            center_x - link_width / 2.0,
            y_pos,
            link_width,
            link_height
        ));
        
        // Navigation buttons
        y_pos += link_height + link_spacing * 3;
        
        try links.append(page.createLink(
            "Back to Settings",
            "/settings",
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
        const fonts_page: *FontsSettingsPage = @fieldParentPtr("base", self);
        allocator.destroy(fonts_page);
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const fonts_page = try allocator.create(FontsSettingsPage);
    fonts_page.* = .{
        .base = .{
            .vtable = .{
                .init = FontsSettingsPage.init,
                .deinit = FontsSettingsPage.deinit,
                .update = FontsSettingsPage.update,
                .render = FontsSettingsPage.render,
                .destroy = FontsSettingsPage.destroy,
            },
            .path = "/settings/fonts",
            .title = "Font Settings",
        },
        .font_manager = null,
        .current_settings = .{},
        .selected_category = .mono,
    };
    return &fonts_page.base;
}