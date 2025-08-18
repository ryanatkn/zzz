/// Health - life management component
/// Dense storage - most gameplay entities have this
pub const Health = struct {
    current: f32,
    max: f32,
    alive: bool,

    pub fn init(max_health: f32) Health {
        return .{
            .current = max_health,
            .max = max_health,
            .alive = true,
        };
    }

    pub fn damage(self: *Health, amount: f32) void {
        self.current = @max(0, self.current - amount);
        if (self.current <= 0) {
            self.alive = false;
        }
    }

    pub fn heal(self: *Health, amount: f32) void {
        self.current = @min(self.max, self.current + amount);
        if (self.current > 0) {
            self.alive = true;
        }
    }

    pub fn getPercent(self: Health) f32 {
        return if (self.max > 0) self.current / self.max else 0;
    }
};