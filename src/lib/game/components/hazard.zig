/// Hazard - marks entities that cause damage/death on contact
/// Sparse storage - only dangerous entities have this
pub const Hazard = struct {
    pub const HazardType = enum {
        pit,        // Fall damage/death
        spikes,     // Piercing damage
        fire,       // Burn damage
        poison,     // Poison damage over time
        crushing,   // Instant death
        environmental, // Generic environmental hazard
    };

    hazard_type: HazardType,
    damage: f32,
    deadly: bool, // If true, causes instant death regardless of damage value
    damage_over_time: bool, // If true, applies damage continuously
    damage_interval: f32, // Seconds between damage applications (for DoT)

    pub fn init(hazard_type: HazardType, damage: f32) Hazard {
        return .{
            .hazard_type = hazard_type,
            .damage = damage,
            .deadly = switch (hazard_type) {
                .pit, .crushing => true, // Instant death hazards
                else => false,
            },
            .damage_over_time = switch (hazard_type) {
                .fire, .poison => true, // DoT hazards
                else => false,
            },
            .damage_interval = 1.0, // Default: 1 damage per second
        };
    }

    pub fn createDeadlyPit() Hazard {
        return .{
            .hazard_type = .pit,
            .damage = 999.0, // High damage, but deadly=true makes this irrelevant
            .deadly = true,
            .damage_over_time = false,
            .damage_interval = 0.0,
        };
    }

    pub fn createSpikes(damage: f32) Hazard {
        return .{
            .hazard_type = .spikes,
            .damage = damage,
            .deadly = false,
            .damage_over_time = false,
            .damage_interval = 0.0,
        };
    }

    pub fn createFire(damage_per_second: f32) Hazard {
        return .{
            .hazard_type = .fire,
            .damage = damage_per_second,
            .deadly = false,
            .damage_over_time = true,
            .damage_interval = 1.0,
        };
    }
};