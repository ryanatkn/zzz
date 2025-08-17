const std = @import("std");
const page = @import("../../../hud/page.zig");
const font_config = @import("../../../lib/font/config.zig");

const FontsInfoPage = struct {
    base: page.Page,
    current_settings: font_config.FontSettings = .{},

    fn init(self: *page.Page, allocator: std.mem.Allocator) !void {
        _ = allocator;
        const fonts_page: *FontsInfoPage = @fieldParentPtr("base", self);

        // Initialize with default settings
        fonts_page.current_settings = font_config.FontSettings{};
    }

    fn deinit(self: *page.Page, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }

    fn update(self: *page.Page, dt: f32) void {
        _ = self;
        _ = dt;
    }

    fn render(self: *const page.Page, links: *std.ArrayList(page.Link), arena: std.mem.Allocator) !void {
        _ = arena;
        const constants = @import("../../../hud/constants.zig");
        const screen_width = constants.SCREEN.BASE_WIDTH;
        const screen_height = constants.SCREEN.BASE_HEIGHT;
        const fonts_page: *const FontsInfoPage = @fieldParentPtr("base", self);

        const center_x = screen_width / 2.0;
        const start_y = screen_height * 0.15;
        const link_height = 35.0;
        const link_width = 500.0;
        const link_spacing = 12.0;
        const section_spacing = 30.0;

        var y_pos: f32 = start_y;

        // Title
        try links.append(page.createLink("DM Font Family Information", "", center_x - link_width / 2.0, y_pos, link_width, link_height * 1.2));
        y_pos += link_height * 1.2 + section_spacing;

        // Font Family Overview
        try links.append(page.createLink("Available Font Families:", "", center_x - link_width / 2.0, y_pos, link_width, link_height));
        y_pos += link_height + link_spacing;

        // DM Mono info
        try links.append(page.createLink("• DM Mono - Monospace font for code", "", center_x - link_width / 2.0 + 20, y_pos, link_width - 20, link_height));
        y_pos += link_height + link_spacing;

        try links.append(page.createLink("  Weights: Light (300), Regular (400), Medium (500)", "", center_x - link_width / 2.0 + 40, y_pos, link_width - 40, link_height));
        y_pos += link_height + link_spacing;

        try links.append(page.createLink("  Styles: Regular, Italic", "", center_x - link_width / 2.0 + 40, y_pos, link_width - 40, link_height));
        y_pos += link_height + link_spacing * 2;

        // DM Sans info
        try links.append(page.createLink("• DM Sans - Sans-serif for UI elements", "", center_x - link_width / 2.0 + 20, y_pos, link_width - 20, link_height));
        y_pos += link_height + link_spacing;

        try links.append(page.createLink("  Weights: 100-900 (Thin to Black)", "", center_x - link_width / 2.0 + 40, y_pos, link_width - 40, link_height));
        y_pos += link_height + link_spacing;

        try links.append(page.createLink("  Optical sizes: 18pt, 24pt, 36pt variants", "", center_x - link_width / 2.0 + 40, y_pos, link_width - 40, link_height));
        y_pos += link_height + link_spacing * 2;

        // DM Serif Display info
        try links.append(page.createLink("• DM Serif Display - Serif for headings", "", center_x - link_width / 2.0 + 20, y_pos, link_width - 20, link_height));
        y_pos += link_height + link_spacing;

        try links.append(page.createLink("  Weight: Regular (400)", "", center_x - link_width / 2.0 + 40, y_pos, link_width - 40, link_height));
        y_pos += link_height + link_spacing * 2;

        // DM Serif Text info
        try links.append(page.createLink("• DM Serif Text - Serif for body text", "", center_x - link_width / 2.0 + 20, y_pos, link_width - 20, link_height));
        y_pos += link_height + link_spacing;

        try links.append(page.createLink("  Weight: Regular (400)", "", center_x - link_width / 2.0 + 40, y_pos, link_width - 40, link_height));
        y_pos += link_height + section_spacing;

        // Current Settings section
        y_pos += link_spacing;
        try links.append(page.createLink("Current Font Settings:", "", center_x - link_width / 2.0, y_pos, link_width, link_height));
        y_pos += link_height + link_spacing;

        // Display current settings
        var settings_buf: [256]u8 = undefined;

        const mono_text = try std.fmt.bufPrint(&settings_buf, "Mono: {s} ({d})", .{ fonts_page.current_settings.mono_family, fonts_page.current_settings.mono_weight });
        try links.append(page.createLink(mono_text, "", center_x - link_width / 2.0 + 20, y_pos, link_width - 20, link_height));
        y_pos += link_height + link_spacing;

        const sans_text = try std.fmt.bufPrint(&settings_buf, "Sans: {s} ({d})", .{ fonts_page.current_settings.sans_family, fonts_page.current_settings.sans_weight });
        try links.append(page.createLink(sans_text, "", center_x - link_width / 2.0 + 20, y_pos, link_width - 20, link_height));
        y_pos += link_height + link_spacing;

        const serif_display_text = try std.fmt.bufPrint(&settings_buf, "Display: {s} ({d})", .{ fonts_page.current_settings.serif_display_family, fonts_page.current_settings.serif_display_weight });
        try links.append(page.createLink(serif_display_text, "", center_x - link_width / 2.0 + 20, y_pos, link_width - 20, link_height));
        y_pos += link_height + link_spacing;

        const serif_text_text = try std.fmt.bufPrint(&settings_buf, "Text: {s} ({d})", .{ fonts_page.current_settings.serif_text_family, fonts_page.current_settings.serif_text_weight });
        try links.append(page.createLink(serif_text_text, "", center_x - link_width / 2.0 + 20, y_pos, link_width - 20, link_height));
        y_pos += link_height + section_spacing;

        // Action buttons
        const button_width = 200.0;
        const button_spacing = 20.0;
        const buttons_x = center_x - (button_width * 2 + button_spacing) / 2.0;

        try links.append(page.createLink("Save Settings", "/settings/fonts/save", buttons_x, y_pos, button_width, link_height * 1.2));

        try links.append(page.createLink("Export Config", "/settings/fonts/export", buttons_x + button_width + button_spacing, y_pos, button_width, link_height * 1.2));

        // Navigation buttons
        y_pos += link_height * 1.2 + section_spacing;

        try links.append(page.createLink("Back to Settings", "/settings", center_x - link_width / 2.0, y_pos, link_width, link_height));

        y_pos += link_height + link_spacing;

        try links.append(page.createLink("Back to Menu", "/", center_x - link_width / 2.0, y_pos, link_width, link_height));
    }

    fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
        const fonts_page: *FontsInfoPage = @fieldParentPtr("base", self);
        allocator.destroy(fonts_page);
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const fonts_page = try allocator.create(FontsInfoPage);
    fonts_page.* = .{
        .base = .{
            .vtable = .{
                .init = FontsInfoPage.init,
                .deinit = FontsInfoPage.deinit,
                .update = FontsInfoPage.update,
                .render = FontsInfoPage.render,
                .destroy = FontsInfoPage.destroy,
            },
            .path = "/settings/fonts",
            .title = "Font Information",
        },
        .current_settings = .{},
    };
    return &fonts_page.base;
}
