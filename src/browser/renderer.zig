const std = @import("std");
const c = @import("../c.zig");
const types = @import("../types.zig");
const renderer = @import("../renderer.zig");
const page = @import("page.zig");

const Color = types.Color;

pub const BrowserRenderer = struct {
    base_renderer: *renderer.Renderer,
    
    pub fn init(base_renderer: *renderer.Renderer) BrowserRenderer {
        return .{
            .base_renderer = base_renderer,
        };
    }

    pub fn renderOverlay(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass) !void {
        // Render semi-transparent background using rectangles
        // Draw a dark overlay by rendering multiple dark rectangles
        const screen_width = 1920.0;
        const screen_height = 1080.0;
        const overlay_color = Color{ .r = 10, .g = 10, .b = 15, .a = 200 };
        
        // Use drawRect if available (seen in drawDigit)
        self.base_renderer.gpu.drawRect(
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
            
            // Also draw a circle indicator in the center
            const indicator_size: f32 = if (is_hovered) 8.0 else 5.0;
            const circle_color = Color{ .r = 150, .g = 180, .b = 220, .a = 255 };
            
            self.base_renderer.gpu.drawCircle(
                cmd_buffer,
                render_pass,
                .{ 
                    .x = link.bounds.position.x + link.bounds.size.x / 2.0,
                    .y = link.bounds.position.y + link.bounds.size.y / 2.0 
                },
                indicator_size,
                circle_color
            );
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
        
        // Path display background
        const path_x = bar_x + button_margin * 3 + button_size * 2;
        const path_width = bar_width - (button_margin * 4 + button_size * 2);
        
        self.base_renderer.gpu.drawRect(
            cmd_buffer,
            render_pass,
            .{ .x = path_x, .y = bar_y + button_margin },
            .{ .x = path_width, .y = button_size },
            Color{ .r = 15, .g = 18, .b = 25, .a = 255 }
        );
        
        _ = current_path; // TODO: Render path text when text rendering is available
    }
};