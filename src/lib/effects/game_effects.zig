const std = @import("std");
const c = @import("../platform/sdl.zig");

const math = @import("../math/mod.zig");
const core_effects = @import("core.zig");

const Vec2 = math.Vec2;
const Effect = core_effects.Effect;
const EffectSystem = core_effects.EffectSystem;
const EffectType = core_effects.EffectType;
const MAX_EFFECTS = core_effects.MAX_EFFECTS;

/// Game-specific extension of the core EffectSystem with ECS integration
pub const GameEffectSystem = struct {
    core: EffectSystem,

    const Self = @This();

    pub fn init() Self {
        return .{
            .core = EffectSystem.init(),
        };
    }

    pub fn clear(self: *Self) void {
        self.core.clear();
    }

    pub fn addEffect(self: *Self, pos: Vec2, radius: f32, effect_type: EffectType, duration: f32) void {
        self.core.addEffect(pos, radius, effect_type, duration);
    }

    pub fn update(self: *Self) void {
        self.core.update();
    }

    pub fn getActiveEffects(self: *const Self) []const Effect {
        return self.core.getActiveEffects();
    }

    // Forward core effect creation methods
    pub fn addPlayerSpawnEffect(self: *Self, pos: Vec2, player_radius: f32) void {
        self.core.addPlayerSpawnEffect(pos, player_radius);
    }

    pub fn addPortalTravelEffect(self: *Self, pos: Vec2, player_radius: f32) void {
        self.core.addPortalTravelEffect(pos, player_radius);
    }

    pub fn addPortalRippleEffect(self: *Self, pos: Vec2, portal_radius: f32) void {
        self.core.addPortalRippleEffect(pos, portal_radius);
    }

    pub fn addPortalAmbientEffect(self: *Self, pos: Vec2, portal_radius: f32) void {
        self.core.addPortalAmbientEffect(pos, portal_radius);
    }

    pub fn addLifestoneGlowEffect(self: *Self, pos: Vec2, lifestone_radius: f32, attuned: bool) void {
        self.core.addLifestoneGlowEffect(pos, lifestone_radius, attuned);
    }

    pub fn addLifestoneInnerEffectOnly(self: *Self, pos: Vec2, lifestone_radius: f32) void {
        self.core.addLifestoneInnerEffectOnly(pos, lifestone_radius);
    }

    pub fn addLullAreaEffect(self: *Self, pos: Vec2, radius: f32, duration: f32) void {
        self.core.addLullAreaEffect(pos, radius, duration);
    }

    pub fn addUnitEffectAura(self: *Self, pos: Vec2, unit_radius: f32, duration: f32) void {
        self.core.addUnitEffectAura(pos, unit_radius, duration);
    }

    /// Game-specific method: Rebuild persistent ambient effects when traveling between zones
    /// This requires ECS world access to query entities in current zone
    pub fn refreshAmbientEffects(self: *Self, world: anytype) void {
        // Clear existing ambient effects while preserving temporary ones
        var write_index: usize = 0;
        for (0..self.core.count) |read_index| {
            const effect = &self.core.effects[read_index];
            if (effect.effect_type != .portal_ambient and effect.effect_type != .lifestone_glow and effect.effect_type != .lifestone_inner) {
                if (write_index != read_index) {
                    self.core.effects[write_index] = self.core.effects[read_index];
                }
                write_index += 1;
            }
        }
        self.core.count = write_index;

        // Create ambient effects for current zone entities using idiomatic iterators
        const ecs_world = world.getECSWorld();

        // Portal ambient effects from current zone
        var portal_iter = world.iteratePortalsInCurrentZone();
        while (portal_iter.next()) |entry| {
            const entity_id = entry.key_ptr.*;
            if (ecs_world.transforms.getConst(entity_id)) |transform| {
                self.addPortalAmbientEffect(transform.pos, transform.radius);
            }
        }

        // Lifestone ambient effects from current zone
        var lifestone_iter = world.iterateLifestonesInCurrentZone();
        while (lifestone_iter.next()) |entry| {
            const entity_id = entry.key_ptr.*;
            if (ecs_world.transforms.getConst(entity_id)) |transform| {
                if (ecs_world.interactables.getConst(entity_id)) |interactable| {
                    // Check if lifestone is attuned
                    const attuned = interactable.attuned;
                    self.addLifestoneGlowEffect(transform.pos, transform.radius, attuned);
                }
            }
        }
    }
};