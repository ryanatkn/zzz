const std = @import("std");

// Core capabilities
const math = @import("../lib/math/mod.zig");
const core_colors = @import("../lib/core/colors.zig");
const hex_colors = @import("colors.zig");
const time_utils = @import("../lib/core/time.zig");

// Platform capabilities
const c = @import("../lib/platform/sdl.zig");
const platform = @import("../lib/platform/mod.zig");

// Rendering capabilities
const simple_gpu_renderer = @import("../lib/rendering/core/gpu.zig");
const batching = @import("../lib/rendering/primitives/batching.zig");

// Font capabilities
const font_manager = @import("../lib/font/manager.zig");
const font_config = @import("../lib/font/config.zig");

// Text capabilities
const text_alignment = @import("../lib/text/alignment.zig");

// Game system capabilities
const camera = @import("../lib/game/camera/camera.zig");
const GameParticleSystem = @import("../lib/particles/game_particles.zig").GameParticleSystem;

// Reactive capabilities
const reactive_text_cache = @import("../lib/reactive/text_cache.zig");

// UI capabilities
const animated_borders = @import("../lib/ui/animated_borders.zig");

// Debug capabilities
const loggers = @import("../lib/debug/loggers.zig");

// Hex game modules
const world_state_mod = @import("world_state.zig");
const game_loop_mod = @import("game_loop.zig");
const constants = @import("constants.zig");
const ui = @import("ui/mod.zig");
const abilities = @import("ability_system.zig");

// Hex rendering subsystems (extracted from this file)
const rendering = @import("rendering/mod.zig");

const Vec2 = math.Vec2;

// Use generic batching utilities from lib/rendering
const RectData = batching.RectData;
const MAX_BATCHED_RECTS = constants.MAX_TERRAIN; // Terrain only
const Color = core_colors.Color;
const GPURenderer = simple_gpu_renderer.GPURenderer;
const HexGame = world_state_mod.HexGame;
const EntityId = world_state_mod.EntityId;
const ZoneData = world_state_mod.HexGame.ZoneData;
const GameState = game_loop_mod.GameState;

pub const GameRenderer = struct {
    gpu: GPURenderer,
    camera: camera.Camera,
    font_manager: *font_manager.FontManager,
    window: *c.sdl.SDL_Window,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, window: *c.sdl.SDL_Window) !GameRenderer {
        var renderer = GameRenderer{
            .gpu = try GPURenderer.init(allocator, window),
            .camera = camera.Camera.init(constants.SCREEN_WIDTH, constants.SCREEN_HEIGHT),
            .font_manager = undefined,
            .window = window,
            .allocator = allocator,
        };

        // Use FontManager from GPURenderer (already has GPU device set)
        loggers.getGameLog().info("init_font", "Using FontManager from GPURenderer (GPU device already set)", .{});
        renderer.font_manager = renderer.gpu.font_manager;

        loggers.getGameLog().info("init_complete", "GameRenderer initialized with Pure Zig font backend", .{});

        return renderer;
    }

    pub fn deinit(self: *GameRenderer) void {
        // Font manager is owned by GPURenderer, so don't deinit it here
        self.gpu.deinit();
    }

    // Begin a new frame
    pub fn beginFrame(self: *GameRenderer) !*c.sdl.SDL_GPUCommandBuffer {
        // Start performance monitoring
        self.gpu.startFrameTiming();
        return try self.gpu.beginFrame(self.window);
    }

    // Begin render pass
    pub fn beginRenderPass(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, bg_color: Color) !*c.sdl.SDL_GPURenderPass {
        // Flush any pending text buffers before starting render pass
        // Text buffers now processed automatically in prepareTextBuffers
        return try self.gpu.beginRenderPass(cmd_buffer, self.window, bg_color);
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
            .fixed => {
                // Show entire world bounds centered at origin (zoom still applies)
                self.camera.setViewport(Vec2{ .x = 0.0, .y = 0.0 }, zone.world_width, zone.world_height);
            },
            .follow => {
                // Follow controlled entity with clean camera system zoom
                const controlled_pos = if (game.getControlledEntity()) |controlled_entity| blk: {
                    if (zone.units.getComponent(controlled_entity, .transform)) |transform| {
                        break :blk transform.pos;
                    }
                    break :blk Vec2.ZERO;
                } else Vec2.ZERO;

                // Set base viewport size - zoom is applied internally by camera
                self.camera.setViewport(controlled_pos, constants.FOLLOW_VIEWPORT_WIDTH, constants.FOLLOW_VIEWPORT_HEIGHT);
            },
        }
    }

    // Render all entities in current zone - delegated to EntityBatchRenderer
    pub fn renderZone(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, game: *const HexGame) void {
        // Delegate to the extracted EntityBatchRenderer which uses lib/rendering utilities
        rendering.EntityBatchRenderer.renderZone(&self.gpu, cmd_buffer, render_pass, &self.camera, game);
    }

    // Simplified rendering architecture completed
    // All rendering now handled by single efficient renderZone() function above

    // Render visual effects - delegated to EffectsRenderer
    pub fn renderParticles(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, particle_system: *const GameParticleSystem) void {
        // Delegate to the extracted EffectsRenderer
        rendering.EffectsRenderer.renderParticles(&self.gpu, cmd_buffer, render_pass, &self.camera, particle_system);
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
                hex_colors.BLUE_BRIGHT,
                hex_colors.GREEN_BRIGHT,
                hex_colors.YELLOW_BRIGHT,
                hex_colors.ORANGE_BRIGHT,
                hex_colors.PURPLE_BRIGHT,
                hex_colors.CYAN,
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

        // Check if controlled entity is dead for border rendering
        const controlled_entity_dead = if (game_state.hex_game.getControlledEntity()) |controlled_entity| blk: {
            const zone = game_state.hex_game.getCurrentZoneConst();
            if (zone.units.getComponent(controlled_entity, .health)) |health| {
                break :blk !health.alive;
            }
            break :blk true; // No health component = assume dead
        } else true; // No controlled entity = assume dead

        if (controlled_entity_dead) {
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
        const rects = ui.borders.calculateBorderRects(width, offset);
        for (rects) |rect| {
            self.gpu.drawRect(cmd_buffer, render_pass, Vec2{ .x = rect.x, .y = rect.y }, Vec2{ .x = rect.w, .y = rect.h }, color);
        }
    }

    /// Prepare FPS text texture BEFORE render pass (avoids copy pass conflicts)
    pub fn prepareFPS(self: *GameRenderer, fps: u32) void {
        rendering.UIOverlayRenderer.prepareFPS(&self.gpu, fps, self.font_manager);
    }

    /// Prepare debug info text texture BEFORE render pass
    pub fn prepareDebugInfo(self: *GameRenderer, game: *const HexGame) void {
        rendering.UIOverlayRenderer.prepareDebugInfo(&self.gpu, game, self.font_manager);
    }

    /// Prepare AI mode text texture BEFORE render pass
    pub fn prepareAIMode(self: *GameRenderer, ai_enabled: bool) void {
        rendering.UIOverlayRenderer.prepareAIMode(&self.gpu, ai_enabled, self.font_manager);
    }

    // FPS rendering - delegated to UIOverlayRenderer (textures already prepared)
    pub fn drawFPS(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass) void {
        // Textures already prepared in prepareFPS
        rendering.UIOverlayRenderer.drawFPS(&self.gpu, cmd_buffer, render_pass);
    }

    // Debug info rendering - delegated to UIOverlayRenderer (textures already prepared)
    pub fn drawDebugInfo(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass) void {
        // Textures already prepared in prepareDebugInfo
        rendering.UIOverlayRenderer.drawDebugInfo(&self.gpu, cmd_buffer, render_pass);
    }

    // AI mode rendering - delegated to UIOverlayRenderer (textures already prepared)
    pub fn drawAIMode(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass) void {
        // Textures already prepared in prepareAIMode
        rendering.UIOverlayRenderer.drawAIMode(&self.gpu, cmd_buffer, render_pass);
    }

    /// Draw the ability bar at the bottom center of the screen
    pub fn drawAbilityBar(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, ability_system: *const abilities.AbilitySystem, ability_bar_ui: *const ui.ability_bar.AbilityBar) void {
        // Delegate to the extracted AbilityBarRenderer
        rendering.AbilityBarRenderer.drawAbilityBar(&self.gpu, cmd_buffer, render_pass, ability_system, ability_bar_ui);
    }
};
