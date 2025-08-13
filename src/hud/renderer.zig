const std = @import("std");
const c = @import("../lib/c.zig");
const types = @import("../lib/types.zig");
const lib_renderer = @import("../lib/renderer.zig");
const game_renderer = @import("../hex/game_renderer.zig");
const page = @import("page.zig");
const fonts = @import("../lib/fonts.zig");
const text_renderer = @import("../lib/text_renderer.zig");
const menu_text = @import("../lib/ui/menu_text.zig");
const drawing = @import("../lib/drawing.zig");

const Color = types.Color;

pub const BrowserRenderer = struct {
    base_renderer: *game_renderer.GameRenderer,
    
    pub fn init(base_renderer: *game_renderer.GameRenderer) BrowserRenderer {
        return .{
            .base_renderer = base_renderer,
        };
    }
    
    pub fn initFonts(self: *BrowserRenderer, allocator: std.mem.Allocator) !void {
        _ = self;
        _ = allocator;
        const log = std.log.scoped(.browser_renderer);
        log.info("HUD using main game's FontManager and TextRenderer - no separate initialization needed", .{});
    }
    
    pub fn deinitFonts(self: *BrowserRenderer, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
        // No separate font manager or text renderer to clean up - using main game's
    }

    pub fn renderOverlay(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass) !void {
        
        // Render semi-transparent background using rectangles
        // Draw a dark overlay by rendering multiple dark rectangles
        const screen_width = 1920.0;
        const screen_height = 1080.0;
        const overlay_color = Color{ .r = 10, .g = 10, .b = 15, .a = 120 };
        
        // Use drawBlendedRect for transparent overlay
        self.base_renderer.gpu.drawBlendedRect(
            cmd_buffer, 
            render_pass,
            .{ .x = 0, .y = 0 },
            .{ .x = screen_width, .y = screen_height },
            overlay_color
        );
    }

    pub fn renderPage(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, current_page: *const page.Page, links: *std.ArrayList(page.Link)) !void {
        _ = self;
        _ = cmd_buffer;
        _ = render_pass;
        
        // Let the page render its content
        // TODO: Add page background rendering when rectangle support is added
        try current_page.render(links);
    }

    pub fn renderLinks(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, links: []const page.Link, hovered_link: ?usize) !void {
        for (links, 0..) |link, i| {
            const is_hovered = if (hovered_link) |h| h == i else false;
            
            // Render link background as rectangle
            const link_color = if (is_hovered)
                Color{ .r = 60, .g = 80, .b = 120, .a = 255 }
            else
                Color{ .r = 40, .g = 50, .b = 80, .a = 255 };
            
            self.base_renderer.gpu.drawRect(
                cmd_buffer,
                render_pass,
                link.bounds.position,
                link.bounds.size,
                link_color
            );
            
            // Render the link text using shared menu text utility with main game renderers
            if (self.base_renderer.font_manager) |fm| {
                // Debug logging disabled to reduce spam
                
                var menu_text_renderer = menu_text.MenuTextRenderer.init(&self.base_renderer.gpu.text_renderer, fm);
                const link_rect = drawing.Rectangle{
                    .position = link.bounds.position,
                    .size = link.bounds.size,
                };
                menu_text_renderer.queueButtonText(link.text, link_rect, is_hovered);
            }
        }
    }

    pub fn renderNavigationBar(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, current_path: []const u8, can_go_back: bool, can_go_forward: bool) !void {
        const screen_width = 1920.0;
        const screen_height = 1080.0;
        
        const bar_height = 50.0;
        const bar_y = screen_height * 0.1 - bar_height / 2.0;
        const bar_width = screen_width * 0.8;
        const bar_x = (screen_width - bar_width) / 2.0;
        
        // Navigation bar background
        self.base_renderer.gpu.drawRect(
            cmd_buffer,
            render_pass,
            .{ .x = bar_x, .y = bar_y },
            .{ .x = bar_width, .y = bar_height },
            Color{ .r = 20, .g = 25, .b = 35, .a = 255 }
        );
        
        // Back button
        const button_size = 40.0;
        const button_margin = 5.0;
        const back_color = if (can_go_back)
            Color{ .r = 60, .g = 70, .b = 90, .a = 255 }
        else
            Color{ .r = 30, .g = 35, .b = 45, .a = 128 };
            
        self.base_renderer.gpu.drawRect(
            cmd_buffer,
            render_pass,
            .{ .x = bar_x + button_margin, .y = bar_y + button_margin },
            .{ .x = button_size, .y = button_size },
            back_color
        );
        
        // Draw back arrow indicator
        if (can_go_back) {
            self.drawArrow(cmd_buffer, render_pass, 
                bar_x + button_margin + button_size / 2.0, 
                bar_y + button_margin + button_size / 2.0, 
                10.0, .Left, 
                Color{ .r = 200, .g = 200, .b = 220, .a = 255 });
        }
        
        // Forward button
        const forward_color = if (can_go_forward)
            Color{ .r = 60, .g = 70, .b = 90, .a = 255 }
        else
            Color{ .r = 30, .g = 35, .b = 45, .a = 128 };
            
        self.base_renderer.gpu.drawRect(
            cmd_buffer,
            render_pass,
            .{ .x = bar_x + button_margin * 2 + button_size, .y = bar_y + button_margin },
            .{ .x = button_size, .y = button_size },
            forward_color
        );
        
        // Draw forward arrow indicator
        if (can_go_forward) {
            self.drawArrow(cmd_buffer, render_pass, 
                bar_x + button_margin * 2 + button_size + button_size / 2.0, 
                bar_y + button_margin + button_size / 2.0, 
                10.0, .Right, 
                Color{ .r = 200, .g = 200, .b = 220, .a = 255 });
        }
        
        // Address bar background
        const address_x = bar_x + button_margin * 3 + button_size * 2;
        const address_width = bar_width - (button_margin * 4 + button_size * 2);
        
        self.base_renderer.gpu.drawRect(
            cmd_buffer,
            render_pass,
            .{ .x = address_x, .y = bar_y + button_margin },
            .{ .x = address_width, .y = button_size },
            Color{ .r = 15, .g = 18, .b = 25, .a = 255 }
        );
        
        // Address bar border (to make it look like an input field)
        self.base_renderer.gpu.drawRect(
            cmd_buffer,
            render_pass,
            .{ .x = address_x, .y = bar_y + button_margin },
            .{ .x = address_width, .y = 2 },
            Color{ .r = 40, .g = 45, .b = 55, .a = 255 }
        );
        self.base_renderer.gpu.drawRect(
            cmd_buffer,
            render_pass,
            .{ .x = address_x, .y = bar_y + button_margin + button_size - 2 },
            .{ .x = address_width, .y = 2 },
            Color{ .r = 40, .g = 45, .b = 55, .a = 255 }
        );
        
        // Queue the path text for rendering using shared utility with main game renderers
        if (self.base_renderer.font_manager) |fm| {
            var menu_text_renderer = menu_text.MenuTextRenderer.init(&self.base_renderer.gpu.text_renderer, fm);
            menu_text_renderer.queueNavigationText(
                current_path, 
                .{ .x = address_x + 10, .y = bar_y + button_margin + 15 }
            );
        }
    }

    const ArrowDirection = enum { Left, Right };

    fn drawArrow(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, x: f32, y: f32, size: f32, direction: ArrowDirection, color: Color) void {
        // Draw simple arrow using rectangles
        const thickness = 2.0;
        
        switch (direction) {
            .Left => {
                // Draw <
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x - size/2, .y = y }, .{ .x = size, .y = thickness }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x - size/2, .y = y - thickness }, .{ .x = thickness, .y = size/2 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x - size/2, .y = y + thickness }, .{ .x = thickness, .y = size/2 }, color);
            },
            .Right => {
                // Draw >
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x - size/2, .y = y }, .{ .x = size, .y = thickness }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + size/2 - thickness, .y = y - thickness }, .{ .x = thickness, .y = size/2 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + size/2 - thickness, .y = y + thickness }, .{ .x = thickness, .y = size/2 }, color);
            },
        }
    }

};