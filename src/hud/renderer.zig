const std = @import("std");
const c = @import("../lib/c.zig");
const types = @import("../lib/types.zig");
const lib_renderer = @import("../lib/renderer.zig");
const game_renderer = @import("../hex/game_renderer.zig");
const page = @import("page.zig");
const fonts = @import("../lib/fonts.zig");

const Color = types.Color;

pub const BrowserRenderer = struct {
    base_renderer: *game_renderer.GameRenderer,
    font_manager: ?*fonts.FontManager,
    
    pub fn init(base_renderer: *game_renderer.GameRenderer) BrowserRenderer {
        return .{
            .base_renderer = base_renderer,
            .font_manager = null,
        };
    }
    
    pub fn initFonts(self: *BrowserRenderer, allocator: std.mem.Allocator) !void {
        const log = std.log.scoped(.browser_renderer);
        log.info("Initializing fonts in BrowserRenderer...", .{});
        
        self.font_manager = try allocator.create(fonts.FontManager);
        log.info("FontManager allocated at: {*}", .{self.font_manager});
        
        self.font_manager.?.* = try fonts.FontManager.init(allocator, self.base_renderer.gpu.device);
        log.info("FontManager initialized successfully", .{});
    }
    
    pub fn deinitFonts(self: *BrowserRenderer, allocator: std.mem.Allocator) void {
        if (self.font_manager) |fm| {
            fm.deinit();
            allocator.destroy(fm);
            self.font_manager = null;
        }
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
            
            // Render the link text centered in the button
            const text_color = if (is_hovered)
                Color{ .r = 220, .g = 230, .b = 240, .a = 255 }
            else
                Color{ .r = 180, .g = 190, .b = 200, .a = 255 };
            
            // Estimate text width (rough approximation)
            const text_width = @as(f32, @floatFromInt(link.text.len)) * 10.0;
            const text_x = link.bounds.position.x + (link.bounds.size.x - text_width) / 2.0;
            const text_y = link.bounds.position.y + (link.bounds.size.y - 10.0) / 2.0;
            
            self.drawSimpleText(
                cmd_buffer,
                render_pass,
                link.text,
                text_x,
                text_y,
                text_color
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
        
        // Render the path text
        self.drawSimpleText(
            cmd_buffer, 
            render_pass, 
            current_path, 
            address_x + 10, 
            bar_y + button_margin + 15,
            Color{ .r = 180, .g = 190, .b = 200, .a = 255 }
        );
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

    fn drawSimpleText(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, text: []const u8, x: f32, y: f32, color: Color) void {
        const log = std.log.scoped(.browser_text);
        log.info("=== DRAW SIMPLE TEXT ===", .{});
        log.info("  Text: '{s}'", .{text});
        log.info("  Position: ({d}, {d})", .{ x, y });
        log.info("  Font manager: {*}", .{self.font_manager});
        
        // Try to use SDL_ttf if available, fallback to geometry text
        if (self.font_manager) |fm| {
            log.info("  Font manager available, attempting TTF render...", .{});
            
            // Try to render text
            const text_obj = fm.renderText(text, .sans, 14.0, color) catch |err| {
                log.err("  Failed to render text: {}", .{err});
                log.info("  Falling back to geometric text", .{});
                self.drawGeometricText(cmd_buffer, render_pass, text, x, y, color);
                return;
            };
            defer c.ttf.TTF_DestroyText(text_obj);
            
            log.info("  Text object created: {*}", .{text_obj});
            
            // Get GPU draw data
            const draw_data = c.ttf.TTF_GetGPUTextDrawData(text_obj);
            log.info("  GPU draw data: {*}", .{draw_data});
            
            if (draw_data != null) {
                const data = draw_data.?;
                log.info("  Draw data details:", .{});
                log.info("    - Texture: {*}", .{data.*.atlas_texture});
                log.info("    - Vertices: {d}", .{data.*.num_vertices});
                log.info("    - Indices: {d}", .{data.*.num_indices});
                
                // Use the new GPU text rendering
                log.info("  Rendering text with GPU data...", .{});
                self.base_renderer.gpu.drawText(
                    cmd_buffer,
                    render_pass,
                    data,
                    .{ .x = x, .y = y },
                    color
                );
                return; // Success! Don't use geometric fallback
            } else {
                log.warn("  No GPU draw data returned", .{});
            }
            
            // Use geometric fallback for now
            log.info("  Using geometric fallback", .{});
            self.drawGeometricText(cmd_buffer, render_pass, text, x, y, color);
        } else {
            log.warn("  No font manager available, using geometric text", .{});
            self.drawGeometricText(cmd_buffer, render_pass, text, x, y, color);
        }
    }
    
    fn drawGeometricText(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, text: []const u8, x: f32, y: f32, color: Color) void {
        var current_x = x;
        const char_spacing = 10.0;
        
        for (text) |char| {
            self.drawChar(cmd_buffer, render_pass, char, current_x, y, color);
            current_x += char_spacing;
            
            // Stop if we're going too far
            if (current_x > 1800) break;
        }
    }

    fn drawChar(self: *BrowserRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, char: u8, x: f32, y: f32, color: Color) void {
        // Simple character rendering using small rectangles
        // For now, just render some basic characters
        const pixel_size = 2.0;
        
        switch (char) {
            '/' => {
                // Draw a forward slash
                for (0..5) |i| {
                    const offset = @as(f32, @floatFromInt(i));
                    self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                        .{ .x = x + 4 - offset, .y = y + offset * 2 }, 
                        .{ .x = pixel_size, .y = pixel_size }, color);
                }
            },
            '-' => {
                // Draw a dash
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 4 }, .{ .x = 6, .y = pixel_size }, color);
            },
            '_' => {
                // Draw underscore
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 8 }, .{ .x = 6, .y = pixel_size }, color);
            },
            '.' => {
                // Draw a dot
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 2, .y = y + 8 }, .{ .x = pixel_size, .y = pixel_size }, color);
            },
            'a', 'A' => {
                // Draw an A shape
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 2 }, .{ .x = pixel_size, .y = 8 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 4, .y = y + 2 }, .{ .x = pixel_size, .y = 8 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = 6, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 5 }, .{ .x = 6, .y = pixel_size }, color);
            },
            's', 'S' => {
                // Draw an S shape
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = 6, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = pixel_size, .y = 5 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 4 }, .{ .x = 6, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 4, .y = y + 4 }, .{ .x = pixel_size, .y = 5 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 8 }, .{ .x = 6, .y = pixel_size }, color);
            },
            'e', 'E' => {
                // Draw an E shape
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = 6, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = pixel_size, .y = 10 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 4 }, .{ .x = 4, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 8 }, .{ .x = 6, .y = pixel_size }, color);
            },
            't', 'T' => {
                // Draw a T shape
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = 6, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 2, .y = y }, .{ .x = pixel_size, .y = 10 }, color);
            },
            'i', 'I' => {
                // Draw an I shape
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 2, .y = y }, .{ .x = pixel_size, .y = 10 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = 5, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 8 }, .{ .x = 5, .y = pixel_size }, color);
            },
            'n', 'N' => {
                // Draw an N shape
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = pixel_size, .y = 10 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 4, .y = y }, .{ .x = pixel_size, .y = 10 }, color);
                // Diagonal
                for (0..5) |i| {
                    const offset = @as(f32, @floatFromInt(i));
                    self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                        .{ .x = x + offset, .y = y + offset * 2 }, 
                        .{ .x = pixel_size, .y = pixel_size }, color);
                }
            },
            'g', 'G' => {
                // Draw a G shape
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = 6, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = pixel_size, .y = 10 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 8 }, .{ .x = 6, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 4, .y = y + 4 }, .{ .x = pixel_size, .y = 5 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 2, .y = y + 4 }, .{ .x = 3, .y = pixel_size }, color);
            },
            'v', 'V' => {
                // Draw a V shape
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = pixel_size, .y = 6 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 4, .y = y }, .{ .x = pixel_size, .y = 6 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 1, .y = y + 6 }, .{ .x = pixel_size, .y = 2 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 3, .y = y + 6 }, .{ .x = pixel_size, .y = 2 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 2, .y = y + 8 }, .{ .x = pixel_size, .y = 2 }, color);
            },
            'd', 'D' => {
                // Draw a D shape
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = pixel_size, .y = 10 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = 4, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 8 }, .{ .x = 4, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 4, .y = y + 2 }, .{ .x = pixel_size, .y = 6 }, color);
            },
            'o', 'O' => {
                // Draw an O shape
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 2 }, .{ .x = pixel_size, .y = 6 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 4, .y = y + 2 }, .{ .x = pixel_size, .y = 6 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = 6, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 8 }, .{ .x = 6, .y = pixel_size }, color);
            },
            'u', 'U' => {
                // Draw a U shape
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = pixel_size, .y = 10 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 4, .y = y }, .{ .x = pixel_size, .y = 10 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 8 }, .{ .x = 6, .y = pixel_size }, color);
            },
            'c', 'C' => {
                // Draw a C shape
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = 6, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = pixel_size, .y = 10 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 8 }, .{ .x = 6, .y = pixel_size }, color);
            },
            'r', 'R' => {
                // Draw an R shape
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = pixel_size, .y = 10 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = 5, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 4, .y = y }, .{ .x = pixel_size, .y = 5 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 4 }, .{ .x = 5, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 3, .y = y + 5 }, .{ .x = pixel_size, .y = 5 }, color);
            },
            'l', 'L' => {
                // Draw an L shape
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = pixel_size, .y = 10 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 8 }, .{ .x = 6, .y = pixel_size }, color);
            },
            'h', 'H' => {
                // Draw an H shape
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = pixel_size, .y = 10 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 4, .y = y }, .{ .x = pixel_size, .y = 10 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 4 }, .{ .x = 6, .y = pixel_size }, color);
            },
            'p', 'P' => {
                // Draw a P shape
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = pixel_size, .y = 10 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = 5, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 4, .y = y }, .{ .x = pixel_size, .y = 5 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 4 }, .{ .x = 5, .y = pixel_size }, color);
            },
            'b', 'B' => {
                // Draw a B shape
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = pixel_size, .y = 10 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = 4, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 4 }, .{ .x = 4, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 8 }, .{ .x = 4, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 4, .y = y + 1 }, .{ .x = pixel_size, .y = 3 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 4, .y = y + 5 }, .{ .x = pixel_size, .y = 3 }, color);
            },
            'k', 'K' => {
                // Draw a K shape
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = pixel_size, .y = 10 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 2, .y = y + 4 }, .{ .x = pixel_size, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 3, .y = y + 2 }, .{ .x = pixel_size, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 4, .y = y }, .{ .x = pixel_size, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 3, .y = y + 6 }, .{ .x = pixel_size, .y = pixel_size }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 4, .y = y + 8 }, .{ .x = pixel_size, .y = pixel_size }, color);
            },
            else => {
                // For unimplemented chars, draw a small box
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = 5, .y = 1 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y + 8 }, .{ .x = 5, .y = 1 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x, .y = y }, .{ .x = 1, .y = 9 }, color);
                self.base_renderer.gpu.drawRect(cmd_buffer, render_pass,
                    .{ .x = x + 4, .y = y }, .{ .x = 1, .y = 9 }, color);
            },
        }
    }
};