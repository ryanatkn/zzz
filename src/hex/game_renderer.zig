const std = @import("std");
const c = @import("../lib/platform/sdl.zig");

const hex_game_mod = @import("hex_game.zig");
const HexGame = hex_game_mod.HexGame;
const math = @import("../lib/math/mod.zig");
const colors = @import("../lib/core/colors.zig");
const simple_gpu_renderer = @import("../lib/rendering/gpu.zig");
const camera = @import("../lib/rendering/camera.zig");
const borders = @import("borders.zig");
const constants = @import("constants.zig");
const GameEffectSystem = @import("../lib/effects/game_effects.zig").GameEffectSystem;
const font_manager = @import("../lib/font/manager.zig");
const reactive_text_cache = @import("../lib/reactive/text_cache.zig");
const loggers = @import("../lib/debug/loggers.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const SimpleGPURenderer = simple_gpu_renderer.SimpleGPURenderer;

// Entity types from HexGame
const EntityId = hex_game_mod.EntityId;
const ZoneData = hex_game_mod.HexGame.ZoneData;

pub const GameRenderer = struct {
    gpu: SimpleGPURenderer,
    camera: camera.Camera,
    font_manager: *font_manager.FontManager,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, window: *c.sdl.SDL_Window) !GameRenderer {
        var renderer = GameRenderer{
            .gpu = try SimpleGPURenderer.init(allocator, window),
            .camera = camera.Camera.init(constants.SCREEN_WIDTH, constants.SCREEN_HEIGHT),
            .font_manager = undefined,
            .allocator = allocator,
        };

        // Initialize Pure Zig font manager
        loggers.getGameLog().info("init_font", "Initializing Pure Zig font backend", .{});
        renderer.font_manager = try allocator.create(font_manager.FontManager);
        renderer.font_manager.* = try font_manager.FontManager.init(allocator, renderer.gpu.device);

        loggers.getGameLog().info("init_complete", "GameRenderer initialized with Pure Zig font backend", .{});

        return renderer;
    }

    pub fn deinit(self: *GameRenderer) void {
        self.font_manager.deinit();
        self.allocator.destroy(self.font_manager);
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
    pub fn updateCamera(self: *GameRenderer, game: *const HexGame) void {
        // Ensure camera has current screen dimensions (in case window resized)
        if (self.camera.screen_width != self.gpu.screen_width or
            self.camera.screen_height != self.gpu.screen_height)
        {
            self.camera.screen_width = self.gpu.screen_width;
            self.camera.screen_height = self.gpu.screen_height;
        }

        const zone = game.getCurrentZoneConst();
        switch (zone.camera_mode) {
            .fixed => self.camera.setupFixed(zone.camera_scale),
            .follow => self.camera.setupFollow(game.getPlayerPos(), zone.camera_scale),
        }
    }

    // Render all entities in current zone only with proper camera transforms
    pub fn renderZone(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, game: *const HexGame) void {
        const zone = game.getCurrentZoneConst();
        
        // Draw rectangles (obstacles) with camera transforms
        for (0..zone.obstacles.count) |i| {
            const transform = &zone.obstacles.transforms[i];
            const visual = &zone.obstacles.visuals[i];
            const terrain = &zone.obstacles.terrains[i];
            
            const screen_pos = self.camera.worldToScreen(transform.pos);
            const screen_size = Vec2{
                .x = self.camera.worldSizeToScreen(terrain.size.x),
                .y = self.camera.worldSizeToScreen(terrain.size.y),
            };
            self.gpu.drawRect(cmd_buffer, render_pass, screen_pos, screen_size, visual.color);
        }
        
        // Draw circles (units, lifestones, portals) with camera transforms
        for (0..zone.units.count) |i| {
            const transform = &zone.units.transforms[i];
            const visual = &zone.units.visuals[i];
            const screen_pos = self.camera.worldToScreen(transform.pos);
            const screen_radius = self.camera.worldSizeToScreen(transform.radius);
            self.gpu.drawCircle(cmd_buffer, render_pass, screen_pos, screen_radius, visual.color);
        }
        
        for (0..zone.lifestones.count) |i| {
            const transform = &zone.lifestones.transforms[i];
            const visual = &zone.lifestones.visuals[i];
            const screen_pos = self.camera.worldToScreen(transform.pos);
            const screen_radius = self.camera.worldSizeToScreen(transform.radius);
            self.gpu.drawCircle(cmd_buffer, render_pass, screen_pos, screen_radius, visual.color);
        }
        
        for (0..zone.portals.count) |i| {
            const transform = &zone.portals.transforms[i];
            const visual = &zone.portals.visuals[i];
            const screen_pos = self.camera.worldToScreen(transform.pos);
            const screen_radius = self.camera.worldSizeToScreen(transform.radius);
            self.gpu.drawCircle(cmd_buffer, render_pass, screen_pos, screen_radius, visual.color);
        }
        
        // Draw player (only if in current zone) with camera transforms
        if (game.player_zone == game.current_zone) {
            for (0..zone.players.count) |i| {
                const transform = &zone.players.transforms[i];
                const visual = &zone.players.visuals[i];
                const screen_pos = self.camera.worldToScreen(transform.pos);
                const screen_radius = self.camera.worldSizeToScreen(transform.radius);
                self.gpu.drawCircle(cmd_buffer, render_pass, screen_pos, screen_radius, visual.color);
            }
        }
        
        // Draw projectiles (bullets) with camera transforms
        for (0..zone.projectiles.count) |i| {
            const transform = &zone.projectiles.transforms[i];
            const visual = &zone.projectiles.visuals[i];
            if (visual.visible) {
                const screen_pos = self.camera.worldToScreen(transform.pos);
                const screen_radius = self.camera.worldSizeToScreen(transform.radius);
                self.gpu.drawCircle(cmd_buffer, render_pass, screen_pos, screen_radius, visual.color);
            }
        }
    }

    // Simplified rendering architecture completed
    // All rendering now handled by single efficient renderZone() function above

    // Render visual effects
    pub fn renderEffects(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, effect_system: *const GameEffectSystem) void {
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
            const wipe_duration = constants.IRIS_WIPE_DURATION;

            if (elapsed_sec < wipe_duration) {
                const progress = elapsed_sec / wipe_duration; // 0.0 to 1.0
                // Strong ease-out curve: fast at start, very slow at end
                const eased_progress = 1.0 - (1.0 - progress) * (1.0 - progress) * (1.0 - progress) * (1.0 - progress); // Quartic ease-out
                const shrink_factor = 1.0 - eased_progress; // 1.0 to 0.0 (shrinking with strong ease-out)

                // Create iris wipe bands using color constants
                const wipe_colors = [_]Color{
                    colors.BLUE_BRIGHT,
                    colors.GREEN_BRIGHT,
                    colors.YELLOW_BRIGHT,
                    colors.ORANGE_BRIGHT,
                    colors.PURPLE_BRIGHT,
                    colors.CYAN,
                };

                for (wipe_colors) |wipe_color| {
                    const max_width = constants.IRIS_WIPE_BAND_WIDTH;
                    const current_width = max_width * shrink_factor;

                    if (current_width > constants.VISIBILITY_THRESHOLD) { // Only render if visible
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
            // Animated paused border: base + pulse amplitude
            border_stack.pushAnimated(constants.PAUSED_BORDER_BASE_WIDTH, borders.GOLD_YELLOW_COLORS, 1.5, constants.PAUSED_BORDER_PULSE_AMPLITUDE);
        }

        if (!game_state.hex_game.getPlayerAlive()) {
            // Animated dead border: base + pulse amplitude
            border_stack.pushAnimated(constants.DEAD_BORDER_BASE_WIDTH, borders.RED_COLORS, 1.2, constants.DEAD_BORDER_PULSE_AMPLITUDE);
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
        const WHITE = colors.WHITE;

        // Position at top-left corner as requested (make it very visible)
        const fps_x = constants.FPS_POSITION_X; // Left margin
        const fps_y = constants.FPS_POSITION_Y; // Top margin

        // Format FPS as string
        var fps_buf: [32]u8 = undefined;
        const fps_text = std.fmt.bufPrintZ(&fps_buf, "FPS: {d}", .{fps}) catch "FPS: ??";

        // Use persistent text rendering to eliminate flashing
        loggers.getGameLog().debug("queue_fps", "Queuing FPS text for persistent rendering: '{s}'", .{fps_text});

        // Queue using persistent mode - texture will be cached and reused
        self.gpu.text_renderer.queuePersistentText(fps_text, .{ .x = fps_x, .y = fps_y }, self.font_manager, .sans, @import("../lib/font/config.zig").getGlobalConfig().fpsFontSize(), WHITE) catch |err| {
            loggers.getGameLog().err("fps_error", "Failed to queue persistent FPS text: {}", .{err});
            // Fall back to geometric rendering
            self.drawFPSGeometric(cmd_buffer, render_pass, fps);
            return;
        };

        loggers.getGameLog().debug("fps_queued", "✓ FPS text queued for persistent rendering", .{});
    }
    
    pub fn drawAIMode(self: *GameRenderer, ai_enabled: bool) void {
        if (!ai_enabled) return;
        
        // Use bright green color for AI mode indicator
        const AI_COLOR = colors.Color{ .r = 0, .g = 255, .b = 128, .a = 255 };
        
        // Position below FPS display
        const ai_x = constants.FPS_POSITION_X;
        const ai_y = constants.FPS_POSITION_Y + 30.0;
        
        const ai_text = "AI MODE ACTIVE";
        
        // Queue using persistent mode
        self.gpu.text_renderer.queuePersistentText(ai_text, .{ .x = ai_x, .y = ai_y }, self.font_manager, .sans, @import("../lib/font/config.zig").getGlobalConfig().fpsFontSize(), AI_COLOR) catch |err| {
            loggers.getGameLog().debug("ai_mode_error", "Failed to queue AI mode text: {}", .{err});
        };
    }


    fn drawFPSGeometric(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, fps: u32) void {
        const WHITE_LIGHT = Color{ .r = 230, .g = 230, .b = 230, .a = 255 }; // Slightly off-white
        const fps_x = constants.FPS_FALLBACK_X;
        const fps_y = constants.FPS_FALLBACK_Y;

        // Simple 2-digit FPS display
        const tens = (fps / 10) % 10;
        const ones = fps % 10;

        // Draw tens digit
        if (tens > 0) {
            self.drawDigit(cmd_buffer, render_pass, @intCast(tens), fps_x, fps_y, WHITE_LIGHT);
        }

        // Draw ones digit
        self.drawDigit(cmd_buffer, render_pass, @intCast(ones), fps_x + constants.FPS_DIGIT_SPACING, fps_y, WHITE_LIGHT);
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
                    const px = x + @as(f32, @floatFromInt(col)) * constants.FPS_PIXEL_SIZE;
                    const py = y + @as(f32, @floatFromInt(row)) * constants.FPS_PIXEL_SIZE;
                    self.gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = px, .y = py }, Vec2{ .x = constants.FPS_DIGIT_PIXEL_SIZE, .y = constants.FPS_DIGIT_PIXEL_SIZE }, color);
                }
            }
        }
    }
};
