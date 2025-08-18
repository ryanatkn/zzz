const math = @import("../../math/mod.zig");
pub const Vec2 = math.Vec2;

/// Teleportable - can be teleported via blink spell
/// Sparse storage - only entities that can teleport have this
pub const Teleportable = struct {
    can_blink: bool = true,
    blink_range: f32 = 200.0, // Maximum blink distance
    last_blink_time: f32 = 0,
    blink_cooldown: f32 = 0.5, // Minimum time between blinks
    invulnerable_after_blink: f32 = 0.2, // Brief invulnerability window
    invulnerable_timer: f32 = 0,

    pub fn init(range: f32, cooldown: f32) Teleportable {
        return .{
            .can_blink = true,
            .blink_range = range,
            .last_blink_time = 0,
            .blink_cooldown = cooldown,
            .invulnerable_after_blink = 0.2,
            .invulnerable_timer = 0,
        };
    }

    pub fn canBlinkNow(self: Teleportable, current_time: f32) bool {
        return self.can_blink and (current_time - self.last_blink_time) >= self.blink_cooldown;
    }

    pub fn canBlinkToPosition(self: Teleportable, from: Vec2, to: Vec2) bool {
        if (!self.can_blink) return false;

        const distance = from.sub(to).length();
        return distance <= self.blink_range;
    }

    pub fn performBlink(self: *Teleportable, current_time: f32) void {
        self.last_blink_time = current_time;
        self.invulnerable_timer = self.invulnerable_after_blink;
    }

    pub fn update(self: *Teleportable, dt: f32) void {
        if (self.invulnerable_timer > 0) {
            self.invulnerable_timer -= dt;
        }
    }

    pub fn isInvulnerable(self: Teleportable) bool {
        return self.invulnerable_timer > 0;
    }

    pub fn getRemainingCooldown(self: Teleportable, current_time: f32) f32 {
        const elapsed = current_time - self.last_blink_time;
        return @max(0, self.blink_cooldown - elapsed);
    }
};
