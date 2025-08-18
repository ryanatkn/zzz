const std = @import("std");
const c = @import("../platform/sdl.zig");

const math = @import("../math/mod.zig");
const core_particles = @import("core.zig");

const Vec2 = math.Vec2;
const Particle = core_particles.Particle;
const ParticleSystem = core_particles.ParticleSystem;
const ParticleType = core_particles.ParticleType;
const MAX_PARTICLES = core_particles.MAX_PARTICLES;

/// Game-specific extension of the core ParticleSystem with ECS integration
pub const GameParticleSystem = struct {
    core: ParticleSystem,

    const Self = @This();

    pub fn init() Self {
        return .{
            .core = ParticleSystem.init(),
        };
    }

    pub fn clear(self: *Self) void {
        self.core.clear();
    }

    pub fn addParticle(self: *Self, pos: Vec2, radius: f32, particle_type: ParticleType, duration: f32) void {
        self.core.addParticle(pos, radius, particle_type, duration);
    }

    pub fn update(self: *Self) void {
        self.core.update();
    }

    pub fn getActiveParticles(self: *const Self) []const Particle {
        return self.core.getActiveParticles();
    }

    // Forward core particle creation methods
    pub fn addPlayerSpawnParticle(self: *Self, pos: Vec2, player_radius: f32) void {
        self.core.addPlayerSpawnParticle(pos, player_radius);
    }

    pub fn addPortalTravelParticle(self: *Self, pos: Vec2, player_radius: f32) void {
        self.core.addPortalTravelParticle(pos, player_radius);
    }

    pub fn addPortalRippleParticle(self: *Self, pos: Vec2, portal_radius: f32) void {
        self.core.addPortalRippleParticle(pos, portal_radius);
    }

    pub fn addPortalAmbientParticle(self: *Self, pos: Vec2, portal_radius: f32) void {
        self.core.addPortalAmbientParticle(pos, portal_radius);
    }

    pub fn addLifestoneGlowParticle(self: *Self, pos: Vec2, lifestone_radius: f32, attuned: bool) void {
        self.core.addLifestoneGlowParticle(pos, lifestone_radius, attuned);
    }

    pub fn addLifestoneInnerParticleOnly(self: *Self, pos: Vec2, lifestone_radius: f32) void {
        self.core.addLifestoneInnerParticleOnly(pos, lifestone_radius);
    }

    pub fn addLullAreaParticle(self: *Self, pos: Vec2, radius: f32, duration: f32) void {
        self.core.addLullAreaParticle(pos, radius, duration);
    }

    pub fn addUnitStatusAura(self: *Self, pos: Vec2, unit_radius: f32, duration: f32) void {
        self.core.addUnitStatusAura(pos, unit_radius, duration);
    }

    /// Game-specific method: Rebuild persistent ambient particles when traveling between zones
    /// This requires ECS world access to query entities in current zone
    pub fn refreshAmbientParticles(self: *Self, world: anytype) void {
        // Clear existing ambient particles while preserving temporary ones
        var write_index: usize = 0;
        for (0..self.core.count) |read_index| {
            const particle = &self.core.particles[read_index];
            if (particle.particle_type != .portal_ambient and particle.particle_type != .lifestone_glow and particle.particle_type != .lifestone_inner) {
                if (write_index != read_index) {
                    self.core.particles[write_index] = self.core.particles[read_index];
                }
                write_index += 1;
            }
        }
        self.core.count = write_index;

        // Create ambient particles for current zone entities using idiomatic iterators
        const zone_storage = world.getZoneStorageConst();

        // Portal ambient particles from current zone
        var portal_iter = world.iteratePortalsInCurrentZone();
        while (portal_iter.next()) |entity_id| {
            if (@constCast(&zone_storage.portals).getComponent(entity_id, .transform)) |transform| {
                self.addPortalAmbientParticle(transform.pos, transform.radius);
            }
        }

        // Lifestone ambient particles from current zone
        var lifestone_iter = world.iterateLifestonesInCurrentZone();
        while (lifestone_iter.next()) |entity_id| {
            if (@constCast(&zone_storage.lifestones).getComponent(entity_id, .transform)) |transform| {
                if (@constCast(&zone_storage.lifestones).getComponent(entity_id, .interactable)) |interactable| {
                    // Check if lifestone is attuned
                    const attuned = interactable.attuned;
                    self.addLifestoneGlowParticle(transform.pos, transform.radius, attuned);
                }
            }
        }
    }
};
