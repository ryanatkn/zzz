const std = @import("std");
const timer = @import("../../core/timer.zig");
const math = @import("../../math/mod.zig");

const Vec2 = math.Vec2;
const Timer = timer.Timer;

/// Generic effect duration manager for timed effects (buffs, debuffs, AoE zones)
/// Games define their own effect types and implement effect application logic
/// Effect stacking behavior
pub const StackingType = enum {
    none, // New effect replaces old one
    duration, // New effect extends duration
    intensity, // New effect increases intensity
    independent, // Effects stack independently
};

/// Generic timed effect structure
pub fn TimedEffect(comptime EffectType: type) type {
    return struct {
        const Self = @This();

        effect_type: EffectType,
        timer: Timer,
        intensity: f32 = 1.0,
        source_pos: Vec2 = Vec2.ZERO,
        target_pos: Vec2 = Vec2.ZERO,
        radius: f32 = 0.0,
        stacking_type: StackingType = .none,
        active: bool = true,

        // Game-specific data can be added via EffectType enum fields

        pub fn init(effect_type: EffectType, duration: f32) Self {
            return .{
                .effect_type = effect_type,
                .timer = Timer.init(duration),
            };
        }

        pub fn initWithPosition(effect_type: EffectType, duration: f32, pos: Vec2) Self {
            var effect = Self.init(effect_type, duration);
            effect.target_pos = pos;
            return effect;
        }

        pub fn initAoE(effect_type: EffectType, duration: f32, center: Vec2, radius: f32) Self {
            var effect = Self.init(effect_type, duration);
            effect.target_pos = center;
            effect.radius = radius;
            return effect;
        }

        /// Start the effect timer
        pub fn start(self: *Self) void {
            self.timer.start();
            self.active = true;
        }

        /// Update the effect timer
        pub fn update(self: *Self, delta_time: f32) void {
            if (self.active) {
                self.timer.update(delta_time);
                if (self.timer.isFinished()) {
                    self.active = false;
                }
            }
        }

        /// Check if effect is still active
        pub fn isActive(self: *const Self) bool {
            return self.active and !self.timer.isFinished();
        }

        /// Get effect progress (0.0 = just started, 1.0 = finished)
        pub fn getProgress(self: *const Self) f32 {
            return self.timer.getProgress();
        }

        /// Get remaining time
        pub fn getRemaining(self: *const Self) f32 {
            return self.timer.getRemaining();
        }

        /// Extend effect duration (for stacking)
        pub fn extendDuration(self: *Self, additional_time: f32) void {
            const current_remaining = self.getRemaining();
            self.timer.startWith(current_remaining + additional_time);
        }

        /// Increase effect intensity (for stacking)
        pub fn increaseIntensity(self: *Self, multiplier: f32) void {
            self.intensity *= multiplier;
        }

        /// Deactivate effect immediately
        pub fn deactivate(self: *Self) void {
            self.active = false;
            self.timer.reset();
        }
    };
}

/// Effect manager for handling multiple timed effects
pub fn EffectManager(comptime EffectType: type, comptime max_effects: usize) type {
    const Effect = TimedEffect(EffectType);

    return struct {
        const Self = @This();

        effects: [max_effects]Effect,
        count: usize,

        pub fn init() Self {
            return .{
                .effects = undefined,
                .count = 0,
            };
        }

        /// Add a new effect
        pub fn addEffect(self: *Self, effect: Effect) ?usize {
            // Check for existing effect of same type to handle stacking
            for (0..self.count) |i| {
                if (self.effects[i].effect_type == effect.effect_type and self.effects[i].isActive()) {
                    switch (effect.stacking_type) {
                        .none => {
                            // Replace existing effect
                            self.effects[i] = effect;
                            self.effects[i].start();
                            return i;
                        },
                        .duration => {
                            // Extend duration
                            self.effects[i].extendDuration(effect.timer.duration);
                            return i;
                        },
                        .intensity => {
                            // Increase intensity
                            self.effects[i].increaseIntensity(effect.intensity);
                            self.effects[i].extendDuration(effect.timer.duration);
                            return i;
                        },
                        .independent => {
                            // Fall through to add new effect
                        },
                    }
                }
            }

            // Add new effect if space available
            if (self.count < max_effects) {
                self.effects[self.count] = effect;
                self.effects[self.count].start();
                const index = self.count;
                self.count += 1;
                return index;
            }

            return null; // No space for new effect
        }

        /// Create and add an instant effect
        pub fn addInstantEffect(
            self: *Self,
            effect_type: EffectType,
            pos: Vec2,
            intensity: f32,
        ) ?usize {
            var effect = Effect.initWithPosition(effect_type, 0.1, pos); // Very short duration
            effect.intensity = intensity;
            return self.addEffect(effect);
        }

        /// Create and add an AoE effect
        pub fn addAoEEffect(
            self: *Self,
            effect_type: EffectType,
            center: Vec2,
            radius: f32,
            duration: f32,
            intensity: f32,
        ) ?usize {
            var effect = Effect.initAoE(effect_type, duration, center, radius);
            effect.intensity = intensity;
            return self.addEffect(effect);
        }

        /// Update all effects
        pub fn updateAll(self: *Self, delta_time: f32) void {
            var write_index: usize = 0;

            // Update and compact active effects
            for (0..self.count) |i| {
                self.effects[i].update(delta_time);

                if (self.effects[i].isActive()) {
                    if (write_index != i) {
                        self.effects[write_index] = self.effects[i];
                    }
                    write_index += 1;
                }
            }

            self.count = write_index;
        }

        /// Remove all effects of a specific type
        pub fn removeEffectsOfType(self: *Self, effect_type: EffectType) void {
            var write_index: usize = 0;

            for (0..self.count) |i| {
                if (self.effects[i].effect_type != effect_type) {
                    if (write_index != i) {
                        self.effects[write_index] = self.effects[i];
                    }
                    write_index += 1;
                }
            }

            self.count = write_index;
        }

        /// Get all active effects of a specific type
        pub fn getActiveEffectsOfType(
            self: *const Self,
            effect_type: EffectType,
            buffer: []Effect,
        ) usize {
            var found: usize = 0;

            for (0..self.count) |i| {
                if (self.effects[i].effect_type == effect_type and self.effects[i].isActive()) {
                    if (found < buffer.len) {
                        buffer[found] = self.effects[i];
                        found += 1;
                    }
                }
            }

            return found;
        }

        /// Check if position is affected by any AoE effect of given type
        pub fn isPositionAffected(
            self: *const Self,
            pos: Vec2,
            effect_type: EffectType,
        ) ?*const Effect {
            for (0..self.count) |i| {
                const effect = &self.effects[i];
                if (effect.effect_type == effect_type and effect.isActive() and effect.radius > 0) {
                    const distance = pos.distance(effect.target_pos);
                    if (distance <= effect.radius) {
                        return effect;
                    }
                }
            }
            return null;
        }

        /// Get total intensity of all active effects of a type at position
        pub fn getTotalIntensityAtPosition(
            self: *const Self,
            pos: Vec2,
            effect_type: EffectType,
        ) f32 {
            var total: f32 = 0.0;

            for (0..self.count) |i| {
                const effect = &self.effects[i];
                if (effect.effect_type == effect_type and effect.isActive()) {
                    if (effect.radius > 0) {
                        // AoE effect
                        const distance = pos.distance(effect.target_pos);
                        if (distance <= effect.radius) {
                            // Apply distance falloff
                            const falloff = 1.0 - (distance / effect.radius);
                            total += effect.intensity * falloff;
                        }
                    } else {
                        // Point effect
                        if (pos.distance(effect.target_pos) < 1.0) {
                            total += effect.intensity;
                        }
                    }
                }
            }

            return total;
        }

        /// Clear all effects
        pub fn clear(self: *Self) void {
            self.count = 0;
        }

        /// Get count of active effects
        pub fn getActiveCount(self: *const Self) usize {
            var active: usize = 0;
            for (0..self.count) |i| {
                if (self.effects[i].isActive()) {
                    active += 1;
                }
            }
            return active;
        }
    };
}

/// Utility patterns for effect applications
pub const EffectPatterns = struct {
    /// Apply effect with distance-based intensity falloff
    pub fn applyWithFalloff(
        base_intensity: f32,
        center: Vec2,
        target: Vec2,
        max_radius: f32,
        falloff_curve: FalloffCurve,
    ) f32 {
        const distance = center.distance(target);
        if (distance > max_radius) return 0.0;

        const normalized_distance = distance / max_radius;
        const falloff_multiplier = switch (falloff_curve) {
            .linear => 1.0 - normalized_distance,
            .quadratic => (1.0 - normalized_distance) * (1.0 - normalized_distance),
            .cubic => std.math.pow(f32, 1.0 - normalized_distance, 3.0),
            .exponential => std.math.exp(-3.0 * normalized_distance),
        };

        return base_intensity * falloff_multiplier;
    }

    pub const FalloffCurve = enum {
        linear,
        quadratic,
        cubic,
        exponential,
    };
};
