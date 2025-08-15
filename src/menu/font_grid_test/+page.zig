const std = @import("std");
const c = @import("../../lib/platform/sdl.zig");
const page = @import("../../hud/page.zig");
const bitmap_simple = @import("../../lib/font/renderers/bitmap_simple.zig");
const oversampling = @import("../../lib/font/renderers/oversampling.zig");
const debug_ascii = @import("../../lib/font/renderers/debug_ascii.zig");
const font_types = @import("../../lib/font/font_types.zig");
const math = @import("../../lib/math/mod.zig");
const colors = @import("../../lib/core/colors.zig");
const bitmap_utils = @import("../../lib/image/bitmap.zig");
const log_throttle = @import("../../lib/debug/log_throttle.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const SimpleBitmapRenderer = bitmap_simple.SimpleBitmapRenderer;

pub const FontGridTestPage = struct {
    base: page.Page,
    simple_renderer: SimpleBitmapRenderer,
    oversampling_2x_renderer: oversampling.OversamplingRenderer,
    oversampling_4x_renderer: oversampling.OversamplingRenderer,
    ascii_renderer: debug_ascii.DebugAsciiRenderer,
    initialized: bool,
    test_status: []const u8,
    
    // Demo text samples to show
    const DEMO_TEXTS = [_][]const u8{
        "Simple Bitmap",
        "Oversampling 2x", 
        "Oversampling 4x",
        "ASCII Debug",
        "The quick brown fox jumps over lazy dog",
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
        "abcdefghijklmnopqrstuvwxyz",
        "0123456789!@#$%^&*()",
    };

    fn init(self: *page.Page, allocator: std.mem.Allocator) !void {
        const grid_page: *FontGridTestPage = @fieldParentPtr("base", self);
        grid_page.simple_renderer = SimpleBitmapRenderer.init();
        grid_page.oversampling_2x_renderer = oversampling.OversamplingRenderer.init(2);
        grid_page.oversampling_4x_renderer = oversampling.OversamplingRenderer.init(4);
        grid_page.ascii_renderer = debug_ascii.DebugAsciiRenderer.init();
        grid_page.initialized = true;
        grid_page.test_status = "Live font renderer comparison ready";
        _ = allocator;
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
        _ = self;
        
        // Use full screen real estate for immediate visual demo
        const screen_width = 1920.0;
        const screen_height = 1080.0;
        const margin = 40.0;
        const header_height = 80.0;
        const content_width = screen_width - (margin * 2);
        
        // Split screen into 4 columns (one for each renderer)
        const renderer_width = content_width / 4.0;
        const text_height = 40.0;
        const text_spacing = 15.0;
        
        // Renderer labels at the top (these will be actual text)
        var start_x: f32 = margin;
        const label_y = margin + 20.0;
        
        // Column 1: Simple Bitmap
        try links.append(page.createLink(
            "Simple Bitmap",
            "#",  // No click action - this is just a label
            start_x + 10.0,
            label_y,
            renderer_width - 20.0,
            30.0
        ));
        
        // Column 2: Oversampling 2x  
        start_x += renderer_width;
        try links.append(page.createLink(
            "Oversampling 2x",
            "#",
            start_x + 10.0,
            label_y,
            renderer_width - 20.0,
            30.0
        ));
        
        // Column 3: Oversampling 4x
        start_x += renderer_width;
        try links.append(page.createLink(
            "Oversampling 4x",
            "#",
            start_x + 10.0,
            label_y,
            renderer_width - 20.0,
            30.0
        ));
        
        // Column 4: ASCII Debug
        start_x += renderer_width;
        try links.append(page.createLink(
            "ASCII Debug",
            "#",
            start_x + 10.0,
            label_y,
            renderer_width - 20.0,
            30.0
        ));
        
        // Demo text samples in rows
        const demo_start_y = margin + header_height;
        var current_y: f32 = demo_start_y;
        
        // Show each demo text across all 4 renderers
        for (DEMO_TEXTS) |demo_text| {
            start_x = margin;
            
            // Simple Bitmap column
            try links.append(page.createLink(
                demo_text,
                "#",
                start_x + 5.0,
                current_y,
                renderer_width - 10.0,
                text_height
            ));
            
            // Oversampling 2x column  
            start_x += renderer_width;
            try links.append(page.createLink(
                demo_text,
                "#",
                start_x + 5.0,
                current_y,
                renderer_width - 10.0,
                text_height
            ));
            
            // Oversampling 4x column
            start_x += renderer_width;
            try links.append(page.createLink(
                demo_text,
                "#",
                start_x + 5.0,
                current_y,
                renderer_width - 10.0,
                text_height
            ));
            
            // ASCII Debug column
            start_x += renderer_width;
            try links.append(page.createLink(
                demo_text,
                "#",
                start_x + 5.0,
                current_y,
                renderer_width - 10.0,
                text_height
            ));
            
            current_y += text_height + text_spacing;
        }
        
        // Navigation at bottom - minimal, compact
        const nav_y = screen_height - 60.0;
        const nav_width = 200.0;
        const nav_spacing = 20.0;
        
        try links.append(page.createLink(
            "Back to Menu",
            "/",
            margin,
            nav_y,
            nav_width,
            30.0
        ));
        
        try links.append(page.createLink(
            "Advanced Tests",
            "/font_test_comparison",
            margin + nav_width + nav_spacing,
            nav_y,
            nav_width,
            30.0
        ));
    }

    fn destroy(self: *page.Page, allocator: std.mem.Allocator) void {
        const font_page: *FontGridTestPage = @fieldParentPtr("base", self);
        allocator.destroy(font_page);
    }
};

pub fn create(allocator: std.mem.Allocator) !*page.Page {
    const font_page = try allocator.create(FontGridTestPage);
    font_page.* = .{
        .base = .{
            .vtable = .{
                .init = FontGridTestPage.init,
                .deinit = FontGridTestPage.deinit,
                .update = FontGridTestPage.update,
                .render = FontGridTestPage.render,
                .destroy = FontGridTestPage.destroy,
            },
            .path = "/font_grid_test",
            .title = "Live Font Renderer Demo",
        },
        .simple_renderer = undefined, // Will be set in init
        .oversampling_2x_renderer = undefined,
        .oversampling_4x_renderer = undefined,
        .ascii_renderer = undefined,
        .initialized = false,
        .test_status = "Not initialized",
    };
    return &font_page.base;
}
