const EntityId = u32;

/// Charmable - can be controlled by charm/command spells
/// Sparse storage - only entities that can be charmed have this
pub const Charmable = struct {
    charmed: bool = false,
    original_controller: EntityId = @import("std").math.maxInt(EntityId), // Store original controller
    charm_duration: f32 = 0,
    charm_strength: f32 = 1.0, // Resistance factor (0.5 = half duration, 2.0 = double duration)
    max_charm_duration: f32 = 10.0,
    can_be_charmed: bool = true,

    pub fn init(max_duration: f32, resistance: f32) Charmable {
        return .{
            .charmed = false,
            .original_controller = @import("std").math.maxInt(EntityId),
            .charm_duration = 0,
            .charm_strength = resistance,
            .max_charm_duration = max_duration,
            .can_be_charmed = true,
        };
    }

    pub fn startCharm(self: *Charmable, caster: EntityId, duration: f32) bool {
        if (!self.can_be_charmed or self.charmed) return false;

        self.charmed = true;
        self.original_controller = caster;
        // Apply resistance factor
        self.charm_duration = @min(duration * self.charm_strength, self.max_charm_duration);
        return true;
    }

    pub fn endCharm(self: *Charmable) void {
        self.charmed = false;
        self.original_controller = @import("std").math.maxInt(EntityId);
        self.charm_duration = 0;
    }

    pub fn update(self: *Charmable, dt: f32) bool {
        if (!self.charmed) return false;

        self.charm_duration -= dt;
        if (self.charm_duration <= 0) {
            self.endCharm();
            return true; // Charm ended this frame
        }
        return false;
    }

    pub fn isCharmed(self: Charmable) bool {
        return self.charmed;
    }

    pub fn getController(self: Charmable) EntityId {
        if (self.charmed) return self.original_controller;
        return @import("std").math.maxInt(EntityId); // Invalid controller when not charmed
    }
};
