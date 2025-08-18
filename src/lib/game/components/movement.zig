/// Movement - locomotion properties
/// Dense storage - most moving entities have this
pub const Movement = struct {
    speed: f32,
    walk_speed: f32,
    can_move_freely: bool,

    pub fn init(speed: f32) Movement {
        return .{
            .speed = speed,
            .walk_speed = speed * 0.5,
            .can_move_freely = true,
        };
    }

    pub fn getCurrentSpeed(self: Movement, is_walking: bool) f32 {
        return if (is_walking) self.walk_speed else self.speed;
    }
};
