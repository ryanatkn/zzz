const std = @import("std");

// Core capabilities
const math = @import("../lib/math/mod.zig");
const colors = @import("../lib/core/colors.zig");
const time_utils = @import("../lib/core/time.zig");

// Platform capabilities
const c = @import("../lib/platform/sdl.zig");

// Rendering capabilities
const simple_gpu_renderer = @import("../lib/rendering/gpu.zig");
const camera = @import("../lib/rendering/camera.zig");

// Font capabilities
const font_manager = @import("../lib/font/manager.zig");
const font_config = @import("../lib/font/config.zig");

// Text capabilities
const text_alignment = @import("../lib/text/alignment.zig");

// Game system capabilities
const GameEffectSystem = @import("../lib/effects/game_effects.zig").GameEffectSystem;

// Reactive capabilities
const reactive_text_cache = @import("../lib/reactive/text_cache.zig");

// UI capabilities
const geometric_text = @import("../lib/ui/geometric_text.zig");
const animated_borders = @import("../lib/ui/animated_borders.zig");

// Debug capabilities
const loggers = @import("../lib/debug/loggers.zig");

// Hex game modules
const hex_game_mod = @import("hex_game.zig");
const game_controller = @import("game.zig");
const borders = @import("borders.zig");
const constants = @import("constants.zig");
const spellbar = @import("spellbar.zig");
const spells = @import("spells.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;
const SimpleGPURenderer = simple_gpu_renderer.SimpleGPURenderer;
const HexGame = hex_game_mod.HexGame;
const EntityId = hex_game_mod.EntityId;
const ZoneData = hex_game_mod.HexGame.ZoneData;
const GameState = game_controller.GameState;

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
        // Start performance monitoring
        self.gpu.startFrameTiming();
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
        // End performance monitoring and log stats
        self.gpu.endFrameTiming();
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
    //
    // Note: New rendering utilities available for future optimization:
    // - src/lib/rendering/entity_renderer.zig: Generic entity rendering with automatic batching/culling
    // - src/lib/rendering/camera_utils.zig: Batch camera transformations and viewport culling
    // These modules can replace the duplicate loops below for improved performance and code reuse
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
        if (game.player_zone == game.zone_manager.getCurrentZoneIndex()) {
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
        const time_sec = time_utils.Time.getTimeSec();

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
    pub fn drawBorders(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, game_state: *GameState) void {
        const border_config = animated_borders.BorderConfig{
            .max_layers = constants.MAX_BORDER_LAYERS,
            .screen_width = constants.SCREEN_WIDTH,
            .screen_height = constants.SCREEN_HEIGHT,
            .visibility_threshold = constants.VISIBILITY_THRESHOLD,
        };
        var border_stack = animated_borders.BorderStack(constants.MAX_BORDER_LAYERS).init(border_config);

        // Iris wipe effect (highest priority - renders over everything)
        if (game_state.iris_wipe_active) {
            const elapsed_sec = game_state.iris_wipe_start_time.getElapsedSec();

            const wipe_colors = [_]Color{
                colors.BLUE_BRIGHT,
                colors.GREEN_BRIGHT,
                colors.YELLOW_BRIGHT,
                colors.ORANGE_BRIGHT,
                colors.PURPLE_BRIGHT,
                colors.CYAN,
            };

            const iris_wipe = animated_borders.IrisWipe{
                .colors = &wipe_colors,
                .band_width = constants.IRIS_WIPE_BAND_WIDTH,
                .duration = constants.IRIS_WIPE_DURATION,
                .easing_fn = animated_borders.Easing.quarticEaseOut,
            };

            iris_wipe.getBorders(elapsed_sec, &border_stack);

            if (elapsed_sec >= constants.IRIS_WIPE_DURATION) {
                game_state.iris_wipe_active = false;
            }
        }

        // Game state borders (lower priority)
        if (game_state.isPaused()) {
            // Animated paused border: base + pulse amplitude
            border_stack.pushAnimated(constants.PAUSED_BORDER_BASE_WIDTH, animated_borders.ColorPairs.GOLD_YELLOW, 1.5, constants.PAUSED_BORDER_PULSE_AMPLITUDE);
        }

        if (!game_state.hex_game.getPlayerAlive()) {
            // Animated dead border: base + pulse amplitude
            border_stack.pushAnimated(constants.DEAD_BORDER_BASE_WIDTH, animated_borders.ColorPairs.RED, 1.2, constants.DEAD_BORDER_PULSE_AMPLITUDE);
        }

        // Render all borders with automatic offset calculation based on current animated widths
        const current_time_ms = time_utils.Time.getTimeMs();
        var current_offset: f32 = 0;

        for (0..border_stack.count) |i| {
            const spec = &border_stack.specs[i];
            const current_width = spec.getCurrentWidth(current_time_ms);
            const current_color = spec.getCurrentColor(current_time_ms);

            if (current_width > constants.VISIBILITY_THRESHOLD) {
                self.drawBorderWithOffset(cmd_buffer, render_pass, current_color, current_width, current_offset);
                current_offset += current_width;
            }
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

        // Queue using persistent mode - texture will be cached and reused
        self.gpu.text_renderer.queuePersistentText(fps_text, .{ .x = fps_x, .y = fps_y }, self.font_manager, .sans, font_config.getGlobalConfig().fpsFontSize(), WHITE) catch |err| {
            loggers.getGameLog().err("fps_error", "Failed to queue persistent FPS text: {}", .{err});
            // Fall back to geometric rendering
            self.drawFPSGeometric(cmd_buffer, render_pass, fps);
            return;
        };
    }

    pub fn drawAIMode(self: *GameRenderer, ai_enabled: bool) void {
        if (!ai_enabled) return;

        // Use bright green color for AI mode indicator
        const AI_COLOR = colors.Color{ .r = 0, .g = 255, .b = 128, .a = 255 };

        const ai_text = "AI MODE ACTIVE";
        const font_size = font_config.getGlobalConfig().fpsFontSize();

        // Calculate text width for right alignment (rough estimation)
        const estimated_text_width = @as(f32, @floatFromInt(ai_text.len)) * font_size * 0.6;

        // Position near bottom right, ensuring we have enough margin for the text
        const margin = 40.0; // Increased margin to move text further left
        const base_position = Vec2{
            .x = constants.SCREEN_WIDTH - margin, // Right edge with more margin for text
            .y = constants.SCREEN_HEIGHT - 50.0, // Above bottom edge
        };

        // Apply right alignment to position text correctly from the right edge
        const aligned_position = text_alignment.applyAlignment(base_position, .right, estimated_text_width);

        // Queue using persistent mode with proper alignment
        self.gpu.text_renderer.queuePersistentText(ai_text, aligned_position, self.font_manager, .sans, font_size, AI_COLOR) catch {
            // AI mode text failed - fallback to no display
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

        const config = geometric_text.TextConfig{
            .pixel_size = constants.FPS_DIGIT_PIXEL_SIZE,
            .char_width = 3,
            .char_height = 5,
        };

        const pattern = geometric_text.CharacterPatterns.getDigitPattern(digit) orelse return;

        for (0..config.char_height) |row| {
            for (0..config.char_width) |col| {
                if (pattern[row * config.char_width + col]) {
                    const px = x + @as(f32, @floatFromInt(col)) * config.pixel_size;
                    const py = y + @as(f32, @floatFromInt(row)) * config.pixel_size;
                    const pixel_size = Vec2{ .x = config.pixel_size, .y = config.pixel_size };
                    self.gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = px, .y = py }, pixel_size, color);
                }
            }
        }
    }

    /// Draw the spellbar at the bottom center of the screen
    pub fn drawSpellbar(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, spell_system: *const spells.SpellSystem, spellbar_ui: *const spellbar.Spellbar) void {
        for (0..8) |slot_index| {
            const slot_rect = spellbar_ui.getSlotRect(slot_index);
            const slot = spell_system.getSlot(slot_index);

            // Determine slot state
            const spell_type = if (slot) |s| s.spell_type else .None;
            const is_active = spell_system.getActiveSlot().spell_type == spell_type and spell_type != .None;
            const is_hovered = spellbar_ui.hovered_slot == slot_index;
            const cooldown_progress = if (slot) |s| s.cooldown_timer.getProgress() else 0.0;

            // Draw slot background
            const slot_color = spellbar_ui.getSlotColor(spell_type, is_hovered);
            self.gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = slot_rect.x, .y = slot_rect.y }, Vec2{ .x = slot_rect.width, .y = slot_rect.height }, slot_color);

            // Draw cooldown overlay if spell is on cooldown
            if (slot != null and cooldown_progress < 1.0) {
                const overlay_height = slot_rect.height * (1.0 - cooldown_progress);
                // Use dark spell color for cooldown overlay
                const dark_color = spellbar.getDarkSpellColor(spell_type);
                self.gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = slot_rect.x, .y = slot_rect.y }, Vec2{ .x = slot_rect.width, .y = overlay_height }, dark_color);
            }

            // Draw border for active/hovered slots
            const border_color = spellbar_ui.getBorderColor(slot_index, is_active, is_hovered);
            if (border_color.a > 0) {
                const border_width = spellbar_ui.config.border_width;

                // Top border
                self.gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = slot_rect.x, .y = slot_rect.y }, Vec2{ .x = slot_rect.width, .y = border_width }, border_color);

                // Bottom border
                self.gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = slot_rect.x, .y = slot_rect.y + slot_rect.height - border_width }, Vec2{ .x = slot_rect.width, .y = border_width }, border_color);

                // Left border
                self.gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = slot_rect.x, .y = slot_rect.y }, Vec2{ .x = border_width, .y = slot_rect.height }, border_color);

                // Right border
                self.gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = slot_rect.x + slot_rect.width - border_width, .y = slot_rect.y }, Vec2{ .x = border_width, .y = slot_rect.height }, border_color);
            }

            // Draw hotkey label
            const label = spellbar.Spellbar.getHotkeyLabel(slot_index);
            const label_x = slot_rect.x + slot_rect.width - 12.0; // Top right corner
            const label_y = slot_rect.y + 2.0;

            // Draw label using geometric text
            self.drawHotkeyLabel(cmd_buffer, render_pass, label, label_x, label_y, colors.WHITE);
        }
    }

    /// Draw a single character hotkey label
    fn drawHotkeyLabel(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, text: []const u8, x: f32, y: f32, color: Color) void {
        if (text.len == 0) return;

        const config = geometric_text.TextConfig{
            .pixel_size = 1.5,
            .char_width = 3,
            .char_height = 5,
        };

        const char = text[0];
        const pattern = geometric_text.CharacterPatterns.getCharPattern(char);

        for (0..config.char_height) |row| {
            for (0..config.char_width) |col| {
                if (pattern[row * config.char_width + col]) {
                    const px = x + @as(f32, @floatFromInt(col)) * config.pixel_size;
                    const py = y + @as(f32, @floatFromInt(row)) * config.pixel_size;
                    const pixel_size = Vec2{ .x = config.pixel_size, .y = config.pixel_size };
                    self.gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = px, .y = py }, pixel_size, color);
                }
            }
        }
    }
};
