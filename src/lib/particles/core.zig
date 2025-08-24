const std = @import("std");
const c = @import("../platform/sdl.zig");
const loggers = @import("../debug/loggers.zig");

const math = @import("../math/mod.zig");
const colors = @import("../core/colors.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;

// TODO these are broken

pub const MAX_PARTICLES = 256; // Increased pool for multiple simultaneous particles

pub const ParticleType = enum {
    player_spawn, // Dramatic ping when player respawns
    portal_travel, // Multiple pings when player travels through portal
    portal_ripple, // Subtle ripples emanating from portal
    portal_ambient, // Single portal effect (reduced from 3 layers)
    lifestone_glow, // Gentle glow around unattuned lifestones
    lifestone_inner, // Brighter effect for attuned lifestones
    lull_area, // Area of effect indicator for Lull spell
    unit_status_aura, // Glowing aura around units under status effects
};

pub const Particle = struct {
    pos: Vec2,
    radius: f32,
    particle_type: ParticleType,
    active: bool,
    start_time: u64,
    duration: f32, // 0.0 = permanent
    intensity: f32,

    pub fn init(pos: Vec2, radius: f32, particle_type: ParticleType, duration: f32) Particle {
        return .{
            .pos = pos,
            .radius = radius,
            .particle_type = particle_type,
            .active = true,
            .start_time = c.sdl.SDL_GetPerformanceCounter(),
            .duration = duration,
            .intensity = 1.0,
        };
    }

    pub fn isActive(self: *const Particle) bool {
        if (!self.active) return false;
        if (self.duration == 0.0) return true; // Permanent effect

        const current_time = c.sdl.SDL_GetPerformanceCounter();
        // Check if effect has started yet (handle delayed effects)
        if (current_time < self.start_time) return true; // Not started yet, but active

        const frequency = c.sdl.SDL_GetPerformanceFrequency();
        const elapsed_sec = @as(f32, @floatFromInt(current_time - self.start_time)) / @as(f32, @floatFromInt(frequency));
        return elapsed_sec < self.duration;
    }

    pub fn getElapsed(self: *const Particle) f32 {
        const current_time = c.sdl.SDL_GetPerformanceCounter();
        // If effect hasn't started yet, return 0 elapsed time
        if (current_time < self.start_time) return 0.0;

        const frequency = c.sdl.SDL_GetPerformanceFrequency();
        return @as(f32, @floatFromInt(current_time - self.start_time)) / @as(f32, @floatFromInt(frequency));
    }

    fn getPulse(elapsed: f32, frequency: f32, phase_offset: f32) f32 {
        return (std.math.sin(elapsed * frequency + phase_offset) + 1.0) * 0.5; // 0.0 to 1.0
    }

    pub fn getCurrentRadius(self: *const Particle) f32 {
        const elapsed = self.getElapsed();

        switch (self.particle_type) {
            .player_spawn => {
                // Grow continuously for full duration, synced with fade out
                if (self.duration > 0.0) {
                    const progress = elapsed / self.duration; // 0.0 to 1.0
                    // Grow from 20% to 300% size over full duration for dramatic expanding ring
                    return self.radius * (0.2 + progress * 2.8); // 20% → 300% size
                }
                return self.radius;
            },
            .portal_travel => {
                // Different growth rates based on effect intensity
                if (self.duration > 0.0) {
                    const progress = elapsed / self.duration;
                    if (self.intensity >= 0.9) {
                        // First ping: fast, dramatic growth (intensity = 1.0)
                        return self.radius * (0.3 + progress * 3.7); // 30% → 400% size - much bigger!
                    } else if (self.intensity >= 0.7 and self.intensity < 0.8) {
                        // NEW slow-growing ring (intensity = 0.7)
                        return self.radius * (0.5 + progress * 4.5); // 50% → 500% size over 3.5 seconds - good as is
                    } else if (self.intensity >= 0.8 and self.intensity < 0.9) {
                        // Small marker ping (intensity = 0.8)
                        return self.radius * (0.2 + progress * 2.8); // 20% → 300% size - much bigger!
                    } else {
                        // Large expansion (intensity = 0.5)
                        return self.radius * (0.4 + progress * 4.1); // 40% → 450% size - much bigger!
                    }
                }
                return self.radius;
            },
            .portal_ripple => {
                // Subtle growing ripple rings
                if (self.duration > 0.0) {
                    const progress = elapsed / self.duration;
                    // Small growth outward from portal edge
                    return self.radius * (1.0 + progress * 0.8); // 100% → 180% size - much smaller growth
                }
                return self.radius;
            },
            .portal_ambient => {
                // Subtle size pulse for ambient effects
                const pulse = getPulse(elapsed, 0.5, 0.0);
                return self.radius * (0.9 + pulse * 0.2); // 90% to 110% size
            },
            .lifestone_glow => {
                // Very gentle size pulse for lifestone glow
                const pulse = getPulse(elapsed, 0.7, 0.0);
                return self.radius * (0.92 + pulse * 0.16); // 92% to 108% size
            },
            .lifestone_inner => {
                // Significantly faster inner aura pulse
                const pulse = getPulse(elapsed, 2.8, 1.5); // Much faster speed (2.8 vs 0.7), phase offset
                return self.radius * (0.88 + pulse * 0.24); // 88% to 112% size (more variation)
            },
            .lull_area => {
                // Stable area indicator with subtle pulse to show it's active
                const pulse = getPulse(elapsed, 1.0, 0.0);
                return self.radius * (0.98 + pulse * 0.04); // 98% to 102% size - very subtle
            },
            .unit_status_aura => {
                // Pulsing aura around affected units
                const pulse = getPulse(elapsed, 2.0, 0.0); // 2 second cycle
                return self.radius * (1.1 + pulse * 0.3); // 110% to 140% size - noticeable effect
            },
        }
    }

    pub fn getCurrentIntensity(self: *const Particle) f32 {
        const elapsed = self.getElapsed();

        switch (self.particle_type) {
            .player_spawn => {
                // Quick fade out over 3 seconds for dramatic ping with lower starting intensity
                if (self.duration > 0.0) {
                    const progress = elapsed / self.duration; // 0.0 to 1.0
                    const fade = 1.0 - (progress * progress); // Quadratic fade out
                    return @max(0.0, fade * self.intensity * 0.4); // Start at 40% intensity for transparency
                }
                return self.intensity * 0.4;
            },
            .portal_travel => {
                // Quick fade over 1.5 seconds with transparency
                if (self.duration > 0.0) {
                    const fade = 1.0 - (elapsed / self.duration);
                    return @max(0.0, fade * self.intensity * 0.5); // 50% intensity for transparency
                }
                return self.intensity * 0.5;
            },
            .portal_ripple => {
                // Ripple fade like ping
                if (self.duration > 0.0) {
                    const progress = elapsed / self.duration;
                    const fade = 1.0 - (progress * progress); // Quadratic fade
                    return @max(0.0, fade * self.intensity * 0.6); // 60% max intensity for visibility
                }
                return self.intensity * 0.6;
            },
            .portal_ambient => {
                // Gentle but visible pulse for ambient effects
                const pulse = getPulse(elapsed, 0.6, 0.0);
                return (0.22 + pulse * 0.03) * self.intensity; // 0.22 to 0.25 range
            },
            .lifestone_glow => {
                // Gentle pulse for lifestone auras
                const pulse = getPulse(elapsed, 0.8, 0.0);
                return (0.38 + pulse * 0.07) * self.intensity;
            },
            .lifestone_inner => {
                // Faster, lower intensity inner aura
                const pulse = getPulse(elapsed, 2.8, 1.5); // Same fast speed as radius
                return (0.38 + pulse * 0.08) * self.intensity; // 0.18 to 0.26 range (lower max, min ~1 when scaled)
            },
            .lull_area => {
                // More visible area indicator
                const pulse = getPulse(elapsed, 1.0, 0.0);
                // Fade in over first 0.5 seconds
                const fade_in = @min(1.0, elapsed / 0.5);
                return (0.35 + pulse * 0.10) * self.intensity * fade_in; // 0.35 to 0.45 range - much more visible
            },
            .unit_status_aura => {
                // Glowing aura intensity for units under status effects
                const pulse = getPulse(elapsed, 2.0, 0.0);
                // Fade in quickly over first 0.3 seconds
                const fade_in = @min(1.0, elapsed / 0.3);
                return (0.4 + pulse * 0.15) * self.intensity * fade_in; // 0.4 to 0.55 range - visible but not overwhelming
            },
        }
    }

    /// Select discrete color based on intensity level
    /// TODO: optimize - Use lookup tables instead of if-chains for color selection.
    /// Could pre-compute intensity buckets and use array indexing: lut[@as(usize, intensity * lut.len)]
    fn selectBlueByIntensity(intensity: f32) Color {
        const intensity_percent = @as(u32, @intFromFloat(@max(0.0, @min(1.0, intensity)) * 100));
        if (intensity_percent >= 80) return colors.BLUE_80;
        if (intensity_percent >= 60) return colors.BLUE_60;
        if (intensity_percent >= 40) return colors.BLUE_40;
        return colors.BLUE_20;
    }

    fn selectPurpleByIntensity(intensity: f32) Color {
        const intensity_percent = @as(u32, @intFromFloat(@max(0.0, @min(1.0, intensity)) * 100));
        if (intensity_percent >= 80) return colors.PURPLE_100;
        if (intensity_percent >= 60) return colors.PURPLE_80;
        if (intensity_percent >= 40) return colors.PURPLE_60;
        if (intensity_percent >= 20) return colors.PURPLE_40;
        return colors.PURPLE_20;
    }

    /// TODO: optimize - Move hardcoded cyan/yellow-green colors to core/colors.zig as discrete color families
    /// (CYAN_20/40/60/80, YELLOW_GREEN_20/40/60/80) for consistency with other color palettes.
    fn selectCyanByIntensity(intensity: f32) Color {
        const intensity_percent = @as(u32, @intFromFloat(@max(0.0, @min(1.0, intensity)) * 100));
        if (intensity_percent >= 80) return colors.CYAN;
        if (intensity_percent >= 60) return Color{ .r = 0.0, .g = 0.627, .b = 0.627, .a = 1.0 }; // 80% cyan
        if (intensity_percent >= 40) return Color{ .r = 0.0, .g = 0.470, .b = 0.470, .a = 1.0 }; // 60% cyan
        return Color{ .r = 0.0, .g = 0.314, .b = 0.314, .a = 1.0 }; // 40% cyan
    }

    fn selectYellowGreenByIntensity(intensity: f32) Color {
        const intensity_percent = @as(u32, @intFromFloat(@max(0.0, @min(1.0, intensity)) * 100));
        if (intensity_percent >= 80) return Color{ .r = 0.863, .g = 1.0, .b = 0.471, .a = 1.0 }; // Bright yellow-green
        if (intensity_percent >= 60) return Color{ .r = 0.706, .g = 0.863, .b = 0.392, .a = 1.0 }; // Medium yellow-green
        if (intensity_percent >= 40) return Color{ .r = 0.549, .g = 0.706, .b = 0.314, .a = 1.0 }; // Dim yellow-green
        return Color{ .r = 0.392, .g = 0.549, .b = 0.235, .a = 1.0 }; // Very dim yellow-green
    }

    /// TODO: optimize - Consider SIMD-friendly alpha operations using @Vector(4, f32) for better performance
    fn applyIntensityAlpha(color: Color, intensity: f32) Color {
        return Color{ .r = color.r, .g = color.g, .b = color.b, .a = intensity };
    }

    pub fn getColor(self: *const Particle) Color {
        const intensity = self.getCurrentIntensity();

        switch (self.particle_type) {
            .player_spawn => {
                // Bright blue/white for dramatic effect - use discrete blue levels
                return applyIntensityAlpha(selectBlueByIntensity(intensity), intensity);
            },
            .portal_travel => {
                // Different intensity levels for first vs second ping
                const base_color = if (self.intensity > 0.8)
                    selectBlueByIntensity(intensity) // First ping: brighter blue
                else
                    selectBlueByIntensity(intensity * 0.8); // Second ping: softer blue

                return applyIntensityAlpha(base_color, intensity * 0.8); // Slightly transparent
            },
            .portal_ripple => {
                // Bright portal purple for visibility - use discrete purple levels
                return applyIntensityAlpha(selectPurpleByIntensity(intensity), intensity * 0.8);
            },
            .portal_ambient => {
                // Brighter purple for better visibility at low alpha
                return applyIntensityAlpha(selectPurpleByIntensity(intensity * 1.2), intensity);
            },
            .lifestone_glow => {
                // Cyan for lifestones
                return applyIntensityAlpha(selectCyanByIntensity(intensity), intensity * 0.6);
            },
            .lifestone_inner => {
                // Brighter cyan/white for inner lifestone aura
                return applyIntensityAlpha(selectCyanByIntensity(intensity * 1.5), intensity * 0.7);
            },
            .lull_area => {
                // Brighter purple/blue for better visibility
                return applyIntensityAlpha(selectPurpleByIntensity(intensity * 1.2), intensity * 0.7);
            },
            .unit_status_aura => {
                // Soft green/yellow aura for units under beneficial effects
                return applyIntensityAlpha(selectYellowGreenByIntensity(intensity), intensity * 0.7);
            },
        }
    }
};

pub const ParticleSystem = struct {
    particles: [MAX_PARTICLES]Particle,
    count: usize,

    const Self = @This();

    pub fn init() Self {
        return .{
            .particles = undefined,
            .count = 0,
        };
    }

    pub fn clear(self: *Self) void {
        self.count = 0;
    }

    pub fn addParticle(self: *Self, pos: Vec2, radius: f32, particle_type: ParticleType, duration: f32) void {
        const game_log = loggers.getGameLog();

        if (self.count >= MAX_PARTICLES) {
            game_log.warn("particles", "Particle pool full! ({} particles)", .{MAX_PARTICLES});
            return;
        }

        self.particles[self.count] = Particle.init(pos, radius, particle_type, duration);
        self.count += 1;

        // Debug warning when approaching limit
        if (self.count > MAX_PARTICLES * 3 / 4) {
            game_log.warn("particles", "Particle pool usage high: {}/{}", .{ self.count, MAX_PARTICLES });
        }
    }

    pub fn update(self: *Self) void {
        // Remove expired particles
        var write_index: usize = 0;
        for (0..self.count) |read_index| {
            if (self.particles[read_index].isActive()) {
                if (write_index != read_index) {
                    self.particles[write_index] = self.particles[read_index];
                }
                write_index += 1;
            }
        }
        self.count = write_index;
    }

    pub fn getActiveParticles(self: *const Self) []const Particle {
        return self.particles[0..self.count];
    }

    // Particle creation methods for different gameplay events
    pub fn addPlayerSpawnParticle(self: *Self, pos: Vec2, player_radius: f32) void {
        // Dramatic staggered ring expansion mimicking old visuals system
        // Multiple waves with varied timing for less uniformity and better visual drama
        const ring_configs = [_]struct { delay: f32, duration: f32, size_mult: f32, intensity: f32 }{
            .{ .delay = 0.0, .duration = 0.8, .size_mult = 1.4, .intensity = 1.0 },
            .{ .delay = 0.1, .duration = 2.4, .size_mult = 1.8, .intensity = 0.4 },
            .{ .delay = 0.15, .duration = 1.2, .size_mult = 1.2, .intensity = 0.7 },
            .{ .delay = 0.25, .duration = 2.0, .size_mult = 3.4, .intensity = 0.5 },
            .{ .delay = 0.3, .duration = 2.2, .size_mult = 1.4, .intensity = 0.5 },
            .{ .delay = 0.4, .duration = 1.4, .size_mult = 2.4, .intensity = 0.3 },
        };

        for (ring_configs) |config| {
            self.addParticle(pos, player_radius * config.size_mult, .player_spawn, config.duration);
            if (self.count > 0) {
                // Customize the effect we just added
                var particle = &self.particles[self.count - 1];
                particle.start_time += @as(u64, @intFromFloat(config.delay * @as(f32, @floatFromInt(c.sdl.SDL_GetPerformanceFrequency()))));
                particle.intensity = config.intensity;
            }
        }
    }

    pub fn addPortalTravelParticle(self: *Self, pos: Vec2, player_radius: f32) void {
        // Multiple staggered pings when traveling through portals - distinct from spawn
        const ring_configs = [_]struct { delay: f32, duration: f32, size_mult: f32, intensity: f32 }{
            .{ .delay = 0.0, .duration = 0.8, .size_mult = 1.8, .intensity = 1.0 }, // Initial bright ping - perfect as is
            .{ .delay = 0.1, .duration = 3.5, .size_mult = 0.8, .intensity = 0.7 }, // Slow ring - bigger base like first
            .{ .delay = 0.35, .duration = 1.5, .size_mult = 0.2, .intensity = 0.5 }, // Large expansion - bigger base
            .{ .delay = 0.55, .duration = 1.0, .size_mult = 0.8, .intensity = 0.8 }, // Location marker - bigger base
        };

        for (ring_configs) |config| {
            self.addParticle(pos, player_radius * config.size_mult, .portal_travel, config.duration);
            if (self.count > 0) {
                // Customize the effect we just added
                var particle = &self.particles[self.count - 1];
                particle.start_time += @as(u64, @intFromFloat(config.delay * @as(f32, @floatFromInt(c.sdl.SDL_GetPerformanceFrequency()))));
                particle.intensity = config.intensity;
            }
        }
    }

    pub fn addPortalRippleParticle(self: *Self, pos: Vec2, portal_radius: f32) void {
        // Subtle ripples emanating from portal
        const ripple_configs = [_]struct { delay: f32, duration: f32, size_mult: f32, intensity: f32 }{
            .{ .delay = 0.0, .duration = 1.5, .size_mult = 1.4, .intensity = 0.5 }, // First ripple - small, quick
            .{ .delay = 0.2, .duration = 1.25, .size_mult = 1.6, .intensity = 0.4 }, // Second ripple
        };

        for (ripple_configs) |config| {
            if (self.count >= MAX_PARTICLES) break;

            self.particles[self.count] = Particle.init(pos, portal_radius * config.size_mult, .portal_ripple, config.duration);
            self.particles[self.count].start_time += @as(u64, @intFromFloat(config.delay * @as(f32, @floatFromInt(c.sdl.SDL_GetPerformanceFrequency()))));
            self.particles[self.count].intensity = config.intensity;
            self.count += 1;
        }
    }

    pub fn addPortalAmbientParticle(self: *Self, pos: Vec2, portal_radius: f32) void {
        // Single subtle portal effect to reduce visual clutter
        self.addParticle(pos, portal_radius * 1.3, .portal_ambient, 0.0); // Single portal aura
    }

    pub fn addLifestoneGlowParticle(self: *Self, pos: Vec2, lifestone_radius: f32, attuned: bool) void {
        self.addLifestoneGlowEffectParts(pos, lifestone_radius, true, attuned);
    }

    pub fn addLifestoneInnerParticleOnly(self: *Self, pos: Vec2, lifestone_radius: f32) void {
        // Add only the inner effect for newly attuned lifestones
        self.addLifestoneGlowEffectParts(pos, lifestone_radius, false, true);
    }

    pub fn addLullAreaParticle(self: *Self, pos: Vec2, radius: f32, duration: f32) void {
        // Add visible area indicator for Lull spell
        self.addParticle(pos, radius, .lull_area, duration);
    }

    pub fn addUnitStatusAura(self: *Self, pos: Vec2, unit_radius: f32, duration: f32) void {
        // Add glowing aura around units under effects
        self.addParticle(pos, unit_radius * 1.5, .unit_status_aura, duration);
    }

    fn addLifestoneGlowEffectParts(self: *Self, pos: Vec2, lifestone_radius: f32, add_outer: bool, attuned: bool) void {
        // Single lifestone effect to reduce visual clutter
        if (add_outer) {
            const particle_type: ParticleType = if (attuned) .lifestone_inner else .lifestone_glow;
            self.addParticle(pos, lifestone_radius * 1.5, particle_type, 0.0);
        }
    }
};
