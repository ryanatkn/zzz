const std = @import("std");
const BoundedArray = std.BoundedArray;

const EntityId = u32;

/// Statuses - temporary modifiers that stack
/// Sparse storage - only affected entities have this
pub const Statuses = struct {
    pub const ModifierType = enum {
        speed_mult,
        damage_mult,
        aggro_mult,
        cooldown_mult,
        radius_mult,
        health_regen,
        damage_resist,
    };

    pub const StackType = enum {
        replace, // New replaces old
        add, // Values add together
        multiply, // Values multiply
        max, // Take maximum value
        min, // Take minimum value
    };

    pub const Modifier = struct {
        type: ModifierType,
        value: f32,
        duration: f32,
        stack_type: StackType,
        source: EntityId,
    };

    modifiers: BoundedArray(Modifier, 16),

    pub fn init() Statuses {
        return .{
            .modifiers = BoundedArray(Modifier, 16).init(0) catch |err| {
                std.log.err("Failed to initialize Statuses modifiers array: {}", .{err});
                @panic("Statuses component initialization failed");
            },
        };
    }

    pub fn addModifier(self: *Statuses, modifier: Modifier) !void {
        try self.modifiers.append(modifier);
    }

    pub fn update(self: *Statuses, dt: f32) void {
        var i: usize = 0;
        while (i < self.modifiers.len) {
            self.modifiers.buffer[i].duration -= dt;
            if (self.modifiers.buffer[i].duration <= 0) {
                _ = self.modifiers.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    pub fn getModifiedValue(self: Statuses, base: f32, modifier_type: ModifierType) f32 {
        var result = base;
        var multiplicative: f32 = 1.0;

        for (self.modifiers.slice()) |mod| {
            if (mod.type != modifier_type) continue;

            switch (mod.stack_type) {
                .replace => result = mod.value,
                .add => result += mod.value - base,
                .multiply => multiplicative *= mod.value,
                .max => result = @max(result, mod.value),
                .min => result = @min(result, mod.value),
            }
        }

        return result * multiplicative;
    }

    /// Get aggro multiplier for this entity (1.0 = normal aggro)
    pub fn getAggroMultiplier(self: Statuses) f32 {
        return self.getModifiedValue(1.0, .aggro_mult);
    }
};
