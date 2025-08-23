const std = @import("std");
const c = @import("../../lib/platform/sdl.zig");
const time_utils = @import("../../lib/core/time.zig");

// Game system capabilities
const camera_mod = @import("../../lib/game/camera/camera.zig");
const GameParticleSystem = @import("../../lib/particles/game_particles.zig").GameParticleSystem;

const Camera = camera_mod.Camera;

/// Effects rendering system extracted from game_renderer.zig
/// Handles particle system and visual effects rendering
pub const EffectsRenderer = struct {
    /// Render visual effects and particles
    /// Extracted from game_renderer.zig lines 234-249
    pub fn renderParticles(gpu_renderer: anytype, cmd_buffer: *c.sdl.SDL_GPUCommandBuffer, render_pass: *c.sdl.SDL_GPURenderPass, camera: *const Camera, particle_system: *const GameParticleSystem) void {
        const active_particles = particle_system.getActiveParticles();

        // Get current time for shader animations
        const time_sec = time_utils.Time.getTimeSec();

        for (active_particles) |particle| {
            const screen_pos = camera.worldToScreen(particle.pos);
            const current_radius = particle.getCurrentRadius(); // Use dynamic radius for ping growth
            const screen_radius = camera.worldSizeToScreen(current_radius);
            const color = particle.getColor();
            const intensity = particle.getCurrentIntensity();

            gpu_renderer.drawParticle(cmd_buffer, render_pass, screen_pos, screen_radius, color, intensity, time_sec);
        }
    }
};
