const EntityId = u32;

/// Projectile - for moving projectile entities (bullets, spells, etc.)
/// Sparse storage - only projectiles have this
pub const Projectile = struct {
    owner: EntityId,
    lifetime: f32,
    max_lifetime: f32,
    pierce_count: u8,
    max_pierce: u8,

    pub fn init(owner: EntityId, max_lifetime: f32) Projectile {
        return .{
            .owner = owner,
            .lifetime = 0,
            .max_lifetime = max_lifetime,
            .pierce_count = 0,
            .max_pierce = 1,
        };
    }

    pub fn update(self: *Projectile, dt: f32) bool {
        self.lifetime += dt;
        return self.lifetime < self.max_lifetime and self.pierce_count < self.max_pierce;
    }

    pub fn canPierce(self: Projectile) bool {
        return self.pierce_count < self.max_pierce;
    }

    pub fn pierce(self: *Projectile) void {
        self.pierce_count += 1;
    }
};
