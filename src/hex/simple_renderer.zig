const std = @import("std");
const c = @import("../lib/platform/sdl.zig");
const HexGame = @import("hex_game.zig").HexGame;
const math = @import("../lib/math/mod.zig");
const colors = @import("../lib/core/colors.zig");
const simple_gpu_renderer = @import("../lib/rendering/gpu.zig");
const camera = @import("../lib/rendering/camera.zig");
const constants = @import("constants.zig");
const Vec2 = math.Vec2;
const Color = colors.Color;

pub const GameRenderer = struct {
    gpu: simple_gpu_renderer.SimpleGPURenderer,
    camera: camera.Camera,
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator, window: *c.sdl.SDL_Window) !GameRenderer {
        return .{
            .gpu = try simple_gpu_renderer.SimpleGPURenderer.init(allocator, window),
            .camera = camera.Camera.init(constants.SCREEN_WIDTH, constants.SCREEN_HEIGHT),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *GameRenderer) void {
        self.gpu.deinit();
    }
    
    pub fn beginFrame(self: *GameRenderer, window: *c.sdl.SDL_Window) !*c.sdl.SDL_GPUCommandBuffer {
        return try self.gpu.beginFrame(window);
    }
    
    pub fn beginRenderPass(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, window: *c.sdl.SDL_Window, bg_color: Color) !*c.sdl.SDL_GPURenderPass {
        return try self.gpu.beginRenderPass(cmd_buffer, window, bg_color);
    }
    
    pub fn endRenderPass(self: *GameRenderer, render_pass: *c.sdl.SDL_GPURenderPass) void {
        self.gpu.endRenderPass(render_pass);
    }
    
    pub fn endFrame(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer) void {
        self.gpu.endFrame(cmd_buffer);
    }
    
    pub fn updateCamera(self: *GameRenderer, game: *const HexGame) void {
        // Update camera based on current zone
        const zone = game.getCurrentZoneConst();
        
        switch (zone.camera_mode) {
            .fixed => self.camera.setupFixed(zone.camera_scale),
            .follow => self.camera.setupFollow(game.getPlayerPos(), zone.camera_scale),
        }
    }
    
    pub fn renderZone(self: *GameRenderer, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, game: *const HexGame) void {
        // Direct zone access - no abstraction layers
        const zone = game.getCurrentZoneConst();
        
        // Log current zone for debugging
        if (game.current_zone != 0) {
            std.log.debug("Rendering zone {}", .{game.current_zone});
        }
        
        // Render obstacles (rectangles) - simplified iteration
        for (0..zone.obstacles.count) |i| {
            const transform = &zone.obstacles.transforms[i];
            const terrain = &zone.obstacles.terrains[i];
            const visual = &zone.obstacles.visuals[i];
            
            if (terrain.terrain_type != .wall and terrain.terrain_type != .pit) continue;
            if (!visual.visible) continue;
            
            const screen_pos = self.camera.worldToScreen(transform.pos);
            const screen_size = Vec2{
                .x = self.camera.worldSizeToScreen(terrain.size.x),
                .y = self.camera.worldSizeToScreen(terrain.size.y),
            };
            self.gpu.drawRect(cmd_buffer, render_pass, screen_pos, screen_size, visual.color);
        }
        
        // Render lifestones - ONLY from current zone
        const lifestone_count = zone.lifestones.count;
        for (0..lifestone_count) |i| {
            const transform = &zone.lifestones.transforms[i];
            const visual = &zone.lifestones.visuals[i];
            const interactable = &zone.lifestones.interactables[i];
            
            if (!visual.visible) continue;
            
            const screen_pos = self.camera.worldToScreen(transform.pos);
            const screen_radius = self.camera.worldSizeToScreen(transform.radius);
            
            // Check attunement for visual feedback
            const render_color = if (interactable.attuned) 
                constants.COLOR_LIFESTONE_ATTUNED 
            else 
                visual.color;
            
            self.gpu.drawCircle(cmd_buffer, render_pass, screen_pos, screen_radius, render_color);
        }
        
        if (lifestone_count > 0) {
            std.log.debug("Rendered {} lifestones in zone {}", .{ lifestone_count, game.current_zone });
        }
        
        // Render portals
        for (0..zone.portals.count) |i| {
            const transform = &zone.portals.transforms[i];
            const visual = &zone.portals.visuals[i];
            
            if (!visual.visible) continue;
            
            const screen_pos = self.camera.worldToScreen(transform.pos);
            const screen_radius = self.camera.worldSizeToScreen(transform.radius);
            self.gpu.drawCircle(cmd_buffer, render_pass, screen_pos, screen_radius, visual.color);
        }
        
        // Render units
        for (0..zone.units.count) |i| {
            const transform = &zone.units.transforms[i];
            const visual = &zone.units.visuals[i];
            
            if (!visual.visible) continue;
            
            const screen_pos = self.camera.worldToScreen(transform.pos);
            const screen_radius = self.camera.worldSizeToScreen(transform.radius);
            self.gpu.drawCircle(cmd_buffer, render_pass, screen_pos, screen_radius, visual.color);
        }
        
        // Render player (if in current zone)
        if (game.player_entity != null and game.player_zone == game.current_zone) {
            for (0..zone.players.count) |i| {
                const transform = &zone.players.transforms[i];
                const visual = &zone.players.visuals[i];
                
                if (!visual.visible) continue;
                
                const screen_pos = self.camera.worldToScreen(transform.pos);
                const screen_radius = self.camera.worldSizeToScreen(transform.radius);
                self.gpu.drawCircle(cmd_buffer, render_pass, screen_pos, screen_radius, visual.color);
            }
        }
        
        // Render projectiles
        for (0..zone.projectiles.count) |i| {
            const transform = &zone.projectiles.transforms[i];
            const visual = &zone.projectiles.visuals[i];
            
            if (!visual.visible) continue;
            
            const screen_pos = self.camera.worldToScreen(transform.pos);
            const screen_radius = self.camera.worldSizeToScreen(transform.radius);
            self.gpu.drawCircle(cmd_buffer, render_pass, screen_pos, screen_radius, visual.color);
        }
    }
};