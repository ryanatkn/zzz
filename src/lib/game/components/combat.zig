/// Combat - offensive capabilities
/// Sparse storage - only combatants have this
pub const Combat = struct {
    damage: f32,
    attack_rate: f32, // Attacks per second
    projectile_speed: f32,
    projectile_lifetime: f32,
    last_attack_time: f32,

    pub fn init(damage: f32, attack_rate: f32) Combat {
        return .{
            .damage = damage,
            .attack_rate = attack_rate,
            .projectile_speed = 300.0,
            .projectile_lifetime = 4.0,
            .last_attack_time = 0,
        };
    }

    pub fn canAttack(self: Combat, current_time: f32) bool {
        return (current_time - self.last_attack_time) >= (1.0 / self.attack_rate);
    }

    pub fn recordAttack(self: *Combat, current_time: f32) void {
        self.last_attack_time = current_time;
    }
};