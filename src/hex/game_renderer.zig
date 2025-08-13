const std = @import("std");

const c = @import("../lib/c.zig");

const entities = @import("entities.zig");
const types = @import("../lib/types.zig");
const simple_gpu_renderer = @import("../lib/simple_gpu_renderer.zig");
const camera = @import("../lib/camera.zig");
const borders = @import("borders.zig");
const constants = @import("constants.zig");
const effects = @import("effects.zig");
const fonts = @import("../lib/fonts.zig");
const reactive_text_cache = @import("../lib/reactive/text_cache.zig");

const Vec2 = types.Vec2;
const Color = types.Color;
const SimpleGPURenderer = simple_gpu_renderer.SimpleGPURenderer;

pub const GameRenderer = struct {
    gpu: SimpleGPURenderer,
    camera: camera.Camera,
    font_manager: ?*fonts.FontManager,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, window: *c.sdl.SDL_Window) !GameRenderer {
        var renderer = GameRenderer{
            .gpu = try SimpleGPURenderer.init(allocator, window),
            .camera = camera.Camera.init(constants.SCREEN_WIDTH, constants.SCREEN_HEIGHT),
            .font_manager = null,
            .allocator = allocator,
        };
        
        // Initialize font manager for TTF text rendering
        renderer.font_manager = try allocator.create(fonts.FontManager);
        renderer.font_manager.?.* = try fonts.FontManager.init(allocator, renderer.gpu.device);
        
        const log = std.log.scoped(.game_renderer);
        log.info("GameRenderer initialized with font_manager: {*}", .{renderer.font_manager});
        
        return renderer;
    }

    pub fn deinit(self: *GameRenderer) void {
        if (self.font_manager) |fm| {
            fm.deinit();
            self.allocator.destroy(fm);
            self.font_manager = null;
        }
        self.gpu.deinit();
    }

    // Begin a new frame
    pub fn beginFrame(self: *GameRenderer, window: *c.sdl.SDL_Window) !*c.sdl.SDL_GPUCommandBuffer {
        return try self.gpu.beginFrame(window);
    }

    // Begin render pass
    pub fn beginRenderPass(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, window: *c.sdl.SDL_Window, bg_color: Color) !*c.sdl.SDL_GPURenderPass {
        // Flush any pending text buffers before starting render pass
        // Text buffers now processed automatically in prepareTextBuffers
        return try self.gpu.beginRenderPass(cmd_buffer, window, bg_color);
    }

    // End render pass
    pub fn endRenderPass(self: *GameRenderer, render_pass: *c.sdl.SDL_GPURenderPass) void {
        self.gpu.endRenderPass(render_pass);
    }

    // End frame
    pub fn endFrame(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer) void {
        self.gpu.endFrame(cmd_buffer);
    }

    // Update camera based on current zone (call before game logic update)
    pub fn updateCamera(self: *GameRenderer, world: *const entities.World) void {
        // Ensure camera has current screen dimensions (in case window resized)
        if (self.camera.screen_width != self.gpu.screen_width or
            self.camera.screen_height != self.gpu.screen_height)
        {
            self.camera.screen_width = self.gpu.screen_width;
            self.camera.screen_height = self.gpu.screen_height;
        }

        const zone = world.getCurrentZone();
        switch (zone.camera_mode) {
            .fixed => self.camera.setupFixed(zone.camera_scale),
            .follow => self.camera.setupFollow(world.player.pos, zone.camera_scale),
        }
    }

    // Render all entities in a zone
    pub fn renderZone(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, world: *const entities.World) void {
        const zone = world.getCurrentZone();

        // Draw all rectangles first (obstacles)
        self.renderObstacles(cmd_buffer, render_pass, zone);

        // Then draw all circles (player, enemies, bullets, etc)
        self.renderCircles(cmd_buffer, render_pass, world);
    }

    // Render all obstacles (rectangles)
    fn renderObstacles(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, zone: *const entities.Zone) void {
        for (0..zone.obstacle_count) |i| {
            const obstacle = &zone.obstacles[i];
            if (obstacle.active) {
                const screen_pos = self.camera.worldToScreen(obstacle.pos);
                const screen_size = Vec2{
                    .x = self.camera.worldSizeToScreen(obstacle.size.x),
                    .y = self.camera.worldSizeToScreen(obstacle.size.y),
                };
                self.gpu.drawRect(cmd_buffer, render_pass, screen_pos, screen_size, obstacle.color);
            }
        }
    }

    // Helper to render a single circular entity
    fn renderCircleEntity(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, pos: Vec2, radius: f32, color: Color) void {
        const screen_pos = self.camera.worldToScreen(pos);
        const screen_radius = self.camera.worldSizeToScreen(radius);
        self.gpu.drawCircle(cmd_buffer, render_pass, screen_pos, screen_radius, color);
    }

    // Render all circular entities
    fn renderCircles(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, world: *const entities.World) void {
        const zone = world.getCurrentZone();

        // Draw player
        const player = &world.player;
        self.renderCircleEntity(cmd_buffer, render_pass, player.pos, player.radius, player.color);

        // Draw bullets
        for (0..entities.MAX_BULLETS) |i| {
            const bullet = &world.bullets[i];
            if (bullet.active) {
                self.renderCircleEntity(cmd_buffer, render_pass, bullet.pos, bullet.radius, bullet.color);
            }
        }

        // Draw lifestones
        for (0..zone.lifestone_count) |i| {
            const lifestone = &zone.lifestones[i];
            if (lifestone.active) {
                self.renderCircleEntity(cmd_buffer, render_pass, lifestone.pos, lifestone.radius, lifestone.color);
            }
        }

        // Draw portals
        for (0..zone.portal_count) |i| {
            const portal = &zone.portals[i];
            if (portal.active) {
                self.renderCircleEntity(cmd_buffer, render_pass, portal.pos, portal.radius, portal.color);
            }
        }

        // Draw units
        for (0..zone.unit_count) |i| {
            const unit = &zone.units[i];
            if (unit.active) {
                self.renderCircleEntity(cmd_buffer, render_pass, unit.pos, unit.radius, unit.color);
            }
        }
    }

    // Render visual effects
    pub fn renderEffects(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, effect_system: *const effects.EffectSystem) void {
        const active_effects = effect_system.getActiveEffects();

        // Get current time for shader animations
        const current_time = c.sdl.SDL_GetPerformanceCounter();
        const frequency = c.sdl.SDL_GetPerformanceFrequency();
        const time_sec = @as(f32, @floatFromInt(current_time)) / @as(f32, @floatFromInt(frequency));

        for (active_effects) |effect| {
            const screen_pos = self.camera.worldToScreen(effect.pos);
            const current_radius = effect.getCurrentRadius(); // Use dynamic radius for ping growth
            const screen_radius = self.camera.worldSizeToScreen(current_radius);
            const color = effect.getColor();
            const intensity = effect.getCurrentIntensity();

            self.gpu.drawEffect(cmd_buffer, render_pass, screen_pos, screen_radius, color, intensity, time_sec);
        }
    }

    // Draw border system with stacking support
    pub fn drawBorders(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, game_state: anytype) void {
        var border_stack = borders.BorderStack.init();

        // Iris wipe effect (highest priority - renders over everything)
        if (game_state.iris_wipe_active) {
            const current_time = c.sdl.SDL_GetPerformanceCounter();
            const frequency = c.sdl.SDL_GetPerformanceFrequency();
            const elapsed_sec = @as(f32, @floatFromInt(current_time - game_state.iris_wipe_start_time)) / @as(f32, @floatFromInt(frequency));
            const wipe_duration = borders.IRIS_WIPE_DURATION;

            if (elapsed_sec < wipe_duration) {
                const progress = elapsed_sec / wipe_duration; // 0.0 to 1.0
                // Strong ease-out curve: fast at start, very slow at end
                const eased_progress = 1.0 - (1.0 - progress) * (1.0 - progress) * (1.0 - progress) * (1.0 - progress); // Quartic ease-out
                const shrink_factor = 1.0 - eased_progress; // 1.0 to 0.0 (shrinking with strong ease-out)

                // Create iris wipe bands using existing game colors
                const wipe_colors = [_]Color{
                    Color{ .r = 100, .g = 150, .b = 255, .a = 255 }, // BLUE_BRIGHT
                    Color{ .r = 80, .g = 220, .b = 80, .a = 255 }, // GREEN_BRIGHT
                    Color{ .r = 255, .g = 220, .b = 80, .a = 255 }, // YELLOW_BRIGHT
                    Color{ .r = 255, .g = 180, .b = 80, .a = 255 }, // ORANGE_BRIGHT
                    Color{ .r = 180, .g = 100, .b = 240, .a = 255 }, // PURPLE_BRIGHT
                    Color{ .r = 0, .g = 200, .b = 200, .a = 255 }, // CYAN
                };

                for (wipe_colors) |wipe_color| {
                    const max_width = borders.IRIS_WIPE_BAND_WIDTH;
                    const current_width = max_width * shrink_factor;

                    if (current_width > 0.5) { // Only render if visible
                        border_stack.pushStatic(current_width, wipe_color);
                    }
                }
            } else {
                // End iris wipe
                @constCast(game_state).iris_wipe_active = false;
            }
        }

        // Game state borders (lower priority)
        if (game_state.isPaused()) {
            // Animated paused border: base 6px + 4px pulse amplitude
            border_stack.pushAnimated(6.0, borders.GOLD_YELLOW_COLORS, 1.5, 4.0);
        }

        if (!game_state.world.player.alive) {
            // Animated dead border: base 9px + 5px pulse amplitude
            border_stack.pushAnimated(9.0, borders.RED_COLORS, 1.2, 5.0);
        }

        // Render all borders with automatic offset calculation based on current animated widths
        var current_offset: f32 = 0;

        for (0..border_stack.count) |i| {
            const spec = &border_stack.specs[i];
            const current_width = spec.getCurrentWidth();
            const current_color = spec.getCurrentColor();

            self.drawBorderWithOffset(cmd_buffer, render_pass, current_color, current_width, current_offset);
            current_offset += current_width;
        }
    }

    // Helper method for border system integration
    pub fn drawBorderWithOffset(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, color: Color, width: f32, offset: f32) void {
        const rects = borders.calculateBorderRects(width, offset);
        for (rects) |rect| {
            self.gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = rect.x, .y = rect.y }, Vec2{ .x = rect.w, .y = rect.h }, color);
        }
    }

    // FPS rendering using PERSISTENT MODE to eliminate flashing
    pub fn drawFPS(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, fps: u32) void {
        
        // Use white color for FPS display
        const WHITE = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
        
        // Position at top-left corner as requested (make it very visible)
        const fps_x = 100.0;   // Left margin
        const fps_y = 100.0;   // Top margin

        // Format FPS as string
        var fps_buf: [32]u8 = undefined;
        const fps_text = std.fmt.bufPrintZ(&fps_buf, "FPS: {d}", .{fps}) catch "FPS: ??";
        
        // Use persistent text rendering to eliminate flashing
        if (self.font_manager) |fm| {
            const log = std.log.scoped(.fps_persistent);
            log.debug("Queuing FPS text for persistent rendering: '{s}'", .{fps_text});
            
            // Queue using persistent mode - texture will be cached and reused
            self.gpu.text_renderer.queuePersistentText(
                fps_text,
                .{ .x = fps_x, .y = fps_y },
                fm,
                .sans,
                48.0,
                WHITE
            ) catch |err| {
                log.err("Failed to queue persistent FPS text: {}", .{err});
                // Fall back to geometric rendering
                self.drawFPSGeometric(cmd_buffer, render_pass, fps);
                return;
            };
            
            log.debug("✓ FPS text queued for persistent rendering", .{});
        } else {
            // No font manager, use geometric fallback
            self.drawFPSGeometric(cmd_buffer, render_pass, fps);
        }
    }
    
    fn drawFPSGeometric(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, fps: u32) void {
        const WHITE = Color{ .r = 230, .g = 230, .b = 230, .a = 255 };
        const fps_x = 1840.0;
        const fps_y = 1060.0;

        // Simple 2-digit FPS display
        const tens = (fps / 10) % 10;
        const ones = fps % 10;

        // Draw tens digit
        if (tens > 0) {
            self.drawDigit(cmd_buffer, render_pass, @intCast(tens), fps_x, fps_y, WHITE);
        }

        // Draw ones digit
        self.drawDigit(cmd_buffer, render_pass, @intCast(ones), fps_x + 12.0, fps_y, WHITE);
    }

    // Draw a circle at screen position (for UI elements)
    pub fn drawCircle(self: *GameRenderer, pos: Vec2, radius: f32, color: Color) void {
        // TODO: This needs to be refactored to work with the current rendering architecture
        // For now, we'll skip this as we need access to cmd_buffer and render_pass
        _ = self;
        _ = pos;
        _ = radius;
        _ = color;
    }

    fn drawDigit(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, digit: u8, x: f32, y: f32, color: Color) void {
        if (digit > 9) return;

        // Simple 3x5 digit patterns
        const patterns = [_][15]bool{
            .{ true, true, true, true, false, true, true, false, true, true, false, true, true, true, true }, // 0
            .{ false, true, false, false, true, false, false, true, false, false, true, false, false, true, false }, // 1
            .{ true, true, true, false, false, true, true, true, true, true, false, false, true, true, true }, // 2
            .{ true, true, true, false, false, true, true, true, true, false, false, true, true, true, true }, // 3
            .{ true, false, true, true, false, true, true, true, true, false, false, true, false, false, true }, // 4
            .{ true, true, true, true, false, false, true, true, true, false, false, true, true, true, true }, // 5
            .{ true, true, true, true, false, false, true, true, true, true, false, true, true, true, true }, // 6
            .{ true, true, true, false, false, true, false, false, true, false, false, true, false, false, true }, // 7
            .{ true, true, true, true, false, true, true, true, true, true, false, true, true, true, true }, // 8
            .{ true, true, true, true, false, true, true, true, true, false, false, true, true, true, true }, // 9
        };

        const pattern = patterns[digit];
        for (0..5) |row| {
            for (0..3) |col| {
                if (pattern[row * 3 + col]) {
                    const px = x + @as(f32, @floatFromInt(col)) * 2.0;
                    const py = y + @as(f32, @floatFromInt(row)) * 2.0;
                    self.gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = px, .y = py }, Vec2{ .x = 1.5, .y = 1.5 }, color);
                }
            }
        }
    }
};
